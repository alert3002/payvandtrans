import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// 👈 ИН БАСТАҲОРО ИЛОВА КУНЕД
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
// -----------------------------------------------------

import 'models/request_model.dart';
import 'order_detail_page.dart';
import 'filter_page.dart';
import 'constants/api_constants.dart';
import 'notifications_history_page.dart';
import 'services/push_notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userRole;
  late Future<List<Request>> _requestsFuture;

  // -----------------------------------------------------
  // 👈 ФУНКСИЯИ ГИРИФТАНИ ТОКЕН (FCM Token Retrieval Function)
  // -----------------------------------------------------
  Future<void> getDeviceToken() async {
    // Проверяем платформу - FCM работает только на мобильных устройствах
    if (kIsWeb) {
      if (kDebugMode) {
        print('⚠️ FCM не поддерживается на Web платформе');
      }
      return;
    }

    try {
      // 0. Проверяем, что Firebase инициализирован
      try {
        final apps = Firebase.apps;
        if (apps.isEmpty) {
          if (kDebugMode) {
            print('⚠️ Firebase не инициализирован. Ожидание инициализации...');
          }
          // Ждем немного и пробуем инициализировать
          await Future.delayed(const Duration(seconds: 1));
          await Firebase.initializeApp();
          
          if (kDebugMode) {
            print('✅ Firebase инициализирован после задержки');
          }
        } else {
          if (kDebugMode) {
            print('✅ Firebase уже инициализирован (${apps.length} app(s))');
          }
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('❌ Ошибка проверки/инициализации Firebase: $e');
          print('Stack trace: $stackTrace');
        }
        return;
      }

      // 1. Иҷозат талаб карда мешавад (муҳим барои iOS ва Android 13+)
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      if (kDebugMode) {
        print('📱 Notification Permission Status: ${settings.authorizationStatus}');
      }
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized || 
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 2. Небольшая задержка для гарантии готовности Firebase
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 3. Токен гирифта мешавад
        String? token = await FirebaseMessaging.instance.getToken();
        
        if (token != null && token.isNotEmpty) {
          // 4. Токен дар консол чоп мешавад
          if (kDebugMode) {
            print('✅ FCM TOKEN: $token'); 
            print('📋 Скопируйте этот токен для тестирования в Firebase Console');
          }
          
          // 5. Токенро ба сервери худ фиристед, агар лозим бошад
          // (PushNotificationService уже делает это автоматически)
        } else {
          if (kDebugMode) {
            print('❌ FCM TOKEN: Токен гирифта нашуд (null ё холӣ).');
            print('💡 Проверьте:');
            print('   1. google-services.json в android/app/');
            print('   2. Package name совпадает с applicationId');
            print('   3. Интернет соединение активно');
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠️ FCM: Иҷозати огоҳинома рад карда шуд: ${settings.authorizationStatus}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Хатогӣ ҳангоми гирифтани токен: $e');
        print('Stack trace: $stackTrace');
      }
    }
  }

  // -----------------------------------------------------
  
  @override
  void initState() {
    super.initState();
    _requestsFuture = Future.value([]);
    // 👈 ДАЪВАТИ ФУНКСИЯИ ГИРИФТАНИ ТОКЕН:
    getDeviceToken(); 
    // ---------------------------------------
    _loadUserRoleAndFetchData();
    _setupNotificationListeners();
  }
  
  void _setupNotificationListeners() {
    // Обновляем список заявок при получении уведомления о статусе
    PushNotificationService.onRequestStatusUpdate = () {
      if (mounted) {
        setState(() {
          _requestsFuture = _fetchRequests();
        });
      }
    };
  }
  
  @override
  void dispose() {
    // Очищаем callback при закрытии страницы
    PushNotificationService.onRequestStatusUpdate = null;
    super.dispose();
  }

  Future<void> _loadUserRoleAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('role');
        _requestsFuture = _fetchRequests();
      });
    }
  }

  // ... (боқимондаи коди шумо бе тағйир мемонад)
  
  Future<List<Request>> _fetchRequests() async {
    final isDriver = _userRole == 'driver';
    final url = isDriver
        ? ApiConstants.getUri('api/zayavki/')
        : ApiConstants.getUri('api/requests/');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Токен ёфт нашуд.');

      final response =
          await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final decodedJson = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> data;

        if (decodedJson is List) {
          data = decodedJson;
        } else if (decodedJson is Map && decodedJson.containsKey('results')) {
          data = decodedJson['results'];
        } else {
          throw Exception('Формати номаълуми JSON');
        }

        List<Request> allRequests =
            data.map((json) => Request.fromJson(json)).toList();

        if (!isDriver) {
          allRequests.retainWhere((r) =>
              r.status == 'active' );
        }

        return allRequests;
      } else {
        throw Exception(
            'Хатогии боркунии маълумот (Коди статус: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Хатогии пайвастшавӣ: $e');
    }
  }

  void _openFilterPage() async {
    final result = await Navigator.push<FilterSettings>(
      context,
      MaterialPageRoute(builder: (context) => const FilterPage()),
    );

    if (result != null) {
      setState(() {
        _requestsFuture =
            _fetchRequests(); // Рӯйхатро бо филтрҳои нав аз нав боргирӣ мекунем
      });
    }
  }

  String _formatDateRange(String? startDate, String? endDate) {
    if (startDate == null && endDate == null) return 'номаълум';
    String formatSingleDate(String? date) {
      if (date == null) return '';
      try {
        final parsedDate = DateTime.parse(date);
        return '${parsedDate.day.toString().padLeft(2, '0')}.${parsedDate.month.toString().padLeft(2, '0')}.${parsedDate.year}';
      } catch (e) {
        return date;
      }
    }

    String start = formatSingleDate(startDate);
    String end = formatSingleDate(endDate);
    if (start.isNotEmpty && end.isNotEmpty) return 'от $start до $end';
    return start.isNotEmpty
        ? 'аз $start'
        : (end.isNotEmpty ? 'то $end' : 'номаълум');
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.greenAccent;
      case 'awaiting_confirmation':
        return Colors.orangeAccent;
      case 'pending':
        return Colors.orangeAccent;
      case 'awaiting':
        return Colors.amberAccent;
      case 'in_transit':
        return Colors.blueAccent;
      case 'closed':
        return Colors.grey;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  String _getRussianStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Актив';
      case 'awaiting_confirmation':
        return 'Ожидает рассмотрения';
      case 'pending':
        return 'На рассмотрении';
      case 'awaiting':
        return 'Ожидание';
      case 'in_transit':
        return 'В пути';
      case 'closed':
        return 'Закрыт';
      case 'completed':
        return 'Завершён';
      default:
        return status ?? 'Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle =
        (_userRole == 'driver') ? 'Все заказы' : 'Активные заявки';

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2a2a2e),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(appBarTitle,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _requestsFuture = _fetchRequests();
              });
            },
            tooltip: 'Обновить',
          ),
          TextButton.icon(
            onPressed: _openFilterPage, // <-- ФУНКСИЯИ НАВРО ИСТИФОДА МЕБАРЕМ
            icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
            label: const Text('ФИЛЬТР', style: TextStyle(color: Colors.white)),
          ),
          IconButton(
              icon: const Icon(Icons.notifications_active, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsHistoryPage(),
                  ),
                );
              },
              tooltip: 'История уведомлений',
            ),
          const SizedBox(width: 5),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserRoleAndFetchData();
        },
        color: const Color(0xFFdcd232),
        backgroundColor: const Color(0xFF2a2a2e),
        child: FutureBuilder<List<Request>>(
          future: _requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFdcd232)));
            } else if (snapshot.hasError) {
              return Center(
                  child: Text('Ошибка: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              final message = _userRole == 'driver'
                  ? 'Пока нет доступных заказов.'
                  : 'У вас пока нет активных заявок.';
              return Center(
                  child: Text(message,
                      style: const TextStyle(color: Colors.white70)));
            } else {
              final requests = snapshot.data!;
              final isDriver = _userRole == 'driver';
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  return isDriver
                      ? _buildDriverRequestCard(requests[index])
                      : _buildClientRequestCard(requests[index]);
                },
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildDriverRequestCard(Request request) {
    final bool isTappable = request.id != null;
    return InkWell(
        onTap: !isTappable
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OrderDetailPage(
                            requestId: request.id!,
                            userRole: _userRole, // <-- ИН САТР ИЛОВА ШУД
                          )),
                );
                // Обновляем данные при возврате (независимо от результата)
                _loadUserRoleAndFetchData();
              },
        child: Card(
          // ... боқимондаи код бе тағйир
          color: const Color(0xFF2a2a2e),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                    child: Text(request.name ?? 'Бе ном',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold))),
                Text('${request.priceTjs?.toStringAsFixed(0) ?? 0} смн',
                    style: const TextStyle(
                        color: Color(0xFFdcd232),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${request.originCity} > ${request.destCity}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                Text('${request.distanceKm?.toStringAsFixed(0) ?? 0} км',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_formatDateRange(request.loadDate, request.deliveryDate),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                Text('${request.tonnageT?.toStringAsFixed(0) ?? 0} т',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
              const SizedBox(height: 16),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(request.transport ?? 'Транспорт',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12))))
            ]),
          ),
        ));
  }

  Widget _buildClientRequestCard(Request request) {
    // ... ин функсия аллакай дуруст аст ва бе тағйир мемонад ...
    final bool isTappable = request.id != null;
    return InkWell(
      onTap: !isTappable
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailPage(
                    requestId: request.id!,
                    userRole: _userRole,
                  ),
                ),
              );
              // Обновляем данные при возврате (независимо от результата)
              _loadUserRoleAndFetchData();
            },
      child: Card(
        color: const Color(0xFF2a2a2e),
        margin: const EdgeInsets.only(bottom: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Заказ №${request.id} ${request.name ?? ''}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildInfoRow(
                  'Маршрут:', '${request.originCity} → ${request.destCity}'),
              _buildInfoRow('Дата:',
                  _formatDateRange(request.loadDate, request.deliveryDate)),
              _buildInfoRow('Расстояние:',
                  '${request.distanceKm?.toStringAsFixed(0) ?? '0'} км'),
              _buildInfoRow(
                  'Вес:', '${request.tonnageT?.toStringAsFixed(0) ?? '0'} т'),
              _buildInfoRow(
                  'Цена:', '${request.priceTjs?.toStringAsFixed(0) ?? '0'} смн',
                  isPrice: true),
              _buildInfoRow('Статус:', _getRussianStatus(request.status),
                  statusColor: _getStatusColor(request.status)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isPrice = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: isPrice
                  ? const Color(0xFFdcd232)
                  : (statusColor ?? Colors.white),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}