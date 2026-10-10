import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'utility_date_helper.dart';
import 'payment_page.dart';
import 'pdf_service.dart';

class MonthlyBillsPage extends StatefulWidget {
  const MonthlyBillsPage({super.key});

  @override
  State<MonthlyBillsPage> createState() => _MonthlyBillsPageState();
}

class _MonthlyBillsPageState extends State<MonthlyBillsPage> {
  List<dynamic> bills = [];

  bool isLoading = true;
  bool isGenerating = false;

  String? errorMessage;
  String selectedMonth = UtilityDateHelper.currentMonth();
  String boardingHouseName = 'Sunrise Boarding House';

  @override
  void initState() {
    super.initState();
    loadBills();
  }

  // =========================
  // LOAD BILLS
  // =========================

  Future<void> loadBills() async {
    try {
      final data = await ApiService.getMonthlyBills(
        month: selectedMonth,
      );
      final settings = await ApiService.getSettings();

      if (!mounted) return;

      setState(() {
        bills = data;
        boardingHouseName = settings['boarding_house_name'] ?? 'Sunrise Boarding House';
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // =========================
  // GENERATE BILLS
  // =========================

  Future<void> generateBills() async {
    setState(() {
      isGenerating = true;
    });

    try {
      await ApiService.generateMonthlyBills(
        month: selectedMonth,
      );

      await loadBills();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Monthly bills generated successfully!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  // =========================
  // OPEN PAYMENT PAGE
  // =========================

  Future<void> openPaymentPage(
    int billId,
    double amount,
    String studentName,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          billId: billId,
          amount: amount,
          studentName: studentName,
        ),
      ),
    );

    if (result == true) {
      loadBills();
    }
  }

  // =========================
  // FORMAT AMOUNT
  // =========================

  String formatAmount(dynamic amount) {
    final value =
        double.tryParse(amount.toString()) ?? 0;

    return 'LKR ${value.toStringAsFixed(0)}';
  }

  // =========================
  // GENERATE PDF
  // =========================

  Future<void> generatePdf({
    required String studentName,
    required String roomName,
    required String month,
    required double boardingFee,
    required double electricity,
    required double water,
    required double total,
    required String status,
    double? totalElectricity,
    double? totalWater,
    int? studentCount,
    String? electricityPeriod,
    String? waterPeriod,
  }) async {
    try {
      final Uint8List pdfBytes =
          await PdfService.generateBillPdf(
        studentName: studentName,
        roomName: roomName,
        month: month,
        boardingFee: boardingFee,
        electricity: electricity,
        water: water,
        total: total,
        status: status,
        boardingHouseName: boardingHouseName,
        totalElectricity: totalElectricity,
        totalWater: totalWater,
        studentCount: studentCount,
        electricityPeriod: electricityPeriod,
        waterPeriod: waterPeriod,
      );

      await PdfService.shareBillPdf(
        pdfBytes: pdfBytes,
        studentName: studentName,
        month: month,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error generating PDF: $e',
          ),
        ),
      );
    }
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monthly Bills',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [

          // =========================
          // GENERATE BILLS SECTION
          // =========================

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                const Text(
                  'Generate Monthly Bills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // =========================
                // MONTH DROPDOWN
                // =========================

                DropdownButtonFormField<String>(
                  initialValue: selectedMonth,

                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                  ),

                  items: UtilityDateHelper.monthOptions()
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(UtilityDateHelper.monthLabel(m)),
                            ))
                        .toList(),

                  onChanged: (value) async {
                    if (value == null) return;

                    setState(() {
                      selectedMonth = value;
                      isLoading = true;
                    });

                    await loadBills();
                  },
                ),

                const SizedBox(height: 12),

                // =========================
                // GENERATE BUTTON
                // =========================

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed:
                        isGenerating
                            ? null
                            : generateBills,

                    icon: isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.receipt_long,
                          ),

                    label: Text(
                      isGenerating
                          ? 'Generating...'
                          : 'Generate Bills',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // =========================
          // BILLS LIST
          // =========================

          Expanded(
            child: isLoading

                // =========================
                // LOADING
                // =========================

                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )

                // =========================
                // ERROR
                // =========================

                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(20),
                          child: Text(
                            'Error loading bills:\n'
                            '$errorMessage',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      )

                    // =========================
                    // NO BILLS
                    // =========================

                    : bills.isEmpty
                        ? const Center(
                            child: Text(
                              'No monthly bills found',
                              style: TextStyle(
                                fontSize: 18,
                              ),
                            ),
                          )

                        // =========================
                        // BILLS
                        // =========================

                        : RefreshIndicator(
                            onRefresh: loadBills,

                            child:
                                ListView.builder(
                              padding:
                                  const EdgeInsets.all(
                                      16),

                              itemCount:
                                  bills.length,

                              itemBuilder:
                                  (context, index) {

                                final bill =
                                    bills[index];

                                final student =
                                    bill['student'];

                                final room =
                                    student?['room'];

                                final studentName =
                                    student?['name'] ??
                                        'Unknown Student';

                                final roomName =
                                    room?['room_name'] ??
                                        'No Room';

                                final month =
                                    bill['month'] ??
                                        'Unknown Month';

                                final boardingFee =
                                    bill[
                                            'boarding_fee'] ??
                                        0;

                                final electricity =
                                    bill[
                                            'electricity'] ??
                                        0;

                                final water =
                                    bill['water'] ?? 0;

                                final total =
                                    bill['total'] ?? 0;

                                final status =
                                    bill['status'] ??
                                        'unpaid';

                                final billId =
                                    int.tryParse(
                                          bill['id']
                                              .toString(),
                                        ) ??
                                        0;

                                final totalElectricityAmount =
                                    double.tryParse(
                                          bill['total_electricity']
                                                  ?.toString() ??
                                              '0',
                                        ) ??
                                        0;

                                final totalWaterAmount =
                                    double.tryParse(
                                          bill['total_water']
                                                  ?.toString() ??
                                              '0',
                                        ) ??
                                        0;

                                final studentCount =
                                    int.tryParse(
                                          bill['student_count']
                                                  ?.toString() ??
                                              '1',
                                        ) ??
                                        1;

                                final electricityPeriod =
                                    bill['electricity_period']
                                            ?.toString() ??
                                        '';

                                final waterPeriod =
                                    bill['water_period']
                                            ?.toString() ??
                                        '';

                                final totalAmount =
                                    double.tryParse(
                                          total.toString(),
                                        ) ??
                                        0;

                                final boardingFeeAmount =
                                    double.tryParse(
                                          boardingFee
                                              .toString(),
                                        ) ??
                                        0;

                                final electricityAmount =
                                    double.tryParse(
                                          electricity
                                              .toString(),
                                        ) ??
                                        0;

                                final waterAmount =
                                    double.tryParse(
                                          water.toString(),
                                        ) ??
                                        0;

                                final isPaid =
                                    status
                                            .toString()
                                            .toLowerCase() ==
                                        'paid';

                                return Card(
                                  margin:
                                      const EdgeInsets.only(
                                    bottom: 16,
                                  ),

                                  child: Padding(
                                    padding:
                                        const EdgeInsets
                                            .all(16),

                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [

                                        // =========================
                                        // STUDENT + STATUS
                                        // =========================

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,

                                          children: [

                                            Expanded(
                                              child: Text(
                                                studentName,
                                                style:
                                                    const TextStyle(
                                                  fontSize: 19,
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                ),
                                              ),
                                            ),

                                            Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal:
                                                    10,
                                                vertical: 6,
                                              ),

                                              decoration:
                                                  BoxDecoration(
                                                color: isPaid
                                                    ? Colors.green.withValues(alpha: 0.12)
                                                    : Colors.red.withValues(alpha: 0.12),

                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            20),
                                              ),

                                              child: Text(
                                                isPaid
                                                    ? 'Paid'
                                                    : 'Unpaid',

                                                style:
                                                    TextStyle(
                                                  color: isPaid
                                                      ? Colors
                                                          .green
                                                      : Colors
                                                          .red,

                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(
                                          height: 6,
                                        ),

                                        // =========================
                                        // ROOM + MONTH
                                        // =========================

                                        Text(
                                          '$roomName • $month',
                                          style: TextStyle(
                                            color:
                                                Colors.grey[
                                                    700],
                                          ),
                                        ),

                                        const Divider(
                                          height: 24,
                                        ),

                                        // =========================
                                        // BOARDING FEE
                                        // =========================

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,

                                          children: [
                                            const Text(
                                              'Boarding Fee',
                                            ),

                                            Text(
                                              formatAmount(
                                                boardingFee,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),                                        // =========================
                                        // ELECTRICITY
                                        // =========================

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Electricity (1 Person Share)',
                                                  ),
                                                  if (totalElectricityAmount > 0 ||
                                                      electricityPeriod.isNotEmpty)
                                                    Text(
                                                      'Total: ${formatAmount(totalElectricityAmount)}${electricityPeriod.isNotEmpty ? ' • $electricityPeriod' : ''}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              formatAmount(
                                                electricity,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),

                                        // =========================
                                        // WATER
                                        // =========================

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Water (1 Person Share)',
                                                  ),
                                                  if (totalWaterAmount > 0 ||
                                                      waterPeriod.isNotEmpty)
                                                    Text(
                                                      'Total: ${formatAmount(totalWaterAmount)}${waterPeriod.isNotEmpty ? ' • $waterPeriod' : ''}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              formatAmount(
                                                water,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const Divider(
                                          height: 24,
                                        ),

                                        // =========================
                                        // TOTAL
                                        // =========================

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,

                                          children: [

                                            const Text(
                                              'TOTAL',
                                              style:
                                                  TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                                fontSize: 16,
                                              ),
                                            ),

                                            Text(
                                              formatAmount(
                                                total,
                                              ),
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // =========================
                                        // MARK AS PAID
                                        // =========================

                                        if (!isPaid) ...[
                                          const SizedBox(
                                            height: 16,
                                          ),

                                          SizedBox(
                                            width:
                                                double.infinity,
                                            height: 45,

                                            child:
                                                ElevatedButton
                                                    .icon(
                                              onPressed: () {
                                                openPaymentPage(
                                                  billId,
                                                  totalAmount,
                                                  studentName,
                                                );
                                              },

                                              icon:
                                                  const Icon(
                                                Icons.check,
                                              ),

                                              label:
                                                  const Text(
                                                'Mark as Paid',
                                              ),
                                            ),
                                          ),
                                        ],

                                        // =========================
                                        // GENERATE PDF
                                        // =========================

                                        const SizedBox(
                                          height: 10,
                                        ),

                                        SizedBox(
                                          width:
                                              double.infinity,
                                          height: 45,

                                          child:
                                              OutlinedButton
                                                  .icon(
                                            onPressed: () {
                                              generatePdf(
                                                studentName:
                                                    studentName,
                                                roomName:
                                                    roomName,
                                                month:
                                                    month,
                                                boardingFee:
                                                    boardingFeeAmount,
                                                electricity:
                                                    electricityAmount,
                                                water:
                                                    waterAmount,
                                                total:
                                                    totalAmount,
                                                status:
                                                    status
                                                        .toString(),
                                                totalElectricity:
                                                    totalElectricityAmount,
                                                totalWater:
                                                    totalWaterAmount,
                                                studentCount:
                                                    studentCount,
                                                electricityPeriod:
                                                    electricityPeriod,
                                                waterPeriod:
                                                    waterPeriod,
                                              );
                                            },

                                            icon:
                                                const Icon(
                                              Icons
                                                  .picture_as_pdf,
                                            ),

                                            label:
                                                const Text(
                                              'Generate PDF',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
