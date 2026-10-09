// UI scenarios for the portion inventory, all in Arabic:
//  * an order without an open shift is blocked with "افتح الشيفت أولاً"
//  * open shift with bags x capacity, shortage dialog -> add bags -> order passes

import 'package:casher_goha/app/app.dart';
import 'package:casher_goha/core/quantity.dart';
import 'package:casher_goha/logic/inventory/inventory_cubit.dart';
import 'package:casher_goha/logic/menu_nav/menu_nav_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'cashier_name': 'أحمد'});
  await tester.pumpWidget(const CasherApp());
  await tester.pumpAndSettle();
}

InventoryCubit inventory(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<InventoryCubit>();

/// Manager enters the real bag capacities (nothing is hard-coded).
void setCapacities(InventoryCubit inv) {
  inv.setManagerPin('1234');
  for (final e in {'basturma': 500, 'mozzarella': 1000}.entries) {
    inv.saveIngredient(inv.state.ingredient(e.key)!.copyWith(bagCapacity: milli(e.value)));
  }
  inv.lockManager();
}

/// Adds "بيتزا بسطرمة" (صغير) to the cart through the menu.
Future<void> addSmallBasturma(WidgetTester tester) async {
  tester.element(find.byType(Scaffold).first).read<MenuNavCubit>().select(5); // البيتزا
  await tester.pumpAndSettle();
  final card = find.ancestor(of: find.text('بيتزا بسطرمة'), matching: find.byType(Card));
  await tester.ensureVisible(card);
  await tester.tap(find.descendant(of: card, matching: find.text('صغير 120ج')));
  await tester.pump();
}

void main() {
  testWidgets('no open shift: order is blocked, cart kept, dialog opens the shift screen', (tester) async {
    await boot(tester);
    expect(find.text('البرسلة - فتح الشيفت'), findsOneWidget);
    await addSmallBasturma(tester);

    await tester.tap(find.text('تسجيل الطلب'));
    await tester.pumpAndSettle();
    expect(find.text('افتح الشيفت أولاً'), findsOneWidget);
    await tester.tap(find.text('فتح الشيفت'));
    await tester.pumpAndSettle();
    expect(find.text('فتح الشيفت - رصيد بداية الشيفت'), findsOneWidget);

    // back at the POS the cart still holds the pizza
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('لا توجد أصناف في السلة'), findsNothing);
    expect(inventory(tester).state.shifts, isEmpty);
  });

  testWidgets('open shift (bags x capacity) -> shortage dialog -> add bags -> order succeeds', (tester) async {
    await boot(tester);
    final inv = inventory(tester);

    // Capacity not set yet: the opening row says so.
    await tester.tap(find.text('البرسلة - فتح الشيفت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الشيفت'));
    await tester.pumpAndSettle();
    expect(find.text('حدد سعة الكيس من الإعدادات'), findsWidgets);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    setCapacities(inv);
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الشيفت'));
    await tester.pumpAndSettle();

    // 1 basturma bag (500 g); mozzarella not issued.
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.pump();
    expect(find.text('الإجمالي: 500 جرام'), findsOneWidget);
    await tester.ensureVisible(find.text('مراجعة وفتح الشيفت'));
    await tester.tap(find.text('مراجعة وفتح الشيفت'));
    await tester.pumpAndSettle();
    expect(find.text('بسطرمة: 1 كيس × 500 جرام = 500 جرام'), findsOneWidget);
    await tester.tap(find.text('فتح الشيفت').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('الشيفت #1 - مفتوح'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await addSmallBasturma(tester);
    await tester.tap(find.text('تسجيل الطلب'));
    await tester.pumpAndSettle();
    expect(find.text('المخزون غير كافٍ'), findsOneWidget);
    expect(find.textContaining('موتزاريلا'), findsWidgets);
    expect(find.text('لا توجد أصناف في السلة'), findsNothing); // cart kept

    // Add bags right from the dialog, no PIN.
    await tester.tap(find.text('إضافة أكياس - موتزاريلا'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة برسلة للمخزن'), findsOneWidget);
    expect(find.text('الكمية المضافة: 1000 جرام'), findsOneWidget);
    await tester.tap(find.text('تأكيد الإضافة'));
    await tester.pumpAndSettle();
    expect(find.text('المخزون غير كافٍ'), findsNothing);
    expect(inv.state.activeShift!.balanceOf('mozzarella'), milli(1000));

    await tester.tap(find.text('تسجيل الطلب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // old snackbar leaves, new one enters
    expect(find.textContaining('تم تسجيل الطلب رقم #1'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(inv.state.activeShift!.balanceOf('basturma'), milli(475));
    expect(inv.state.activeShift!.balanceOf('mozzarella'), milli(900));
  });

  testWidgets('capacity not set: clear Arabic notice with a button that opens settings', (tester) async {
    await boot(tester);
    await tester.tap(find.text('البرسلة - فتح الشيفت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الشيفت'));
    await tester.pumpAndSettle();
    expect(find.text('حدد سعة الكيس من الإعدادات'), findsWidgets);
    await tester.ensureVisible(find.text('فتح الإعدادات').first);
    await tester.tap(find.text('فتح الإعدادات').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // spinner behind the PIN dialog never settles
    expect(find.text('إنشاء رمز المدير'), findsOneWidget); // settings gate (first-time PIN)
  });

  testWidgets('open-shift screen: bag count can be typed, re-edited and stepped before confirming', (tester) async {
    await boot(tester);
    setCapacities(inventory(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البرسلة - فتح الشيفت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الشيفت'));
    await tester.pumpAndSettle();

    final field = find.byType(TextField).at(0); // basturma, 500 g bags
    await tester.enterText(field, '3');
    await tester.pump();
    expect(find.text('الإجمالي: 1500 جرام'), findsOneWidget);
    await tester.enterText(field, '5'); // edit the number
    await tester.pump();
    expect(find.text('الإجمالي: 2500 جرام'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add).first); // + -> 6
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).first); // + -> 7
    await tester.tap(find.byIcon(Icons.remove).first); // - -> 6
    await tester.pump();
    expect(find.text('الإجمالي: 3000 جرام'), findsOneWidget);

    await tester.ensureVisible(find.text('مراجعة وفتح الشيفت'));
    await tester.tap(find.text('مراجعة وفتح الشيفت'));
    await tester.pumpAndSettle();
    expect(find.text('بسطرمة: 6 كيس × 500 جرام = 3000 جرام'), findsOneWidget);
    await tester.tap(find.text('فتح الشيفت').last);
    await tester.pumpAndSettle();
    expect(inventory(tester).state.activeShift!.balanceOf('basturma'), milli(3000));
    expect(inventory(tester).state.activeShift!.openingBags['basturma'], 6);
  });

  testWidgets('add bags twice in a row with the same amount, no PIN: two movements', (tester) async {
    await boot(tester);
    final inv = inventory(tester);
    setCapacities(inv);
    inv.openShift(bags: {'basturma': 1}, employee: 'أحمد');
    await tester.pumpAndSettle();
    await tester.tap(find.text('البرسلة (شيفت #1)'));
    await tester.pumpAndSettle();

    for (var n = 0; n < 2; n++) {
      await tester.tap(find.text('إضافة برسلة'));
      await tester.pumpAndSettle();
      expect(find.text('إضافة برسلة للمخزن'), findsOneWidget);
      expect(find.text('إنشاء رمز المدير'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, '1'), '2');
      await tester.pump();
      await tester.tap(find.text('تأكيد الإضافة'));
      await tester.pumpAndSettle();
    }
    final adds = inv.state.activeShift!.movements.where((m) => m.type.name == 'addition').toList();
    expect(adds.length, 2);
    expect(inv.state.activeShift!.balanceOf('basturma'), milli(500 + 2000));
  });
}
