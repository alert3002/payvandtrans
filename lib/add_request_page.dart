import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/city_model.dart';
import 'models/transport_model.dart';
import 'success_page.dart';
import 'map_popup.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'models/request_model.dart';
import 'route_map_page.dart';

class Stop {
  City? city;
  final TextEditingController addressController;
  final TextEditingController warehouseController;
  double? lat;
  double? lng;
  int? cityId; // дополнительное поле для надёжного сравнения

  Stop({
    this.city,
    required this.addressController,
    required this.warehouseController,
    this.lat,
    this.lng,
    this.cityId,
  });
}

class AddRequestPage extends StatefulWidget {
  const AddRequestPage({super.key});

  @override
  State<AddRequestPage> createState() => _AddRequestPageState();
}

class _AddRequestPageState extends State<AddRequestPage> {
  Timer? _debounce;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _tonnageController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Stop> _originStops = [];
  List<Stop> _destinationStops = [];

  TransportCategory? _selectedTransport;
  DateTime? _loadDate;
  DateTime? _deliveryDate;
  late Future<List<TransportCategory>> _transportCategoriesFuture;
  late Future<List<City>> _citiesFuture;
  String? _distanceKm;

  // Сохраняем локально список, чтобы быстро искать по id
  List<City> _citiesCache = [];

  @override
  void initState() {
    super.initState();
    _originStops.add(Stop(
        addressController: TextEditingController(),
        warehouseController: TextEditingController()));
    _destinationStops.add(Stop(
        addressController: TextEditingController(),
        warehouseController: TextEditingController()));
    _transportCategoriesFuture = _fetchTransportCategories();
    _citiesFuture = _fetchCities();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _priceController.dispose();
    _tonnageController.dispose();
    _descriptionController.dispose();
    for (var stop in _originStops) {
      stop.addressController.dispose();
      stop.warehouseController.dispose();
    }
    for (var stop in _destinationStops) {
      stop.addressController.dispose();
      stop.warehouseController.dispose();
    }
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ));
    }
  }

  void _addStop({required bool isOrigin}) {
    setState(() {
      if (isOrigin) {
        if (_originStops.length < 4) {
          _originStops.add(Stop(
              addressController: TextEditingController(),
              warehouseController: TextEditingController()));
        } else {
          _showErrorSnackBar('Максимум 4 адрес можно добавить.');
        }
      } else {
        if (_destinationStops.length < 4) {
          _destinationStops.add(Stop(
              addressController: TextEditingController(),
              warehouseController: TextEditingController()));
        } else {
          _showErrorSnackBar('Максимум 4 адреса можно добавить.');
        }
      }
    });
  }

  void _removeStop(int index, {required bool isOrigin}) {
    setState(() {
      if (isOrigin) {
        if (_originStops.length > 1) {
          _originStops[index].addressController.dispose();
          _originStops[index].warehouseController.dispose();
          _originStops.removeAt(index);
        }
      } else {
        if (_destinationStops.length > 1) {
          _destinationStops[index].addressController.dispose();
          _destinationStops[index].warehouseController.dispose();
          _destinationStops.removeAt(index);
        }
      }
      _calculateDistance();
    });
  }

  Future<void> _geocodeCityCenter(Stop stop) async {
    if (stop.city == null && stop.cityId == null) return;

    final cityName = stop.city?.name ??
        _citiesCache
            .firstWhere((c) => c.id == stop.cityId,
                orElse: () => City(id: 0, name: ''))
            .name;
    if (cityName.isEmpty) return;

    final viewbox = '67.3,41.1,75.2,36.7'; // Сарҳади Тоҷикистон

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cityName)}&format=json&limit=1&viewbox=$viewbox&bounded=1&countrycodes=tj');

    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'tj.payvandtrans.app/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lng = double.parse(data[0]['lon']);
          if (mounted) {
            setState(() {
              stop.lat = lat;
              stop.lng = lng;
            });
            _calculateDistance();
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Не удалось найти центр города.');
    }
  }

  Future<void> _geocodeAddress(Stop stop) async {
    final cityName = stop.city?.name ??
        _citiesCache
            .firstWhere((c) => c.id == stop.cityId,
                orElse: () => City(id: 0, name: ''))
            .name;
    if (stop.addressController.text.isEmpty || cityName.isEmpty) return;

    final fullAddress = "$cityName, ${stop.addressController.text}";
    final viewbox = '67.3,41.1,75.2,36.7';

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(fullAddress)}&format=json&limit=1&viewbox=$viewbox&bounded=1&countrycodes=tj');

    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'tj.payvandtrans.app/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lng = double.parse(data[0]['lon']);

          if (mounted) {
            setState(() {
              stop.lat = lat;
              stop.lng = lng;
            });
            _calculateDistance();
          }
        } else {
          await _geocodeCityCenter(stop);
        }
      } else {
        await _geocodeCityCenter(stop);
      }
    } catch (e) {
      await _geocodeCityCenter(stop);
    }
  }

  Future<void> _reverseGeocode(Stop stop, double lat, double lng) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json');
    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'tj.payvandtrans.app/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String address = data['display_name'] ?? 'Точка на карте';
        setState(() {
          stop.lat = lat;
          stop.lng = lng;
          stop.addressController.text = address;
        });
        _calculateDistance();
      }
    } catch (e) {
      print('Ошибка обратного геокодирования (Nominatim): $e');
    }
  }

  Future<void> _calculateDistance() async {
    final allStops = [..._originStops, ..._destinationStops];
    final pointsWithCoords =
        allStops.where((stop) => stop.lat != null && stop.lng != null).toList();

    if (pointsWithCoords.length < 2) {
      setState(() {
        _distanceKm = null;
      });
      return;
    }

    final waypoints =
        pointsWithCoords.map((stop) => '${stop.lng},${stop.lat}').join(';');
    final url =
        'https://router.project-osrm.org/route/v1/driving/$waypoints?overview=false';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final distanceMeters = data['routes'][0]['distance'];
          if (mounted) {
            setState(() {
              _distanceKm = (distanceMeters / 1000).toStringAsFixed(2);
            });
          }
        } else {
          _showErrorSnackBar('Не удалось проложить маршрут.');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Ошибка расчёта расстояния: $e');
    }
  }

  Future<void> _showMapDialog(Stop stop) async {
    final LatLng initialPoint = stop.lat != null && stop.lng != null
        ? LatLng(stop.lat!, stop.lng!)
        : const LatLng(38.8, 71.2);

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => MapPopup(initialPoint: initialPoint),
    );

    if (result != null &&
        result.containsKey('lat') &&
        result.containsKey('lng')) {
      if (mounted) {
        await _reverseGeocode(stop, result['lat']!, result['lng']!);
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Пожалуйста, заполните все обязательные поля.');
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final String allOriginAddresses =
        _originStops.map((stop) => stop.addressController.text).join(';');
    final String allOriginWarehouses =
        _originStops.map((stop) => stop.warehouseController.text).join(';');
    final String allDestAddresses =
        _destinationStops.map((stop) => stop.addressController.text).join(';');
    final String allDestWarehouses = _destinationStops
        .map((stop) => stop.warehouseController.text)
        .join(';');

    final url = Uri.parse('https://app.payvandtrans.com/api/requests/create/');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final body = json.encode({
      'name': _nameController.text,
      'transport': _selectedTransport?.id,
      'load_date': _loadDate?.toIso8601String().substring(0, 10),
      'delivery_date': _deliveryDate?.toIso8601String().substring(0, 10),
      'origin_cities':
          _originStops.map((stop) => stop.city?.id ?? stop.cityId).toList(),
      'dest_cities': _destinationStops
          .map((stop) => stop.city?.id ?? stop.cityId)
          .toList(),
      'origin_address': allOriginAddresses,
      'origin_warehouse': allOriginWarehouses,
      'dest_address': allDestAddresses,
      'dest_warehouse': allDestWarehouses,
      'price_tjs':
          _priceController.text.isNotEmpty ? _priceController.text : null,
      'tonnage_t':
          _tonnageController.text.isNotEmpty ? _tonnageController.text : null,
      'description': _descriptionController.text,
      'distance_km': _distanceKm,
      'origin_lats': _originStops.map((stop) => stop.lat).toList(),
      'origin_lngs': _originStops.map((stop) => stop.lng).toList(),
      'dest_lats': _destinationStops.map((stop) => stop.lat).toList(),
      'dest_lngs': _destinationStops.map((stop) => stop.lng).toList(),
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SuccessPage()),
          );
        }
      } else {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          _showErrorSnackBar('Ошибка: ${responseData.toString()}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Ошибка подключения: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<dynamic>> _fetchPaginatedData(String urlString) async {
    List<dynamic> all = [];
    String? next = urlString;

    while (next != null) {
      final url = Uri.parse(next);
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('Не удалось загрузить данные: ${response.statusCode}');
      }

      final decodedData = json.decode(utf8.decode(response.bodyBytes));
      if (decodedData is Map<String, dynamic>) {
        // Если API возвращает пагинацию
        if (decodedData.containsKey('results')) {
          final results = decodedData['results'] as List<dynamic>;
          all.addAll(results);
          // следующий URL может быть абсолютным
          next = (decodedData['next'] != null &&
                  decodedData['next'].toString().isNotEmpty)
              ? decodedData['next'].toString()
              : null;
        } else {
          // Непагинированный объект — пробуем найти вложенный список
          bool found = false;
          decodedData.forEach((k, v) {
            if (!found && v is List) {
              all.addAll(v);
              found = true;
            }
          });
          if (!found) throw Exception('Неизвестный формат JSON');
          next = null;
        }
      } else if (decodedData is List) {
        all.addAll(decodedData);
        next = null;
      } else {
        throw Exception('Неизвестный формат JSON');
      }
    }

    return all;
  }

  Future<List<TransportCategory>> _fetchTransportCategories() async {
    final data = await _fetchPaginatedData(
        'https://app.payvandtrans.com/api/transports/');
    return data.map((json) => TransportCategory.fromJson(json)).toList();
  }

  Future<List<City>> _fetchCities() async {
    final data =
        await _fetchPaginatedData('https://app.payvandtrans.com/api/cities/');
    final list = data.map((json) => City.fromJson(json)).toList();
    // Обновляем локальный кеш для поиска по id
    _citiesCache = list;
    return list;
  }

  Future<void> _selectDate(BuildContext context, bool isLoadDate) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2030));
    if (picked != null) {
      setState(() {
        if (isLoadDate) {
          _loadDate = picked;
        } else {
          _deliveryDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        title: const Text('Добавить заказ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2a2a2e),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildSection(
                icon: Icons.title,
                title: 'Название',
                child: _buildTextField(
                  controller: _nameController,
                  hint: 'Название товара',
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Пожалуйста, введите название'
                      : null,
                ),
              ),
              _buildSection(
                icon: Icons.directions_car,
                title: 'Транспорт',
                child: _buildDropdown<TransportCategory>(
                  future: _transportCategoriesFuture,
                  hint: 'Категория транспорта',
                  value: _selectedTransport,
                  onChanged: (item) =>
                      setState(() => _selectedTransport = item),
                  itemBuilder: (item) =>
                      DropdownMenuItem(value: item, child: Text(item.name)),
                  validator: (value) =>
                      (value == null) ? 'Пожалуйста, выберите транспорт' : null,
                ),
              ),
              _buildSection(
                icon: Icons.date_range,
                title: 'Даты',
                child: Row(children: [
                  Expanded(
                      child: _buildDateField('Дата погрузки', _loadDate,
                          () => _selectDate(context, true))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildDateField('Срок доставки', _deliveryDate,
                          () => _selectDate(context, false))),
                ]),
              ),
              _buildSection(
                icon: Icons.location_on_outlined,
                title: 'Откуда',
                child: Column(
                  children: [
                    ..._originStops.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Stop stop = entry.value;
                      return _buildStopInputWidget(stop, idx, isOrigin: true);
                    }).toList(),
                    if (_originStops.length < 4)
                      _buildAddButton(
                          onPressed: () => _addStop(isOrigin: true)),
                  ],
                ),
              ),
              _buildSection(
                icon: Icons.flag_outlined,
                title: 'Куда',
                child: Column(
                  children: [
                    ..._destinationStops.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Stop stop = entry.value;
                      return _buildStopInputWidget(stop, idx, isOrigin: false);
                    }).toList(),
                    if (_destinationStops.length < 4)
                      _buildAddButton(
                          onPressed: () => _addStop(isOrigin: false)),
                  ],
                ),
              ),
              if (_distanceKm != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Расстояние: $_distanceKm км',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      IconButton(
                        icon:
                            const Icon(Icons.map_outlined, color: Colors.green),
                        onPressed: () {
                          final List<OriginStop> originStopsForMap =
                              _originStops
                                  .map((s) => OriginStop(
                                        city: s.city?.name ?? '',
                                        address: s.addressController.text,
                                        warehouse: s.warehouseController.text,
                                        lat: s.lat,
                                        lng: s.lng,
                                      ))
                                  .toList();

                          final List<DestinationStop> destStopsForMap =
                              _destinationStops
                                  .map((s) => DestinationStop(
                                        city: s.city?.name ?? '',
                                        address: s.addressController.text,
                                        warehouse: s.warehouseController.text,
                                        lat: s.lat,
                                        lng: s.lng,
                                      ))
                                  .toList();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RouteMapPage(
                                originStops: originStopsForMap,
                                destStops: destStopsForMap,
                              ),
                            ),
                          );
                        },
                      )
                    ],
                  ),
                ),
              _buildSection(
                  icon: Icons.info_outline,
                  title: 'Дополнительная информация',
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildTextField(
                        controller: _priceController,
                        hint: 'Цена (смн)',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Введите цену'
                            : null,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildTextField(
                        controller: _tonnageController,
                        hint: 'Тонна (т)',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Введите тоннаж'
                            : null,
                      )),
                    ],
                  )),
              _buildSection(
                icon: Icons.description_outlined,
                title: 'Описание (необязательно)',
                child: _buildTextField(
                    controller: _descriptionController,
                    hint: 'Подробно указал в вашей заявке...',
                    maxLines: 4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFdcd232),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Добавить',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopInputWidget(Stop stop, int index, {required bool isOrigin}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Передаём future и текущий Stop (чтобы корректно выбрать элемент по id)
                _buildDropdown<City>(
                  future: _citiesFuture,
                  hint: 'Город',
                  value: stop.city,
                  onChanged: (item) {
                    // При выборе сохраняем и объект и id
                    setState(() {
                      stop.city = item;
                      stop.cityId = item?.id;
                    });
                    if (stop.addressController.text.isNotEmpty) {
                      _geocodeAddress(stop);
                    } else {
                      // если адрес пуст — попытка получить центр города
                      _geocodeCityCenter(stop);
                    }
                  },
                  itemBuilder: (item) =>
                      DropdownMenuItem(value: item, child: Text(item.name)),
                  validator: (value) =>
                      (value == null) ? 'Выберите город' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: stop.addressController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Адрес',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF212121),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          errorStyle:
                              const TextStyle(color: Colors.orangeAccent),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Введите адрес'
                            : null,
                        onChanged: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 1000), () {
                            _geocodeAddress(stop);
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.map_outlined,
                          color: stop.lat != null
                              ? Colors.green
                              : const Color(0xFFdcd232)),
                      onPressed: () => _showMapDialog(stop),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: stop.warehouseController,
                  hint: 'Склад (необязательно)',
                ),
                if (stop.lat != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Координаты: ${stop.lat?.toStringAsFixed(4)}, ${stop.lng?.toStringAsFixed(4)}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  )
              ],
            ),
          ),
          if ((isOrigin && _originStops.length > 1) ||
              (!isOrigin && _destinationStops.length > 1))
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.redAccent),
              onPressed: () => _removeStop(index, isOrigin: isOrigin),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton({required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_circle_outline,
            color: Color(0xFFdcd232), size: 20),
        label: const Text('Добавить другой город и адрес',
            style: TextStyle(color: Color(0xFFdcd232))),
      ),
    );
  }

  Widget _buildSection(
      {required IconData icon, required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF2a2a2e),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: const Color(0xFFdcd232), size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF212121),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
      ),
      validator: validator,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildDateField(String hint, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF212121),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date == null ? hint : DateFormat('dd.MM.yyyy').format(date),
              style: TextStyle(
                  color: date == null ? Colors.white54 : Colors.white,
                  fontSize: 16),
            ),
            const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required Future<List<T>> future,
    required String hint,
    required void Function(T?) onChanged,
    required DropdownMenuItem<T> Function(T) itemBuilder,
    String? Function(T?)? validator,
    T? value,
  }) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFdcd232))));
        }
        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}',
              style: const TextStyle(color: Colors.red));
        }
        final items = snapshot.data ?? [];

        // Надёжно определяем выбранный элемент по id (если value - объект другого инстанса)
        T? selected;
        try {
          if (value != null) {
            final dynamic v = value as dynamic;
            final dynamic vid = (v is int || v is String) ? v : (v.id ?? v);
            selected = items.firstWhere(
                (it) => (it as dynamic).id.toString() == vid.toString(),
                orElse: () => null as T);
          }
        } catch (_) {
          selected = null;
        }

        return DropdownButtonFormField<T>(
          value: selected,
          onChanged: (val) => onChanged(val),
          hint: Text(hint, style: const TextStyle(color: Colors.white54)),
          dropdownColor: const Color(0xFF333333),
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF212121),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            errorStyle: const TextStyle(color: Colors.orangeAccent),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
          items: items.map(itemBuilder).toList(),
          validator: validator,
        );
      },
    );
  }
}
