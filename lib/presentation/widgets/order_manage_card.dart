import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/category_grouping.dart';
import '../../data/models/order.dart';
import '../../logic/shift/shift_cubit.dart';
import '../screens/inventory/inventory_ui.dart';

class OrderManageCard extends StatelessWidget {
  final Order order;
  final bool isExpanded;

  const OrderManageCard({super.key, required this.order, required this.isExpanded});

  Future<bool> _ask(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _report(BuildContext context, OrderResult r) {
    if (!r.ok) showOrderBlockedDialog(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShiftCubit>();
    final time = DateFormat('hh:mm a').format(order.time);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFF9F9F9),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أوردر #${order.id} - ${order.type.arabicLabel} ($time)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (order.cashierName.isNotEmpty)
                        Text('الكاشير: ${order.cashierName}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      Text(
                        'الإجمالي: ${order.total.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.restaurant),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    _SmallButton(
                      label: isExpanded ? 'إخفاء الأصناف' : 'عرض الأصناف / تعديل',
                      color: AppColors.warning,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        cubit.toggleExpanded(order.id);
                      },
                    ),
                    _SmallButton(
                      label: 'حذف الأوردر كلياً',
                      color: AppColors.primary,
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final ok = await _ask(context, 'هل أنت متأكد من إلغاء/حذف الطلب رقم #${order.id} بالكامل؟');
                        if (ok) cubit.cancelOrder(order.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
            if (isExpanded) ...[
              const Divider(),
              for (final categoryEntry in groupItemsByCategory(order.items).entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    categoryEntry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                  ),
                ),
                for (final grouped in categoryEntry.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(grouped.item.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              Text(
                                '${grouped.item.price.toStringAsFixed(0)} ج.م × ${grouped.item.qty} = ${grouped.item.total.toStringAsFixed(0)} ج.م',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        _QtyBtn(icon: Icons.remove, onTap: () {
                          HapticFeedback.lightImpact();
                          _report(context, cubit.updateOrderItemQty(order.id, grouped.originalIndex, -1));
                        }),
                        SizedBox(width: 24, child: Text('${grouped.item.qty}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        _QtyBtn(icon: Icons.add, onTap: () {
                          HapticFeedback.lightImpact();
                          _report(context, cubit.updateOrderItemQty(order.id, grouped.originalIndex, 1));
                        }),
                        const SizedBox(width: 6),
                        _SmallButton(
                          label: 'إلغاء الصنف',
                          color: const Color(0xFFE74C3C),
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final ok = await _ask(context, 'هل أنت متأكد من إلغاء صنف (${grouped.item.key}) من الأوردر #${order.id}؟');
                            if (ok && context.mounted) _report(context, cubit.removeItemFromOrder(order.id, grouped.originalIndex));
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          border: Border.all(color: const Color(0xFFCCCCCC)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }
}
