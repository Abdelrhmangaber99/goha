import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/quantity.dart';
import '../../../logic/cashier/cashier_cubit.dart';
import '../../../logic/inventory/inventory_cubit.dart';
import '../../../logic/inventory/inventory_state.dart';
import 'inventory_ui.dart';

/// "فتح الشيفت" — records the bags issued to the kitchen, then starts the shift.
class OpenShiftScreen extends StatefulWidget {
  const OpenShiftScreen({super.key});

  @override
  State<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final _controllers = <String, TextEditingController>{};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(String id) =>
      _controllers.putIfAbsent(id, () => TextEditingController(text: '0'));

  int? _bags(String id) => parseWhole(_ctl(id).text);

  void _step(String id, int delta) {
    final v = (_bags(id) ?? 0) + delta;
    setState(() => _ctl(id).text = '${v < 0 ? 0 : v}');
  }

  Future<void> _submit(InventoryState state) async {
    if (_submitting) return;
    final active = state.ingredients.where((i) => i.active).toList();
    final bags = <String, int>{};
    for (final i in active) {
      final b = _bags(i.id);
      if (b == null) {
        setState(() => _error = 'أدخل عدد أكياس صحيح (أرقام صحيحة غير سالبة) للمكوّن: ${i.name}');
        return;
      }
      bags[i.id] = b;
    }
    setState(() => _error = null);
    final lines = active.where((i) => bags[i.id]! > 0).toList();
    final ok = await confirmDialog(
      context,
      'تأكيد رصيد بداية الشيفت',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lines.isEmpty) const Text('لم تُصرف أي أكياس (الرصيد صفر لكل المكونات).'),
          for (final i in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${i.name}: ${bags[i.id]} كيس × ${formatQty(i.bagCapacity, i.unit)} = ${formatQty(bags[i.id]! * i.bagCapacity, i.unit)}'),
            ),
          const SizedBox(height: 8),
          const Text('لا يمكن تعديل رصيد البداية بعد التأكيد.',
              style: TextStyle(color: AppColors.primaryDark, fontSize: 12)),
        ],
      ),
      ok: 'فتح الشيفت',
    );
    if (!ok || !mounted) return;
    setState(() => _submitting = true);
    final r = context.read<InventoryCubit>().openShift(
          bags: bags,
          employee: context.read<CashierCubit>().state.name,
        );
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context);
      showResult(context, r);
    } else {
      setState(() {
        _submitting = false;
        _error = r.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryCubit>().state;
    final active = state.ingredients.where((i) => i.active).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('فتح الشيفت - رصيد بداية الشيفت')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text(
                'سجّل عدد أكياس البرسلة المسلّمة للمطبخ قبل بدء الشيفت. اترك 0 للمكوّن غير المصروف.',
              ),
              const SizedBox(height: 10),
              if (active.isEmpty) const Text('لا توجد مكونات مفعّلة. أضفها من إعدادات البرسلة.'),
              for (final i in active)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      spacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              if (i.bagCapacity > 0)
                                Text('سعة الكيس: ${formatQty(i.bagCapacity, i.unit)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700))
                              else
                                const Padding(padding: EdgeInsets.only(top: 4), child: CapacityMissingNotice()),
                            ],
                          ),
                        ),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton.filledTonal(
                              onPressed: i.bagCapacity > 0 ? () => _step(i.id, -1) : null, icon: const Icon(Icons.remove)),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: _ctl(i.id),
                              enabled: i.bagCapacity > 0,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]'))],
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'أكياس', isDense: true),
                            ),
                          ),
                          IconButton.filledTonal(onPressed: i.bagCapacity > 0 ? () => _step(i.id, 1) : null, icon: const Icon(Icons.add)),
                        ]),
                        SizedBox(
                          width: 150,
                          child: Text(
                            'الإجمالي: ${formatQty((_bags(i.id) ?? 0) * i.bagCapacity, i.unit)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.restaurant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!, style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.restaurant, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _submitting ? null : () => _submit(state),
                icon: const Icon(Icons.play_arrow),
                label: const Text('مراجعة وفتح الشيفت'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
