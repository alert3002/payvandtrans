// Саҳифа барои клиент — нишон додани ҷойгиршавии шофер (мошин) дар карта
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;
import 'package:http/http.dart' as http;
import 'package:polyline_codec/polyline_codec.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/api_constants.dart';
import 'models/request_model.dart';

class DriverTrackingPage extends StatefulWidget {
  final Request request;

  const DriverTrackingPage({super.key, required this.request});

  @override
  State<DriverTrackingPage> createState() => _DriverTrackingPageState();
}

class _DriverTrackingPageState extends State<DriverTrackingPage> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  final List<LatLng> _pointsForBounds = [];
  List<LatLng> _routePoints = [];
  bool _hasDriverLocation = false;
  Timer? _pollTimer;
  double? _latestDriverLat;
  double? _latestDriverLng;
  double? _distanceRemainingKm;
  String _driverPlace = '—';
  final Distance _distance = Distance();

  @override
  void initState() {
    super.initState();
    _setupMap();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshDriverLocation());
  }

  Future<void> _refreshDriverLocation() async {
    final id = widget.request.id;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;
      final resp = await http.get(
        ApiConstants.getUri('api/detail/?id=$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode != 200 || !mounted) return;
      final data = json.decode(utf8.decode(resp.bodyBytes));
      final r = Request.fromJson(data);
      final lat = r.driverLat;
      final lng = r.driverLng;
      if (lat == null || lng == null) {
        if (_hasDriverLocation && mounted) {
          _markers.removeWhere((m) => m.key == ValueKey('driver'));
          if (_pointsForBounds.isNotEmpty) _pointsForBounds.removeLast();
          setState(() {
            _hasDriverLocation = false;
            _latestDriverLat = null;
            _latestDriverLng = null;
          });
        }
        return;
      }
      _latestDriverLat = lat;
      _latestDriverLng = lng;
      final driverPoint = LatLng(lat, lng);
      _updateDistanceAndPlace(driverPoint);
      if (_hasDriverLocation) {
        final idx = _markers.indexWhere((m) => m.key == ValueKey('driver'));
        if (idx >= 0) {
          _markers[idx] = _buildDriverMarker(driverPoint);
          if (mounted) setState(() {});
        }
      } else {
        _hasDriverLocation = true;
        _pointsForBounds.add(driverPoint);
        _markers.add(_buildDriverMarker(driverPoint));
        if (mounted) setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pointsForBounds.isNotEmpty) {
            _mapController.fitCamera(CameraFit.coordinates(
              coordinates: _pointsForBounds,
              padding: const EdgeInsets.all(60.0),
            ));
          }
        });
      }
    } catch (_) {}
  }

  Marker _buildDriverMarker(LatLng point) {
    return Marker(
      key: const ValueKey('driver'),
      point: point,
      width: 90,
      height: 90,
      child: GestureDetector(
        onTap: () => _showAddressOnTap('Водитель', _driverPlace, point),
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
            const Text('Грузовик', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _setupMap() async {
    final r = widget.request;
    // Нуқтаи ибтидо (точка А)
    for (var stop in r.originStops) {
      if (stop.lat != null && stop.lng != null) {
        final point = LatLng(stop.lat!, stop.lng!);
        final addr = _formatStopAddress(stop);
        _pointsForBounds.add(point);
        _markers.add(
          Marker(
            point: point,
            width: 70,
            height: 70,
            child: GestureDetector(
              onTap: () => _showAddressOnTap('Точка А (погрузка)', addr, point),
              child: const Icon(Icons.flag, color: Colors.green, size: 36),
            ),
          ),
        );
      }
    }
    // Нуқтаи ниҳоя (точка Б)
    for (var stop in r.destinationStops) {
      if (stop.lat != null && stop.lng != null) {
        final point = LatLng(stop.lat!, stop.lng!);
        final addr = _formatStopAddress(stop);
        _pointsForBounds.add(point);
        _markers.add(
          Marker(
            point: point,
            width: 70,
            height: 70,
            child: GestureDetector(
              onTap: () => _showAddressOnTap('Точка Б (выгрузка)', addr, point),
              child: const Icon(Icons.location_on, color: Colors.red, size: 36),
            ),
          ),
        );
      }
    }
    // Мошин (шофер) — иконкаи грузовик
    if (r.driverLat != null && r.driverLng != null) {
      _hasDriverLocation = true;
      _latestDriverLat = r.driverLat;
      _latestDriverLng = r.driverLng;
      final driverPoint = LatLng(r.driverLat!, r.driverLng!);
      _pointsForBounds.add(driverPoint);
      _markers.add(_buildDriverMarker(driverPoint));
      _updateDistanceAndPlace(driverPoint);
    }
    if (_pointsForBounds.length >= 2) {
      await _fetchRoute();
    }
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pointsForBounds.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: _pointsForBounds,
            padding: const EdgeInsets.all(60.0),
          ),
        );
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_pointsForBounds.length < 2) return;
    final waypoints = _pointsForBounds
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    try {
      final response = await http.get(Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$waypoints?geometries=polyline'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final decoded = PolylineCodec.decode(geometry);
          _routePoints = decoded
              .map((p) => LatLng(p[0].toDouble(), p[1].toDouble()))
              .toList();
          if (mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  LatLng? _getDestinationPoint() {
    final stops = widget.request.destinationStops;
    if (stops.isEmpty) return null;
    final last = stops.last;
    if (last.lat == null || last.lng == null) return null;
    return LatLng(last.lat!, last.lng!);
  }

  void _updateDistanceAndPlace(LatLng driverPoint) {
    final dest = _getDestinationPoint();
    if (dest != null) {
      final km = _distance.as(LengthUnit.Kilometer, driverPoint, dest);
      if (mounted) setState(() => _distanceRemainingKm = km);
    }
    _reverseGeocode(driverPoint);
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
        if (place.length > 50) place = '${place.substring(0, 47)}...';
        if (mounted) setState(() => _driverPlace = place);
      }
    } catch (_) {}
  }

  void _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _launchWhatsApp(String phone) async {
    final p = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _launchTelegram(String phone) async {
    final p = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://t.me/+$p');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareDriverLocation() async {
    final r = widget.request;
    final origin = r.originStops.isNotEmpty ? r.originStops.first : null;
    final dest = r.destinationStops.isNotEmpty ? r.destinationStops.last : null;
    final latA = origin?.lat;
    final lngA = origin?.lng;
    final latB = dest?.lat;
    final lngB = dest?.lng;
    final driverLat = _latestDriverLat ?? r.driverLat;
    final driverLng = _latestDriverLng ?? r.driverLng;

    final buf = StringBuffer();
    buf.writeln('Маршрут заказа:');
    buf.writeln('Точка А (погрузка): ${_formatStopAddress(origin)}');
    buf.writeln('Точка Б (выгрузка): ${_formatStopAddress(dest)}');
    if (driverLat != null && driverLng != null) {
      buf.writeln('Водитель сейчас: $_driverPlace');
      buf.writeln('https://www.google.com/maps/search/?api=1&query=$driverLat,$driverLng');
    }
    if (latA != null && lngA != null && latB != null && lngB != null) {
      buf.writeln('');
      buf.writeln('Маршрут на карте:');
      buf.write('https://www.google.com/maps/dir/?api=1&origin=$latA,$lngA&destination=$latB,$lngB');
      if (driverLat != null && driverLng != null) {
        buf.write('&waypoints=$driverLat,$driverLng');
      }
    }
    final text = buf.toString().trim();
    if (text.length > 10) {
      await Share.share(text, subject: 'Маршрут и местоположение водителя');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет данных маршрута для sharing.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Где водитель?', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2a2a2e),
        iconTheme: const IconThemeData(color: Colors.white),
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
                    ),
                  ],
                ),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (!_hasDriverLocation)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Водитель ещё не отправил своё местоположение. Обновите позже.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          if (r.driverPhone != null && r.driverPhone!.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2e).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasDriverLocation) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.straighten, color: const Color(0xFFdcd232), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _distanceRemainingKm != null
                                ? '${_distanceRemainingKm!.toStringAsFixed(1)} км до пункта'
                                : '— км',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, color: const Color(0xFFdcd232), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _driverPlace,
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Text(
                      'Связаться с водителем',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildContactBtn(Icons.phone, 'Звонить', Colors.green, () => _launchPhone(r.driverPhone!)),
                        _buildContactBtn(FontAwesomeIcons.whatsapp, 'WhatsApp', const Color(0xFF25D366), () => _launchWhatsApp(r.driverPhone!)),
                        _buildContactBtn(Icons.send, 'Telegram', const Color(0xFF0088CC), () => _launchTelegram(r.driverPhone!)),
                        _buildContactBtn(Icons.share, 'Поделиться', const Color(0xFFdcd232), _shareDriverLocation),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}
