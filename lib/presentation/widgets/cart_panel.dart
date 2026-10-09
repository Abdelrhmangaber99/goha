import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../core/category_grouping.dart';
import '../../data/models/order.dart';
import '../../logic/cart/cart_cubit.dart';
import '../../logic/cart/cart_state.dart';
import '../../logic/cashier/cashier_cubit.dart';
import '../../logic/shift/shift_cubit.dart';
import '../screens/inventory/inventory_ui.dart';
import '../screens/shift_report_screen.dart';
import 'live_shift_box.dart';
import 'order_type_toggle.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  void _checkout(BuildContext context) {
    final cartCubit = context.read<CartCubit>();
    final cart = cartCubit.state;
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة!')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final cashierName = context.read<CashierCubit>().state.name;
    final result = context.read<ShiftCubit>().checkout(
          items: cart.items,
          type: cart.orderType,
          cashierName: cashierName,
        );
    if (!result.ok) {
      // No open shift / insufficient stock: the cart is kept untouched.
      showOrderBlockedDialog(context, result);
      return;
    }
    final orderId = result.orderId;
    cartCubit.clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          'تم تسجيل الطلب رقم #$orderId (${cart.orderType.arabicLabel})!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('الطلب الحالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Text('اختر الجهة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            const OrderTypeToggle(),
            const SizedBox(height: 10),
            const LiveShiftBox(),
            const SizedBox(height: 10),
            Expanded(child: _CartItemsList(cart: cart)),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  Text(
                    '${cart.total.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () => _checkout(context),
              child: const Text('تسجيل الطلب'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.info, side: const BorderSide(color: AppColors.info)),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShiftReportScreen()),
                );
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('عرض تقرير إدارة الشيفت والطلبات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemsList extends StatelessWidget {
  final CartState cart;

  const _CartItemsList({required this.cart});

  @override
  Widget build(BuildContext context) {
    if (cart.items.isEmpty) {
      return Center(
        child: Text('لا توجد أصناف في السلة', style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    final byCategory = groupItemsByCategory(cart.items);
    return ListView(
      children: [
        for (final entry in byCategory.entries) ...[
          _CategoryLabel(name: entry.key),
          for (final grouped in entry.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(grouped.item.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          '${grouped.item.price.toStringAsFixed(0)} × ${grouped.item.qty} = ${grouped.item.total.toStringAsFixed(0)} ج.م',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  _QtyStepper(
                    qty: grouped.item.qty,
                    onChanged: (delta) {
                      HapticFeedback.lightImpact();
                      context.read<CartCubit>().changeQty(grouped.originalIndex, delta);
                    },
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  final String name;

  const _CategoryLabel({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.primary),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final void Function(int delta) onChanged;

  const _QtyStepper({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: Icons.remove, onTap: () => onChanged(-1)),
        SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center)),
        _StepButton(icon: Icons.add, onTap: () => onChanged(1)),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
