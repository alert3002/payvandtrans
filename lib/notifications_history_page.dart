import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/notification_history_service.dart';
import 'order_detail_page.dart';

class NotificationsHistoryPage extends StatefulWidget {
  const NotificationsHistoryPage({super.key});

  @override
  State<NotificationsHistoryPage> createState() => _NotificationsHistoryPageState();
}

class _NotificationsHistoryPageState extends State<NotificationsHistoryPage> {
  List<NotificationHistoryItem> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final history = await NotificationHistoryService.getHistory();
    final unreadCount = await NotificationHistoryService.getUnreadCount();

    if (mounted) {
      setState(() {
        _notifications = history;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationHistoryItem item) async {
    if (!item.isRead) {
      await NotificationHistoryService.markAsRead(item.id);
      await _loadNotifications();
    }
  }

  Future<void> _markAllAsRead() async {
    await NotificationHistoryService.markAllAsRead();
    await _loadNotifications();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3d3e42),
        title: const Text(
          'Очистить историю?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Вы уверены, что хотите удалить всю историю уведомлений?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NotificationHistoryService.clearHistory();
      await _loadNotifications();
    }
  }

  void _handleNotificationTap(NotificationHistoryItem item) async {
    // Отмечаем как прочитанное
    await _markAsRead(item);

    // Если есть данные о заявке, открываем детали
    // Приоритет: request_id важнее order_id
    if (item.data != null) {
      int? requestId;
      if (item.data!.containsKey('request_id')) {
        requestId = int.tryParse(item.data!['request_id'].toString());
      } else if (item.data!.containsKey('order_id')) {
        requestId = int.tryParse(item.data!['order_id'].toString());
      }
      
      final userRole = item.data!['user_role'] ?? 'driver';

      if (requestId != null && requestId > 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(
              requestId: requestId!,
              userRole: userRole,
            ),
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Только что';
        }
        return '${difference.inMinutes} мин. назад';
      }
      return '${difference.inHours} ч. назад';
    } else if (difference.inDays == 1) {
      return 'Вчера, ${DateFormat('HH:mm').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE, HH:mm', 'ru').format(timestamp);
    } else {
      return DateFormat('dd.MM.yyyy, HH:mm').format(timestamp);
    }
  }

  String _getStatusText(Map<String, dynamic>? data, String title) {
    if (data == null) return '';
    
    // Извлекаем информацию о статусе из данных уведомления
    final status = data['status'] ?? data['new_status'] ?? '';
    final oldStatus = data['old_status'] ?? '';
    final orderId = data['order_id'] ?? data['request_id'] ?? '';
    final notificationType = data['type'] ?? data['notification_type'] ?? '';
    final titleLower = title.toLowerCase();
    
    // Специальные типы уведомлений
    if (notificationType == 'driver_found' || 
        titleLower.contains('водитель найден')) {
      final carNumber = data['car_number'] ?? data['carNumber'] ?? '';
      if (carNumber.toString().isNotEmpty) {
        return '🚗 Номер машины: $carNumber';
      }
      return 'Водитель найден для заявки #$orderId';
    }
    
    if (notificationType == 'car_departed' ||
        titleLower.contains('машина выехала')) {
      final carNumber = data['car_number'] ?? data['carNumber'] ?? '';
      if (carNumber.toString().isNotEmpty) {
        return '🚗 Номер машины: $carNumber';
      }
      return 'Машина выехала к заявке #$orderId';
    }
    
    if (status == 'rejected' || oldStatus == 'rejected') {
      return '❌ Заявка #$orderId отклонена';
    }
    
    // Обработка уведомлений о балансе
    if (notificationType == 'balance_update' || 
        notificationType == 'balance_replenished' ||
        notificationType == 'balance_deducted' ||
        titleLower.contains('баланс')) {
      final amount = data['amount'] ?? data['sum'] ?? '';
      final balance = data['balance'] ?? data['remaining_balance'] ?? '';
      if (amount.toString().isNotEmpty && balance.toString().isNotEmpty) {
        return 'Сумма: $amount сомон | Остаток: $balance сомон';
      } else if (amount.toString().isNotEmpty) {
        return 'Сумма: $amount сомон';
      } else if (balance.toString().isNotEmpty) {
        return 'Остаток: $balance сомон';
      }
      return '';
    }
    
    if (status == 'active') {
      // Статус актив (независимо от старого статуса)
      if (oldStatus == 'pending') {
        return '✅ Заявка #$orderId одобрена';
      } else {
        return '✅ Заявка #$orderId стала активной';
      }
    }
    
    if (status.isNotEmpty && oldStatus.isNotEmpty && status != oldStatus) {
      return 'Заявка #$orderId: $oldStatus → $status';
    } else if (status.isNotEmpty && orderId.isNotEmpty) {
      return 'Заявка #$orderId: статус "$status"';
    } else if (orderId.isNotEmpty) {
      return 'Заявка #$orderId';
    }
    
    return '';
  }
  
  IconData _getNotificationIcon(Map<String, dynamic>? data, String title, String body) {
    if (data == null) return Icons.notifications;
    
    final status = data['status'] ?? data['new_status'] ?? '';
    final notificationType = data['type'] ?? data['notification_type'] ?? '';
    final titleLower = title.toLowerCase();
    final bodyLower = body.toLowerCase();
    
    // Уведомления о балансе
    if (notificationType == 'balance_update' || 
        notificationType == 'balance_replenished' ||
        notificationType == 'balance_deducted' ||
        titleLower.contains('баланс') ||
        bodyLower.contains('баланс')) {
      if (titleLower.contains('пополнен') || bodyLower.contains('пополнен')) {
        return Icons.add_circle;
      } else if (titleLower.contains('минус') || bodyLower.contains('минус') ||
                 titleLower.contains('списан') || bodyLower.contains('списан')) {
        return Icons.remove_circle;
      }
      return Icons.account_balance_wallet;
    }
    
    if (notificationType == 'driver_found' || titleLower.contains('водитель найден')) {
      return Icons.person_add;
    }
    
    if (notificationType == 'car_departed' || titleLower.contains('машина выехала')) {
      return Icons.directions_car;
    }
    
    if (status == 'rejected' || titleLower.contains('отклонен')) {
      return Icons.cancel;
    }
    
    if (status == 'active' || titleLower.contains('актив')) {
      return Icons.check_circle;
    }
    
    if (titleLower.contains('статус') || status.isNotEmpty) {
      return Icons.info;
    }
    
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2e2f34),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2e2f34),
        elevation: 0,
        title: const Text(
          'История уведомлений',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: 'Отметить все как прочитанные',
              onPressed: _markAllAsRead,
            ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Очистить историю',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFdcd232)),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 64,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'История уведомлений пуста',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFFdcd232),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      final statusText = _getStatusText(item.data, item.title);
                      final icon = _getNotificationIcon(item.data, item.title, item.body);

                      return GestureDetector(
                        onTap: () => _handleNotificationTap(item),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? const Color(0xFF3d3e42)
                                : const Color(0xFF4a4b50),
                            borderRadius: BorderRadius.circular(12),
                            border: item.isRead
                                ? null
                                : Border.all(
                                    color: const Color(0xFFdcd232).withOpacity(0.3),
                                    width: 1,
                                  ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Иконка уведомления
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFdcd232).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: const Color(0xFFdcd232),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: item.isRead
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.body,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (statusText.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFdcd232)
                                                  .withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              statusText,
                                              style: const TextStyle(
                                                color: Color(0xFFdcd232),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!item.isRead)
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFdcd232),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTimestamp(item.timestamp),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (!item.isRead)
                                    TextButton(
                                      onPressed: () => _markAsRead(item),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Отметить как прочитанное',
                                        style: TextStyle(
                                          color: Color(0xFFdcd232),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

