import 'package:flutter_test/flutter_test.dart';
import 'package:tv_app/main.dart';

void main() {
  testWidgets('DirectNet TV app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DirectNetTvApp());
    expect(find.text('DirectNet TV'), findsWidgets);
  });
}
