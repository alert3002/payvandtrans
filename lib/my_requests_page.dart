// Файли: lib/my_requests_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/request_model.dart';
import 'order_detail_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  late Future<List<Request>> _myRequestsFuture;

  @override
  void initState() {
    super.initState();
    _myRequestsFuture = _fetchMyRequests();
  }

  Future<void> _refreshRequests() async {
    setState(() {
      _myRequestsFuture = _fetchMyRequests();
    });
  }

  Future<List<Request>> _fetchMyRequests() async {
    const urlString = 'https://app.payvandtrans.com/api/requests/';
    final url = Uri.parse(urlString);

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
          return data.map((json) => Request.fromJson(json)).toList();
        } else if (decodedJson is List) {
          return decodedJson.map((json) => Request.fromJson(json)).toList();
        } else {
          throw Exception('Формати номаълуми JSON');
        }
      } else {
        throw Exception(
            'Гирифтани маълумот номуваффақ: ${response.statusCode}');
      }
    } catch (e) {
      print('Хатогӣ дар _fetchMyRequests: $e');
      throw Exception('Хатогӣ ҳангоми боргирӣ: $e');
    }
  }

  Future<void> _closeOrderAsClient(int requestId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFdcd232))),
    );

    try {
      final response = await http.post(
        Uri.parse(
            'https://app.payvandtrans.com/api/orders/$requestId/client_close/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      Navigator.of(context).pop();

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Заказ успешно закрыт!'),
          backgroundColor: Colors.green,
        ));
        _refreshRequests();
      } else {
        final data = json.decode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Ошибка: ${data['message'] ?? 'Не удалось закрыть заказ'}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка сети: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showCloseConfirmationDialog(int requestId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2e),
        title:
            const Text('Подтверждение', style: TextStyle(color: Colors.white)),
        content: const Text('Вы уверены, что хотите завершить этот заказ?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child:
                const Text('Отмена', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Да, завершить',
                style: TextStyle(color: Colors.green)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _closeOrderAsClient(requestId);
            },
          ),
        ],
      ),
    );
  }

  String _formatDateRange(String? startDate, String? endDate) {
    if (startDate == null && endDate == null) return 'номаълум';
    String formatSingleDate(String? date) {
      if (date == null) return '';
      try {
        final parsedDate = DateTime.parse(date);
        return '${parsedDate.day.toString().padLeft(2, '0')}.${parsedDate.month.toString().padLeft(2, '0')}.${parsedDate.year}';
      } catch (e) {
        return date;
      }
    }

    String start = formatSingleDate(startDate);
    String end = formatSingleDate(endDate);
    if (start.isNotEmpty && end.isNotEmpty) return 'от $start до $end';
    return start.isNotEmpty
        ? 'аз $start'
        : (end.isNotEmpty ? 'то $end' : 'номаълум');
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.greenAccent;
      case 'in_transit':
        return Colors.blueAccent;
      case 'pending':
        return Colors.orangeAccent;
      case 'completed':
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
      case 'pending':
        return 'На рассмотрении';
      case 'completed':
        return 'Завершён';
      case 'closed':
        return 'Закрыт';
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
        title: const Text('Мои заявки',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshRequests,
        color: const Color(0xFFdcd232),
        backgroundColor: const Color(0xFF2a2a2e),
        child: FutureBuilder<List<Request>>(
          future: _myRequestsFuture,
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
                  child: Text('У вас пока нет ни одной заявки.',
                      style: TextStyle(color: Colors.white, fontSize: 16)));
            } else {
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return _buildMyRequestCard(snapshot.data![index]);
                },
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildMyRequestCard(Request request) {
    final isTappable = request.id != null;
    return Card(
      color: const Color(0xFF2a2a2e),
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: !isTappable
            ? null
            : () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailPage(
                      requestId: request.id!,
                      userRole: 'client',
                    ),
                  ),
                );
                if (result == true && mounted) {
                  _refreshRequests();
                }
              },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Заявка №${request.id} ${request.name ?? ''}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildInfoRow(
                  'Маршрут:', '${request.originCity} → ${request.destCity}'),
              _buildInfoRow('Дата:',
                  _formatDateRange(request.loadDate, request.deliveryDate)),
              _buildInfoRow(
                  'Цена:', '${request.priceTjs?.toStringAsFixed(0) ?? '0'} смн',
                  isPrice: true),
              _buildInfoRow('Статус:', _getRussianStatus(request.status),
                  statusColor: _getStatusColor(request.status)),
              if (request.status == 'in_transit') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCloseConfirmationDialog(request.id!),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('Завершить заказ',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]
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
