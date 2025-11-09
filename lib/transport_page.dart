import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/models/transport_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class TransportPage extends StatefulWidget {
  const TransportPage({super.key});

  @override
  _TransportPageState createState() => _TransportPageState();
}

class _TransportPageState extends State<TransportPage> {
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();

  final _carNumberController = TextEditingController();
  List<TransportCategory> _transportTypes = [];
  TransportCategory? _selectedTransport;

  File? _transportPhotoFile;
  File? _techPassportFrontFile;
  File? _techPassportBackFile;
  File? _permissionFile;
  File? _pravoFile;

  String? _transportPhotoUrl;
  String? _techPassportFrontUrl;
  String? _techPassportBackUrl;
  String? _permissionUrl;
  String? _pravoUrl;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || !mounted) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Дар як вақт ҳам маълумоти профил ва ҳам рӯйхати транспортҳоро мегирем
      final responses = await Future.wait([
        http.get(Uri.parse('https://app.payvandtrans.com/api/me/'),
            headers: {'Authorization': 'Bearer $token'}),
        http.get(Uri.parse('https://app.payvandtrans.com/api/transports/'),
            headers: {'Authorization': 'Bearer $token'}),
      ]);

      if (!mounted) return;

      // Аввал рӯйхати пурраи намудҳои транспортро коркард мекунем
      List<TransportCategory> transportList = [];
      if (responses[1].statusCode == 200) {
        final dynamic decodedData =
            json.decode(utf8.decode(responses[1].bodyBytes));
        List<dynamic> transportJson;
        if (decodedData is Map && decodedData.containsKey('results')) {
          transportJson = decodedData['results'];
        } else if (decodedData is List) {
          transportJson = decodedData;
        } else {
          throw Exception('Формати номаълуми JSON барои транспортҳо');
        }
        transportList = transportJson
            .map((json) => TransportCategory.fromJson(json))
            .toList();
      }

      // Сипас, маълумоти профилро коркард карда, майдонҳоро пур мекунем
      TransportCategory? currentTransport;
      if (responses[0].statusCode == 200) {
        final data = json.decode(utf8.decode(responses[0].bodyBytes));

        // Рақами мошин ва URL-ҳои расмҳоро мегирем
        _carNumberController.text = data['car_number'] ?? '';
        _transportPhotoUrl = data['transport_photo'];
        _techPassportFrontUrl = data['tech_passport_front'];
        _techPassportBackUrl = data['tech_passport_back'];
        _permissionUrl = data['permission'];
        _pravoUrl = data['pravo'];

        // Транспорти ҷории ронандаро аз рӯйхати боргирифташуда меёбем
        if (data['transport_category_detail'] != null &&
            data['transport_category_detail']['id'] != null) {
          final int transportId = data['transport_category_detail']['id'];

          // Усули дурусти ҷустуҷӯ
          final matchingTransports =
              transportList.where((transport) => transport.id == transportId);
          if (matchingTransports.isNotEmpty) {
            currentTransport = matchingTransports.first;
          }
        }
      }

      // Ҳамаи маълумоти ёфтшударо ба ҳолат (state) мегузорем
      setState(() {
        _transportTypes = transportList;
        _selectedTransport = currentTransport;
      });
    } catch (e) {
      print('Error loading transport data: $e');
      // Метавонед дар ин ҷо SnackBar бо паёми хатогӣ нишон диҳед
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Функсия барои интихоби расм
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

  // Функсия барои сабт кардани маълумот
  Future<void> _saveTransportData() async {
    if (!_formKey.currentState!.validate() || !mounted) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    var request = http.MultipartRequest(
        'PATCH', Uri.parse('https://app.payvandtrans.com/api/me/'));
    request.headers['Authorization'] = 'Bearer $token';

    // Майдонҳои матниро илова мекунем
    request.fields['car_number'] = _carNumberController.text;
    if (_selectedTransport != null) {
      request.fields['transport_category'] = _selectedTransport!.id.toString();
    }

    // Файлҳои расмиро (агар интихоб шуда бошанд) илова мекунем
    if (_transportPhotoFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'transport_photo', _transportPhotoFile!.path));
    }
    if (_techPassportFrontFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'tech_passport_front', _techPassportFrontFile!.path));
    }
    if (_techPassportBackFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'tech_passport_back', _techPassportBackFile!.path));
    }
    if (_permissionFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'permission', _permissionFile!.path));
    }
    if (_pravoFile != null) {
      request.files
          .add(await http.MultipartFile.fromPath('pravo', _pravoFile!.path));
    }

    try {
      final response = await request.send();
      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Данные транспорта успешно сохранены!'),
            backgroundColor: Colors.green,
          ));
          Navigator.of(context).pop();
        } else {
          final respStr = await response.stream.bytesToString();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Ошибка сохранения: ${response.statusCode}, $respStr'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2e2f34),
      appBar: AppBar(
        title: const Text('Транспорт', style: TextStyle(color: Colors.white)),
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
                    // --- Dropdown барои "Тип транспорта" ---
                    const Text('Тип транспорта',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<TransportCategory>(
                      value: _selectedTransport,
                      items: _transportTypes.map((transport) {
                        return DropdownMenuItem<TransportCategory>(
                          value: transport,
                          child: Text(transport.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTransport = value;
                        });
                      },
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF3d3e42),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          hintText: 'Выберите тип транспорта',
                          hintStyle: const TextStyle(color: Colors.white54)),
                      dropdownColor: const Color(0xFF3d3e42),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) =>
                          value == null ? 'Обязательное поле' : null,
                    ),

                    const SizedBox(height: 20),

                    // --- Майдон барои "Номер машины" ---
                    const Text('Номер машины',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _carNumberController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF3d3e42),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Обязательное поле'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // --- Интихоби расмҳо ---
                    const Text('Фото', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildImagePicker(
                            'Транспорт',
                            _transportPhotoFile,
                            _transportPhotoUrl,
                            (file) => _transportPhotoFile = file),
                        _buildImagePicker(
                            'Тех.паспорт (спереди)',
                            _techPassportFrontFile,
                            _techPassportFrontUrl,
                            (file) => _techPassportFrontFile = file),
                        _buildImagePicker(
                            'Тех.паспорт (сзади)',
                            _techPassportBackFile,
                            _techPassportBackUrl,
                            (file) => _techPassportBackFile = file),
                        _buildImagePicker('Доверенность', _permissionFile,
                            _permissionUrl, (file) => _permissionFile = file),
                        _buildImagePicker(
                            'Вод. права', // Номи кӯтоҳ
                            _pravoFile,
                            _pravoUrl,
                            (file) => _pravoFile = file),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // --- Тугмаи "Сохранить" ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveTransportData,
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

  Widget _buildImagePicker(String label, File? imageFile, String? imageUrl,
      Function(File) onImagePicked) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickImage(ImageSource.gallery, onImagePicked),
            child: Container(
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
              child:
                  (imageFile == null && (imageUrl == null || imageUrl.isEmpty))
                      ? const Center(
                          child: Icon(Icons.add_a_photo,
                              color: Colors.white70, size: 40))
                      : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
