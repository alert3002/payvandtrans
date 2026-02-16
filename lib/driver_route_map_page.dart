// Карта барои водитель — маршрут + мавқеи ҷории худ (мошин)
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show StrokeCap, StrokeJoin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;
import 'package:http/http.dart' as http;
import 'package:polyline_codec/polyline_codec.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/api_constants.dart';
import 'models/request_model.dart';

class DriverRouteMapPage extends StatefulWidget {
  final Request request;

  const DriverRouteMapPage({super.key, required this.request});

  @override
  State<DriverRouteMapPage> createState() => _DriverRouteMapPageState();
}

class _DriverRouteMapPageState extends State<DriverRouteMapPage> {
  final MapController _mapController = MapController();
  final Distance _distance = Distance();
  final List<Marker> _markers = [];
  final List<LatLng> _pointsForBounds = [];
  List<LatLng> _routePoints = [];
  LatLng? _myPosition;
  Timer? _locationTimer;
  Timer? _sendTimer;
  bool _loading = true;
  double? _speedKmh;
  double? _distanceRemainingKm;
  int? _etaMinutes;
  String _currentPlace = '—';
  int? _orderId;
  String? _driverStatus;
  bool _canManualStartTrip = false;
  bool _canManualClose = false;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _driverStatus = widget.request.status;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _setupMap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionAndStartLocation();
    });
  }

  Future<void> _requestPermissionAndStartLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Включите доступ к геолокации в настройках'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _sendTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  String _formatStopAddress(dynamic stop) {
    if (stop == null) return '—';
    final parts = <String>[];
    final cityVal = stop.city;
    if (cityVal != null) {
      final s = cityVal is Map ? (cityVal['name'] ?? cityVal).toString() : cityVal.toString();
      if (s.trim().isNotEmpty) parts.add(s.trim());
    }
    final addr = stop.address?.toString().trim();
    if (addr != null && addr.isNotEmpty) parts.add(addr);
    final wh = stop.warehouse?.toString().trim();
    if (wh != null && wh.isNotEmpty) parts.add(wh);
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  Future<void> _showAddressOnTap(String label, String address, LatLng? point) async {
    String text = address;
    if (text.isEmpty || text == '—') {
      if (point != null) {
        try {
          final url = Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json');
          final resp = await http.get(url, headers: {'User-Agent': 'tj.payvandtrans.app/1.0'});
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            text = data['display_name'] ?? '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          } else {
            text = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          }
        } catch (_) {
          text = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        }
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label: $text', style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF2a2a2e),
        action: SnackBarAction(label: 'OK', textColor: const Color(0xFFdcd232), onPressed: () {}),
      ),
    );
  }

  Future<void> _shareRoute() async {
    final r = widget.request;
    final origin = r.originStops.isNotEmpty ? r.originStops.first : null;
    final dest = r.destinationStops.isNotEmpty ? r.destinationStops.last : null;
    final latA = origin?.lat;
    final lngA = origin?.lng;
    final latB = dest?.lat;
    final lngB = dest?.lng;
    final buf = StringBuffer();
    buf.writeln('Маршрут заказа:');
    buf.writeln('Точка А (погрузка): ${_formatStopAddress(origin)}');
    buf.writeln('Точка Б (выгрузка): ${_formatStopAddress(dest)}');
    buf.writeln('Моя позиция: $_currentPlace');
    if (_myPosition != null) {
      buf.writeln('https://www.google.com/maps/search/?api=1&query=${_myPosition!.latitude},${_myPosition!.longitude}');
    }
    if (latA != null && lngA != null && latB != null && lngB != null) {
      buf.writeln('');
      buf.writeln('Маршрут: https://www.google.com/maps/dir/?api=1&origin=$latA,$lngA&destination=$latB,$lngB');
      if (_myPosition != null) {
        buf.write('&waypoints=${_myPosition!.latitude},${_myPosition!.longitude}');
      }
    }
    final text = buf.toString().trim();
    if (text.length > 10) {
      await Share.share(text, subject: 'Маршрут заказа');
    }
  }

  Future<void> _setupMap() async {
    final r = widget.request;
    for (var stop in r.originStops) {
      if (stop.lat != null && stop.lng != null) {
        final point = LatLng(stop.lat!, stop.lng!);
        final addr = _formatStopAddress(stop);
        _pointsForBounds.add(point);
        _markers.add(Marker(
          point: point,
          width: 70,
          height: 70,
          child: GestureDetector(
            onTap: () => _showAddressOnTap('Точка А (погрузка)', addr, point),
            child: const Icon(Icons.flag, color: Colors.green, size: 36),
          ),
        ));
      }
    }
    for (var stop in r.destinationStops) {
      if (stop.lat != null && stop.lng != null) {
        final point = LatLng(stop.lat!, stop.lng!);
        final addr = _formatStopAddress(stop);
        _pointsForBounds.add(point);
        _markers.add(Marker(
          point: point,
          width: 70,
          height: 70,
          child: GestureDetector(
            onTap: () => _showAddressOnTap('Точка Б (выгрузка)', addr, point),
            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
          ),
        ));
      }
    }
    if (_pointsForBounds.length >= 2) await _fetchRoute();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchRoute() async {
    if (_pointsForBounds.length < 2) return;
    final waypoints = _pointsForBounds
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    try {
      final resp = await http.get(Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$waypoints?geometries=polyline&overview=full'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final geom = data['routes'][0]['geometry'];
          final decoded = PolylineCodec.decode(geom);
          _routePoints = decoded
              .map((p) => LatLng(p[0].toDouble(), p[1].toDouble()))
              .toList();
          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  void _startLocationUpdates() {
    _updateMyPosition();
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) => _updateMyPosition());
    _sendTimer?.cancel();
    _sendTimer = Timer.periodic(const Duration(seconds: 12), (_) => _sendLocationToServer());
  }

  Future<void> _updateMyPosition() async {
    if (!mounted) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      double? speedKmh;
      if (pos.speed >= 0 && pos.speed < 500) speedKmh = pos.speed * 3.6;
      double? distKm;
      int? etaMin;
      if (_pointsForBounds.isNotEmpty) {
        final dest = _pointsForBounds.last;
        distKm = _distance.as(LengthUnit.Kilometer, point, dest);
        if (speedKmh != null && speedKmh > 1) {
          etaMin = (distKm / speedKmh * 60).round();
        }
      }
      _reverseGeocode(point);
      setState(() {
        _myPosition = point;
        _speedKmh = speedKmh;
        _distanceRemainingKm = distKm;
        _etaMinutes = etaMin;
        _updateDriverMarker();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(point, 15);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json');
      final resp = await http.get(url, headers: {'User-Agent': 'tj.payvandtrans.app/1.0'});
      if (resp.statusCode == 200 && mounted) {
        final data = json.decode(resp.body);
        final name = data['display_name'] ?? data['name'] ?? '—';
        final addr = data['address'];
        String place = '—';
        if (addr is Map) {
          final m = Map<String, dynamic>.from(addr);
          place = m['city'] ?? m['town'] ?? m['village'] ?? m['municipality'] ?? m['county'] ?? m['suburb'] ?? name.toString();
        } else {
          place = name.toString();
        }
        if (place.length > 40) place = '${place.substring(0, 37)}...';
        setState(() => _currentPlace = place);
      }
    } catch (_) {}
  }

  Future<void> _sendLocationToServer() async {
    if (_myPosition == null || widget.request.id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;
      final resp = await http.post(
        ApiConstants.getUri('api/requests/${widget.request.id}/update_location/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'lat': _myPosition!.latitude, 'lng': _myPosition!.longitude}),
      );
      if (resp.statusCode == 200 && mounted) {
        final data = json.decode(resp.body) as Map<String, dynamic>?;
        if (data != null && data['success'] == true) {
          setState(() {
            _orderId = data['order_id'] as int?;
            _driverStatus = data['status'] as String?;
            _canManualStartTrip = data['can_manual_start_trip'] == true;
            _canManualClose = data['can_manual_close'] == true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _tapStartTrip() async {
    if (_orderId == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;
      final resp = await http.post(
        ApiConstants.getUri('api/orders/$_orderId/start_trip/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mounted) {
        final data = resp.statusCode == 200 ? json.decode(resp.body) as Map<String, dynamic>? : null;
        if (data != null && data['success'] == true) {
          setState(() {
            _driverStatus = 'in_transit';
            _canManualStartTrip = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Поездка началась'), backgroundColor: Color(0xFF2a2a2e)),
          );
        } else {
          final msg = data?['message']?.toString() ?? 'Не удалось начать поездку';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
        }
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка сети'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _tapCloseOrder() async {
    if (_orderId == null || _actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;
      final resp = await http.post(
        ApiConstants.getUri('api/orders/$_orderId/close/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mounted) {
        final data = resp.statusCode == 200 ? json.decode(resp.body) as Map<String, dynamic>? : null;
        if (data != null && data['success'] == true) {
          setState(() {
            _driverStatus = 'closed';
            _canManualClose = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заказ закрыт'), backgroundColor: Color(0xFF2a2a2e)),
          );
          Navigator.of(context).pop(true);
        } else {
          final msg = data?['message']?.toString() ?? 'Не удалось закрыть заказ';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
        }
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка сети'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFdcd232), size: 18),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  static const _brandYellow = Color(0xFFdcd232);

  Widget _buildStatusBtn(String label, bool isActive, bool enabled, VoidCallback? onPressed) {
    final bg = isActive ? _brandYellow : (enabled ? Colors.grey.shade700 : Colors.black);
    final fg = isActive ? Colors.black : Colors.white70;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  void _updateDriverMarker() {
    if (_myPosition == null) return;
    final idx = _markers.indexWhere((m) => m.key == const ValueKey('driver'));
    final marker = Marker(
      key: const ValueKey('driver'),
      point: _myPosition!,
      width: 90,
      height: 90,
      child: GestureDetector(
        onTap: () => _showAddressOnTap('Моя позиция', _currentPlace, _myPosition),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFdcd232),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.local_shipping, color: Colors.black, size: 44),
            ),
            const SizedBox(height: 4),
            const Text('Вы здесь', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
    if (idx >= 0) {
      _markers[idx] = marker;
    } else {
      _markers.add(marker);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Моя позиция на карте', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2a2a2e),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareRoute,
            tooltip: 'Поделиться маршрутом',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pointsForBounds.isNotEmpty
                  ? _pointsForBounds.first
                  : const LatLng(40.28, 69.62),
              initialZoom: 10,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.flingAnimation,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'tj.payvandtrans.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.lightBlue,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Color(0xFFdcd232))),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(Icons.straighten, '${_distanceRemainingKm?.toStringAsFixed(1) ?? '—'} км'),
                  _buildInfoItem(Icons.speed, '${_speedKmh?.toStringAsFixed(0) ?? '—'} км/ч'),
                  _buildInfoItem(Icons.access_time, _etaMinutes != null ? '$_etaMinutes мин' : '—'),
                ],
              ),
            ),
          ),
          Positioned(
            top: 52,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Color(0xFFdcd232), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _currentPlace,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: Material(
              color: const Color(0xFFdcd232),
              borderRadius: BorderRadius.circular(30),
              elevation: 4,
              child: InkWell(
                onTap: () async {
                  await _updateMyPosition();
                },
                borderRadius: BorderRadius.circular(30),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.my_location, color: Colors.black, size: 28),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusBtn('Ожидание', _driverStatus == 'awaiting' || _driverStatus == 'active' || _driverStatus == 'awaiting_confirmation', false, null),
                      const SizedBox(width: 8),
                      _buildStatusBtn('В пути', _driverStatus == 'in_transit', _canManualStartTrip && !_actionLoading, _tapStartTrip),
                      const SizedBox(width: 8),
                      _buildStatusBtn('Закрыт', _driverStatus == 'closed', _canManualClose && !_actionLoading, _tapCloseOrder),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Держите экран включённым — клиент видит вашу позицию на карте.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
