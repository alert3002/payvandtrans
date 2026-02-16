// Файли route_map_page.dart (Версияи нав бо нишон додани роҳ)

import 'dart:ui' show StrokeCap, StrokeJoin;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:polyline_codec/polyline_codec.dart';
import 'models/request_model.dart';

class RouteMapPage extends StatefulWidget {
  final List<OriginStop> originStops;
  final List<DestinationStop> destStops;

  const RouteMapPage({
    super.key,
    required this.originStops,
    required this.destStops,
  });

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  final List<LatLng> _pointsForBounds = [];
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _setupMapPointsAndFetchRoute();
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

  Future<void> _setupMapPointsAndFetchRoute() async {
    // Нуқтаҳои "Откуда" (Точка А)
    for (var stop in widget.originStops) {
      if (stop.lat != null && stop.lng != null) {
        final point = LatLng(stop.lat!, stop.lng!);
        final addr = _formatStopAddress(stop);
        _pointsForBounds.add(point);
        _markers.add(
          Marker(
            point: point,
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () => _showAddressOnTap('Точка А (погрузка)', addr, point),
              child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
            ),
          ),
        );
      }
    }
    // Нуқтаҳои "Куда" (Точка Б)
    for (var stop in widget.destStops) {
      if (stop.lat != null && stop.lng != null) {
        final point = LatLng(stop.lat!, stop.lng!);
        final addr = _formatStopAddress(stop);
        _pointsForBounds.add(point);
        _markers.add(
          Marker(
            point: point,
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () => _showAddressOnTap('Точка Б (выгрузка)', addr, point),
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
          ),
        );
      }
    }

    if (_pointsForBounds.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Для построения маршрута нужно минимум 2 точки.')),
        );
      }
      return;
    }

    await _fetchRoute();

    setState(() {}); // Барои навсозии маркерҳо ва роҳ

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pointsForBounds.isNotEmpty) {
        _zoomToFitAllPoints();
      }
    });
  }

  Future<void> _fetchRoute() async {
    // Ба ҷои allStops, мо _pointsForBounds-ро истифода мебарем, ки аллакай
    // ҳамаи нуқтаҳои дурустро дар формати LatLng дорад.
    if (_pointsForBounds.length < 2) return;

    // URL-ро барои OSRM бо ҳамаи нуқтаҳо месозем
    // Мо аз _pointsForBounds истифода мебарем, ки навъи LatLng дорад
    final waypoints = _pointsForBounds
        .map((point) =>
            '${point.longitude},${point.latitude}') // <-- САТРИ ИСЛОҲШУДА
        .join(';');
    final url =
        'https://router.project-osrm.org/route/v1/driving/$waypoints?geometries=polyline&overview=full';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final decodedPoints = PolylineCodec.decode(geometry);
          _routePoints = decodedPoints
              .map((p) => LatLng(p[0].toDouble(), p[1].toDouble()))
              .toList();
        }
      }
    } catch (e) {
      print("Error fetching route: $e");
    }
  }

  void _zoomToFitAllPoints() {
    if (_pointsForBounds.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _pointsForBounds,
        padding: const EdgeInsets.all(50.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Маршрут на карте',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2a2a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(40.28, 69.62),
          initialZoom: 7,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'tj.payvandtrans.app',
          ),
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
    );
  }
}
