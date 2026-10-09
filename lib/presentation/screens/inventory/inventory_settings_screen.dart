import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/quantity.dart';
import '../../../data/menu_repository.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/inventory/ingredient.dart';
import '../../../data/models/inventory/recipe.dart';
import '../../../logic/inventory/inventory_cubit.dart';
import '../../../logic/inventory/inventory_state.dart';
import 'inventory_ui.dart';

const _units = ['جرام', 'كجم', 'قطعة', 'لتر', 'مل'];

/// "إعدادات البرسلة": ingredients (unit, bag capacity, alert threshold) and
/// per-product/size recipes. Manager PIN required.
class InventorySettingsScreen extends StatefulWidget {
  const InventorySettingsScreen({super.key});

  @override
  State<InventorySettingsScreen> createState() => _InventorySettingsScreenState();
}

class _InventorySettingsScreenState extends State<InventorySettingsScreen> {
  bool _allowed = false;
  late final InventoryCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<InventoryCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await requireManager(context);
      if (!mounted) return;
      if (ok) {
        setState(() => _allowed = true);
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _cubit.lockManager();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات البرسلة'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [Tab(text: 'المكونات والأكياس'), Tab(text: 'وصفات الأصناف')],
          ),
        ),
        body: BlocBuilder<InventoryCubit, InventoryState>(
          builder: (context, state) => TabBarView(children: [
            _IngredientsTab(state: state),
            _RecipesTab(state: state),
          ]),
        ),
      ),
    );
  }
}

class _IngredientsTab extends StatelessWidget {
  final InventoryState state;
  const _IngredientsTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editIngredient(context, null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة مكوّن'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
        if (state.activeShift != null)
          const Card(
            color: Color(0xFFFFF6E5),
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Text('ملاحظة: تغيير سعة الكيس أو الاسم أو الوصفات لا يؤثر على الشيفت المفتوح حالياً ولا على التقارير السابقة، ويسري من الشيفت القادم.'),
            ),
          ),
        for (final i in state.ingredients)
          Card(
            child: ListTile(
              title: Text(i.name + (i.active ? '' : ' (غير مفعّل)')),
              subtitle: Text.rich(TextSpan(children: [
                TextSpan(text: 'الوحدة: ${i.unit}  |  سعة الكيس: '),
                i.bagCapacity > 0
                    ? TextSpan(
                        text: formatQty(i.bagCapacity, i.unit),
                        style: const TextStyle(fontWeight: FontWeight.bold))
                    : const TextSpan(
                        text: 'غير محددة - اضغط للتعديل',
                        style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                if (i.minStock != null) TextSpan(text: '  |  حد التنبيه: ${formatQty(i.minStock!, i.unit)}'),
              ])),
              trailing: const Icon(Icons.edit),
              onTap: () => _editIngredient(context, i),
            ),
          ),
      ]),
    );
  }

  Future<void> _editIngredient(BuildContext context, Ingredient? existing) async {
    final cubit = context.read<InventoryCubit>();
    final name = TextEditingController(text: existing?.name ?? '');
    final cap = TextEditingController(text: existing == null ? '' : formatMilli(existing.bagCapacity));
    final min = TextEditingController(text: existing?.minStock == null ? '' : formatMilli(existing!.minStock!));
    var unit = existing?.unit ?? _units.first;
    var active = existing?.active ?? true;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        final unitItems = {..._units, unit}.toList();
        return AlertDialog(
          title: Text(existing == null ? 'إضافة مكوّن' : 'تعديل ${existing.name}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المكوّن')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'وحدة القياس'),
                items: [for (final u in unitItems) DropdownMenuItem(value: u, child: Text(u))],
                onChanged: (v) => setState(() => unit = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cap,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'سعة الكيس ($unit)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: min,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'حد تنبيه نقص المخزون ($unit) - اختياري'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('مفعّل'),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
              if (error != null) Text(error!, style: const TextStyle(color: AppColors.primaryDark)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final capacity = parseMilli(cap.text);
                final minimum = min.text.trim().isEmpty ? null : parseMilli(min.text);
                if (capacity == null) {
                  setState(() => error = 'سعة الكيس غير صحيحة.');
                  return;
                }
                if (min.text.trim().isNotEmpty && minimum == null) {
                  setState(() => error = 'حد التنبيه غير صحيح.');
                  return;
                }
                final base = existing ??
                    Ingredient(id: cubit.newIngredientId(), name: '', unit: unit, bagCapacity: capacity);
                final r = cubit.saveIngredient(Ingredient(
                  id: base.id,
                  name: name.text.trim(),
                  unit: unit,
                  bagCapacity: capacity,
                  minStock: minimum,
                  active: active,
                ));
                if (r.ok) {
                  Navigator.pop(ctx);
                } else {
                  setState(() => error = r.message);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      }),
    );
  }
}

class _RecipesTab extends StatelessWidget {
  final InventoryState state;
  const _RecipesTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final sorted = [...state.recipes]..sort((a, b) => a.productName.compareTo(b.productName));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editRecipe(context, null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة وصفة'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
        const Text('الكميات لكل قطعة واحدة من الصنف بالحجم المحدد (بالجرام، أو بعدد القطع). التغيير يسري من الشيفت القادم.'),
        const SizedBox(height: 6),
        ..._missing(context),
        for (final r in sorted)
          Card(
            child: ListTile(
              title: Text('${r.productName} (${r.size})'),
              subtitle: Text([
                for (final e in r.lines.entries)
                  '${state.ingredient(e.key)?.name ?? e.key}: ${formatQty(e.value, state.ingredient(e.key)?.unit ?? '')}',
              ].join('  |  ')),
              trailing: const Icon(Icons.edit),
              onTap: () => _editRecipe(context, r),
            ),
          ),
      ]),
    );
  }

  /// Items in recipe-tracked categories that have no recipe for some size.
  List<Widget> _missing(BuildContext context) {
    final missing = <(String, String)>[];
    for (final c in const MenuRepository().categories) {
      final items = [...?c.items, for (final s in c.subcategories ?? const <MenuSubcategory>[]) ...s.items];
      final tracked = items.any((it) => it.prices.keys.any((sz) => state.recipeFor(it.name, sz) != null));
      if (!tracked) continue;
      for (final it in items) {
        for (final sz in it.prices.keys) {
          if (state.recipeFor(it.name, sz) == null) missing.add((it.name, sz));
        }
      }
    }
    if (missing.isEmpty) return const [];
    return [
      Card(
        color: const Color(0xFFFFF6E5),
        child: ExpansionTile(
          leading: const Icon(Icons.warning_amber, color: AppColors.warning),
          title: Text('${missing.length} صنف/حجم بدون وصفة - لا يستهلك أي مخزون'),
          children: [
            for (final m in missing)
              ListTile(
                dense: true,
                title: Text('${m.$1} (${m.$2})'),
                trailing: const Text('إضافة وصفة', style: TextStyle(color: AppColors.info)),
                onTap: () => _editRecipe(context, null, presetProduct: m.$1, presetSize: m.$2),
              ),
          ],
        ),
      ),
    ];
  }

  Future<void> _editRecipe(BuildContext context, Recipe? existing, {String? presetProduct, String? presetSize}) async {
    final cubit = context.read<InventoryCubit>();
    final catalog = <String, List<String>>{};
    for (final c in const MenuRepository().categories) {
      for (final it in [...?c.items, for (final s in c.subcategories ?? const <MenuSubcategory>[]) ...s.items]) {
        catalog[it.name] = it.prices.keys.toList();
      }
    }
    final ingredients = cubit.state.ingredients;
    var product = existing?.productName ?? presetProduct ?? catalog.keys.first;
    var size = existing?.size ?? presetSize ?? catalog[product]!.first;
    final lines = <String, TextEditingController>{
      for (final e in (existing?.lines ?? const <String, int>{}).entries)
        e.key: TextEditingController(text: formatMilli(e.value)),
    };
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        final sizes = catalog[product] ?? [size];
        return AlertDialog(
          title: Text(existing == null ? 'إضافة وصفة' : 'تعديل الوصفة'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (existing == null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: product,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الصنف'),
                    items: [for (final p in catalog.keys) DropdownMenuItem(value: p, child: Text(p))],
                    onChanged: (v) => setState(() {
                      product = v!;
                      size = catalog[product]!.first;
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(product),
                    initialValue: sizes.contains(size) ? size : sizes.first,
                    decoration: const InputDecoration(labelText: 'الحجم'),
                    items: [for (final s in sizes) DropdownMenuItem(value: s, child: Text(s))],
                    onChanged: (v) => setState(() => size = v!),
                  ),
                ] else
                  Text('${existing.productName} (${existing.size})', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                for (final ing in ingredients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TextField(
                      controller: lines.putIfAbsent(ing.id, () => TextEditingController(text: '')),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${ing.name} (${ing.unit}) - اتركه فارغاً لعدم الاستهلاك',
                        isDense: true,
                      ),
                    ),
                  ),
                if (error != null) Text(error!, style: const TextStyle(color: AppColors.primaryDark)),
              ]),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  cubit.deleteRecipe(existing.key);
                  Navigator.pop(ctx);
                },
                child: const Text('حذف', style: TextStyle(color: AppColors.primaryDark)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final result = <String, int>{};
                for (final e in lines.entries) {
                  final t = e.value.text.trim();
                  if (t.isEmpty) continue;
                  final v = parseMilli(t);
                  if (v == null || v == 0) {
                    setState(() => error = 'كمية غير صحيحة (يجب أن تكون أكبر من صفر).');
                    return;
                  }
                  result[e.key] = v;
                }
                final r = cubit.saveRecipe(Recipe(
                  productName: existing?.productName ?? product,
                  size: existing?.size ?? size,
                  lines: result,
                ));
                if (r.ok) {
                  Navigator.pop(ctx);
                } else {
                  setState(() => error = r.message);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      }),
    );
  }
}
