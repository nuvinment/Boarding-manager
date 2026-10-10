import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'utility_date_helper.dart';

class PdfService {
  // =========================
  // GENERATE BILL PDF
  // =========================

  static Future<Uint8List> generateBillPdf({
    required String studentName,
    required String roomName,
    required String month,
    required double boardingFee,
    required double electricity,
    required double water,
    required double total,
    required String status,
    String? dueDate, // Removed from display as requested, kept optional for compatibility
    String? boardingHouseName,
    double? totalElectricity,
    double? totalWater,
    int? studentCount,
    String? electricityPeriod,
    String? waterPeriod,
  }) async {
    final pdf = pw.Document();

    final int effectiveStudentCount =
        (studentCount != null && studentCount > 0) ? studentCount : 1;
    final double effectiveTotalElectricity =
        totalElectricity ?? (electricity * effectiveStudentCount);
    final double effectiveTotalWater =
        totalWater ?? (water * effectiveStudentCount);

    final defaultElec = UtilityDateHelper.defaultElectricityPeriod(month);
    final defaultWater = UtilityDateHelper.defaultWaterPeriod(month);

    final String effectiveElecPeriod = (electricityPeriod != null &&
            electricityPeriod.isNotEmpty)
        ? electricityPeriod
        : '${defaultElec['start']} to ${defaultElec['end']}';

    final String effectiveWaterPeriod =
        (waterPeriod != null && waterPeriod.isNotEmpty)
            ? waterPeriod
            : '${defaultWater['start']} to ${defaultWater['end']}';

    final String houseHeader = (boardingHouseName != null &&
            boardingHouseName.trim().isNotEmpty)
        ? boardingHouseName.trim().toUpperCase()
        : 'SUNRISE BOARDING HOUSE';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          final isPaid = status.toLowerCase() == 'paid';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Real-life Header with Boarding House Name & Invoice Title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        houseHeader,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Monthly Boarding & Utility Invoice',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: isPaid ? PdfColors.green50 : PdfColors.red50,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6),
                      ),
                      border: pw.Border.all(
                        color: isPaid ? PdfColors.green : PdfColors.red,
                        width: 1,
                      ),
                    ),
                    child: pw.Text(
                      status.toUpperCase(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: isPaid ? PdfColors.green900 : PdfColors.red900,
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 14),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Resident & Stay Details (Due date removed as requested)
              pw.Text(
                'Resident & Accommodation Details',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900,
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _detailRow('Resident Student', studentName),
                        _detailRow('Allocated Room', roomName),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _detailRow('Billing Month', month),
                        _detailRow(
                          'Sharing Residents',
                          '$effectiveStudentCount Students',
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Utility Charges Breakdown Section
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Utility Expenses & Cost-Sharing Breakdown',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      children: [
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _cell('Utility Type', isHeader: true),
                            _cell('Billing Cycle (Date Range)', isHeader: true),
                            _cell(
                              'Total Charged',
                              isHeader: true,
                              alignRight: true,
                            ),
                            _cell(
                              '1 Person Share',
                              isHeader: true,
                              alignRight: true,
                            ),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            _cell('Electricity Bill'),
                            _cell(effectiveElecPeriod),
                            _cell(
                              _formatAmount(effectiveTotalElectricity),
                              alignRight: true,
                            ),
                            _cell(
                              _formatAmount(electricity),
                              alignRight: true,
                            ),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            _cell('Water Bill'),
                            _cell(effectiveWaterPeriod),
                            _cell(
                              _formatAmount(effectiveTotalWater),
                              alignRight: true,
                            ),
                            _cell(
                              _formatAmount(water),
                              alignRight: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // Final Bill Summary Table
              pw.Text(
                'Bill Statement',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900,
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                ),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Description', isHeader: true),
                      _cell('Billing Period / Cost Share', isHeader: true),
                      _cell('Amount', isHeader: true, alignRight: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Monthly Boarding Fee'),
                      _cell('Room accommodation for $month'),
                      _cell(_formatAmount(boardingFee), alignRight: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Electricity (1 Person Share)'),
                      _cell(
                        'Period: $effectiveElecPeriod\n(Total: ${_formatAmount(effectiveTotalElectricity)} / $effectiveStudentCount)',
                      ),
                      _cell(_formatAmount(electricity), alignRight: true),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _cell('Water (1 Person Share)'),
                      _cell(
                        'Period: $effectiveWaterPeriod\n(Total: ${_formatAmount(effectiveTotalWater)} / $effectiveStudentCount)',
                      ),
                      _cell(_formatAmount(water), alignRight: true),
                    ],
                  ),
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _cell('TOTAL PAYABLE', isHeader: true, isTotal: true),
                      _cell(
                        'Total for $studentName',
                        isHeader: true,
                        isTotal: true,
                      ),
                      _cell(
                        _formatAmount(total),
                        isHeader: true,
                        isTotal: true,
                        alignRight: true,
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for staying at $houseHeader',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // =========================
  // SHARE PDF
  // =========================

  static Future<void> shareBillPdf({
    required Uint8List pdfBytes,
    required String studentName,
    required String month,
  }) async {
    final fileName = 'Boarding_Bill_${studentName}_$month.pdf';

    final file = XFile.fromData(
      pdfBytes,
      name: fileName,
      mimeType: 'application/pdf',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: 'Monthly boarding bill for $studentName - $month',
      ),
    );
  }

  // =========================
  // DETAIL ROW
  // =========================

  static pw.Widget _detailRow(
    String label,
    String value,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // TABLE CELL
  // =========================

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    bool isTotal = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment:
            alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isTotal ? 11 : 9.5,
            fontWeight:
                (isHeader || isTotal) ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: (isHeader || isTotal) ? PdfColors.indigo900 : PdfColors.black,
          ),
        ),
      ),
    );
  }

  // =========================
  // FORMAT AMOUNT
  // =========================

  static String _formatAmount(
    double amount,
  ) {
    return 'LKR ${amount.toStringAsFixed(0)}';
  }
}