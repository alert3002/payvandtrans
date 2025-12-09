import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:firebase_core/firebase_core.dart';
// 👈 БАСТАҲОИ FCM-ро ИЛОВА КУНЕД
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter/foundation.dart';
// ------------------------------------------------------------------

import 'auth_screen.dart';
import 'main_screen.dart'; 

// 1. 👈 ФУНКСИЯИ КОРКАРДИ ПАЁМҲОИ ЗАМИНА (TOP LEVEL FUNCTION)
// Ин функсия бояд берун аз ҳамаи синфҳо ва дар дохили main.dart бошад.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Агар лозим ояд, Firebase-ро дубора оғоз кунед (вақте ки замима пурра баста аст)
  await Firebase.initializeApp(); 
  
  if (kDebugMode) {
    print("✅ Handling a background message: ${message.messageId}");
    print("Data: ${message.data}");
    print("Notification: ${message.notification?.title}");
  }
  // Дар ин ҷо шумо метавонед логикаи коркарди паёмро (масалан, захира ба локалӣ) илова кунед
}
// ------------------------------------------------------------------


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Firebase
  try {
    // Для Android с google-services.json можно вызывать без опций
    // Firebase автоматически найдет конфигурацию из google-services.json
    // Для Web может потребоваться firebase_options.dart (но мы фокусируемся на Android)
    await Firebase.initializeApp();
    
    if (kDebugMode) {
      print('✅ Firebase.initializeApp() вызван');
      
      // Проверяем, что Firebase действительно инициализирован
      try {
        final apps = Firebase.apps;
        print('📱 Firebase Apps: ${apps.length}');
        if (apps.isNotEmpty) {
          final defaultApp = Firebase.app();
          print('📱 Default App: ${defaultApp.name}');
          print('📱 App Options: ${defaultApp.options.appId}');
        } else {
          print('⚠️ Firebase Apps пуст - возможно ошибка инициализации');
        }
      } catch (e) {
        print('❌ Ошибка проверки Firebase Apps: $e');
      }
    }
    
    // 2. 👈 КОРКАРДИ ПАЁМҲОИ ЗАМИНА (Background Message Handler)
    // Регистрируем обработчик ДО запуска приложения
    // Только для мобильных платформ (не Web)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      if (kDebugMode) {
        print('✅ Background message handler зарегистрирован');
      }
    }
    
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('❌ Ошибка инициализации Firebase: $e');
      print('Stack trace: $stackTrace');
      print('💡 Убедитесь, что:');
      print('   1. google-services.json находится в android/app/');
      print('   2. Package name совпадает с applicationId');
      print('   3. Google Services plugin применен в build.gradle.kts');
    }
    // Продолжаем запуск приложения даже при ошибке Firebase
    // Пользователь увидит ошибку при попытке получить токен
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Payvandtrans',
      theme: ThemeData(fontFamily: 'Montserrat'),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    Widget nextPage;

    if (token == null) {
      nextPage = const AuthScreen();
    } else {
      try {
        final bool isExpired = JwtDecoder.isExpired(token);
        if (isExpired) {
          nextPage = const AuthScreen();
        } else {
          // === 2. ҚИСМИ МУҲИМИ ИСЛОҲШУДА ===
          // Ба ҷои HomePage, ба MainScreen мегузарем, то менюи поёнӣ пайдо шавад
          nextPage = const MainScreen();
          // ================================
        }
      } catch (e) {
        print("Хатогӣ ҳангоми тафтиши токен: $e");
        nextPage = const AuthScreen();
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => nextPage),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo1.png', width: 150),
            const SizedBox(height: 20),
            const Text(
              'Приложение от Payvandtrans',
              style: TextStyle(
                  color: Color.fromARGB(255, 255, 255, 255),
                  fontSize: 20,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
