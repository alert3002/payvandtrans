import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'transport_page.dart';
import 'balance_page.dart';
import 'auth_screen.dart';
import 'models/city_model.dart'; // Боварӣ ҳосил кунед, ки ин файл вуҷуд дорад

// =======================================================================
// Саҳифаи асосии "Настройки"
// =======================================================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _fullName = 'Загрузка...';
  String _phone = '';
  String? _userRole;
  String? _balance;
  String? _photoUrl;
  int? _userId; // Барои нигоҳ доштани ID-и корбар

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    setState(() {
      _userRole = prefs.getString('role');
    });

    if (token == null) {
      setState(() {
        _fullName = 'Ошибка: Токен не найден';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://app.payvandtrans.com/api/me/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mounted && response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _fullName = data['user']?['full_name'] ?? 'Имя не указано';
          _phone = data['user']?['phone'] ?? '';
          _photoUrl = data['photo'];
          _userId = data['user']?['id']; // ID-и корбарро захира мекунем

          if (_userRole == 'driver' && data['balance'] != null) {
            _balance = data['balance'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fullName = 'Ошибка загрузки';
        });
      }
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false);
    }
  }

  Widget _buildMenuItem(
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF3d3e42),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDriver = _userRole == 'driver';

    return Scaffold(
      backgroundColor: const Color(0xFF2e2f34),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2e2f34),
        elevation: 0,
        title: const Text('Настройки',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Қисми болоии профил
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF3d3e42),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade700,
                    backgroundImage:
                        (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? NetworkImage(_photoUrl!)
                            : null,
                    child: (_photoUrl == null || _photoUrl!.isEmpty)
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_phone,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                        if (isDriver && _balance != null) ...[
                          const SizedBox(height: 4),
                          Text('Баланс: $_balance смн',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1. Профиль
            _buildMenuItem(
              icon: Icons.person_outline,
              text: 'Профиль',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EditProfilePage()),
                ).then((_) => _loadInitialData());
              },
            ),

            const SizedBox(height: 16),

            // 2. БЛОКИ АМАЛҲОИ РОНАНДА
            if (isDriver) ...[
              _buildMenuItem(
                icon: Icons.directions_car,
                text: 'Транспорт',
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TransportPage()));
                },
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.add_circle_outline,
                text: 'Пополнить баланс',
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BalancePage()));
                },
              ),
              const SizedBox(height: 16),

              // ТУГМАИ "ОТЗЫВЫ"
              _buildMenuItem(
                icon: Icons.reviews,
                text: 'Отзывы',
                onTap: () {
                  if (_userId != null) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                ReviewListPage(driverId: _userId!)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Не удалось получить ID пользователя.')),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],

            // 3. Выйти
            _buildMenuItem(
              icon: Icons.exit_to_app,
              text: 'Выйти',
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// Саҳифаи Таҳрири Профил (EditProfilePage)
// =======================================================================

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _userRole;

  final _fullNameController = TextEditingController();
  final _passportController = TextEditingController();
  final _innController = TextEditingController();

  List<City> _cities = [];
  City? _selectedCity;
  DateTime? _birthDate;

  File? _photoFile;
  File? _passportFrontFile;
  File? _passportBackFile;

  String? _photoUrl;
  String? _passportFrontUrl;
  String? _passportBackUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    _userRole = prefs.getString('role');
    if (token == null || !mounted) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://app.payvandtrans.com/api/me/'),
            headers: {'Authorization': 'Bearer $token'}),
        http.get(Uri.parse('https://app.payvandtrans.com/api/cities/'),
            headers: {'Authorization': 'Bearer $token'}),
      ]);

      if (!mounted) return;

      List<City> citiesList = [];
      if (responses[1].statusCode == 200) {
        final dynamic decodedData =
            json.decode(utf8.decode(responses[1].bodyBytes));
        List<dynamic> citiesJson =
            (decodedData is Map && decodedData.containsKey('results'))
                ? decodedData['results']
                : (decodedData is List ? decodedData : []);
        citiesList = citiesJson.map((json) => City.fromJson(json)).toList();
      }

      if (responses[0].statusCode == 200) {
        final data = json.decode(utf8.decode(responses[0].bodyBytes));
        _fullNameController.text = data['user']?['full_name'] ?? '';
        _photoUrl = data['photo'];
        DateTime? parsedBirthDate = data['birth_date'] != null
            ? DateTime.tryParse(data['birth_date'])
            : null;

        City? profileCity;
        if (data['city'] != null && data['city']['id'] != null) {
          final int cityId = data['city']['id'];
          final matchingCities = citiesList.where((city) => city.id == cityId);
          if (matchingCities.isNotEmpty) {
            profileCity = matchingCities.first;
          }
        }

        if (_userRole == 'driver') {
          _passportController.text = data['passport'] ?? '';
          _innController.text = data['inn'] ?? '';
          _passportFrontUrl = data['passport_front'];
          _passportBackUrl = data['passport_back'];
        }

        setState(() {
          _cities = citiesList;
          _selectedCity = profileCity;
          _birthDate = parsedBirthDate;
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(
      ImageSource source, Function(File) onImagePicked) async {
    final pickedFile =
        await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        onImagePicked(File(pickedFile.path));
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    var request = http.MultipartRequest(
        'PATCH', Uri.parse('https://app.payvandtrans.com/api/me/'));
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['full_name'] = _fullNameController.text;
    if (_selectedCity != null)
      request.fields['city'] = _selectedCity!.id.toString();
    if (_birthDate != null)
      request.fields['birth_date'] =
          DateFormat('yyyy-MM-dd').format(_birthDate!);
    if (_userRole == 'driver') {
      request.fields['passport'] = _passportController.text;
      request.fields['inn'] = _innController.text;
    }

    if (_photoFile != null)
      request.files
          .add(await http.MultipartFile.fromPath('photo', _photoFile!.path));
    if (_userRole == 'driver') {
      if (_passportFrontFile != null)
        request.files.add(await http.MultipartFile.fromPath(
            'passport_front', _passportFrontFile!.path));
      if (_passportBackFile != null)
        request.files.add(await http.MultipartFile.fromPath(
            'passport_back', _passportBackFile!.path));
    }

    try {
      final response = await request.send();
      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Профиль успешно сохранен!'),
              backgroundColor: Colors.green));
          Navigator.of(context).pop();
        } else {
          final respStr = await response.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Ошибка сохранения: ${response.statusCode}\n$respStr'),
              backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDriver = _userRole == 'driver';
    return Scaffold(
      backgroundColor: const Color(0xFF2e2f34),
      appBar: AppBar(
        title: const Text('Профиль',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2e2f34),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFdcd232)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                        label: 'ФИО', controller: _fullNameController),
                    _buildDatePicker(),
                    if (isDriver) ...[
                      _buildTextField(
                          label: 'Паспорт', controller: _passportController),
                      _buildTextField(label: 'ИНН', controller: _innController),
                    ],
                    _buildCityDropdown(),
                    const SizedBox(height: 20),
                    const Text('Фото', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    if (isDriver)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildImagePicker('Водитель', _photoFile, _photoUrl,
                              (file) => _photoFile = file),
                          _buildImagePicker(
                              'Паспорт (спереди)',
                              _passportFrontFile,
                              _passportFrontUrl,
                              (file) => _passportFrontFile = file),
                          _buildImagePicker(
                              'Паспорт (сзади)',
                              _passportBackFile,
                              _passportBackUrl,
                              (file) => _passportBackFile = file),
                        ],
                      )
                    else
                      Center(
                          child: _buildImagePicker('Клиент', _photoFile,
                              _photoUrl, (file) => _photoFile = file)),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFdcd232),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Сохранить',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
      {required String label, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF3d3e42),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Город', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          DropdownButtonFormField<City>(
            value: _selectedCity,
            items: _cities.map((city) {
              return DropdownMenuItem<City>(
                value: city,
                child: Text(city.name,
                    style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCity = value;
              });
            },
            decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF3d3e42),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                hintText: 'Выбрать город',
                hintStyle: const TextStyle(color: Colors.white54)),
            dropdownColor: const Color(0xFF3d3e42),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Дата рождения', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime.now(),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (picked != null && picked != _birthDate) {
                setState(() {
                  _birthDate = picked;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFF3d3e42),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                _birthDate == null
                    ? 'Выбрать дату'
                    : DateFormat('dd.MM.yyyy').format(_birthDate!),
                style: TextStyle(
                    color: _birthDate == null ? Colors.white54 : Colors.white,
                    fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(String label, File? imageFile, String? imageUrl,
      Function(File) onImagePicked) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImage(ImageSource.gallery, onImagePicked),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF3d3e42),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
              image: imageFile != null
                  ? DecorationImage(
                      image: FileImage(imageFile), fit: BoxFit.cover)
                  : (imageUrl != null && imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl), fit: BoxFit.cover)
                      : null),
            ),
            child: (imageFile == null && (imageUrl == null || imageUrl.isEmpty))
                ? const Icon(Icons.add_a_photo, color: Colors.white70, size: 40)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

// =======================================================================
// Саҳифаи Рӯйхати Отзывҳо (ReviewListPage)
// =======================================================================

class ReviewListPage extends StatefulWidget {
  final int driverId;

  const ReviewListPage({
    super.key,
    required this.driverId,
  });

  @override
  State<ReviewListPage> createState() => _ReviewListPageState();
}

class _ReviewListPageState extends State<ReviewListPage> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка: Токен не найден.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
            'https://app.payvandtrans.com/api/drivers/${widget.driverId}/reviews/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final decodedData = json.decode(utf8.decode(response.bodyBytes));

          if (decodedData is Map<String, dynamic> &&
              decodedData.containsKey('results')) {
            final List<dynamic> reviewsJson = decodedData['results'];
            setState(() {
              _reviews = reviewsJson;
              _isLoading = false;
            });
          } else if (decodedData is List) {
            // Агар ҷавоб бе пагинация ояд
            final List<dynamic> reviewsJson = decodedData;
            setState(() {
              _reviews = reviewsJson;
              _isLoading = false;
            });
          } else {
            setState(() {
              _errorMessage = 'Ошибка: Формати нодурусти маълумот аз сервер.';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _errorMessage =
                'Ошибка ${response.statusCode}: Не удалось загрузить отзывы.';
            _isLoading = false;
          });
        }
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

  // ❗️ ФУНКСИЯИ ЁРИРАСОНИ НАВ БАРОИ САНА
  DateTime? _tryParseDate(String dateString) {
    try {
      // Аввал кӯшиш мекунем, ки формати стандартиро коркард кунем
      return DateTime.parse(dateString);
    } catch (e) {
      // Агар хато шавад, ба консол менависем ва null бармегардонем
      print('Could not parse date in standard format: $dateString');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2e2f34),
      appBar: AppBar(
        title: const Text('Отзывы',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2e2f34),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFdcd232)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return const Center(
        child: Text(
          'Отзывов пока нет.',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];

        final int rating = review['rating'] ?? 0;

        // ❗️ ИСТИФОДАИ ФУНКСИЯИ ЁРИРАСОНИ НАВ
        final DateTime? parsedDate = review['created_at'] != null
            ? _tryParseDate(review['created_at'])
            : null;
        final String dateStr = parsedDate != null
            ? DateFormat('dd.MM.yyyy HH:mm').format(parsedDate)
            : 'Нет даты';

        final String clientName =
            review['client']?['full_name'] ?? 'Анонимный клиент';
        final String orderName = review['order_name'] ?? 'Без названия';

        return Card(
          color: const Color(0xFF3d3e42),
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Оценка за заказ "$orderName"',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Color(0xFFdcd232), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$rating',
                          style: const TextStyle(
                              color: Color(0xFFdcd232),
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (review['comment'] != null &&
                    review['comment'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      review['comment'],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
                const Divider(color: Colors.white24, height: 24),
                Text(
                  'От: $clientName',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
