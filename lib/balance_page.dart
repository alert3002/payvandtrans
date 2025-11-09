import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BalancePage extends StatelessWidget {
  const BalancePage({super.key});

  // Функсияи ёрирасон барои кушодани замимаҳои бонкӣ
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Агар замима ёфт нашавад, метавонед ягон амал иҷро кунед
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Маълумоти муваққатӣ барои таърихи транзаксияҳо
    final List<Map<String, dynamic>> transactions = [
      {
        "date": "03.07.2025",
        "status": "Успешно",
        "type": "Пополнение",
        "amount": "+6 500 c",
        "balance_after": "12 500 c",
        "txn_id": "TRX-2025-000123",
        "description": "Пополнение баланса через банковскую карту",
        "is_success": true
      },
      {
        "date": "02.07.2025",
        "status": "Отклонено",
        "type": "Списание",
        "amount": "-2 000 c",
        "balance_after": "6 000 c",
        "txn_id": "TRX-2025-000122",
        "description": "Оплата за поездку",
        "is_success": false
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF2e2f34),
      appBar: AppBar(
        title: const Text('Пополнить баланс',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2e2f34),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Блоки баланси ҷорӣ
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFF3d3e42),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Водитель:',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Text('Баланс',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                        Spacer(),
                        Text('0',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Text('c',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Пополнение зачисляется после проверки.',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                )),
            const SizedBox(height: 24),

            // Усулҳои пардохт
            _buildPaymentMethodTile(
                icon: Icons.account_balance,
                title: 'DC Next',
                subtitle:
                    'После перехода проверьте номер получателя перед переводом: 9929257711',
                onTap: () {
                  // Дар ин ҷо deeplink барои DC Next-ро мегузоред
                  _launchUrl('dcnexpay://');
                }),
            _buildPaymentMethodTile(
                icon: Icons.credit_card,
                title: 'Эсхата Онлайн',
                subtitle:
                    'После перехода проверьте номер получателя перед переводом: 9929257711',
                onTap: () {
                  // Дар ин ҷо deeplink барои Эсхата Онлайн-ро мегузоред
                  _launchUrl('eskhataonline://');
                }),
            _buildPaymentMethodTile(
                icon: Icons.phone_android,
                title: 'Alif Mobi',
                subtitle:
                    'После перехода выберите перевод на alif mobi и введите номер телефона: 9929257711',
                onTap: () {
                  // Дар ин ҷо deeplink барои Alif Mobi-ро мегузоред
                  _launchUrl('alifmobi://');
                }),

            // Блоки "Важно"
            Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFF3d3e42),
                    borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white70),
                    SizedBox(width: 16),
                    Expanded(
                        child: Text(
                            'Указывайте номер получателя точно как в инструкции. Комиссия',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12))),
                  ],
                )),

            // Таърихи баланс
            const Text('История баланса',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListView.separated(
              itemCount: transactions.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return _buildTransactionHistoryItem(
                    date: tx['date'],
                    status: tx['status'],
                    type: tx['type'],
                    amount: tx['amount'],
                    balanceAfter: tx['balance_after'],
                    txnId: tx['txn_id'],
                    description: tx['description'],
                    isSuccess: tx['is_success']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      color: const Color(0xFF3d3e42),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward_ios, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionHistoryItem(
      {required String date,
      required String status,
      required String type,
      required String amount,
      required String balanceAfter,
      required String txnId,
      required String description,
      required bool isSuccess}) {
    final statusColor = isSuccess ? Colors.greenAccent : Colors.redAccent;
    final amountColor =
        amount.startsWith('+') ? Colors.greenAccent : Colors.redAccent;

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF3d3e42),
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 12),
            _buildHistoryRow('Тип операции:', type),
            _buildHistoryRow('Сумма:', amount, valueColor: amountColor),
            _buildHistoryRow('Баланс после операции:', balanceAfter),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            _buildHistoryRow('Транзакция №:', txnId),
            _buildHistoryRow('Описание:', description),
          ],
        ));
  }

  Widget _buildHistoryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
