// Файли map_popup.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapPopup extends StatefulWidget {
  final LatLng? initialPoint;

  const MapPopup({super.key, this.initialPoint});

  @override
  _MapPopupState createState() => _MapPopupState();
}

class _MapPopupState extends State<MapPopup> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedPoint;
  List<Marker> _markers = [];
  bool _searching = false;
  bool _loadingMyLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPoint != null) {
      _selectedPoint = widget.initialPoint;
      _updateMarker();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition pos, LatLng point) {
    setState(() {
      _selectedPoint = point;
      _updateMarker();
    });
  }

  void _updateMarker() {
    if (_selectedPoint == null) return;
    _markers = [
      Marker(
        width: 80.0,
        height: 80.0,
        point: _selectedPoint!,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 50),
      ),
    ];
  }

  Future<void> _goToMyLocation() async {
    setState(() => _loadingMyLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Включите доступ к геолокации'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedPoint = point;
        _updateMarker();
        _loadingMyLocation = false;
      });
      _mapController.move(point, 16);
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMyLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось получить местоположение'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _searchAddress() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      const countryCodes = 'tj,uz';
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=5&countrycodes=$countryCodes');
      final resp = await http.get(url, headers: {'User-Agent': 'tj.payvandtrans.app/1.0'});
      if (resp.statusCode == 200 && mounted) {
        final list = json.decode(resp.body) as List;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            final point = LatLng(lat, lon);
            setState(() {
              _selectedPoint = point;
              _updateMarker();
              _searching = false;
            });
            _mapController.move(point, 16);
            return;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Адрес не найден'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка поиска'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final LatLng mapCenter = widget.initialPoint ?? const LatLng(38.57, 68.79);

    return AlertDialog(
      backgroundColor: const Color(0xFF2a2a2e),
      contentPadding: EdgeInsets.zero,
      title: const Text('Выберите точку на карте',
          style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Поиск адреса...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF212121),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFdcd232)),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, color: Color(0xFFdcd232), size: 22),
                                onPressed: _searchAddress,
                              ),
                      ),
                      onSubmitted: (_) => _searchAddress(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadingMyLocation ? null : _goToMyLocation,
                    icon: _loadingMyLocation
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFdcd232)),
                          )
                        : const Icon(Icons.my_location, color: Color(0xFFdcd232), size: 28),
                    tooltip: 'Моё местоположение',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 12,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'tj.payvandtrans.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Отмена', style: TextStyle(color: Colors.white70))),
        ElevatedButton(
          onPressed: _selectedPoint == null
              ? null
              : () {
                  Navigator.of(context).pop({
                    'lat': _selectedPoint!.latitude,
                    'lng': _selectedPoint!.longitude,
                  });
                },
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFdcd232)),
          child: const Text('Выбрать', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
