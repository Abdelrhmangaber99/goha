// Exercises the golden path end-to-end: set cashier name, add an item to
// the cart, check it out, and confirm it lands correctly in the shift report.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:casher_goha/app/app.dart';
import 'package:casher_goha/logic/inventory/inventory_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  testWidgets('cashier name -> add item -> checkout -> shows in shift report',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CasherApp());
    await tester.pumpAndSettle();

    // 1. Cashier name gate.
    expect(find.text('مرحباً بك في نظام الكاشير'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'أحمد');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    // 2. Home screen shows with the cashier name in the app bar.
    expect(find.text('نظام الكاشير (POS)'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);

    // 2b. Orders now require an open inventory shift.
    expect(tester.element(find.byType(Scaffold).first).read<InventoryCubit>().openShift(bags: {}, employee: 'أحمد').ok, isTrue);
    await tester.pumpAndSettle();

    // 3. Add "فرخة كاملة" (400ج) from the first category to the cart.
    expect(find.text('فرخة كاملة'), findsOneWidget);
    await tester.tap(find.text('400ج'));
    await tester.pumpAndSettle();

    // 4. Switch to the cart tab (mobile layout) and confirm the item is there.
    await tester.tap(find.text('السلة'));
    await tester.pumpAndSettle();
    expect(find.text('فرخة كاملة'), findsOneWidget);
    expect(find.text('400 ج.م'), findsOneWidget);

    // 5. Checkout.
    await tester.tap(find.text('تسجيل الطلب'));
    await tester.pump();
    expect(find.textContaining('تم تسجيل الطلب رقم #1'), findsOneWidget);
    // The confirmation SnackBar auto-dismisses on a real Timer (not the fake
    // clock `pump()` advances), so dismiss it explicitly rather than the
    // test hanging around waiting on real wall-clock time.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // 6. Cart is cleared after checkout.
    expect(find.text('لا توجد أصناف في السلة'), findsOneWidget);

    // 7. Open the shift report and confirm the order + revenue are recorded.
    await tester.tap(find.text('عرض تقرير إدارة الشيفت والطلبات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('إجمالي مبيعات المطعم: 400 ج.م'), findsOneWidget);
    // The order-management section is further down the report; scroll to it.
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.textContaining('أوردر #1'), findsOneWidget);
  });
}
