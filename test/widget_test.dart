// Smoke test: the app boots straight into the cashier-name gate when no
// cashier name has been saved yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:casher_goha/app/app.dart';

void main() {
  testWidgets('shows cashier name gate on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CasherApp());
    await tester.pumpAndSettle();

    expect(find.text('مرحباً بك في نظام الكاشير'), findsOneWidget);
  });
}
