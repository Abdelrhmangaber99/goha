import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/quantity.dart';
import '../../../data/models/inventory/ingredient.dart';
import '../../../data/models/inventory/inventory_shift.dart';
import '../../../logic/cashier/cashier_cubit.dart';
import '../../../logic/inventory/inventory_cubit.dart';
import '../../../logic/inventory/inventory_state.dart';
import 'close_shift_screen.dart';
import 'inventory_settings_screen.dart';
import 'inventory_ui.dart';
import 'movement_history_screen.dart';
import 'open_shift_screen.dart';
import 'shift_inventory_report_screen.dart';

enum _Filter { all, low, out }

/// "إدارة البرسلة" — live inventory of the active shift (or the launch pad for
/// opening one when none is active).
class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  String _query = '';
  _Filter _filter = _Filter.all;

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        final shift = state.activeShift;
        return Scaffold(
          appBar: AppBar(
            title: const Text('إدارة البرسلة'),
            actions: [
              IconButton(
                tooltip: 'إعدادات البرسلة والوصفات',
                icon: const Icon(Icons.settings),
                onPressed: () => _push(const InventorySettingsScreen()),
              ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (shift == null) _NoShift(onOpen: () => _push(const OpenShiftScreen())) else ..._active(state, shift),
                    if (state.closedShifts.isNotEmpty) ...[
                      const SectionTitle('تقارير الشيفتات السابقة'),
                      for (final s in state.closedShifts)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.assessment, color: AppColors.info),
                            title: Text('شيفت رقم ${s.id}'),
                            subtitle: Text('${fmtDate(s.openedAt)}  ←  ${fmtDate(s.closedAt!)}'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => _push(ShiftInventoryReportScreen(shiftId: s.id)),
                          ),
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _active(InventoryState state, InventoryShift shift) {
    final rows = <_Row>[];
    for (final e in shift.meta.entries) {
      final ing = state.ingredient(e.key);
      final bal = shift.balanceOf(e.key);
      final min = ing?.minStock;
      rows.add(_Row(
        id: e.key,
        meta: e.value,
        opening: shift.openingOf(e.key),
        added: shift.addedOf(e.key),
        consumed: shift.consumedOf(e.key),
        reversed: shift.reversedOf(e.key),
        adjustments: shift.adjustmentsOf(e.key),
        balance: bal,
        isOut: bal <= 0,
        isLow: bal > 0 && min != null && bal <= min,
      ));
    }
    final lowCount = rows.where((r) => r.isLow).length;
    final outCount = rows.where((r) => r.isOut).length;
    final filtered = rows.where((r) {
      if (_query.isNotEmpty && !r.meta.name.contains(_query.trim())) return false;
      return switch (_filter) {
        _Filter.all => true,
        _Filter.low => r.isLow,
        _Filter.out => r.isOut,
      };
    }).toList();
    final last = shift.movements.isEmpty ? shift.openedAt : shift.movements.last.time;

    return [
      Card(
        color: const Color(0xFFEAFAF1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الشيفت #${shift.id} - مفتوح', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.restaurant)),
            Text('بدأ: ${fmtDate(shift.openedAt)} بواسطة ${shift.openedBy}'),
            Text('آخر تحديث للمخزون: ${fmtDate(last)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ]),
        ),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Stat(label: 'عدد المكونات', value: '${rows.length}', color: AppColors.info),
        _Stat(label: 'مخزون منخفض', value: '$lowCount', color: AppColors.warning),
        _Stat(label: 'نفد', value: '$outCount', color: AppColors.primary),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(
          onPressed: () => showAddStockDialog(context),
          icon: const Icon(Icons.add_box),
          label: const Text('إضافة برسلة'),
        ),
        OutlinedButton.icon(
          onPressed: () => _push(MovementHistoryScreen(shiftId: shift.id)),
          icon: const Icon(Icons.history),
          label: const Text('سجل حركة المخزون'),
        ),
        OutlinedButton.icon(
          onPressed: () => showAdjustDialog(context, shift),
          icon: const Icon(Icons.tune),
          label: const Text('تسوية المخزون'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => _push(const CloseShiftScreen()),
          icon: const Icon(Icons.stop_circle),
          label: const Text('إغلاق الشيفت'),
        ),
      ]),
      const SizedBox(height: 10),
      TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث عن مكوّن'),
        onChanged: (v) => setState(() => _query = v),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final f in _Filter.values)
          ChoiceChip(
            label: Text(switch (f) { _Filter.all => 'الكل', _Filter.low => 'تنبيه نقص المخزون', _Filter.out => 'نفد' }),
            selected: _filter == f,
            onSelected: (_) => setState(() => _filter = f),
          ),
      ]),
      const SectionTitle('المخزون الحالي'),
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('لا توجد مكونات مطابقة', style: TextStyle(color: Colors.grey.shade600))),
        ),
      LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 760 && filtered.isNotEmpty) return _Table(rows: filtered);
        return Column(children: [for (final r in filtered) _RowCard(row: r)]);
      }),
    ];
  }
}

class _Row {
  final String id;
  final IngredientMeta meta;
  final int opening, added, consumed, reversed, adjustments, balance;
  final bool isLow, isOut;
  _Row({
    required this.id,
    required this.meta,
    required this.opening,
    required this.added,
    required this.consumed,
    required this.reversed,
    required this.adjustments,
    required this.balance,
    required this.isLow,
    required this.isOut,
  });

  String get status => isOut ? 'نفد' : (isLow ? 'منخفض' : 'جيد');
  Color get color => isOut ? AppColors.primary : (isLow ? AppColors.warning : AppColors.restaurant);
}

class _Table extends StatelessWidget {
  final List<_Row> rows;
  const _Table({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('المكوّن')),
            DataColumn(label: Text('رصيد البداية')),
            DataColumn(label: Text('المضاف خلال الشيفت')),
            DataColumn(label: Text('المستهلك')),
            DataColumn(label: Text('المتبقي')),
            DataColumn(label: Text('الأكياس المتبقية')),
            DataColumn(label: Text('الحالة')),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(r.meta.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(formatQty(r.opening, r.meta.unit))),
                DataCell(Text(formatQty(r.added, r.meta.unit))),
                DataCell(Text(formatQty(r.consumed - r.reversed, r.meta.unit))),
                DataCell(Text(formatQty(r.balance, r.meta.unit), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Builder(builder: (_) {
                  final b = bagBreakdown(r.balance, r.meta.bagCapacity);
                  return Text('${b.fullBags} كيس + ${formatQty(b.looseMilli, r.meta.unit)}');
                })),
                DataCell(Text(r.status, style: TextStyle(color: r.color, fontWeight: FontWeight.bold))),
              ]),
          ],
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final _Row row;
  const _RowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final u = row.meta.unit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(row.meta.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: row.color, borderRadius: BorderRadius.circular(10)),
              child: Text(row.status, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 6),
          StockText(total: row.balance, capacity: row.meta.bagCapacity, unit: u),
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 2, children: [
            Text('البداية: ${formatQty(row.opening, u)}', style: const TextStyle(fontSize: 12)),
            Text('المضاف: ${formatQty(row.added, u)}', style: const TextStyle(fontSize: 12)),
            Text('المستهلك: ${formatQty(row.consumed - row.reversed, u)}', style: const TextStyle(fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white)),
        ]),
      );
}

class _NoShift extends StatelessWidget {
  final VoidCallback onOpen;
  const _NoShift({required this.onOpen});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 8),
            const Text('لا يوجد شيفت مفتوح', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('افتح الشيفت وسجّل أكياس البرسلة المسلّمة للمطبخ ليبدأ خصم المكونات تلقائياً مع كل أوردر.',
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.restaurant),
              onPressed: onOpen,
              icon: const Icon(Icons.play_arrow),
              label: const Text('فتح الشيفت'),
            ),
          ]),
        ),
      );
}

/// "إضافة برسلة للمخزن" dialog.
Future<bool> showAddStockDialog(BuildContext context, {String? ingredientId}) async {
  final cubit = context.read<InventoryCubit>();
  final employee = context.read<CashierCubit>().state.name;
  final shift = cubit.state.activeShift;
  if (shift == null) return false;
  final ingredients = cubit.state.ingredients.where((i) => i.active).toList();
  if (ingredients.isEmpty) return false;
  var added = false;
  // One key per dialog opening: a double tap on "تأكيد" can't add twice.
  final requestKey = DateTime.now().microsecondsSinceEpoch.toString();
  var selected = ingredients.firstWhere((i) => i.id == ingredientId, orElse: () => ingredients.first);
  final bagsCtl = TextEditingController(text: '1');
  final noteCtl = TextEditingController();
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final frozenCap = shift.meta[selected.id]?.bagCapacity ?? 0;
      final capacity = frozenCap > 0 ? frozenCap : selected.bagCapacity;
      final bags = parseWhole(bagsCtl.text) ?? 0;
      return AlertDialog(
        title: const Text('إضافة برسلة للمخزن'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'المكوّن'),
              items: [for (final i in ingredients) DropdownMenuItem(value: i, child: Text(i.name))],
              onChanged: (v) => setState(() => selected = v!),
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: capacity > 0
                  ? Text('سعة الكيس: ${formatQty(capacity, selected.unit)}')
                  : CapacityMissingNotice(beforeNavigate: () => Navigator.pop(ctx))),
            const SizedBox(height: 8),
            TextField(
              controller: bagsCtl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'عدد الأكياس المستلمة'),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text('الكمية المضافة: ${formatQty(bags * capacity, selected.unit)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.restaurant)),
            ),
            const SizedBox(height: 8),
            TextField(controller: noteCtl, decoration: const InputDecoration(labelText: 'ملاحظة / المصدر (اختياري)')),
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
            onPressed: busy
                ? null
                : () {
                    final n = parseWhole(bagsCtl.text);
                    if (n == null || n <= 0) {
                      setState(() => error = 'أدخل عدد أكياس صحيحاً أكبر من صفر.');
                      return;
                    }
                    setState(() => busy = true);
                    final r = cubit.addStock(
                      ingredientId: selected.id,
                      bags: n,
                      employee: employee,
                      requestKey: requestKey,
                      note: noteCtl.text,
                    );
                    if (r.ok) {
                      added = true;
                      Navigator.pop(ctx);
                      showResult(context, r);
                    } else {
                      setState(() {
                        busy = false;
                        error = r.message;
                      });
                    }
                  },
            child: const Text('تأكيد الإضافة'),
          ),
        ],
      );
    }),
  );
  return added;
}
