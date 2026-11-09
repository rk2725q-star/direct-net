import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('DirectNet mobile app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DirectNetMobileApp());
    expect(find.text('DirectNet'), findsWidgets);
  });
}
