import 'package:flutter/material.dart';

import 'api_service.dart';
import 'electricity_page.dart';
import 'utility_date_helper.dart';
import 'water_page.dart';

class UtilitiesPage extends StatefulWidget {
  const UtilitiesPage({super.key});

  @override
  State<UtilitiesPage> createState() => _UtilitiesPageState();
}

class _UtilitiesPageState extends State<UtilitiesPage> {
  final String month = UtilityDateHelper.currentMonth();
  double? electricityAmount;
  double? waterAmount;

  @override
  void initState() {
    super.initState();
    loadAmounts();
  }

  Future<double?> _amountFor(String type) async {
    final bills = await ApiService.getUtilityBills(month: month, type: type);
    if (bills.isEmpty) return null;
    return (bills.first['amount'] as num?)?.toDouble();
  }

  Future<void> loadAmounts() async {
    try {
      final e = await _amountFor('electricity');
      final w = await _amountFor('water');
      if (!mounted) return;
      setState(() {
        electricityAmount = e;
        waterAmount = w;
      });
    } catch (_) {}
  }

  String _subtitle(String label, double? amount) {
    final m = UtilityDateHelper.monthLabel(month);
    return amount == null
        ? 'No $label bill added for $m'
        : '$m: LKR ${amount.toStringAsFixed(0)}';
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    loadAmounts();
  }

  Widget _tile(IconData icon, String title, String subtitle, Widget page) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _open(page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Utilities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _tile(Icons.bolt, 'Electricity',
                _subtitle('electricity', electricityAmount), const ElectricityPage()),
            const SizedBox(height: 12),
            _tile(Icons.water_drop, 'Water',
                _subtitle('water', waterAmount), const WaterPage()),
          ],
        ),
      ),
    );
  }
}
