import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/quantity.dart';
import '../../../data/models/inventory/stock_movement.dart';
import '../../../logic/inventory/inventory_cubit.dart';
import '../../../logic/inventory/inventory_state.dart';
import 'inventory_ui.dart';

/// "سجل حركة المخزون" — append-only ledger of one shift.
class MovementHistoryScreen extends StatefulWidget {
  final int shiftId;
  const MovementHistoryScreen({super.key, required this.shiftId});

  @override
  State<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends State<MovementHistoryScreen> {
  MovementType? _type;
  String? _ingredient;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(builder: (context, state) {
      final shift = state.shifts.firstWhere((s) => s.id == widget.shiftId);
      final list = shift.movements.reversed
          .where((m) => (_type == null || m.type == _type) && (_ingredient == null || m.ingredientId == _ingredient))
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text('سجل حركة المخزون - شيفت #${shift.id}')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<MovementType?>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'نوع الحركة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    for (final t in MovementType.values) DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _ingredient,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المكوّن'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    for (final e in shift.meta.entries) DropdownMenuItem(value: e.key, child: Text(e.value.name)),
                  ],
                  onChanged: (v) => setState(() => _ingredient = v),
                ),
              ),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('لا توجد حركات', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final name = shift.meta[m.ingredientId]?.name ?? m.ingredientId;
                      final positive = m.delta > 0;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            m.delta == 0 ? Icons.flag : (positive ? Icons.arrow_downward : Icons.arrow_upward),
                            color: m.delta == 0 ? AppColors.info : (positive ? AppColors.restaurant : AppColors.primary),
                          ),
                          title: Text('${m.type.label} - $name'),
                          subtitle: Text([
                            'الكمية: ${m.delta > 0 ? '+' : ''}${formatQty(m.delta, m.unit)}',
                            'قبل: ${formatMilli(m.before)} ← بعد: ${formatMilli(m.after)}',
                            if (m.orderId != null) 'أوردر #${m.orderId}',
                            'بواسطة: ${m.employee}  |  ${fmtDate(m.time)}',
                            if (m.note.isNotEmpty) 'ملاحظة: ${m.note}',
                          ].join('\n')),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );
    });
  }
}
