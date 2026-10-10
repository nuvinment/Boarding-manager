import 'package:flutter/material.dart';
import 'api_service.dart';
import 'utility_date_helper.dart';

class WaterPage extends StatefulWidget {
  const WaterPage({super.key});

  @override
  State<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<WaterPage> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController startDateController = TextEditingController();
  final TextEditingController endDateController = TextEditingController();

  String selectedMonth = UtilityDateHelper.currentMonth();
  Map<String, dynamic>? currentBill;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadCurrentBill();
  }

  @override
  void dispose() {
    amountController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    super.dispose();
  }

  Future<void> loadCurrentBill() async {
    setState(() {
      isLoading = true;
    });

    try {
      final bills = await ApiService.getUtilityBills(
        month: selectedMonth,
        type: 'water',
      );

      final defaultPeriod = UtilityDateHelper.defaultWaterPeriod(selectedMonth);

      if (!mounted) return;

      if (bills.isNotEmpty) {
        final latest = bills.first;
        setState(() {
          currentBill = latest;
          final amt = (latest['amount'] as num?)?.toDouble() ?? 0.0;
          amountController.text = amt > 0 ? amt.toStringAsFixed(0) : '';
          startDateController.text = latest['start_date'] ?? defaultPeriod['start']!;
          endDateController.text = latest['end_date'] ?? defaultPeriod['end']!;
          isLoading = false;
        });
      } else {
        setState(() {
          currentBill = null;
          amountController.clear();
          startDateController.text = defaultPeriod['start']!;
          endDateController.text = defaultPeriod['end']!;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading water bill: $e')),
      );
    }
  }

  Future<void> pickDate({
    required TextEditingController controller,
    required String title,
  }) async {
    final currentParsed = UtilityDateHelper.parseDisplayDate(controller.text) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: currentParsed,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: title,
    );

    if (picked != null) {
      setState(() {
        controller.text = UtilityDateHelper.formatDisplayDate(picked);
      });
    }
  }

  Future<void> saveWaterBill() async {
    if (amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the water amount')),
      );
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final startDate = startDateController.text.trim();
    final endDate = endDateController.text.trim();

    if (startDate.isEmpty || endDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify the billing date range')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await ApiService.addUtilityBill(
        month: selectedMonth,
        type: 'water',
        amount: amount,
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Water bill for $selectedMonth saved: LKR ${amount.toStringAsFixed(0)} ($startDate to $endDate)',
          ),
          backgroundColor: Colors.teal.shade800,
        ),
      );

      await loadCurrentBill();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Water Bill',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month selection
                  const Text(
                    'Billing Month',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMonth,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    items: UtilityDateHelper.monthOptions()
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(UtilityDateHelper.monthLabel(m)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedMonth = value;
                        });
                        loadCurrentBill();
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Currently Added Value Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: currentBill != null
                          ? Colors.cyan.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentBill != null
                            ? Colors.cyan.shade300
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              currentBill != null
                                  ? Icons.water_drop
                                  : Icons.info_outline,
                              color: currentBill != null
                                  ? Colors.cyan.shade800
                                  : Colors.blue.shade800,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentBill != null
                                  ? 'Currently Added Water Bill'
                                  : 'No Water Bill Added Yet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: currentBill != null
                                    ? Colors.cyan.shade900
                                    : Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (currentBill != null) ...[
                          Text(
                            'LKR ${((currentBill!['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyan.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Period: ${currentBill!['start_date'] ?? 'N/A'} to ${currentBill!['end_date'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You can edit the values below and press Save to update.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'No water bill has been entered for $selectedMonth yet. Enter the amount and date range below.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Date range section
                  const Text(
                    'Water Billing Period (Date Range)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pattern: 15th of previous month to 15th of current month (e.g. 15/08/2026 to 15/09/2026)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Start Date
                      Expanded(
                        child: TextField(
                          controller: startDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'From Date',
                            hintText: 'DD/MM/YYYY',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              onPressed: () => pickDate(
                                controller: startDateController,
                                title: 'Select Start Date',
                              ),
                            ),
                          ),
                          onTap: () => pickDate(
                            controller: startDateController,
                            title: 'Select Start Date',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // End Date
                      Expanded(
                        child: TextField(
                          controller: endDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'To Date',
                            hintText: 'DD/MM/YYYY',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              onPressed: () => pickDate(
                                controller: endDateController,
                                title: 'Select End Date',
                              ),
                            ),
                          ),
                          onTap: () => pickDate(
                            controller: endDateController,
                            title: 'Select End Date',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Amount
                  const Text(
                    'Water Bill Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: 'LKR ',
                      hintText: 'Enter total water bill amount',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : saveWaterBill,
                      icon: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        isSaving
                            ? 'Saving...'
                            : (currentBill != null
                                ? 'Update Water Bill'
                                : 'Save Water Bill'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
