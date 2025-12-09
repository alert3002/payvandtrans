import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Модель для хранения истории уведомлений
class NotificationHistoryItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final bool isRead;

  NotificationHistoryItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.data,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'isRead': isRead,
    };
  }

  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

/// Сервис для управления историей уведомлений
class NotificationHistoryService {
  static const String _key = 'notification_history';
  static const int _maxHistorySize = 100; // Максимальное количество уведомлений

  /// Сохранение уведомления в историю
  static Future<void> saveNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_key);
      
      List<NotificationHistoryItem> history = [];
      if (historyJson != null) {
        final List<dynamic> decoded = json.decode(historyJson);
        history = decoded
            .map((item) => NotificationHistoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // Добавляем новое уведомление в начало списка
      final newItem = NotificationHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        data: data,
        isRead: false,
      );

      history.insert(0, newItem);

      // Ограничиваем размер истории
      if (history.length > _maxHistorySize) {
        history = history.take(_maxHistorySize).toList();
      }

      // Сохраняем обратно
      final encoded = json.encode(history.map((item) => item.toJson()).toList());
      await prefs.setString(_key, encoded);
    } catch (e) {
      print('❌ Ошибка сохранения уведомления в историю: $e');
    }
  }

  /// Получение всей истории уведомлений
  static Future<List<NotificationHistoryItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_key);
      
      if (historyJson == null) {
        return [];
      }

      final List<dynamic> decoded = json.decode(historyJson);
      return decoded
          .map((item) => NotificationHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Ошибка загрузки истории уведомлений: $e');
      return [];
    }
  }

  /// Отметить уведомление как прочитанное
  static Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_key);
      
      if (historyJson == null) return;

      final List<dynamic> decoded = json.decode(historyJson);
      List<NotificationHistoryItem> history = decoded
          .map((item) => NotificationHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Находим и обновляем уведомление
      for (int i = 0; i < history.length; i++) {
        if (history[i].id == id) {
          history[i] = NotificationHistoryItem(
            id: history[i].id,
            title: history[i].title,
            body: history[i].body,
            timestamp: history[i].timestamp,
            data: history[i].data,
            isRead: true,
          );
          break;
        }
      }

      final encoded = json.encode(history.map((item) => item.toJson()).toList());
      await prefs.setString(_key, encoded);
    } catch (e) {
      print('❌ Ошибка отметки уведомления как прочитанного: $e');
    }
  }

  /// Отметить все уведомления как прочитанные
  static Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_key);
      
      if (historyJson == null) return;

      final List<dynamic> decoded = json.decode(historyJson);
      List<NotificationHistoryItem> history = decoded
          .map((item) => NotificationHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Обновляем все уведомления
      history = history.map((item) {
        return NotificationHistoryItem(
          id: item.id,
          title: item.title,
          body: item.body,
          timestamp: item.timestamp,
          data: item.data,
          isRead: true,
        );
      }).toList();

      final encoded = json.encode(history.map((item) => item.toJson()).toList());
      await prefs.setString(_key, encoded);
    } catch (e) {
      print('❌ Ошибка отметки всех уведомлений как прочитанных: $e');
    }
  }

  /// Получить количество непрочитанных уведомлений
  static Future<int> getUnreadCount() async {
    try {
      final history = await getHistory();
      return history.where((item) => !item.isRead).length;
    } catch (e) {
      print('❌ Ошибка подсчета непрочитанных уведомлений: $e');
      return 0;
    }
  }

  /// Очистить всю историю
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      print('❌ Ошибка очистки истории уведомлений: $e');
    }
  }
}

