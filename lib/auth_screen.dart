import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'otp_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '992');
  String? _selectedRole;
  bool _isLoading = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _phoneController.dispose();
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final phone = _phoneController.text;
    final isLogin = _tabController.index == 0;

    try {
      final checkUrl =
          Uri.parse('https://app.payvandtrans.com/api/check_phone/');
      final checkResponse = await http.post(
        checkUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      );

      if (checkResponse.statusCode != 200) {
        _showErrorSnackBar('Ошибка проверки номера. Попробуйте снова.');
        return;
      }

      final bool phoneExists = json.decode(checkResponse.body)['exists'];

      // ... дар дохили _submitForm дар auth_screen.dart ...
      if (isLogin) {
        if (!phoneExists) {
          _showErrorSnackBar(
              'Этот номер не зарегистрирован. Пожалуйста, зарегистрируйтесь.');
          _tabController.animateTo(1);
          return;
        }
      } else {
        // Ин қисми РЕГИСТРАЦИЯ аст
        if (phoneExists) {
          // ✅ ПАЁМИ ДУРУСТ
          _showErrorSnackBar(
              'Этот номер уже зарегистрирован. Пожалуйста, войдите.');
          _tabController.animateTo(0); // Ба саҳифаи "Вход" гузарондан
          return;
        }
      }
//...
      await _sendOtp(phone);
    } catch (error) {
      _showErrorSnackBar(
          'Ошибка подключения. Проверьте подключение к интернету.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendOtp(String phone) async {
    final url = Uri.parse('https://app.payvandtrans.com/send_otp/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone}),
    );
    final responseData = json.decode(response.body);

    if (response.statusCode == 200 && responseData['success'] == true) {
      final role = _tabController.index == 1 ? _selectedRole : null;
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OtpScreen(phoneNumber: phone, role: role),
          ),
        );
      }
    } else {
      _showErrorSnackBar(
          responseData['message'] ?? 'Ошибка отправки СМС. Попробуйте снова.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 50),
                Image.asset('assets/images/logo1.png', width: 100),
                const SizedBox(height: 20),
                const Text('Добро пожаловать!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(25.0)),
                  child: TabBar(
                    controller: _tabController,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 0.0),
                    indicator: BoxDecoration(
                        color: const Color(0xFFdcd232),
                        borderRadius: BorderRadius.circular(25.0)),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.white,
                    tabs: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Tab(text: 'Вход'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Tab(text: 'Регистрация'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: Form(
                    key: _formKey,
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildAuthForm(isLogin: true),
                        _buildAuthForm(isLogin: false)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm({required bool isLogin}) {
    return Column(
      children: [
        const SizedBox(height: 20),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: _buildInputDecoration('Номер телефон'),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12)
          ],
          validator: (value) {
            if (value == null || !value.startsWith('992')) {
              return 'Номер должен начинаться с 992';
            }
            if (value.length != 12) {
              return 'Введите полный 9-значный номер после кода страны';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        if (!isLogin)
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            onChanged: (String? newValue) {
              setState(() {
                _selectedRole = newValue;
              });
            },
            dropdownColor: const Color(0xFF333333),
            style:
                const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            decoration: _buildInputDecoration('Выбрать роль...'),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
            items: const [
              DropdownMenuItem(value: 'client', child: Text('Клиент')),
              DropdownMenuItem(value: 'driver', child: Text('Водитель')),
            ],
            validator: (value) {
              // Тағйирот: Валидатсия танҳо барои бахши Регистрация
              if (_tabController.index == 1 && value == null) {
                return 'Пожалуйста, выберите роль';
              }
              return null;
            },
          ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFdcd232),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : Text(isLogin ? 'Войти по смс' : 'Отправить смс',
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String? label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      errorStyle: const TextStyle(color: Colors.redAccent),
      enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFdcd232)),
          borderRadius: BorderRadius.circular(12)),
      errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(12)),
      focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          borderRadius: BorderRadius.circular(12)),
    );
  }
}
