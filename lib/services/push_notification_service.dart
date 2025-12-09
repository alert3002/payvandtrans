import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import '../constants/api_constants.dart';
import '../order_detail_page.dart';
import 'notification_history_service.dart';

/// Сервис для работы с push-уведомлениями Firebase
class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static BuildContext? _context;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  // ID канала для Android уведомлений
  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'Уведомления о заказах';
  static const String _channelDescription = 'Уведомления об изменениях статусов заказов и заявок';
  
  // Callback для обновления UI при получении уведомлений
  static Function(Map<String, dynamic>)? onBalanceUpdate;
  static Function()? onRequestStatusUpdate;

  /// Инициализация push-уведомлений
  static Future<void> initPushNotifications(BuildContext context) async {
    _context = context;

    try {
      // 0. Проверяем, что Firebase инициализирован
      try {
        final apps = Firebase.apps;
        if (apps.isEmpty) {
          print('⚠️ Firebase не инициализирован. Инициализация...');
          await Firebase.initializeApp();
        }
      } catch (e) {
        print('❌ Ошибка проверки Firebase: $e');
        return;
      }

      // 1. Инициализация локальных уведомлений (для Android канала)
      await _initializeLocalNotifications();

      // 2. Запрос разрешения на уведомления
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Пользователь разрешил уведомления');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ Пользователь предоставил временное разрешение');
      } else {
        print('❌ Пользователь отклонил уведомления');
        return;
      }

      // 3. Получение FCM токена
      String? token = await _messaging.getToken();
      if (token != null) {
        print('📱 FCM Token: $token');
        // 4. Отправка токена на backend
        await _sendTokenToBackend(token);
      } else {
        print('⚠️ Не удалось получить FCM токен');
      }

      // 5. Обработка обновления токена
      _messaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token обновлен: $newToken');
        _sendTokenToBackend(newToken);
      });

      // 6. Настройка обработки уведомлений
      _setupMessageHandlers();

    } catch (e) {
      print('❌ Ошибка инициализации push-уведомлений: $e');
    }
  }

  /// Инициализация локальных уведомлений и создание канала для Android 8.0+
  static Future<void> _initializeLocalNotifications() async {
    // Проверяем платформу безопасно (без использования Platform на Web)
    if (kIsWeb) return;
    if (!io.Platform.isAndroid) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Обработка клика по локальному уведомлению
        if (response.payload != null) {
          try {
            final data = json.decode(response.payload!);
            if (data is Map<String, dynamic>) {
              _handleNotificationClickFromPayload(data);
            }
          } catch (e) {
            print('⚠️ Ошибка обработки payload уведомления: $e');
          }
        }
      },
    );

    // Создание канала для Android 8.0+ (Oreo)
    // Используем кастомный звук если есть, иначе системный
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      // Звук канала (можно указать кастомный через sound)
      // sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('✅ Канал уведомлений создан: $_channelName');
  }

  /// Отправка FCM токена на backend
  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? authToken = prefs.getString('token');

      if (authToken == null) {
        print('⚠️ Пользователь не авторизован, токен не отправлен');
        return;
      }

      // Определяем тип устройства безопасно
      String deviceType = 'android'; // По умолчанию для Android
      if (!kIsWeb) {
        if (io.Platform.isIOS) {
          deviceType = 'ios';
        } else if (io.Platform.isAndroid) {
          deviceType = 'android';
        }
      }

      final response = await http.post(
        ApiConstants.getUri('api/fcm/device/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'registration_id': token,
          'type': deviceType,
          'name': kIsWeb ? 'Web Device' : '${io.Platform.operatingSystem} Device',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ FCM токен успешно отправлен на сервер: ${data['message']}');
      } else {
        print('❌ Ошибка отправки FCM токена: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Ошибка при отправке FCM токена: $e');
    }
  }

  // Хранилище для предотвращения дублирования уведомлений
  static final Set<String> _processedNotifications = <String>{};
  static const Duration _deduplicationWindow = Duration(minutes: 1);

  /// Настройка обработчиков сообщений
  static void _setupMessageHandlers() {
    // Обработка уведомлений, когда приложение открыто (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📬 Получено уведомление (foreground): ${message.notification?.title}');
      
      // Предотвращение дублирования уведомлений
      final messageId = message.messageId ?? 
                       '${message.data['order_id'] ?? message.data['request_id']}_${message.notification?.title}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}';
      
      if (_processedNotifications.contains(messageId)) {
        print('⚠️ Дубликат уведомления пропущен: $messageId');
        return;
      }
      
      _processedNotifications.add(messageId);
      // Очистка старых ID каждую минуту
      Future.delayed(_deduplicationWindow, () {
        _processedNotifications.remove(messageId);
      });
      
      // Формируем улучшенный текст для истории
      final data = message.data;
      String notificationBody = _formatNotificationBody(
        message.notification?.body ?? '', 
        data
      );
      
      // Сохраняем в историю
      if (message.notification != null) {
        final data = message.data;
        await NotificationHistoryService.saveNotification(
          title: message.notification!.title ?? 'Уведомление',
          body: notificationBody,
          data: data,
        );
        
        // Обработка специальных типов уведомлений для обновления UI
        _handleSpecialNotifications(data);
      }

      // Показываем локальное уведомление для Android
      if (!kIsWeb && io.Platform.isAndroid && message.notification != null) {
        await _showLocalNotification(message);
      }
      
      // Показываем SnackBar
      if (_context != null) {
        _showNotificationSnackBar(message);
      }
    });

    // Обработка клика по уведомлению, когда приложение в фоне
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('👆 Пользователь открыл уведомление: ${message.notification?.title}');
      
        // Сохраняем в историю с улучшенным текстом
        if (message.notification != null) {
          final data = message.data;
          final formattedBody = _formatNotificationBody(
            message.notification!.body ?? '',
            data
          );
          
          await NotificationHistoryService.saveNotification(
            title: message.notification!.title ?? 'Уведомление',
            body: formattedBody,
            data: message.data,
          );
          
          // Обработка специальных типов уведомлений
          _handleSpecialNotifications(data);
        }
        
        _handleNotificationClick(message);
    });

    // Обработка уведомления, которое открыло приложение (когда оно было закрыто)
    _messaging.getInitialMessage().then((RemoteMessage? message) async {
      if (message != null) {
        print('🚀 Приложение открыто из уведомления: ${message.notification?.title}');
        
        // Сохраняем в историю с улучшенным текстом
        if (message.notification != null) {
          final data = message.data;
          final formattedBody = _formatNotificationBody(
            message.notification!.body ?? '',
            data
          );
          
          await NotificationHistoryService.saveNotification(
            title: message.notification!.title ?? 'Уведомление',
            body: formattedBody,
            data: message.data,
          );
          
          // Обработка специальных типов уведомлений
          _handleSpecialNotifications(data);
        }
        
        _handleNotificationClick(message);
      }
    });
  }

  /// Показ локального уведомления для Android
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb || !io.Platform.isAndroid || message.notification == null) return;

    final notification = message.notification!;
    final data = message.data;
    
    // Формируем улучшенный текст уведомления
    String notificationBody = _formatNotificationBody(notification.body ?? '', data);
    
    // Используем кастомный звук (если есть) или системный
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      // Кастомная иконка для уведомлений (имя ресурса без префикса)
      icon: 'launcher_icon',
      // Кастомный звук (если файл notification_sound.mp3 есть в res/raw)
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      // Если кастомного звука нет, используем системный по умолчанию
      // sound: null, // будет использован звук канала
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification.title,
      notificationBody,
      notificationDetails,
      payload: json.encode(message.data),
    );
  }

  /// Форматирование текста уведомления с дополнительной информацией
  static String _formatNotificationBody(String baseBody, Map<String, dynamic> data) {
    String body = baseBody;
    
    // Определяем тип уведомления
    final notificationType = data['type'] ?? data['notification_type'] ?? '';
    final status = data['status'] ?? data['new_status'] ?? '';
    final oldStatus = data['old_status'] ?? '';
    final baseBodyLower = baseBody.toLowerCase();
    
    // Обработка уведомлений о балансе водителя
    if (notificationType == 'balance_update' || 
        notificationType == 'balance_replenished' ||
        baseBodyLower.contains('баланс пополнен') ||
        baseBodyLower.contains('баланс минус')) {
      return _formatBalanceNotification(baseBody, data);
    }
    
    // Обработка специальных типов уведомлений
    if (notificationType == 'driver_found' || 
        baseBodyLower.contains('водитель найден') || 
        baseBodyLower.contains('driver found')) {
      // Уведомление "Водитель найден!"
      final carNumber = data['car_number'] ?? data['carNumber'] ?? '';
      final driverName = data['driver_name'] ?? data['driverName'] ?? '';
      
      // Номер машины обязателен для этого типа уведомления
      if (carNumber.toString().isNotEmpty) {
        body = baseBody; // Сохраняем оригинальный текст
        body += '\n🚗 Номер машины: $carNumber';
      } else {
        // Если номера нет, добавляем информацию о заявке
        final requestId = data['request_id'] ?? data['order_id'] ?? '';
        if (requestId.toString().isNotEmpty) {
          body += '\n📋 Заявка №$requestId';
        }
      }
      
      if (driverName.toString().isNotEmpty) {
        body += '\n👤 Водитель: $driverName';
      }
    } else if (notificationType == 'car_departed' || 
               baseBody.toLowerCase().contains('машина выехала') ||
               baseBody.toLowerCase().contains('car departed')) {
      // Уведомление "Машина выехала к вам"
      final carNumber = data['car_number'] ?? data['carNumber'] ?? data['car_number'] ?? '';
      final estimatedTime = data['estimated_time'] ?? data['estimatedTime'] ?? '';
      
      if (carNumber.toString().isNotEmpty) {
        body += '\n🚗 Номер машины: $carNumber';
      }
      if (estimatedTime.toString().isNotEmpty) {
        body += '\n⏱ Примерное время прибытия: $estimatedTime';
      }
    } else if (status == 'rejected' || oldStatus == 'rejected') {
      // Обработка отклоненных заказов
      final orderId = data['order_id'] ?? data['request_id'] ?? '';
      if (orderId.toString().isNotEmpty) {
        body = 'Ваш заказ под №$orderId отклонен';
        final reason = data['rejection_reason'] ?? data['reason'] ?? '';
        if (reason.toString().isNotEmpty) {
          body += '\nПричина: $reason';
        }
      }
    } else if (status == 'active') {
      // Статус стал "актив" (независимо от старого статуса)
      final requestId = data['request_id'] ?? data['order_id'] ?? '';
      String routeInfo = '';
      String priceInfo = '';
      String weightInfo = '';
      
      // Добавляем маршрут
      final originCity = data['origin_city'] ?? data['from_city'] ?? data['originCity'] ?? '';
      final destCity = data['dest_city'] ?? data['to_city'] ?? data['destCity'] ?? '';
      if (originCity.toString().isNotEmpty && destCity.toString().isNotEmpty) {
        routeInfo = '\nМаршрут: $originCity → $destCity';
      }
      
      // Добавляем сумму
      final price = data['price'] ?? data['amount'] ?? data['sum'] ?? '';
      if (price.toString().isNotEmpty) {
        final priceValue = double.tryParse(price.toString());
        if (priceValue != null) {
          priceInfo = '\nСумма: ${priceValue.toStringAsFixed(0)} сомон';
        } else {
          priceInfo = '\nСумма: $price сомон';
        }
      }
      
      // Добавляем вес
      final weight = data['weight'] ?? data['tonnage'] ?? data['tonnage_t'] ?? '';
      if (weight.toString().isNotEmpty) {
        final weightValue = double.tryParse(weight.toString());
        if (weightValue != null) {
          weightInfo = '\nВес: ${weightValue.toStringAsFixed(0)} т';
        } else {
          weightInfo = '\nВес: $weight т';
        }
      }
      
      if (requestId.toString().isNotEmpty) {
        if (oldStatus == 'pending') {
          body = 'Заявка №$requestId одобрена и стала активной';
        } else {
          body = 'Заявка №$requestId стала активной';
        }
        body += routeInfo + priceInfo + weightInfo;
      } else {
        // Если нет ID заявки, добавляем информацию к базовому тексту
        body += routeInfo + priceInfo + weightInfo;
      }
    } else if (status.isNotEmpty && oldStatus.isNotEmpty && status != oldStatus) {
      // Общее изменение статуса
      final orderId = data['order_id'] ?? data['request_id'] ?? '';
      if (orderId.toString().isNotEmpty) {
        body += '\n📋 Заявка №$orderId: $oldStatus → $status';
      }
    } else {
      // Добавляем номер машины для других типов уведомлений (если есть)
      if (data.containsKey('car_number') || data.containsKey('carNumber')) {
        final carNumber = data['car_number'] ?? data['carNumber'] ?? '';
        if (carNumber.toString().isNotEmpty) {
          body += '\n🚗 Номер машины: $carNumber';
        }
      }
      
      // Добавляем информацию о маршруте, сумме и весе для новых заявок
      final originCity = data['origin_city'] ?? data['from_city'] ?? data['originCity'] ?? '';
      final destCity = data['dest_city'] ?? data['to_city'] ?? data['destCity'] ?? '';
      if (originCity.toString().isNotEmpty && destCity.toString().isNotEmpty) {
        body += '\nМаршрут: $originCity → $destCity';
      }
      
      final price = data['price'] ?? data['amount'] ?? data['sum'] ?? '';
      if (price.toString().isNotEmpty) {
        final priceValue = double.tryParse(price.toString());
        if (priceValue != null) {
          body += '\nСумма: ${priceValue.toStringAsFixed(0)} сомон';
        } else {
          body += '\nСумма: $price сомон';
        }
      }
      
      final weight = data['weight'] ?? data['tonnage'] ?? data['tonnage_t'] ?? '';
      if (weight.toString().isNotEmpty) {
        final weightValue = double.tryParse(weight.toString());
        if (weightValue != null) {
          body += '\nВес: ${weightValue.toStringAsFixed(0)} т';
        } else {
          body += '\nВес: $weight т';
        }
      }
    }
    
    // Добавляем дополнительную информацию если есть
    final additionalInfo = data['additional_info'] ?? data['info'] ?? '';
    if (additionalInfo.toString().isNotEmpty) {
      body += '\n$additionalInfo';
    }
    
    return body;
  }

  /// Форматирование уведомления о балансе
  static String _formatBalanceNotification(String baseBody, Map<String, dynamic> data) {
    final balanceType = data['balance_type'] ?? data['type'] ?? '';
    final amount = data['amount'] ?? data['sum'] ?? '';
    final balance = data['balance'] ?? data['remaining_balance'] ?? data['current_balance'] ?? '';
    final requestId = data['request_id'] ?? data['order_id'] ?? '';
    
    String body = '';
    
    // Пополнение баланса
    if (balanceType == 'replenished' || 
        balanceType == 'balance_replenished' ||
        baseBody.toLowerCase().contains('пополнен')) {
      body = 'Ваш баланс пополнен!';
      if (amount.toString().isNotEmpty) {
        final amountValue = double.tryParse(amount.toString());
        if (amountValue != null) {
          body += '\nСумма: ${amountValue.toStringAsFixed(0)} сомон';
        } else {
          body += '\nСумма: $amount сомон';
        }
      }
      if (balance.toString().isNotEmpty) {
        final balanceValue = double.tryParse(balance.toString());
        if (balanceValue != null) {
          body += '\nОстаток: ${balanceValue.toStringAsFixed(0)} сомон';
        } else {
          body += '\nОстаток: $balance сомон';
        }
      }
    } 
    // Списание баланса
    else if (balanceType == 'deducted' || 
             balanceType == 'balance_deducted' ||
             baseBody.toLowerCase().contains('минус') ||
             baseBody.toLowerCase().contains('списан')) {
      body = 'Ваш баланс уменьшен';
      if (amount.toString().isNotEmpty) {
        final amountValue = double.tryParse(amount.toString());
        if (amountValue != null) {
          body += ' на ${amountValue.toStringAsFixed(0)} сомон';
        } else {
          body += ' на $amount сомон';
        }
      }
      if (requestId.toString().isNotEmpty) {
        body += ' для заявки №$requestId';
      }
      if (balance.toString().isNotEmpty) {
        final balanceValue = double.tryParse(balance.toString());
        if (balanceValue != null) {
          body += '\nОстаток: ${balanceValue.toStringAsFixed(0)} сомон';
        } else {
          body += '\nОстаток: $balance сомон';
        }
      }
    } else {
      // Общий случай изменения баланса
      body = baseBody;
      if (amount.toString().isNotEmpty) {
        final amountValue = double.tryParse(amount.toString());
        if (amountValue != null) {
          body += '\nСумма: ${amountValue.toStringAsFixed(0)} сомон';
        } else {
          body += '\nСумма: $amount сомон';
        }
      }
      if (balance.toString().isNotEmpty) {
        final balanceValue = double.tryParse(balance.toString());
        if (balanceValue != null) {
          body += '\nОстаток: ${balanceValue.toStringAsFixed(0)} сомон';
        } else {
          body += '\nОстаток: $balance сомон';
        }
      }
    }
    
    return body;
  }

  /// Обработка специальных уведомлений для обновления UI
  static void _handleSpecialNotifications(Map<String, dynamic> data) {
    final notificationType = data['type'] ?? data['notification_type'] ?? '';
    
    // Обновление баланса
    if (notificationType == 'balance_update' || 
        notificationType == 'balance_replenished' ||
        notificationType == 'balance_deducted') {
      if (onBalanceUpdate != null) {
        onBalanceUpdate!(data);
      }
    }
    
    // Обновление статуса заявки
    final status = data['status'] ?? data['new_status'] ?? '';
    if (status.isNotEmpty) {
      if (onRequestStatusUpdate != null) {
        onRequestStatusUpdate!();
      }
    }
  }

  /// Обработка клика по уведомлению из payload
  static void _handleNotificationClickFromPayload(Map<String, dynamic> data) {
    if (_context == null) return;

    // Приоритет: request_id (заявка) важнее order_id (заказ)
    int? requestId;
    if (data.containsKey('request_id')) {
      requestId = int.tryParse(data['request_id'].toString());
    } else if (data.containsKey('order_id')) {
      requestId = int.tryParse(data['order_id'].toString());
    }
    
    if (requestId != null && requestId > 0) {
      // Получаем роль пользователя из SharedPreferences, а не из data
      // Это гарантирует, что клиент увидит свою заявку, а не заявку водителя
      SharedPreferences.getInstance().then((prefs) {
        final userRole = prefs.getString('role') ?? data['user_role'] ?? 'driver';
        
        try {
          // Используем pushAndRemoveUntil чтобы очистить стек навигации
          // и оставить только главную страницу, затем добавить OrderDetailPage
          Navigator.of(_context!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => OrderDetailPage(
                requestId: requestId!,
                userRole: userRole,
              ),
            ),
            (route) {
              // Оставляем только главную страницу (MainScreen) в стеке
              // Все остальные страницы удаляются
              return route.isFirst;
            },
          );
        } catch (e) {
          print('⚠️ Ошибка навигации к заявке: $e');
        }
      });
    }
  }

  /// Показ SnackBar для уведомления в foreground
  static void _showNotificationSnackBar(RemoteMessage message) {
    if (_context == null) return;

    final notification = message.notification;
    if (notification == null) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.title != null)
              Text(
                notification.title!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            if (notification.body != null)
              Text(notification.body!),
          ],
        ),
        backgroundColor: const Color(0xFF2a2a2e),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Открыть',
          textColor: const Color(0xFFdcd232),
          onPressed: () {
            _handleNotificationClick(message);
          },
        ),
      ),
    );
  }

  /// Обработка клика по уведомлению
  static void _handleNotificationClick(RemoteMessage message) {
    if (_context == null) return;

    final data = message.data;
    
    // Приоритет: request_id (заявка) важнее order_id (заказ)
    // Для клиентов это заявка, для водителей это тоже заявка (request)
    int? requestId;
    if (data.containsKey('request_id')) {
      requestId = int.tryParse(data['request_id'].toString());
    } else if (data.containsKey('order_id')) {
      // Если есть только order_id, используем его как request_id
      // так как OrderDetailPage использует requestId
      requestId = int.tryParse(data['order_id'].toString());
    }
    
    if (requestId != null && requestId > 0) {
      // Получаем роль пользователя из SharedPreferences, а не из data
      // Это гарантирует, что клиент увидит свою заявку, а не заявку водителя
      SharedPreferences.getInstance().then((prefs) {
        final userRole = prefs.getString('role') ?? data['user_role'] ?? 'driver';
        
        print('📦 Открываем заявку: $requestId (userRole: $userRole)');
        
        try {
          // Используем pushAndRemoveUntil чтобы очистить стек навигации
          // и оставить только главную страницу, затем добавить OrderDetailPage
          Navigator.of(_context!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => OrderDetailPage(
                requestId: requestId!,
                userRole: userRole,
              ),
            ),
            (route) {
              // Оставляем только главную страницу (MainScreen) в стеке
              // Все остальные страницы удаляются
              return route.isFirst;
            },
          );
        } catch (e) {
          print('⚠️ Ошибка навигации к заявке: $e');
          ScaffoldMessenger.of(_context!).showSnackBar(
            SnackBar(
              content: Text('Заявка #$requestId'),
              action: SnackBarAction(
                label: 'Открыть',
                onPressed: () {
                  // Можно добавить прямую навигацию здесь
                },
              ),
            ),
          );
        }
      });
    }
  }
}

