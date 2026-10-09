import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/menu_repository.dart';
import '../../data/models/menu_category.dart';
import '../../data/models/menu_item.dart';
import '../../logic/inventory/inventory_cubit.dart';
import '../../logic/cart/cart_cubit.dart';

class ItemCard extends StatelessWidget {
  final MenuItem item;
  final String categoryName;

  const ItemCard({super.key, required this.item, required this.categoryName});

  /// In categories that track stock (any item has a recipe), tell the cashier
  /// when the picked item/size deducts nothing instead of failing silently.
  void _warnIfNoRecipe(BuildContext context, String size) {
    final inv = context.read<InventoryCubit>();
    if (inv.state.activeShift == null || inv.hasRecipe(item.name, size)) return;
    final category = const MenuRepository().categories.where((c) => c.name == categoryName);
    if (category.isEmpty) return;
    final c = category.first;
    final siblings = [...?c.items, for (final s in c.subcategories ?? const <MenuSubcategory>[]) ...s.items];
    final tracked = siblings.any((it) => it.prices.keys.any((sz) => inv.hasRecipe(it.name, sz)));
    if (!tracked) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('تنبيه: "${item.name}" ($size) بدون وصفة - لن يخصم أي مخزون برسلة.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            if (item.description != null) ...[
              const SizedBox(height: 4),
              Text(
                item.description!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.2),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.prices.entries.map((entry) {
                final label = {'عادي', 'وجبة', 'طاجن'}.contains(entry.key)
                    ? ''
                    : entry.key;
                return SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5CB85C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.read<CartCubit>().addItem(
                            name: item.name,
                            size: entry.key,
                            price: entry.value,
                            category: categoryName,
                          );
                      _warnIfNoRecipe(context, entry.key);
                    },
                    child: Text('$label ${entry.value.toStringAsFixed(0)}ج'.trim()),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
