import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:boarding_manager/database_service.dart';
import 'package:boarding_manager/api_service.dart';

import 'package:boarding_manager/pdf_service.dart';
import 'package:boarding_manager/utility_date_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseService.instance.database;
    await db.delete('payments');
    await db.delete('monthly_bills');
    await db.delete('utility_bills');
    await db.delete('students');
  });

  test('DatabaseService initializes, seeds rooms and handles bill generation', () async {
    // 1. Get initial rooms (seeded)
    final rooms = await ApiService.getRooms();
    expect(rooms.isNotEmpty, true, reason: 'Initial default rooms should be seeded');

    final firstRoomId = rooms.first['id'] as int;
    final firstRoomFee = (rooms.first['monthly_fee'] as num).toDouble();

    // 2. Add a student
    final studentRes = await ApiService.addStudent(
      roomId: firstRoomId,
      name: 'Kasun Perera',
      phone: '0771234567',
      joinDate: '2026-09-01',
    );
    expect(studentRes['student']['name'], 'Kasun Perera');

    // 3. Add utility bills (electricity & water)
    await ApiService.addUtilityBill(
      month: '2026-09',
      type: 'electricity',
      amount: 4000.0,
    );
    await ApiService.addUtilityBill(
      month: '2026-09',
      type: 'water',
      amount: 2000.0,
    );

    // 4. Generate monthly bills
    final genResult = await ApiService.generateMonthlyBills(
      month: '2026-09',
      dueDate: '2026-09-30',
    );
    expect(genResult['message'], 'Monthly bills generated successfully.');

    // 5. Fetch generated monthly bills
    final bills = await ApiService.getMonthlyBills(month: '2026-09');
    expect(bills.isNotEmpty, true);

    final bill = bills.first;
    expect(bill['status'], 'unpaid');
    // Total should equal room fee + (electricity / 1 student) + (water / 1 student)
    expect(bill['boarding_fee'], firstRoomFee);
    expect(bill['electricity'], 4000.0);
    expect(bill['water'], 2000.0);
    expect(bill['total'], firstRoomFee + 6000.0);

    // 6. Record payment
    final billId = bill['id'] as int;
    await ApiService.addPayment(
      monthlyBillId: billId,
      amount: bill['total'] as double,
      paidDate: '2026-09-15',
      paymentMethod: 'Cash',
      note: 'Full payment received',
    );

    // 7. Verify bill status is now paid
    final updatedBills = await ApiService.getMonthlyBills(month: '2026-09');
    final updatedBill = updatedBills.firstWhere((b) => b['id'] == billId);
    expect(updatedBill['status'], 'paid');

    // 8. Verify dashboard statistics
    final dashboard = await ApiService.getDashboard();
    expect(dashboard['students'], greaterThanOrEqualTo(1));
    expect(dashboard['rooms'], greaterThanOrEqualTo(1));
    expect(dashboard['paid'], greaterThanOrEqualTo(bill['total']));
  });

  test('Utility bills support custom date ranges, retrieve currently added value, and generate PDF without due date', () async {
    // 1. Test UtilityDateHelper default patterns
    final elecDefault = UtilityDateHelper.defaultElectricityPeriod('2026-09');
    expect(elecDefault['start'], '01/09/2026');
    expect(elecDefault['end'], '30/09/2026');

    final waterDefault = UtilityDateHelper.defaultWaterPeriod('2026-09');
    expect(waterDefault['start'], '15/08/2026');
    expect(waterDefault['end'], '15/09/2026');

    // 2. Add water bill with specific 15/08/2026 to 15/09/2026 date range
    await ApiService.addUtilityBill(
      month: '2026-09',
      type: 'water',
      amount: 2250.0,
      startDate: '15/08/2026',
      endDate: '15/09/2026',
    );

    // 3. Add electricity bill with 01/09/2026 to 30/09/2026 date range
    await ApiService.addUtilityBill(
      month: '2026-09',
      type: 'electricity',
      amount: 4000.0,
      startDate: '01/09/2026',
      endDate: '30/09/2026',
    );

    // 4. Verify retrieving currently added value
    final waterBills = await ApiService.getUtilityBills(month: '2026-09', type: 'water');
    expect(waterBills.isNotEmpty, true);
    expect(waterBills.first['amount'], 2250.0);
    expect(waterBills.first['start_date'], '15/08/2026');
    expect(waterBills.first['end_date'], '15/09/2026');

    final elecBills = await ApiService.getUtilityBills(month: '2026-09', type: 'electricity');
    expect(elecBills.isNotEmpty, true);
    expect(elecBills.first['amount'], 4000.0);
    expect(elecBills.first['start_date'], '01/09/2026');
    expect(elecBills.first['end_date'], '30/09/2026');

    // 5. Add student and generate monthly bills
    final rooms = await ApiService.getRooms();
    await ApiService.addStudent(
      roomId: rooms.first['id'] as int,
      name: 'Nimal Silva',
      phone: '0719876543',
      joinDate: '2026-09-01',
    );

    await ApiService.generateMonthlyBills(month: '2026-09');

    final bills = await ApiService.getMonthlyBills(month: '2026-09');
    expect(bills.isNotEmpty, true);
    final bill = bills.first;

    expect(bill['total_electricity'], 4000.0);
    expect(bill['total_water'], 2250.0);
    expect(bill['electricity_period'], '01/09/2026 to 30/09/2026');
    expect(bill['water_period'], '15/08/2026 to 15/09/2026');

    // 6. Generate PDF bytes and ensure successful build
    final pdfBytes = await PdfService.generateBillPdf(
      studentName: 'Nimal Silva',
      roomName: 'Room 1',
      month: '2026-09',
      boardingFee: 12000.0,
      electricity: 4000.0,
      water: 2250.0,
      total: 18250.0,
      status: 'unpaid',
      boardingHouseName: 'Sunrise Boarding House',
      totalElectricity: 4000.0,
      totalWater: 2250.0,
      studentCount: 1,
      electricityPeriod: '01/09/2026 to 30/09/2026',
      waterPeriod: '15/08/2026 to 15/09/2026',
    );

    expect(pdfBytes.isNotEmpty, true);
  });
}
