// Verifies receipt items are grouped by category instead of showing in the
// mixed order they were added, and that grouping works for any category
// name without special-casing.

import 'package:flutter_test/flutter_test.dart';

import 'package:casher_goha/core/category_grouping.dart';
import 'package:casher_goha/data/models/cart_item.dart';

CartItem _item(String name, String category) => CartItem(
      key: name,
      name: name,
      size: 'عادي',
      price: 100,
      qty: 1,
      category: category,
    );

void main() {
  test('groups mixed-order items by category, preserving first-seen category order', () {
    final items = [
      _item('Crepe Meat', 'كريب'),
      _item('Pizza Meat', 'بيتزا'),
      _item('Crepe Fish', 'كريب'),
      _item('Pizza Fish', 'بيتزا'),
    ];

    final grouped = groupItemsByCategory(items);

    expect(grouped.keys.toList(), ['كريب', 'بيتزا']);
    expect(grouped['كريب']!.map((g) => g.item.name), ['Crepe Meat', 'Crepe Fish']);
    expect(grouped['بيتزا']!.map((g) => g.item.name), ['Pizza Meat', 'Pizza Fish']);
  });

  test('preserves each item original index for later qty/remove operations', () {
    final items = [
      _item('Crepe Meat', 'كريب'),
      _item('Pizza Meat', 'بيتزا'),
      _item('Crepe Fish', 'كريب'),
    ];

    final grouped = groupItemsByCategory(items);

    expect(grouped['كريب']!.map((g) => g.originalIndex), [0, 2]);
    expect(grouped['بيتزا']!.map((g) => g.originalIndex), [1]);
  });

  test('a brand-new, previously-unseen category gets its own group automatically', () {
    final items = [
      _item('Sushi Roll', 'سوشي'),
      _item('Pizza Meat', 'بيتزا'),
    ];

    final grouped = groupItemsByCategory(items);

    expect(grouped.keys.toList(), ['سوشي', 'بيتزا']);
  });
}
