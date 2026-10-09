import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/menu_repository.dart';
import '../../logic/cart/cart_cubit.dart';
import '../../logic/cashier/cashier_cubit.dart';
import '../../logic/inventory/inventory_cubit.dart';
import '../../logic/inventory/inventory_state.dart';
import '../../logic/menu_nav/menu_nav_cubit.dart';
import '../widgets/cart_panel.dart';
import '../widgets/category_chips.dart';
import '../widgets/menu_items_grid.dart';
import 'inventory/inventory_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _menu = MenuRepository();
  int _mobileTab = 0; // 0 = menu, 1 = cart

  Future<void> _editCashierName(BuildContext context) async {
    final cubit = context.read<CashierCubit>();
    final controller = TextEditingController(text: cubit.state.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم الكاشير'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'الاسم'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      cubit.setName(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashierName = context.watch<CashierCubit>().state.name;
    final categories = _menu.categories;

    final menuColumn = Column(
      children: [
        CategoryChips(categories: categories),
        const SizedBox(height: 8),
        Expanded(
          child: BlocBuilder<MenuNavCubit, int>(
            builder: (context, selectedIndex) =>
                MenuItemsGrid(category: categories[selectedIndex]),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام الكاشير (POS)'),
        actions: [
          BlocBuilder<InventoryCubit, InventoryState>(
            builder: (context, inv) {
              final open = inv.activeShift != null;
              return TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InventoryDashboardScreen()),
                ),
                icon: Icon(open ? Icons.inventory_2 : Icons.inventory_2_outlined, color: Colors.white, size: 20),
                label: Text(
                  open ? 'البرسلة (شيفت #${inv.activeShift!.id})' : 'البرسلة - فتح الشيفت',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: InkWell(
                onTap: () => _editCashierName(context),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(cashierName, style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 14, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: menuColumn),
                    const SizedBox(width: 12),
                    const Expanded(flex: 2, child: CartPanel()),
                  ],
                );
              }
              return IndexedStack(
                index: _mobileTab,
                children: [menuColumn, const CartPanel()],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) return const SizedBox.shrink();
          final cartCount = context.watch<CartCubit>().state.items.length;
          return NavigationBar(
            selectedIndex: _mobileTab,
            onDestinationSelected: (i) => setState(() => _mobileTab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'القائمة'),
              NavigationDestination(
                icon: Badge(
                  label: Text('$cartCount'),
                  isLabelVisible: cartCount > 0,
                  child: const Icon(Icons.shopping_cart),
                ),
                label: 'السلة',
              ),
            ],
          );
        },
      ),
    );
  }
}
