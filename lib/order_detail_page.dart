import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/transport_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/request_model.dart';
import 'balance_page.dart';
import 'route_map_page.dart';

class OrderDetailPage extends StatefulWidget {
  final int requestId;
  final String? userRole;

  const OrderDetailPage({super.key, required this.requestId, this.userRole});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool _isLoading = true;
  Request? _requestData;
  String? _driverBalance;
  String? _errorMessage;

  // NEW: Store the full driver profile to get vehicle info
  Map<String, dynamic>? _driverProfile;

  final _priceController = TextEditingController();
  String _commissionText = '0.00 смн';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _priceController.addListener(_validateAndCalculateCommission);
  }

  @override
  void dispose() {
    _priceController.removeListener(_validateAndCalculateCommission);
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final requestFuture = http.get(
          Uri.parse(
              'https://app.payvandtrans.com/api/detail/?id=${widget.requestId}'),
          headers: {'Authorization': 'Bearer $token'});

      if (widget.userRole == 'driver') {
        final responses = await Future.wait([
          requestFuture,
          http.get(Uri.parse('https://app.payvandtrans.com/api/me/'),
              headers: {'Authorization': 'Bearer $token'}),
        ]);

        if (mounted) {
          if (responses[0].statusCode == 200) {
            final requestJson =
                json.decode(utf8.decode(responses[0].bodyBytes));
            _requestData = Request.fromJson(requestJson);
            _priceController.text = _requestData?.priceTjs?.toString() ?? '0';
          }
          if (responses.length > 1 && responses[1].statusCode == 200) {
            final profileJson =
                json.decode(utf8.decode(responses[1].bodyBytes));
            _driverBalance = profileJson['balance'];
          }
        }
      } else {
        final response = await requestFuture;
        if (mounted && response.statusCode == 200) {
          final requestJson = json.decode(utf8.decode(response.bodyBytes));
          _requestData = Request.fromJson(requestJson);
        }
      }
    } catch (e) {
      print("Error fetching data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _validateAndCalculateCommission() {
    if (_requestData == null) return;
    final enteredPrice = double.tryParse(_priceController.text) ?? 0.0;
    final commissionPercentageFromServer =
        _requestData!.commissionPercentage ?? 5.0;

    final commissionRate = commissionPercentageFromServer / 100.0;

    final commission = enteredPrice * commissionRate;
    // ================================

    setState(() {
      // Санҷиши нарх бе тағйир мемонад
      final originalPrice = _requestData!.priceTjs ?? 0.0;
      if (enteredPrice != originalPrice) {
        _errorMessage = 'Сумма должна соответствовать сумме заказа';
      } else {
        _errorMessage = null;
      }
      _commissionText = '${commission.toStringAsFixed(2)} смн';
    });
  }

  // NEW: Dialog to confirm if transport type mismatches
  Future<bool?> _showTransportMismatchDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Внимание'),
        content: const Text(
            'Тип вашего транспорта не соответствует требованиям данного заказа. Вы действительно хотите откликнуться на заказ?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Отмена'),
            onPressed: () {
              Navigator.of(ctx).pop(false);
            },
          ),
          TextButton(
            child: const Text('Да'),
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _respondToOrder() async {
    if (_errorMessage != null || _requestData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Пожалуйста, введите правильную сумму.'),
          backgroundColor: Colors.orange));
      return;
    }

    // Санҷиши мувофиқати намуди транспорт
    final requiredTransport = _requestData!.transport;
    final driverTransport =
        _driverProfile?['transport_category_detail']?['name'];

    if (driverTransport != null &&
        requiredTransport != null &&
        driverTransport != requiredTransport) {
      final confirmed = await _showTransportMismatchDialog();
      if (confirmed != true) {
        return; // Агар корбар "Отмена"-ро пахш кунад, амалиёт қатъ мешавад
      }
    }

    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.post(
        Uri.parse(
            'https://app.payvandtrans.com/api/requests/${widget.requestId}/respond/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'price': _priceController.text}),
      );

      final responseBody = json.decode(utf8.decode(response.bodyBytes));

      if (!mounted) return;

      // === МАНТИҚИ НАВ БАРОИ САНҶИШИ ВЕРИФИКАТСИЯ (403) ===
      if (response.statusCode == 403) {
        final errorMessage =
            responseBody['message'] ?? 'Сначала пройдите верификацию!';

        // 1. Паёми хатогиро нишон медиҳем
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(errorMessage, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ));

        // 2. Ба саҳифаи "Транспорт" мегузарем
        Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const TransportPage()));
      } else if (response.statusCode == 201) {
        // 201 - Муваффақ
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Вы успешно откликнулись на заказ!'),
            backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      } else if (response.statusCode == 400 &&
          responseBody['message'] == 'Баланс недостаточен') {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ошибка'),
            content: const Text(
                'Уважаемый водитель, ваш баланс недостаточен для списания комиссии.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Закрыть')),
              TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BalancePage()));
                  },
                  child: const Text('Пополнить баланс')),
            ],
          ),
        );
      } else {
        // Дигар хатогиҳо
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Ошибка: ${responseBody['message'] ?? 'Неизвестная ошибка'}'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка сети: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeOrderAsClient() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
            'https://app.payvandtrans.com/api/orders/${widget.requestId}/client_close/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Заказ успешно закрыт!'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(true);
      } else {
        final data = json.decode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Ошибка: ${data['message'] ?? 'Не удалось закрыть заказ'}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка сети: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCloseConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text(
            'Вы уверены, что хотите завершить и закрыть этот заказ? Это действие необратимо.'),
        actions: [
          TextButton(
            child: const Text('Отмена'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Да, закрыть'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _closeOrderAsClient();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Color(0xFF212121),
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFdcd232))));
    }
    if (_requestData == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF212121),
          body: Center(
              child: Text('Не удалось загрузить данные заказа',
                  style: TextStyle(color: Colors.white))));
    }

    final r = _requestData!;
    final bool isDriver = widget.userRole == 'driver';
    final bool isClient = widget.userRole == 'client';

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF212121),
        elevation: 0,
        title: Text('Заказ № ${r.id}',
            style: const TextStyle(color: Colors.white)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2e),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Название', r.name),
                  _buildDetailRow('Транспорт', r.transport),
                  const Divider(color: Colors.white24, height: 24),
                  _buildDetailRow('Дата погрузки', r.loadDate),
                  _buildDetailRow('Срок доставки', r.deliveryDate),
                  _buildDetailRow('Расстояние',
                      '${r.distanceKm?.toStringAsFixed(2) ?? '0'} км'),
                  _buildDetailRow('Общий вес', '${r.tonnageT ?? 0} т'),
                  _buildDetailRow('Сумма заказа',
                      '${r.priceTjs?.toStringAsFixed(0) ?? '0'} смн',
                      isPrice: true),
                ],
              ),
            ),

            _buildInfoCard('Погрузка', r),
            _buildInfoCard('Выгрузка', r),
            _buildDescriptionCard('Описание', r.description),

            if (r.originStops.isNotEmpty || r.destinationStops.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.map_outlined,
                        color: Color(0xFFdcd232)),
                    label: const Text('Посмотреть на карте',
                        style: TextStyle(
                            color: Color(0xFFdcd232),
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RouteMapPage(
                            originStops: r.originStops,
                            destStops: r.destinationStops,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // === БЛОКҲОИ БАРОИ РОНАНДА ВА КЛИЕНТ, КИ ШУМО ИЛОВА НАКАРДА БУДЕД ===
            if (isDriver)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2e),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Укажите цену, за которую вы готовы выполнить заказ',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Сумма',
                        labelStyle: const TextStyle(color: Colors.white70),
                        errorText: _errorMessage,
                        errorStyle: const TextStyle(color: Colors.redAccent),
                        filled: true,
                        fillColor: const Color(0xFF212121),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: _errorMessage == null
                                    ? const Color(0xFFdcd232)
                                    : Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Комиссия за заказ: $_commissionText',
                        style: const TextStyle(color: Colors.white70)),
                    Text('Ваш баланс ${_driverBalance ?? '0'} смн',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            if (isClient && r.status != 'completed' && r.status != 'closed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showCloseConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Завершить и закрыть заказ',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ),

            if (isDriver)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _respondToOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFdcd232),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ОТКЛИКНУТЬСЯ НА ЗАКАЗ',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              )
            // ====================================================================
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool isPrice = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value ?? '-',
              style: TextStyle(
                  color: isPrice ? const Color(0xFFdcd232) : Colors.white,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, Request requestData) {
    final bool isOrigin = title == 'Погрузка';
    final List<dynamic> stops =
        isOrigin ? requestData.originStops : requestData.destinationStops;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF2a2a2e),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (stops.isEmpty)
            const Text('Не указано', style: TextStyle(color: Colors.white70)),
          ...stops.map((stop) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stop.city != null && stop.city.isNotEmpty)
                    Row(
                      children: [
                        const Text('город: ',
                            style: TextStyle(color: Colors.white70)),
                        Expanded(
                            child: Text(stop.city,
                                style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  if (stop.address != null && stop.address.isNotEmpty)
                    Row(
                      children: [
                        const Text('адрес: ',
                            style: TextStyle(color: Colors.white70)),
                        Expanded(
                            child: Text(stop.address,
                                style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  if (stop.warehouse != null && stop.warehouse.isNotEmpty)
                    Row(
                      children: [
                        const Text('склад: ',
                            style: TextStyle(color: Colors.white70)),
                        Expanded(
                            child: Text(stop.warehouse,
                                style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  if (stop != stops.last)
                    const Divider(color: Colors.white12, height: 16),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // === ИН ФУНКСИЯИ НАВ БАРОИ "ОПИСАНИЕ" АСТ ===
  Widget _buildDescriptionCard(String title, String? description) {
    // Агар "Описание" холӣ бошад, ин виджетро умуман нишон намедиҳем
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink(); // Виҷети ноаён
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF2a2a2e),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
