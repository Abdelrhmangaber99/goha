// Confirms the tablet/desktop two-column layout (menu + cart side-by-side)
// renders without overflow — the mobile-width flow test never exercises it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:casher_goha/app/app.dart';

void main() {
  testWidgets('wide layout renders menu and cart side by side without overflow',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CasherApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'سارة');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    // Both panels visible at once, no bottom nav tabs.
    expect(find.text('الطلب الحالي'), findsOneWidget);
    expect(find.text('فرخة كاملة'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_menu), findsNothing);

    await tester.tap(find.text('400ج'));
    await tester.pumpAndSettle();
    expect(find.text('400 ج.م'), findsWidgets);
  });
}
