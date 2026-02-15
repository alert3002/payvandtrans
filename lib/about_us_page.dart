// О нас — текст ва рақамҳои тамос (fixed поён)
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const List<String> _phones = [
    '+992105778888',
    '+992937195005',
    '+992777000570',
  ];

  Future<void> _launchCall(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2e2f34),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2a2a2e),
        elevation: 0,
        title: const Text(
          'О нас',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚛 Добро пожаловать в Payvand Trans!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Мы — ваша надёжная транспортная компания с более чем 20-летним опытом в грузоперевозках по Таджикистану и странам СНГ.\n'
                    'У нас собственный автопарк и профессиональные водители, которые внимательно следят за вашим грузом на каждом этапе пути.',
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Заказать перевозку просто — через наш сайт или удобное мобильное приложение для клиентов и водителей.\n'
                    'Payvand Trans — логистика, на которую можно положиться.',
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Будем рады долгосрочному сотрудничеству и новым клиентам!\n'
                    'Оставайтесь с нами и следите за обновлениями.',
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  // Пустое место, чтобы контент не скрывался под fixed блоком
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Фиксированный блок с номерами внизу
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2a2a2e),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '📞 Свяжитесь с нами:',
                    style: TextStyle(
                      color: Color(0xFFdcd232),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._phones.map((phone) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _launchCall(phone),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3d3e42),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, color: Color(0xFFdcd232), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              phone,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.call, color: Colors.greenAccent, size: 22),
                          ],
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
