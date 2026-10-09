import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/quantity.dart';
import '../../../data/models/inventory/inventory_shift.dart';
import '../../../logic/cashier/cashier_cubit.dart';
import '../../../logic/inventory/inventory_cubit.dart';
import '../../../logic/shift/shift_cubit.dart';
import 'inventory_dashboard_screen.dart';
import 'inventory_settings_screen.dart';
import 'open_shift_screen.dart';

final _dateFmt = DateFormat('yyyy/MM/dd hh:mm a');
String fmtDate(DateTime d) => _dateFmt.format(d);

void showResult(BuildContext context, InventoryResult r) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: r.ok ? null : AppColors.primaryDark,
      duration: const Duration(seconds: 4),
      content: Text(r.message),
    ));
}

Future<bool> confirmDialog(BuildContext context, String title, Widget body, {String ok = 'تأكيد'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

/// Asks for the manager PIN (or creates one the first time). Returns true when
/// a manager session is active.
Future<bool> requireManager(BuildContext context) async {
  final cubit = context.read<InventoryCubit>();
  if (cubit.state.managerUnlocked) return true;
  final creating = !cubit.hasManagerPin;
  final controller = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(creating ? 'إنشاء رمز المدير' : 'صلاحية المدير'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(creating
                ? 'اختر رمزاً من 4 إلى 8 أرقام لحماية إعدادات البرسلة والتسويات.'
                : 'أدخل رمز المدير للمتابعة.'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'الرمز', errorText: error),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final r = creating
                  ? cubit.setManagerPin(controller.text.trim())
                  : cubit.unlockManager(controller.text.trim());
              if (r.ok) {
                Navigator.pop(ctx, true);
              } else {
                setState(() => error = r.message);
              }
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// "3 كيس + 250 جرام" style description plus the precise total.
class StockText extends StatelessWidget {
  final int total;
  final int capacity;
  final String unit;
  final TextStyle? style;

  const StockText({super.key, required this.total, required this.capacity, required this.unit, this.style});

  @override
  Widget build(BuildContext context) {
    final b = bagBreakdown(total, capacity);
    final equivalent = capacity > 0 ? (total / capacity).toStringAsFixed(2) : '0';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${formatQty(total, unit)} (≈ $equivalent كيس)', style: style ?? const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          '${b.fullBags} كيس كامل + ${formatQty(b.looseMilli, unit)} في الكيس المفتوح',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
      );
}

/// Manager-only manual adjustment (open shift) / correction (closed shift).
Future<void> showAdjustDialog(BuildContext context, InventoryShift shift) async {
  if (!await requireManager(context)) return;
  if (!context.mounted) return;
  final cubit = context.read<InventoryCubit>();
  final employee = context.read<CashierCubit>().state.name;
  String? ingredientId = shift.meta.keys.first;
  var increase = true;
  final qty = TextEditingController();
  final reason = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final meta = shift.meta[ingredientId]!;
        return AlertDialog(
          title: Text(shift.isOpen ? 'تسوية المخزون' : 'تصحيح بعد إغلاق الشيفت'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: ingredientId,
                decoration: const InputDecoration(labelText: 'المكوّن'),
                items: [
                  for (final e in shift.meta.entries) DropdownMenuItem(value: e.key, child: Text(e.value.name)),
                ],
                onChanged: (v) => setState(() => ingredientId = v),
              ),
              const SizedBox(height: 8),
              Text('الرصيد الحالي: ${formatQty(shift.balanceOf(ingredientId!), meta.unit)}'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('زيادة')),
                  ButtonSegment(value: false, label: Text('نقص')),
                ],
                selected: {increase},
                onSelectionChanged: (s) => setState(() => increase = s.first),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'الكمية (${meta.unit})'),
              ),
              const SizedBox(height: 8),
              TextField(controller: reason, decoration: const InputDecoration(labelText: 'السبب (مطلوب)')),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: AppColors.primaryDark)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final amount = parseMilli(qty.text);
                if (amount == null || amount == 0) {
                  setState(() => error = 'أدخل كمية صحيحة أكبر من صفر.');
                  return;
                }
                final r = cubit.adjustStock(
                  shiftId: shift.id,
                  ingredientId: ingredientId!,
                  delta: increase ? amount : -amount,
                  reason: reason.text,
                  employee: employee,
                );
                if (r.ok) {
                  Navigator.pop(ctx);
                  showResult(context, r);
                } else {
                  setState(() => error = r.message);
                }
              },
              child: const Text('تسجيل'),
            ),
          ],
        );
      },
    ),
  );
}

/// Shown when an order/edit is refused. Handles both "no open shift" and
/// ingredient shortage (with a direct "إضافة أكياس" action per short item).
Future<void> showOrderBlockedDialog(BuildContext context, OrderResult result) async {
  if (result.ok) return;
  final cubit = context.read<InventoryCubit>();
  if (result.needsShift) {
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('افتح الشيفت أولاً'),
        content: const Text('لا يمكن تسجيل الطلبات قبل فتح الشيفت وتسجيل رصيد البرسلة. السلة محفوظة كما هي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.restaurant),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('فتح الشيفت'),
          ),
        ],
      ),
    );
    if (open == true && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpenShiftScreen()));
    }
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('المخزون غير كافٍ'),
      content: Text(result.error!),
      actions: [
        for (final id in result.shortIds)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.restaurant),
            onPressed: () async {
              final added = await showAddStockDialog(context, ingredientId: id);
              if (added && ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(Icons.add_box),
            label: Text('إضافة أكياس - ${cubit.state.activeShift?.meta[id]?.name ?? cubit.state.ingredient(id)?.name ?? ''}'),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
      ],
    ),
  );
}

/// Shown wherever an ingredient's bag capacity is "not set": explains why bags
/// can't be entered and takes the user straight to settings (PIN protected).
class CapacityMissingNotice extends StatelessWidget {
  final VoidCallback? beforeNavigate;
  const CapacityMissingNotice({super.key, this.beforeNavigate});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(8)),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text('حدد سعة الكيس من الإعدادات',
                style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
            OutlinedButton.icon(
              onPressed: () {
                beforeNavigate?.call();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventorySettingsScreen()));
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('فتح الإعدادات'),
            ),
          ],
        ),
      );
}
