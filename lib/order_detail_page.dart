import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/transport_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/request_model.dart';
import 'balance_page.dart';
import 'route_map_page.dart';
import 'constants/api_constants.dart';
import 'leave_review_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'driver_tracking_page.dart';
import 'driver_route_map_page.dart';



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

  Map<String, dynamic>? _myBidStatus;

  Map<String, dynamic>? _driverProfile;

  final _priceController = TextEditingController();

  String _commissionText = '0.00 смн';

  Timer? _locationTimer;



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
    _locationTimer?.cancel();
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

      final requestFuture = http.get(ApiConstants.getUri('api/detail/?id=${widget.requestId}'), headers: {'Authorization': 'Bearer $token'});

      if (widget.userRole == 'driver') {

        final responses = await Future.wait([

          requestFuture,

          http.get(ApiConstants.getUri('api/me/'), headers: {'Authorization': 'Bearer $token'}),

          http.get(ApiConstants.getUri('api/requests/${widget.requestId}/my_bid/'), headers: {'Authorization': 'Bearer $token'}),

        ]);

        if (mounted) {

          if (responses[0].statusCode == 200) {

            final requestJson = json.decode(utf8.decode(responses[0].bodyBytes));

            _requestData = Request.fromJson(requestJson);

            _priceController.text = _requestData?.priceTjs?.toString() ?? '0';

          }

          if (responses.length > 1 && responses[1].statusCode == 200) {

            final profileJson = json.decode(utf8.decode(responses[1].bodyBytes));

            _driverBalance = profileJson['balance']?.toString();

            _driverProfile = profileJson;

          }

          if (responses.length > 2 && responses[2].statusCode == 200) {

            final bidJson = json.decode(utf8.decode(responses[2].bodyBytes));

            if (bidJson['has_bid'] == true) {

              _myBidStatus = bidJson;

            }

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
      if (mounted) {
        setState(() => _isLoading = false);
        _maybeStartLocationUpdates();
      }
    }
  }

  void _maybeStartLocationUpdates() {
    _locationTimer?.cancel();
    if (widget.userRole != 'driver' || _myBidStatus == null) return;
    if (!['in_transit', 'active', 'awaiting'].contains(_requestData?.status)) return;
    final bidStatus = _myBidStatus!['status']?.toString().toLowerCase();
    if (bidStatus != 'accepted' && bidStatus != 'active') return;
    _sendLocationOnce();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sendLocationOnce());
  }

  Future<void> _sendLocationOnce() async {
    if (!mounted) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;
      await http.post(
        ApiConstants.getUri('api/requests/${widget.requestId}/update_location/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'lat': pos.latitude, 'lng': pos.longitude}),
      );
    } catch (_) {}
  }



  void _validateAndCalculateCommission() {

    if (_requestData == null) return;

    final enteredPrice = double.tryParse(_priceController.text) ?? 0.0;

    final commissionPercentageFromServer = _requestData!.commissionPercentage ?? 5.0;

    final commissionRate = commissionPercentageFromServer / 100.0;

    final commission = enteredPrice * commissionRate;

    setState(() {

      final originalPrice = _requestData!.priceTjs ?? 0.0;

      // Валидация: предложенная цена должна быть >= исходной цене заказа

      if (enteredPrice < originalPrice) {

        _errorMessage = 'Предложенная цена не может быть меньше суммы заказа (${originalPrice.toStringAsFixed(0)} с.)';

      } else {

        _errorMessage = null;

      }

      _commissionText = '${commission.toStringAsFixed(2)} смн';

    });

  }



  Future<bool?> _showTransportMismatchDialog() {

    return showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Внимание'),

        content: const Text('Тип вашего транспорта не соответствует требованиям данного заказа. Вы действительно хотите откликнуться на заказ?'),

        actions: <Widget>[

          TextButton(child: const Text('Отмена'), onPressed: () => Navigator.of(ctx).pop(false)),

          TextButton(child: const Text('Да'), onPressed: () => Navigator.of(ctx).pop(true)),

        ],

      ),

    );

  }



  Future<void> _respondToOrder() async {

    if (_requestData == null) {

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось загрузить данные заказа.'), backgroundColor: Colors.red));

      return;

    }

   

    // Валидация цены перед отправкой

    final enteredPrice = double.tryParse(_priceController.text) ?? 0.0;

    final originalPrice = _requestData!.priceTjs ?? 0.0;

   

    if (enteredPrice < originalPrice) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            'Предложенная цена не может быть меньше суммы заказа (${originalPrice.toStringAsFixed(0)} с.)',

            style: const TextStyle(color: Colors.white),

          ),

          backgroundColor: Colors.red,

        ),

      );

      return;

    }

   

    if (_errorMessage != null) {

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, введите правильную сумму.'), backgroundColor: Colors.orange));

      return;

    }

   

    final requiredTransport = _requestData!.transport;

    final driverTransport = _driverProfile?['transport_category_detail']?['name'];

    if (driverTransport != null && requiredTransport != null && driverTransport != requiredTransport) {

      final confirmed = await _showTransportMismatchDialog();

      if (confirmed != true) return;

    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');

    try {

      final response = await http.post(

        ApiConstants.getUri('api/requests/${widget.requestId}/respond/'),

        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},

        body: json.encode({'price': _priceController.text}),

      );

      final responseBody = json.decode(utf8.decode(response.bodyBytes));

      if (!mounted) return;

      if (response.statusCode == 403) {

        final errorMessage = responseBody['message'] ?? 'Сначала пройдите верификацию!';

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));

        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TransportPage())).then((_) => _fetchData());

      } else if (response.statusCode == 201) {

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вы успешно откликнулись на заказ!'), backgroundColor: Colors.green));

        // Обновляем данные для отображения статуса отклика, НЕ закрываем страницу

        await _fetchData();

      } else if (response.statusCode == 400 && responseBody['message'] == 'Баланс недостаточен') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Баланс недостаточен. Пополните баланс.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BalancePage())).then((_) => _fetchData());
      } else {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${responseBody['message'] ?? 'Неизвестная ошибка'}'), backgroundColor: Colors.red));

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сети: $e'), backgroundColor: Colors.red));

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

      final response = await http.post(ApiConstants.getUri('api/orders/${widget.requestId}/client_close/'), headers: {'Authorization': 'Bearer $token'});

      if (!mounted) return;

      if (response.statusCode == 200) {

        final data = json.decode(utf8.decode(response.bodyBytes));

        final orderId = data['order_id'];

       

        // Сразу после успешного закрытия перенаправляем на экран отзыва

        if (orderId != null) {

          Navigator.of(context).pushReplacement(

            MaterialPageRoute(

              builder: (context) => LeaveReviewPage(orderId: orderId),

            ),

          );

        } else {

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заказ успешно закрыт!'), backgroundColor: Colors.green));

          Navigator.of(context).pop(true);

        }

      } else {

        final data = json.decode(utf8.decode(response.bodyBytes));

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${data['message'] ?? 'Не удалось закрыть заказ'}'), backgroundColor: Colors.red));

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сети: $e'), backgroundColor: Colors.red));

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

        content: const Text('Вы уверены, что хотите завершить и закрыть этот заказ? Это действие необратимо.'),

        actions: [

          TextButton(child: const Text('Отмена'), onPressed: () => Navigator.of(ctx).pop()),

          TextButton(child: const Text('Да, закрыть'), onPressed: () { Navigator.of(ctx).pop(); _closeOrderAsClient(); }),

        ],

      ),

    );

  }



  String _getBidStatusText(String? status) {

    switch (status?.toLowerCase()) {

      case 'pending':

        return 'Ожидание рассмотрения';

      case 'awaiting_confirmation':

        return 'Ожидание рассмотрения';

      case 'accepted':

        return 'Заказ принят';

      case 'rejected':

        return 'Заказ отклонен';

      case 'active':

        return 'Заказ принят';

      case 'closed':

        return 'Заказ отклонен';

      default:

        return 'Неизвестно';

    }

  }

 

  String _getRequestStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'На рассмотрении';
      case 'active':
        return 'Актив';
      case 'awaiting_confirmation':
        return 'Ожидает рассмотрения';
      case 'awaiting':
        return 'Ожидание';
      case 'in_transit':
        return 'В пути';
      case 'closed':
        return 'Закрыт';
      default:
        return 'Неизвестно';
    }
  }



  String _formatDateTime(String? dateTimeStr) {

    if (dateTimeStr == null) return '-';

    try {

      final dt = DateTime.parse(dateTimeStr);

      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    } catch (e) {

      return dateTimeStr;

    }

  }



  @override

  Widget build(BuildContext context) {

    if (_isLoading) {

      return const Scaffold(backgroundColor: Color(0xFF212121), body: Center(child: CircularProgressIndicator(color: Color(0xFFdcd232))));

    }

    if (_requestData == null) {

      return const Scaffold(backgroundColor: Color(0xFF212121), body: Center(child: Text('Не удалось загрузить данные заказа', style: TextStyle(color: Colors.white))));

    }

    final r = _requestData!;

    final bool isDriver = widget.userRole == 'driver';

    final bool isClient = widget.userRole == 'client';

    return Scaffold(

      backgroundColor: const Color(0xFF212121),

      appBar: AppBar(

        backgroundColor: const Color(0xFF212121),

        elevation: 0,

        title: Text('Заказ № ${r.id}', style: const TextStyle(color: Colors.white)),

        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),

        actions: [

          IconButton(

            icon: const Icon(Icons.refresh, color: Colors.white),

            onPressed: () {

              setState(() => _isLoading = true);

              _fetchData();

            },

            tooltip: 'Обновить',

          ),

        ],

      ),

      body: RefreshIndicator(

        onRefresh: _fetchData,

        color: const Color(0xFFdcd232),

        backgroundColor: const Color(0xFF2a2a2e),

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(16.0),

          physics: const AlwaysScrollableScrollPhysics(), // Позволяет pull-to-refresh даже когда контент не скроллится

          child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Container(

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(color: const Color(0xFF2a2a2e), borderRadius: BorderRadius.circular(12)),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  _buildDetailRow('Название', r.name),

                  _buildDetailRow('Транспорт', r.transport),

                  _buildDetailRow('Статус заявки', _getRequestStatusText(r.status)),

                  // Телефоны при статусе awaiting (принят) или in_transit (в пути)
                  if (r.status == 'in_transit' || r.status == 'awaiting') ...[

                    const Divider(color: Colors.white24, height: 24),

                    if (isClient && r.driverPhone != null && r.driverPhone!.isNotEmpty)

                      _buildPhoneRow('Тел: водителя', r.driverPhone!),

                    if (isDriver && r.clientPhone != null && r.clientPhone!.isNotEmpty)

                      _buildPhoneRow('Тел: клиента', r.clientPhone!),

                  ],

                  const Divider(color: Colors.white24, height: 24),

                  _buildDetailRow('Дата погрузки', r.loadDate),

                  _buildDetailRow('Срок доставки', r.deliveryDate),

                  _buildDetailRow('Расстояние', '${r.distanceKm?.toStringAsFixed(2) ?? '0'} км'),

                  _buildDetailRow('Общий вес', '${r.tonnageT ?? 0} т'),

                  _buildDetailRow('Сумма заказа', '${r.priceTjs?.toStringAsFixed(0) ?? '0'} смн', isPrice: true),

                ],

              ),

            ),

            _buildInfoCard('Погрузка', r),

            _buildInfoCard('Выгрузка', r),

            _buildDescriptionCard('Описание', r.description),

            if (isDriver && _myBidStatus != null)

              Container(

                margin: const EdgeInsets.only(top: 16),

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(color: const Color(0xFF2a2a2e), borderRadius: BorderRadius.circular(12)),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text('Вы откликнулись на заказ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

                    const SizedBox(height: 12),

                    _buildDetailRow('Сумма', '${_myBidStatus!['price'] ?? r.priceTjs?.toStringAsFixed(0) ?? '0'} смн', isPrice: true),

                    if (_myBidStatus!['created_at'] != null) _buildDetailRow('Время отклика', _formatDateTime(_myBidStatus!['created_at'])),

                    const SizedBox(height: 12),

                    Row(

                      children: [

                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFdcd232))),

                        const SizedBox(width: 8),

                        Text(_getBidStatusText(_myBidStatus!['status']), style: const TextStyle(color: Color(0xFFdcd232), fontSize: 16, fontWeight: FontWeight.bold)),

                      ],

                    ),

                  ],

                ),

              ),

            if (r.originStops.isNotEmpty || r.destinationStops.isNotEmpty)

              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isClient && r.status != 'in_transit')
                      TextButton.icon(
                        icon: const Icon(Icons.map_outlined, color: Color(0xFFdcd232)),
                        label: const Text('Посмотреть на карте', style: TextStyle(color: Color(0xFFdcd232), fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => RouteMapPage(originStops: r.originStops, destStops: r.destinationStops))).then((_) => _fetchData());
                        },
                      ),
                    if (isClient && r.status == 'in_transit')
                      TextButton.icon(
                        icon: const Icon(Icons.local_shipping, color: Color(0xFFdcd232)),
                        label: const Text('Где водитель?', style: TextStyle(color: Color(0xFFdcd232), fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DriverTrackingPage(request: r))).then((_) => _fetchData());
                        },
                      ),
                    if (isDriver && (r.status == 'in_transit' || r.status == 'active' || r.status == 'awaiting'))
                      TextButton.icon(
                        icon: const Icon(Icons.local_shipping, color: Color(0xFFdcd232)),
                        label: const Text('Моя позиция', style: TextStyle(color: Color(0xFFdcd232), fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DriverRouteMapPage(request: r)));
                        },
                      ),
                  ],
                ),
              ),
            if (isDriver && _myBidStatus == null)

              Container(

                margin: const EdgeInsets.only(top: 16),

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(color: const Color(0xFF2a2a2e), borderRadius: BorderRadius.circular(12)),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text('Укажите цену, за которую вы готовы выполнить заказ', style: TextStyle(color: Colors.white, fontSize: 16)),

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

                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),

                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _errorMessage == null ? const Color(0xFFdcd232) : Colors.redAccent)),

                      ),

                    ),

                    const SizedBox(height: 12),

                    Text('Комиссия за заказ: $_commissionText', style: const TextStyle(color: Colors.white70)),

                    Text('Ваш баланс ${_driverBalance ?? '0'} смн', style: const TextStyle(color: Colors.white70)),

                  ],

                ),

              ),

            const SizedBox(height: 24),

            if (isClient && r.status != 'completed' && r.status != 'closed')

              SizedBox(

                width: double.infinity,

                child: ElevatedButton(

                  onPressed: _showCloseConfirmationDialog,

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),

                  child: const Text('Завершить и закрыть заказ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),

                ),

              ),

            if (isDriver && _myBidStatus == null)

              SizedBox(

                width: double.infinity,

                child: ElevatedButton(

                  onPressed: _respondToOrder,

                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFdcd232), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),

                  child: const Text('ОТКЛИКНУТЬСЯ НА ЗАКАЗ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),

                ),

              )

          ],

          ),

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

          Text(value ?? '-', style: TextStyle(color: isPrice ? const Color(0xFFdcd232) : Colors.white, fontWeight: FontWeight.bold)),

        ],

      ),

    );

  }



  // Функсия барои нормализатсияи номер телефона
  String _normalizePhone(String phone) {
    // Убираем все символы кроме цифр
    String normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Если номер начинается с 992, оставляем как есть
    // Если начинается с 9 (9 цифр), добавляем 992
    if (normalized.length == 9 && normalized.startsWith('9')) {
      normalized = '992$normalized';
    }
    // Убеждаемся, что номер начинается с 992
    if (!normalized.startsWith('992') && normalized.length >= 9) {
      if (normalized.startsWith('9')) {
        normalized = '992$normalized';
      }
    }
    return normalized;
  }

  // Функсия барои кушодани URL
  Future<void> _launchUrl(String url, {LaunchMode mode = LaunchMode.externalApplication}) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть: $url'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при запуске URL: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Функсия барои кушодани Telegram
  Future<void> _launchTelegram(String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    // Используем веб-ссылку, которая автоматически откроет приложение
    final webLink = Uri.parse('https://t.me/+$normalizedPhone');
    
    try {
      // Пробуем сначала веб-ссылку (она автоматически откроет приложение если установлено)
      await launchUrl(webLink, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Если не получилось, пробуем deep link
      try {
        final deepLink = Uri.parse('tg://resolve?phone=$normalizedPhone');
        await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось открыть Telegram. Убедитесь, что приложение установлено.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Функсия барои кушодани WhatsApp
  Future<void> _launchWhatsApp(String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    // Используем веб-ссылку, которая автоматически откроет приложение
    final webLink = Uri.parse('https://wa.me/$normalizedPhone');
    
    try {
      // Пробуем сначала веб-ссылку (она автоматически откроет приложение если установлено)
      await launchUrl(webLink, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Если не получилось, пробуем deep link
      try {
        final deepLink = Uri.parse('whatsapp://send?phone=$normalizedPhone');
        await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось открыть WhatsApp. Убедитесь, что приложение установлено.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildContactIcon(IconData icon, VoidCallback onTap, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildPhoneRow(String label, String phone) {
    final String _adminPhone = '105778888'; // Номер телефона администратора

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF2a2a2e),
                  contentPadding: const EdgeInsets.all(16),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Номер телефон администратора
                      Text(
                        'Номер телефон администратора',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _launchUrl('tel:$_adminPhone'),
                        child: Text(
                          _adminPhone,
                          style: const TextStyle(
                            color: Color(0xFFdcd232),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 16),
                      // Телефон клиента/водителя
                      Text(
                        label,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        phone,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Иконки для связи
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 1. Telegram
                          _buildContactIcon(Icons.send, () {
                            _launchTelegram(phone);
                          }, const Color(0xFF0088CC), 'Telegram'),
                          
                          // 2. WhatsApp
                          _buildContactIcon(FontAwesomeIcons.whatsapp, () {
                            _launchWhatsApp(phone);
                          }, const Color(0xFF25D366), 'WhatsApp'),

                          // 3. Телефон
                          _buildContactIcon(Icons.phone, () => _launchUrl('tel:$phone'), Colors.green, 'Занг'),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Закрыть', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone, color: Color(0xFFdcd232), size: 20),
                const SizedBox(width: 8),
                Text(phone, style: const TextStyle(color: Color(0xFFdcd232), fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildInfoCard(String title, Request requestData) {

    final bool isOrigin = title == 'Погрузка';

    final List<dynamic> stops = isOrigin ? requestData.originStops : requestData.destinationStops;

    return Container(

      width: double.infinity,

      margin: const EdgeInsets.only(top: 16),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(color: const Color(0xFF2a2a2e), borderRadius: BorderRadius.circular(12)),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 8),

          if (stops.isEmpty) const Text('Не указано', style: TextStyle(color: Colors.white70)),

          ...stops.map((stop) {

            return Padding(

              padding: const EdgeInsets.only(top: 8.0),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  if (stop.city != null && stop.city.isNotEmpty)

                    Row(children: [const Text('город: ', style: TextStyle(color: Colors.white70)), Expanded(child: Text(stop.city, style: const TextStyle(color: Colors.white)))]),

                  if (stop.address != null && stop.address.isNotEmpty)

                    Row(children: [const Text('адрес: ', style: TextStyle(color: Colors.white70)), Expanded(child: Text(stop.address, style: const TextStyle(color: Colors.white)))]),

                  if (stop.warehouse != null && stop.warehouse.isNotEmpty)

                    Row(children: [const Text('склад: ', style: TextStyle(color: Colors.white70)), Expanded(child: Text(stop.warehouse, style: const TextStyle(color: Colors.white)))]),

                  if (stop != stops.last) const Divider(color: Colors.white12, height: 16),

                ],

              ),

            );

          }).toList(),

        ],

      ),

    );

  }



  Widget _buildDescriptionCard(String title, String? description) {

    if (description == null || description.isEmpty) {

      return const SizedBox.shrink();

    }

    return Container(

      width: double.infinity,

      margin: const EdgeInsets.only(top: 16),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(color: const Color(0xFF2a2a2e), borderRadius: BorderRadius.circular(12)),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 8),

          Text(description, style: const TextStyle(color: Colors.white70)),

        ],

      ),

    );

  }

}