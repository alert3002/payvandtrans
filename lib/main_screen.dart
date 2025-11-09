// Файли: lib/main_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ҳамаи саҳифаҳои заруриро import мекунем
import 'home_page.dart';
import 'profile_page.dart';
import 'my_orders_page.dart';
import 'add_request_page.dart';
import 'my_requests_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _userRole;

  // Рӯйхати саҳифаҳо барои РОНАНДА
  final List<Widget> _driverPages = [
    const HomePage(),
    MyOrdersPage(),
    const ProfilePage(),
  ];

  final List<Widget> _clientPages = [
    const HomePage(),
    const AddRequestPage(),
    MyRequestsPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('role');
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF212121),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFdcd232))),
      );
    }

    final bool isDriver = _userRole == 'driver';
    final List<Widget> currentPages = isDriver ? _driverPages : _clientPages;
    final List<BottomNavigationBarItem> currentItems = isDriver
        ? const <BottomNavigationBarItem>[
            // Меню барои Ронанда
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'Главная'),
            BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined), label: 'Мои заказы'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'Профиль'),
          ]
        : const <BottomNavigationBarItem>[
            // Меню барои Клиент
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'Главная'),
            BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline), label: 'Добавить'),
            BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined), label: 'Мои заявки'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'Профиль'),
          ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: currentPages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: currentItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF2a2a2e),
        selectedItemColor: const Color(0xFFdcd232),
        unselectedItemColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}
