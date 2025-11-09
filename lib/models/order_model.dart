// Файли: lib/models/order_model.dart
class Order {
  final int id;
  final String? fromCity;
  final int? requestId;
  final String? toCity;
  final String? requestName;
  final String? requestPrice;
  final String? requestStatus;
  final String? statusRu;
  final String orderSum;
  final String status;

  Order({
    required this.id,
    this.fromCity,
    this.requestId,
    this.toCity,
    this.requestName,
    this.requestPrice,
    this.requestStatus,
    this.statusRu,
    required this.orderSum,
    required this.status,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      fromCity: json['from_city'],
      requestId: json['request_id'],
      toCity: json['to_city'],
      requestName: json['request_name'],
      requestPrice: json['request_price'],
      requestStatus: json['request_status'],
      orderSum: json['order_sum']?.toString() ?? '0',
      status: json['status'] ?? 'unknown',
      statusRu: json['status_ru'],
    );
  }
}
