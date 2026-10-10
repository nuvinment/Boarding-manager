import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:boarding_manager/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('BoardingManagerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BoardingManagerApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Dashboard'), findsWidgets);
  });
}
