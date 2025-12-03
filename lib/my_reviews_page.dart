import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'constants/api_constants.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  bool _isLoading = true;
  List<dynamic> _reviews = [];
  String? _errorMessage;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndFetchReviews();
  }

  Future<void> _loadUserRoleAndFetchReviews() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role');
    });
    await _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка авторизации';
        });
      }
      return;
    }

    try {
      final response = await http.get(
        ApiConstants.getUri('api/my_reviews/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        // Отладочная информация
        print('MyReviewsPage: Received ${data is List ? data.length : 0} reviews');
        if (data is List && data.isNotEmpty) {
          print('MyReviewsPage: First review: ${data[0]}');
        }
        setState(() {
          _reviews = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        print('MyReviewsPage: Error ${response.statusCode}: $errorBody');
        setState(() {
          _errorMessage = 'Не удалось загрузить отзывы (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка сети: $e';
          _isLoading = false;
        });
      }
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

  String _getReviewTitle(dynamic review) {
    if (_userRole == 'driver') {
      // Ман Ронанда -> Номи/Телефони Клиентро нишон деҳ
      var phone = review['client_phone'];
      if (phone == null || phone == "---") {
         phone = review['client']?['phone'];
      }
      return phone ?? 'Неизвестный номер';
    } else {
      // Ман Клиент -> Номи/Телефони Ронандаро нишон деҳ
      var phone = review['driver_phone'];
      if (phone == null || phone == "---") {
         phone = review['driver']?['phone'];
      }
      return phone ?? 'Неизвестный номер';
    }
  }

  String _getReviewSubtitle(dynamic review) {
    if (_userRole == 'driver') {
      return 'Тел. Клиента';
    } else {
      return 'Тел. Водителя';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF212121),
        elevation: 0,
        title: Text(
          _userRole == 'driver' ? 'Отзывы обо мне' : 'Мои отзывы',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchReviews,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFdcd232)),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReviews,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _reviews.isEmpty
                  ? Center(
                      child: Text(
                        _userRole == 'driver'
                            ? 'У вас пока нет отзывов'
                            : 'Вы еще не оставили ни одного отзыва',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchReviews,
                      color: const Color(0xFFdcd232),
                      backgroundColor: const Color(0xFF2a2a2e),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          final review = _reviews[index];
                          final rating = review['rating'] ?? 0;
                          final comment = review['comment'] ?? '';
                          final createdAt = review['created_at'] ?? '';
                          final orderName = review['order_name'] ?? 'Заказ';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2a2a2e),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getReviewTitle(review),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getReviewSubtitle(review),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Звездочки
                                    Row(
                                      children: List.generate(5, (i) {
                                        return Icon(
                                          i < rating ? Icons.star : Icons.star_border,
                                          color: i < rating
                                              ? const Color(0xFFdcd232)
                                              : Colors.white54,
                                          size: 24,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  orderName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF212121),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      comment,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  _formatDateTime(createdAt),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

