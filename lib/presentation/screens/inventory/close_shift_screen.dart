import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/quantity.dart';
import '../../../logic/cashier/cashier_cubit.dart';
import '../../../logic/inventory/inventory_cubit.dart';
import 'inventory_ui.dart';
import 'shift_inventory_report_screen.dart';

/// "إغلاق الشيفت": shows expected remaining stock, optionally records the
/// physical count, then closes and saves the permanent report snapshot.
class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final _actual = <String, TextEditingController>{};
  final _reason = <String, TextEditingController>{};
  bool _closing = false;
  String? _error;

  TextEditingController _a(String id) => _actual.putIfAbsent(id, () => TextEditingController());
  TextEditingController _r(String id) => _reason.putIfAbsent(id, () => TextEditingController());

  @override
  void dispose() {
    for (final c in [..._actual.values, ..._reason.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    final cubit = context.read<InventoryCubit>();
    final shift = cubit.state.activeShift;
    if (shift == null) return;
    final counts = <String, int>{};
    final reasons = <String, String>{};
    for (final id in shift.meta.keys) {
      final text = _a(id).text.trim();
      if (text.isNotEmpty) {
        final v = parseMilli(text);
        if (v == null) {
          setState(() => _error = 'كمية الجرد غير صحيحة للمكوّن: ${shift.meta[id]!.name}');
          return;
        }
        counts[id] = v;
      }
      reasons[id] = _r(id).text;
    }
    final ok = await confirmDialog(
      context,
      'تأكيد إغلاق الشيفت',
      const Text('سيتم حفظ تقرير المخزون نهائياً ولن يمكن إضافة أو خصم مخزون على هذا الشيفت بعد الإغلاق.'),
      ok: 'إغلاق الشيفت',
    );
    if (!ok || !mounted) return;
    setState(() {
      _closing = true;
      _error = null;
    });
    final r = cubit.closeShift(
      employee: context.read<CashierCubit>().state.name,
      actualCounts: counts,
      reasons: reasons,
    );
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _closing = false;
        _error = r.message;
      });
      return;
    }
    final id = cubit.state.closedShifts.first.id;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ShiftInventoryReportScreen(shiftId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryCubit>().state;
    final shift = state.activeShift;
    if (shift == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('إغلاق الشيفت')),
        body: const Center(child: Text('لا يوجد شيفت مفتوح.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إغلاق الشيفت')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(12), children: [
            const Text('المخزون المتوقع بعد خصم الاستهلاك. يمكنك إدخال الجرد الفعلي لكل مكوّن (اختياري). أي فرق يُسجَّل كتسوية مع السبب.'),
            for (final e in shift.meta.entries)
              Builder(builder: (_) {
                final id = e.key;
                final meta = e.value;
                final expected = shift.balanceOf(id);
                final actual = parseMilli(_a(id).text);
                final diff = actual == null ? 0 : actual - expected;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(meta.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 14, children: [
                        Text('البداية: ${formatQty(shift.openingOf(id), meta.unit)}', style: const TextStyle(fontSize: 12)),
                        Text('المضاف: ${formatQty(shift.addedOf(id), meta.unit)}', style: const TextStyle(fontSize: 12)),
                        Text('المستهلك: ${formatQty(shift.consumedOf(id), meta.unit)}', style: const TextStyle(fontSize: 12)),
                        Text('المردود: ${formatQty(shift.reversedOf(id), meta.unit)}', style: const TextStyle(fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      const Text('المتوقع المتبقي:', style: TextStyle(fontSize: 12)),
                      StockText(total: expected, capacity: meta.bagCapacity, unit: meta.unit),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _a(id),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: 'الجرد الفعلي (${meta.unit}) - اختياري', isDense: true),
                      ),
                      if (actual != null && diff != 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${diff > 0 ? 'زيادة' : 'عجز'}: ${formatQty(diff.abs(), meta.unit)}',
                          style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _r(id),
                          decoration: const InputDecoration(labelText: 'سبب الفرق (مطلوب)', isDense: true),
                        ),
                      ],
                    ]),
                  ),
                );
              }),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _closing ? null : _close,
              icon: const Icon(Icons.lock),
              label: const Text('مراجعة وإغلاق الشيفت'),
            ),
          ]),
        ),
      ),
    );
  }
}
