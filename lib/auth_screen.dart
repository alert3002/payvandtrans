import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main_screen.dart';
import 'constants/api_constants.dart';
import 'services/push_notification_service.dart';
import 'package:flutter/foundation.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _countryCode = '992';
  String _selectedRole = 'client';
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const List<Map<String, String>> countries = [
    {'code': '992', 'label': 'Таджикистан +992'},
    {'code': '998', 'label': 'Узбекистан +998'},
    {'code': '7', 'label': 'Казахстан/Россия +7'},
    {'code': '93', 'label': 'Афганистан +93'},
    {'code': '86', 'label': 'Китай +86'},
  ];

  late TabController _tabController;

  int get _phoneLength {
    switch (_countryCode) {
      case '992':
      case '998':
      case '93':
        return 9;
      case '7':
        return 10;
      case '86':
        return 11;
      default:
        return 9;
    }
  }

  String get _fullPhone {
    final n = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return _countryCode + n;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  static const String _whatsappSupportPhone = '992777000570';

  Future<void> _openForgotPasswordWhatsApp() async {
    final fullPhone = _fullPhone;
    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final text = phoneDigits.isEmpty
        ? 'Ассалому алайкум! Пароли рақами телефон лозим аст.'
        : 'Ассалому алайкум! Номери ман: +$fullPhone. Пароли ин номери +$fullPhone. лозим аст.';
    final uri = Uri.parse(
      'https://wa.me/$_whatsappSupportPhone?text=${Uri.encodeComponent(text)}',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showErrorSnackBar('WhatsApp кушода нашуд.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('WhatsApp кушода нашуд. Интернети ё барномаро санҷед.');
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final phone = _fullPhone;
    final password = _passwordController.text;
    final isLogin = _tabController.index == 0;

    try {
      final url = Uri.parse(
        ApiConstants.getUrl(isLogin ? 'api/auth/login/' : 'api/auth/register/'),
      );
      final body = <String, dynamic>{
        'phone': phone,
        'password': password,
      };
      if (!isLogin) body['role'] = _selectedRole;

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('Вакти интизорӣ гузашт. Иттисоро санҷед.'),
          );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access']);
        await prefs.setString('role', data['role'] ?? 'client');
        if (data['refresh'] != null) {
          await prefs.setString('refresh_token', data['refresh']);
        }
        if (mounted) {
          try {
            if (!kIsWeb) {
              await PushNotificationService.initPushNotifications(context);
            }
          } catch (e) {
            print('⚠️ Push инициализация: $e');
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      } else {
        _showErrorSnackBar(data['message'] ?? 'Хатогӣ. Аз нав санҷед.');
      }
    } on TimeoutException catch (e) {
      _showErrorSnackBar(e.message ?? 'Вакти интизорӣ гузашт.');
    } on http.ClientException catch (e) {
      _showErrorSnackBar('Иттисор: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Хатогӣ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 36),
                Image.asset('assets/images/logo1.png', width: 80),
                const SizedBox(height: 14),
                const Text('Добро пожаловать!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 22),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20.0)),
                  child: TabBar(
                    controller: _tabController,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 0.0),
                    indicator: BoxDecoration(
                        color: const Color(0xFFdcd232),
                        borderRadius: BorderRadius.circular(20.0)),
                    labelColor: Colors.black,
                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    unselectedLabelColor: Colors.white,
                    unselectedLabelStyle: const TextStyle(fontSize: 14),
                    tabs: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Tab(text: 'Вход'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Tab(text: 'Регистрация'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white38, width: 1),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _countryCode,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF333333),
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 22),
                                items: countries
                                    .map((c) => DropdownMenuItem(
                                          value: c['code'],
                                          child: Text(c['label']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _countryCode = v);
                                },
                                selectedItemBuilder: (context) => countries
                                    .map((c) => Center(child: Text('+${c['code']}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))))
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: _buildInputDecoration('Номер телефона').copyWith(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(_phoneLength),
                                ],
                                validator: (value) {
                                  final n = (value ?? '').replaceAll(RegExp(r'\D'), '');
                                  if (n.length != _phoneLength) {
                                    return 'Номер должен содержать $_phoneLength цифр';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _buildInputDecoration('Пароль (от 8 букв/цифр)').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(32),
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите пароль';
                          }
                          if (value.length < 8) {
                            return 'Пароль не менее 8 символов (буквы и цифры)';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                            return 'Только буквы и цифры';
                          }
                          return null;
                        },
                      ),
                      if (_tabController.index == 0) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _openForgotPasswordWhatsApp,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFdcd232),
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                            ),
                            child: const Text('Забыл пароль?', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_tabController.index == 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            dropdownColor: const Color(0xFF333333),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _buildInputDecoration('Роль (клиент/водитель)'),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20),
                            items: const [
                              DropdownMenuItem(value: 'client', child: Text('Клиент')),
                              DropdownMenuItem(value: 'driver', child: Text('Водитель')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedRole = v);
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFdcd232),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                              : Text(
                                  _tabController.index == 0 ? 'Войти' : 'Зарегистрироваться',
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String? label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white38),
          borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFdcd232), width: 1.5),
          borderRadius: BorderRadius.circular(10)),
      errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(10)),
      focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(10)),
    );
  }
}
