// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/main.dart';

void main() {
  testWidgets('Disguise Notes smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StealthMessengerApp());
    expect(find.text('Notas Rápidas'), findsOneWidget);
  });
}
