import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'auth_screen.dart';
import 'main_screen.dart'; // <-- 1. IMPORT-И НАВ ИЛОВА ШУД

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
