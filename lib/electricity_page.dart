import 'package:flutter/material.dart';
import 'api_service.dart';
import 'utility_date_helper.dart';

class ElectricityPage extends StatefulWidget {
  const ElectricityPage({super.key});

  @override
  State<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends State<ElectricityPage> {
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
        type: 'electricity',
      );

      final defaultPeriod = UtilityDateHelper.defaultElectricityPeriod(selectedMonth);

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
        SnackBar(content: Text('Error loading electricity bill: $e')),
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

  Future<void> saveElectricityBill() async {
    if (amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the electricity amount')),
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
        type: 'electricity',
        amount: amount,
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Electricity bill for $selectedMonth saved: LKR ${amount.toStringAsFixed(0)} ($startDate to $endDate)',
          ),
          backgroundColor: Colors.green.shade800,
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
          'Electricity Bill',
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
                          ? Colors.amber.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentBill != null
                            ? Colors.amber.shade400
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
                                  ? Icons.bolt
                                  : Icons.info_outline,
                              color: currentBill != null
                                  ? Colors.amber.shade900
                                  : Colors.blue.shade800,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentBill != null
                                  ? 'Currently Added Electricity Bill'
                                  : 'No Electricity Bill Added Yet',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: currentBill != null
                                    ? Colors.amber.shade900
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
                              color: Colors.amber.shade900,
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
                            'No electricity bill has been entered for $selectedMonth yet. Enter the amount and date range below.',
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
                    'Electricity Billing Period (Date Range)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pattern: 1st of month to end of month (e.g. 01/09/2026 to 30/09/2026)',
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
                    'Electricity Bill Amount',
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
                      hintText: 'Enter total electricity bill amount',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : saveElectricityBill,
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
                                ? 'Update Electricity Bill'
                                : 'Save Electricity Bill'),
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
