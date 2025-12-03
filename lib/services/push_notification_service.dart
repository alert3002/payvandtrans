import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../constants/api_constants.dart';
import '../order_detail_page.dart';

/// Сервис для работы с push-уведомлениями Firebase
class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static BuildContext? _context;

  /// Инициализация push-уведомлений
  static Future<void> initPushNotifications(BuildContext context) async {
    _context = context;

    try {
      // 1. Запрос разрешения на уведомления
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

      // 2. Получение FCM токена
      String? token = await _messaging.getToken();
      if (token != null) {
        print('📱 FCM Token: $token');
        // 3. Отправка токена на backend
        await _sendTokenToBackend(token);
      } else {
        print('⚠️ Не удалось получить FCM токен');
      }

      // 4. Обработка обновления токена
      _messaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token обновлен: $newToken');
        _sendTokenToBackend(newToken);
      });

      // 5. Настройка обработки уведомлений
      _setupMessageHandlers();

    } catch (e) {
      print('❌ Ошибка инициализации push-уведомлений: $e');
    }
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

      // Определяем тип устройства
      String deviceType = Platform.isAndroid ? 'android' : 'ios';

      final response = await http.post(
        ApiConstants.getUri('api/fcm/device/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'registration_id': token,
          'type': deviceType,
          'name': '${Platform.operatingSystem} Device',
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

  /// Настройка обработчиков сообщений
  static void _setupMessageHandlers() {
    // Обработка уведомлений, когда приложение открыто (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📬 Получено уведомление (foreground): ${message.notification?.title}');
      
      // Показываем локальное уведомление или SnackBar
      if (_context != null) {
        _showNotificationSnackBar(message);
      }
    });

    // Обработка клика по уведомлению, когда приложение в фоне
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('👆 Пользователь открыл уведомление: ${message.notification?.title}');
      _handleNotificationClick(message);
    });

    // Обработка уведомления, которое открыло приложение (когда оно было закрыто)
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 Приложение открыто из уведомления: ${message.notification?.title}');
        _handleNotificationClick(message);
      }
    });
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
    
    // Если в данных есть order_id или request_id, открываем детали заказа
    if (data.containsKey('order_id') || data.containsKey('request_id')) {
      final orderId = data['order_id'] ?? data['request_id'];
      final userRole = data['user_role'] ?? 'driver'; // По умолчанию driver
      
      print('📦 Открываем заказ: $orderId');
      
      // Импортируем OrderDetailPage динамически, чтобы избежать циклических зависимостей
      try {
        // Используем Navigator для перехода к деталям заказа
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(
              requestId: int.tryParse(orderId.toString()) ?? 0,
              userRole: userRole,
            ),
          ),
        );
      } catch (e) {
        print('⚠️ Ошибка навигации к заказу: $e');
        // Альтернативный способ - показать SnackBar
        ScaffoldMessenger.of(_context!).showSnackBar(
          SnackBar(
            content: Text('Заказ #$orderId'),
            action: SnackBarAction(
              label: 'Открыть',
              onPressed: () {
                // Можно добавить прямую навигацию здесь
              },
            ),
          ),
        );
      }
    }
  }
}

