// Файли: lib/models/request_model.dart

// === ФУНКСИЯИ ЁРИРАСОНИ НАВ ===
// Ин функсия барои он аст, ки рақамҳоро аз ҳар гуна намуд (String ё num) бехатар ба double табдил диҳад
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
// ================================

// Модели ёрирасон барои нуқтаҳои боргирӣ
class OriginStop {
  final String? city;
  final String? address;
  final String? warehouse;
  final double? lat;
  final double? lng;

  OriginStop({this.city, this.address, this.warehouse, this.lat, this.lng});

  factory OriginStop.fromJson(Map<String, dynamic> json) {
    return OriginStop(
      city: json['city'],
      address: json['address'],
      warehouse: json['warehouse'],
      // Истифодаи функсияи ёрирасон
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lng']),
    );
  }
}

// Модели ёрирасон барои нуқтаҳои таҳвил
class DestinationStop {
  final String? city;
  final String? address;
  final String? warehouse;
  final double? lat;
  final double? lng;

  DestinationStop(
      {this.city, this.address, this.warehouse, this.lat, this.lng});

  factory DestinationStop.fromJson(Map<String, dynamic> json) {
    return DestinationStop(
      city: json['city'],
      address: json['address'],
      warehouse: json['warehouse'],
      // Истифодаи функсияи ёрирасон
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lng']),
    );
  }
}

// Модели асосии Request
class Request {
  final int? id;
  final String? name;
  final String? transport;
  final List<OriginStop> originStops;
  final List<DestinationStop> destinationStops;
  final double? priceTjs;
  final double? tonnageT;
  final double? distanceKm;
  final String? status;
  final String? loadDate;
  final String? deliveryDate;
  final String? createdAt;
  final String? description;
  final double? commissionPercentage;

  Request({
    this.id,
    this.name,
    this.transport,
    required this.originStops,
    required this.destinationStops,
    this.priceTjs,
    this.tonnageT,
    this.distanceKm,
    this.status,
    this.loadDate,
    this.deliveryDate,
    this.createdAt,
    this.description,
    this.commissionPercentage,
  });

  String get originCity =>
      originStops.isNotEmpty ? originStops.first.city ?? '' : '';
  String get destCity =>
      destinationStops.isNotEmpty ? destinationStops.first.city ?? '' : '';

  String get allOriginAddresses => originStops
      .map((s) => s.address?.trim() ?? '')
      .where((s) => s.isNotEmpty)
      .join('; ');

  String get allDestAddresses => destinationStops
      .map((s) => s.address?.trim() ?? '')
      .where((s) => s.isNotEmpty)
      .join('; ');

  String get allOriginWarehouses => originStops
      .map((s) => s.warehouse?.trim() ?? '')
      .where((s) => s.isNotEmpty)
      .join('; ');

  String get allDestWarehouses => destinationStops
      .map((s) => s.warehouse?.trim() ?? '')
      .where((s) => s.isNotEmpty)
      .join('; ');

  factory Request.fromJson(Map<String, dynamic> json) {
    var originStopsList = (json['origin_stops'] as List? ?? [])
        .map((i) => OriginStop.fromJson(i))
        .toList();
    var destinationStopsList = (json['destination_stops'] as List? ?? [])
        .map((i) => DestinationStop.fromJson(i))
        .toList();

    return Request(
      id: json['id'],
      name: json['name'],
      transport: json['transport'],
      originStops: originStopsList,
      destinationStops: destinationStopsList,
      // Истифодаи функсияи ёрирасон барои ҳамаи майдонҳои рақамӣ
      priceTjs: _parseDouble(json['price_tjs']),
      tonnageT: _parseDouble(json['tonnage_t']),
      distanceKm: _parseDouble(json['distance_km']),
      status: json['status'],
      loadDate: json['load_date'],
      deliveryDate: json['delivery_date'],
      createdAt: json['created_at'],
      description: json['description'],
      commissionPercentage: _parseDouble(json['commission_percentage']),
    );
  }
}
