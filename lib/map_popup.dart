// Файли map_popup.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPopup extends StatefulWidget {
  final LatLng? initialPoint;

  const MapPopup({super.key, this.initialPoint});

  @override
  _MapPopupState createState() => _MapPopupState();
}

class _MapPopupState extends State<MapPopup> {
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialPoint != null) {
      _selectedPoint = widget.initialPoint;
      _updateMarker();
    }
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
        height: MediaQuery.of(context).size.height * 0.6,
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
