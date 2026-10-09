// Regression test: items from different Pizza sub-sections (e.g. "بيتزا
// الجبنة" vs "بيتزا الدجاج") must be tagged with the main "البيتزا" category,
// not their subcategory, so the receipt groups all pizza together.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:casher_goha/app/app.dart';
import 'package:casher_goha/core/category_grouping.dart';
import 'package:casher_goha/logic/cart/cart_cubit.dart';
import 'package:casher_goha/logic/menu_nav/menu_nav_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> _tapItemSize(WidgetTester tester, String itemName) async {
  final card = find.ancestor(of: find.text(itemName), matching: find.byType(Card));
  final button = find.descendant(of: card, matching: find.byType(ElevatedButton)).first;
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pizza items from different subcategories share one category tag',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CasherApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'أحمد');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    // Open the "البيتزا" category tab (index 5 in MenuRepository). Selecting
    // via the cubit sidesteps the horizontal chip list being a lazy-built
    // ListView that may not have that far-off chip in the tree yet.
    tester.element(find.byType(MaterialApp)).read<MenuNavCubit>().select(5);
    await tester.pumpAndSettle();

    // "بيتزا مارجريتا" lives under subcategory "بيتزا الجبنة",
    // "بيتزا زنجر حار" lives under subcategory "بيتزا الدجاج".
    await _tapItemSize(tester, 'بيتزا مارجريتا');
    await _tapItemSize(tester, 'بيتزا زنجر حار');

    final cartState = tester
        .element(find.byType(MaterialApp))
        .read<CartCubit>()
        .state;
    expect(cartState.items.length, 2);

    final grouped = groupItemsByCategory(cartState.items);
    expect(grouped.keys.toList(), ['البيتزا']);
    expect(grouped['البيتزا']!.length, 2);
  });
}
