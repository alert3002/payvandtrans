import 'package:flutter/material.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Саҳифаи Ронанда'),
        backgroundColor: const Color(0xFFdcd232),
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: Text('Хуш омадед, Ронанда!'),
      ),
    );
  }
}
