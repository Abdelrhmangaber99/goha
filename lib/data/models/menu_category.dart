import 'menu_item.dart';

class MenuSubcategory {
  final String name;
  final List<MenuItem> items;

  const MenuSubcategory({required this.name, required this.items});
}

class MenuCategory {
  final String name;
  final List<MenuItem>? items;
  final List<MenuSubcategory>? subcategories;
  final bool isCustom;

  const MenuCategory({
    required this.name,
    this.items,
    this.subcategories,
    this.isCustom = false,
  });
}
