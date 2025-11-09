// Файли: lib/my_orders_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/order_model.dart';
import 'order_detail_page.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  late Future<List<Order>> _myOrdersFuture;

  @override
  void initState() {
    super.initState();
    _myOrdersFuture = _fetchMyOrders();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _myOrdersFuture = _fetchMyOrders();
    });
  }

  Future<List<Order>> _fetchMyOrders() async {
    final url = Uri.parse('https://app.payvandtrans.com/api/my_orders/driver/');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Токен ёфт нашуд.');

      final response =
          await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final decodedJson = json.decode(utf8.decode(response.bodyBytes));
        if (decodedJson is Map && decodedJson.containsKey('results')) {
          final List<dynamic> data = decodedJson['results'];
          return data.map((json) => Order.fromJson(json)).toList();
        } else if (decodedJson is List) {
          return decodedJson.map((json) => Order.fromJson(json)).toList();
        } else {
          throw Exception('Формати номаълуми JSON');
        }
      } else {
        throw Exception('Гирифтани заказҳо номуваффақ: ${response.statusCode}');
      }
    } catch (e) {
      print('Хатогӣ дар _fetchMyOrders: $e');
      throw Exception('Хатогӣ: $e');
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.greenAccent;
      case 'in_transit':
        return Colors.blueAccent;
      case 'awaiting_payment':
      case 'paid':
        return Colors.orangeAccent;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  String _getRussianStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Актив';
      case 'in_transit':
        return 'В пути';
      case 'awaiting_payment':
        return 'Ожидает подтверждения';
      case 'paid':
        return 'Оплачен';
      case 'closed':
        return 'Закрыт';
      case 'pending': // <-- ИН САТР ИЛОВА ШУД
        return 'На рассмотрении';
      default:
        return status ?? 'Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2a2a2e),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Мои заказы',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        color: const Color(0xFFdcd232),
        backgroundColor: const Color(0xFF2a2a2e),
        child: FutureBuilder<List<Order>>(
          future: _myOrdersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFdcd232)));
            } else if (snapshot.hasError) {
              return Center(
                  child: Text('${snapshot.error}',
                      style: const TextStyle(color: Colors.red)));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('У вас пока нет заказов.',
                      style: TextStyle(color: Colors.white, fontSize: 16)));
            } else {
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return _buildMyOrderCard(snapshot.data![index]);
                },
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildMyOrderCard(Order order) {
    return InkWell(
      onTap: () async {
        // Боварӣ ҳосил мекунем, ки requestId холӣ нест
        if (order.requestId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID-и заявка ёфт нашуд!')),
          );
          return;
        }

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailPage(
              // ИСЛОҲ ШУД: Ба ҷои `order.id`, мо `order.requestId`-ро мефиристем
              requestId: order.requestId!,
              userRole: 'driver',
            ),
          ),
        );
        if (result == true && mounted) {
          _refreshOrders();
        }
      },
      child: Card(
        color: const Color(0xFF2a2a2e),
        margin: const EdgeInsets.only(bottom: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.requestName ?? 'Заказ №${order.id}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildInfoRow('Маршрут:', '${order.fromCity} → ${order.toCity}'),
              _buildInfoRow('Цена:',
                  '${double.tryParse(order.orderSum)?.toStringAsFixed(0) ?? '0'} смн',
                  isPrice: true),
              _buildInfoRow('Статус:', _getRussianStatus(order.status),
                  statusColor: _getStatusColor(order.status)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isPrice = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: isPrice
                  ? const Color(0xFFdcd232)
                  : (statusColor ?? Colors.white),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
