import 'package:flutter/material.dart';

import '../../data/models/menu_category.dart';
import '../../data/models/menu_item.dart';
import 'custom_item_form.dart';
import 'item_card.dart';

class MenuItemsGrid extends StatelessWidget {
  final MenuCategory category;

  const MenuItemsGrid({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    if (category.isCustom) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(4),
        child: CustomItemForm(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = (constraints.maxWidth / 190).floor().clamp(2, 6);
        final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(2),
          child: category.subcategories != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final sub in category.subcategories!) ...[
                      _SubcategoryHeader(title: sub.name),
                      const SizedBox(height: 6),
                      _ItemsWrap(
                        // Tag with the main category (e.g. "البيتزا"), not the
                        // subcategory, so the receipt/report group all pizza
                        // (or crepe, etc.) types together under one heading.
                        items: sub.items,
                        categoryName: category.name,
                        itemWidth: itemWidth,
                        spacing: spacing,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                )
              : _ItemsWrap(
                  items: category.items ?? const [],
                  categoryName: category.name,
                  itemWidth: itemWidth,
                  spacing: spacing,
                ),
        );
      },
    );
  }
}

class _ItemsWrap extends StatelessWidget {
  final List<MenuItem> items;
  final String categoryName;
  final double itemWidth;
  final double spacing;

  const _ItemsWrap({
    required this.items,
    required this.categoryName,
    required this.itemWidth,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final item in items)
          SizedBox(
            width: itemWidth,
            child: ItemCard(item: item, categoryName: categoryName),
          ),
      ],
    );
  }
}

class _SubcategoryHeader extends StatelessWidget {
  final String title;

  const _SubcategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF292B2C),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
