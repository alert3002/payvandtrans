// Файли нав: lib/filter_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/city_model.dart';
import 'models/transport_model.dart';

// Ин класс барои нигоҳ доштани ҳолати филтрҳо истифода мешавад
class FilterSettings {
  final TransportCategory? transport;
  final City? originCity;
  final City? destCity;
  // Дигар майдонҳоро низ метавон илова кард

  FilterSettings({this.transport, this.originCity, this.destCity});
}

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  bool _isLoading = true;

  // Рӯйхатҳо барои Dropdown-ҳо
  List<City> _cities = [];
  List<TransportCategory> _transportTypes = [];

  // Тағйирёбандаҳо барои нигоҳ доштани интихобҳо
  City? _selectedOriginCity;
  City? _selectedDestCity;
  TransportCategory? _selectedTransport;

  @override
  void initState() {
    super.initState();
    _loadDataForFilters();
  }

  Future<void> _loadDataForFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://app.payvandtrans.com/api/cities/'),
            headers: {'Authorization': 'Bearer $token'}),
        http.get(Uri.parse('https://app.payvandtrans.com/api/transports/'),
            headers: {'Authorization': 'Bearer $token'}),
      ]);

      List<City> citiesList = [];
      if (responses[0].statusCode == 200) {
        final data = json.decode(utf8.decode(responses[0].bodyBytes));
        citiesList =
            (data['results'] as List).map((c) => City.fromJson(c)).toList();
      }

      List<TransportCategory> transportList = [];
      if (responses[1].statusCode == 200) {
        final data = json.decode(utf8.decode(responses[1].bodyBytes));
        transportList = (data['results'] as List)
            .map((t) => TransportCategory.fromJson(t))
            .toList();
      }

      if (mounted) {
        setState(() {
          _cities = citiesList;
          _transportTypes = transportList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print(e);
    }
  }

  void _applyFilter() {
    final filters = FilterSettings(
      transport: _selectedTransport,
      originCity: _selectedOriginCity,
      destCity: _selectedDestCity,
    );
    Navigator.of(context)
        .pop(filters); // Танзимоти филтрро ба саҳифаи пешина бармегардонем
  }

  void _resetFilter() {
    Navigator.of(context).pop(FilterSettings()); // Филтри холиро бармегардонем
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2a2a2e),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Фильтр',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFFdcd232)),
            onPressed: _applyFilter,
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFdcd232)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdown<TransportCategory>(
                    label: 'Тип транспорта',
                    hint: 'Все',
                    items: _transportTypes,
                    value: _selectedTransport,
                    onChanged: (val) =>
                        setState(() => _selectedTransport = val),
                    itemBuilder: (item) => Text(item.name),
                  ),
                  const SizedBox(height: 20),
                  _buildDropdown<City>(
                    label: 'Город погрузки',
                    hint: 'Все',
                    items: _cities,
                    value: _selectedOriginCity,
                    onChanged: (val) =>
                        setState(() => _selectedOriginCity = val),
                    itemBuilder: (item) => Text(item.name),
                  ),
                  const SizedBox(height: 20),
                  _buildDropdown<City>(
                    label: 'Город выгрузки',
                    hint: 'Все',
                    items: _cities,
                    value: _selectedDestCity,
                    onChanged: (val) => setState(() => _selectedDestCity = val),
                    itemBuilder: (item) => Text(item.name),
                  ),

                  // Майдонҳо барои Расстояние ва Цена дар ин ҷо илова мешаванд

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFdcd232),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ПРИМЕНИТЬ ФИЛЬТР',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _resetFilter,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('СБРОСИТЬ ФИЛЬТР',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required String hint,
    required List<T> items,
    required T? value,
    required Function(T?) onChanged,
    required Widget Function(T) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items
              .map((item) =>
                  DropdownMenuItem<T>(value: item, child: itemBuilder(item)))
              .toList(),
          onChanged: onChanged,
          hint: Text(hint, style: const TextStyle(color: Colors.white)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2a2a2e),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
          dropdownColor: const Color(0xFF3d3e42),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
        ),
      ],
    );
  }
}
