import 'package:flutter/material.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Саҳифаи Клиент'),
        backgroundColor: const Color(0xFFdcd232),
        foregroundColor: Colors.black,
      ),
      body: const Center(
        child: Text('Хуш омадед, Клиент!'),
      ),
    );
  }
}
