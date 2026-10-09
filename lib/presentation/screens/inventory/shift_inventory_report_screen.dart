import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/quantity.dart';
import '../../../data/models/inventory/inventory_shift.dart';
import '../../../data/models/inventory/stock_movement.dart';
import '../../../logic/inventory/inventory_cubit.dart';
import '../../../logic/inventory/inventory_state.dart';
import 'inventory_ui.dart';
import 'movement_history_screen.dart';

/// "تقرير نهاية الشيفت" — rendered from the permanent closing snapshot.
class ShiftInventoryReportScreen extends StatelessWidget {
  final int shiftId;
  const ShiftInventoryReportScreen({super.key, required this.shiftId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(builder: (context, state) {
      final shift = state.shifts.firstWhere((s) => s.id == shiftId);
      final rows = shift.closingRows ?? const <ClosingRow>[];
      final corrections = shift.movements.where((m) => m.type == MovementType.correction).toList();
      return Scaffold(
        appBar: AppBar(title: Text('تقرير المخزون - شيفت #${shift.id}')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('فتح: ${fmtDate(shift.openedAt)} - ${shift.openedBy}'),
                    if (shift.closedAt != null) Text('إغلاق: ${fmtDate(shift.closedAt!)} - ${shift.closedBy}'),
                    const SizedBox(height: 4),
                    const Text('المتبقي = البداية + المضاف + المردود - المستهلك ± التسويات',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
                ),
              ),
              for (final r in rows) _ReportCard(row: r),
              if (corrections.isNotEmpty) ...[
                const SectionTitle('تصحيحات بعد الإغلاق (لا تغيّر التقرير أعلاه)'),
                for (final m in corrections)
                  Card(
                    child: ListTile(
                      title: Text('${shift.meta[m.ingredientId]?.name}: ${m.delta > 0 ? '+' : ''}${formatQty(m.delta, m.unit)}'),
                      subtitle: Text('${m.note}\n${m.employee} | ${fmtDate(m.time)}'),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => MovementHistoryScreen(shiftId: shift.id))),
                  icon: const Icon(Icons.history),
                  label: const Text('سجل حركة المخزون'),
                ),
                if (!shift.isOpen)
                  OutlinedButton.icon(
                    onPressed: () => showAdjustDialog(context, shift),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('تصحيح بعد الإغلاق (المدير)'),
                  ),
              ]),
            ]),
          ),
        ),
      );
    });
  }
}

class _ReportCard extends StatelessWidget {
  final ClosingRow row;
  const _ReportCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final u = row.unit;
    final b = bagBreakdown(row.remaining, row.bagCapacity);
    final notes = <String>[
      if (row.remaining <= 0) 'نفد المخزون بالكامل',
      if (row.difference != 0)
        'فرق جرد ${row.difference > 0 ? 'زيادة' : 'عجز'} ${formatQty(row.difference.abs(), u)} - ${row.reason}',
      if (row.adjustments != 0) 'تسويات خلال الشيفت: ${formatQty(row.adjustments, u)}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          _line('رصيد البداية', '${row.openingBags} كيس = ${formatQty(row.opening, u)}'),
          _line('أكياس مضافة', formatQty(row.added, u)),
          _line('إجمالي المستهلك', formatQty(row.consumed, u)),
          _line('المردود (إلغاء/تعديل)', formatQty(row.reversed, u)),
          _line('المتوقع المتبقي', formatQty(row.expected, u)),
          if (row.actual != null) _line('الجرد الفعلي', formatQty(row.actual!, u)),
          const Divider(),
          _line('الأكياس المتبقية', '${b.fullBags} كيس كامل'),
          _line('المتبقي في الكيس المفتوح', formatQty(b.looseMilli, u)),
          _line('إجمالي المتبقي', '${formatQty(row.remaining, u)} ${row.bagCapacity > 0 ? '(≈ ${(row.remaining / row.bagCapacity).toStringAsFixed(2)} كيس)' : ''}', bold: true),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                const SizedBox(width: 4),
                Expanded(child: Text(n, style: const TextStyle(color: AppColors.primaryDark, fontSize: 12.5))),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _line(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k)),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );
}
