import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/default_recipes.dart';
import '../../data/local_storage_service.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/inventory/ingredient.dart';
import '../../data/models/inventory/inventory_shift.dart';
import '../../data/models/inventory/recipe.dart';
import '../../data/models/inventory/stock_movement.dart';
import '../../core/quantity.dart';
import 'inventory_state.dart';

/// Outcome of an inventory operation. [message] is always user-facing Arabic.
class InventoryResult {
  final bool ok;
  final String message;

  /// Ingredients that were short (only set for shortage failures), so the UI
  /// can offer to add bags for exactly those.
  final List<String> shortIds;
  const InventoryResult.ok([this.message = '']) : ok = true, shortIds = const [];
  const InventoryResult.fail(this.message, {this.shortIds = const []}) : ok = false;
}

/// Stored-schema version. Bump and extend [_migrate] for later changes.
const int kInventorySchemaVersion = 1;

/// All inventory business rules live here (never in widgets). Every public
/// mutation validates first and applies second, in one synchronous step, so a
/// rejected operation leaves no partial movements behind and two operations
/// can never interleave.
class InventoryCubit extends Cubit<InventoryState> {
  final LocalStorageService _storage;

  InventoryCubit(this._storage) : super(InventoryState.initial) {
    _load();
  }

  // ───────────────────────── persistence ─────────────────────────

  Future<void> _load() async {
    final raw = await _storage.loadInventory();
    if (raw == null || raw.isEmpty) {
      // First run: seed ingredients + initial recipes.
      emit(InventoryState(
        ingredients: InventorySeed.ingredients(),
        recipes: InventorySeed.recipes(),
        shifts: const [],
        nextShiftId: 1,
        nextMovementId: 1,
        isLoading: false,
      ));
      _persist();
      return;
    }
    final json = _migrate(jsonDecode(raw) as Map<String, dynamic>);
    emit(InventoryState(
      ingredients: (json['ingredients'] as List)
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      recipes: (json['recipes'] as List)
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
          .toList(),
      shifts: (json['shifts'] as List)
          .map((e) => InventoryShift.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextShiftId: json['nextShiftId'] as int,
      nextMovementId: json['nextMovementId'] as int,
      managerPin: json['managerPin'] as String?,
      isLoading: false,
    ));
  }

  Map<String, dynamic> _migrate(Map<String, dynamic> json) {
    // v1 is the first schema; future versions transform [json] here.
    return json;
  }

  void _persist() {
    final s = state;
    _storage.saveInventory(jsonEncode({
      'version': kInventorySchemaVersion,
      'ingredients': s.ingredients.map((e) => e.toJson()).toList(),
      'recipes': s.recipes.map((e) => e.toJson()).toList(),
      'shifts': s.shifts.map((e) => e.toJson()).toList(),
      'nextShiftId': s.nextShiftId,
      'nextMovementId': s.nextMovementId,
      'managerPin': s.managerPin,
    }));
  }

  /// Bumps the revision and saves. Called after every successful mutation.
  void _commit({int? nextMovementId, int? nextShiftId, List<InventoryShift>? shifts}) {
    emit(state.copyWith(
      nextMovementId: nextMovementId,
      nextShiftId: nextShiftId,
      shifts: shifts ?? List.of(state.shifts),
    ));
    _persist();
  }

  // ───────────────────────── ledger primitive ─────────────────────────

  int _movementSeq = 0;

  StockMovement _post(
    InventoryShift shift, {
    required String ingredientId,
    required MovementType type,
    required int delta,
    required String employee,
    required String refKey,
    int? orderId,
    String note = '',
  }) {
    final meta = shift.meta[ingredientId]!;
    final before = shift.balanceOf(ingredientId);
    final mv = StockMovement(
      id: state.nextMovementId + _movementSeq++,
      shiftId: shift.id,
      ingredientId: ingredientId,
      type: type,
      delta: delta,
      before: before,
      after: before + delta,
      unit: meta.unit,
      orderId: orderId,
      employee: employee,
      time: DateTime.now(),
      note: note,
      refKey: refKey,
    );
    shift.movements.add(mv);
    shift.refKeys.add(refKey);
    return mv;
  }

  void _finish() {
    final next = state.nextMovementId + _movementSeq;
    _movementSeq = 0;
    _commit(nextMovementId: next);
  }

  // ───────────────────────── opening a shift ─────────────────────────

  /// [bags] maps ingredientId -> number of bags issued to the kitchen.
  /// [requestKey] makes a repeated submission (double tap) a no-op.
  InventoryResult openShift({
    required Map<String, int> bags,
    required String employee,
    String? requestKey,
  }) {
    if (state.activeShift != null) {
      return const InventoryResult.fail('يوجد شيفت مفتوح بالفعل. أغلقه أولاً.');
    }
    if (employee.trim().isEmpty) {
      return const InventoryResult.fail('يجب تحديد اسم الكاشير أولاً.');
    }
    for (final e in bags.entries) {
      final ing = state.ingredient(e.key);
      if (ing == null || !ing.active) {
        return const InventoryResult.fail('مكوّن غير معروف أو غير مفعّل.');
      }
      if (e.value < 0) return const InventoryResult.fail('لا يمكن إدخال كمية سالبة.');
      if (e.value > 0 && ing.bagCapacity <= 0) {
        return InventoryResult.fail('سعة الكيس غير محددة للمكوّن "${ing.name}". حدّدها من إعدادات البرسلة.');
      }
    }

    final active = state.ingredients.where((i) => i.active).toList();
    final shift = InventoryShift(
      id: state.nextShiftId,
      openedAt: DateTime.now(),
      openedBy: employee,
      openingBags: {for (final i in active) i.id: bags[i.id] ?? 0},
      meta: {for (final i in active) i.id: IngredientMeta.of(i)},
      recipes: {for (final r in state.recipes) r.key: Map<String, int>.of(r.lines)},
    );
    for (final i in active) {
      final count = bags[i.id] ?? 0;
      if (count == 0) continue;
      _post(shift,
          ingredientId: i.id,
          type: MovementType.opening,
          delta: count * i.bagCapacity,
          employee: employee,
          refKey: 'open:${shift.id}:${i.id}',
          note: '$count كيس');
    }
    final next = state.nextMovementId + _movementSeq;
    _movementSeq = 0;
    _commit(
      nextMovementId: next,
      nextShiftId: shift.id + 1,
      shifts: [...state.shifts, shift],
    );
    return const InventoryResult.ok('تم فتح الشيفت وتسجيل رصيد البداية.');
  }

  // ───────────────────────── adding bags ─────────────────────────

  InventoryResult addStock({
    required String ingredientId,
    required int bags,
    required String employee,
    required String requestKey,
    String note = '',
  }) {
    final shift = state.activeShift;
    if (shift == null) return const InventoryResult.fail('لا يوجد شيفت مفتوح.');
    final ing = state.ingredient(ingredientId);
    if (ing == null || !ing.active) return const InventoryResult.fail('اختر مكوّناً صحيحاً.');
    if (bags <= 0) return const InventoryResult.fail('أدخل عدد أكياس أكبر من صفر.');
    final refKey = 'add:${shift.id}:$requestKey';
    if (shift.refKeys.contains(refKey)) {
      return const InventoryResult.fail('تمت إضافة هذه الدفعة بالفعل.');
    }
    // A capacity that was "not set" when the shift opened may be filled in
    // from the current settings; a capacity that was set stays frozen.
    final frozen = shift.meta[ingredientId];
    if (frozen == null || frozen.bagCapacity <= 0) shift.meta[ingredientId] = IngredientMeta.of(ing);
    final meta = shift.meta[ingredientId]!;
    if (meta.bagCapacity <= 0) {
      return InventoryResult.fail('سعة الكيس غير محددة للمكوّن "${ing.name}". حدّدها من إعدادات البرسلة.');
    }
    _post(shift,
        ingredientId: ingredientId,
        type: MovementType.addition,
        delta: bags * meta.bagCapacity,
        employee: employee,
        refKey: refKey,
        note: note.trim().isEmpty ? '$bags كيس' : '$bags كيس - ${note.trim()}');
    _finish();
    return InventoryResult.ok('تمت إضافة ${formatQty(bags * meta.bagCapacity, meta.unit)}.');
  }

  // ───────────────────────── order consumption ─────────────────────────

  /// Per-ingredient total for a set of order lines, honouring frozen per-unit
  /// recipes of lines that were already consumed (so recipe edits don't
  /// distort edits of existing orders).
  Map<String, LineConsumption> _linesFor(
    InventoryShift shift,
    int orderId,
    List<CartItem> items,
  ) {
    final previous = shift.orderConsumption[orderId] ?? const {};
    final qtyByKey = <String, int>{};
    final recipeByKey = <String, Map<String, int>?>{};
    for (final item in items) {
      qtyByKey[item.key] = (qtyByKey[item.key] ?? 0) + item.qty;
      recipeByKey.putIfAbsent(item.key, () => _recipeLines(shift, item.name, item.size));
    }
    final result = <String, LineConsumption>{};
    qtyByKey.forEach((key, qty) {
      Map<String, int> perUnit;
      if (previous.containsKey(key)) {
        perUnit = previous[key]!.perUnit;
      } else {
        perUnit = {
          for (final e in (recipeByKey[key] ?? const <String, int>{}).entries)
            if (state.ingredient(e.key)?.active ?? false) e.key: e.value,
        };
      }
      if (perUnit.isNotEmpty) result[key] = LineConsumption(qty: qty, perUnit: perUnit);
    });
    return result;
  }

  /// Recipe in force for [shift]: its frozen snapshot, else the live recipes.
  Map<String, int>? _recipeLines(InventoryShift? shift, String name, String size) {
    final snapshot = shift?.recipes;
    if (snapshot != null) return snapshot[recipeKey(name, size)];
    return state.recipeFor(name, size)?.lines;
  }

  /// Whether selling [name] in [size] deducts any stock (used for warnings).
  bool hasRecipe(String name, String size) {
    final lines = _recipeLines(state.activeShift, name, size);
    return lines != null && lines.isNotEmpty;
  }

  Map<String, int> _totals(Map<String, LineConsumption> lines) {
    final totals = <String, int>{};
    for (final l in lines.values) {
      l.perUnit.forEach((ing, q) => totals[ing] = (totals[ing] ?? 0) + q * l.qty);
    }
    return totals;
  }

  /// Brings the stock recorded for [orderId] in line with [items]:
  /// first call consumes, later calls apply only the difference, and an empty
  /// list (cancel/delete) reverses everything. Calling it again with the same
  /// items is a no-op, so retries can never double-deduct.
  ///
  /// Orders that don't belong to the active inventory shift are ignored, so a
  /// closed shift can never be modified by order operations.
  InventoryResult syncOrder({
    required int orderId,
    required int? orderShiftId,
    required List<CartItem> items,
    required String employee,
  }) {
    final shift = state.activeShift;
    if (shift == null || orderShiftId != shift.id) return const InventoryResult.ok();

    final newLines = _linesFor(shift, orderId, items);
    final wanted = _totals(newLines);
    final current = _totals(shift.orderConsumption[orderId] ?? const {});

    // Validate everything before touching the ledger.
    final shortages = <String>[];
    final shortIds = <String>[];
    final diffs = <String, int>{};
    for (final id in {...wanted.keys, ...current.keys}) {
      final diff = (wanted[id] ?? 0) - (current[id] ?? 0);
      if (diff == 0) continue;
      diffs[id] = diff;
      if (diff > 0) {
        final balance = shift.balanceOf(id);
        if (balance < diff) {
          shortIds.add(id);
          final meta = shift.meta[id] ?? IngredientMeta.of(state.ingredient(id)!);
          shortages.add('${meta.name} (المتاح ${formatQty(balance, meta.unit)}، المطلوب ${formatQty(diff, meta.unit)})');
        }
      }
    }
    if (shortages.isNotEmpty) {
      return InventoryResult.fail(
          'المخزون غير كافٍ: ${shortages.join('، ')}. أضف أكياس ثم أعد المحاولة.',
          shortIds: shortIds);
    }
    if (diffs.isEmpty && !shift.orderConsumption.containsKey(orderId) && newLines.isEmpty) {
      return const InventoryResult.ok();
    }

    for (final e in diffs.entries) {
      shift.meta.putIfAbsent(e.key, () => IngredientMeta.of(state.ingredient(e.key)!));
      final seq = shift.movements.where((m) => m.orderId == orderId && m.ingredientId == e.key).length;
      _post(shift,
          ingredientId: e.key,
          type: e.value > 0 ? MovementType.orderConsumption : MovementType.orderReversal,
          delta: -e.value,
          employee: employee,
          orderId: orderId,
          refKey: 'order:${shift.id}:$orderId:${e.key}:$seq',
          note: 'أوردر #$orderId');
    }
    if (newLines.isEmpty) {
      shift.orderConsumption.remove(orderId);
    } else {
      shift.orderConsumption[orderId] = newLines;
    }
    if (diffs.isNotEmpty) {
      _finish();
    } else {
      _commit();
    }
    return const InventoryResult.ok();
  }

  /// Dry-run of [syncOrder] used by the UI to warn before committing.
  Map<String, int> previewRequirements(int orderId, List<CartItem> items) {
    final shift = state.activeShift;
    if (shift == null) return {};
    return _totals(_linesFor(shift, orderId, items));
  }

  // ───────────────────────── closing ─────────────────────────

  /// Expected remaining quantity per ingredient (before any physical count).
  Map<String, int> expectedRemaining() {
    final shift = state.activeShift;
    if (shift == null) return {};
    return {for (final id in shift.meta.keys) id: shift.balanceOf(id)};
  }

  /// [actualCounts]: optional physical count (milli units) per ingredient.
  /// A difference needs a non-empty entry in [reasons].
  InventoryResult closeShift({
    required String employee,
    Map<String, int> actualCounts = const {},
    Map<String, String> reasons = const {},
  }) {
    final shift = state.activeShift;
    if (shift == null) return const InventoryResult.fail('لا يوجد شيفت مفتوح للإغلاق.');
    for (final e in actualCounts.entries) {
      if (!shift.meta.containsKey(e.key)) return const InventoryResult.fail('مكوّن غير معروف.');
      if (e.value < 0) return const InventoryResult.fail('لا يمكن إدخال كمية سالبة.');
      final diff = e.value - shift.balanceOf(e.key);
      if (diff != 0 && (reasons[e.key] ?? '').trim().isEmpty) {
        return InventoryResult.fail('اكتب سبب الفرق في ${shift.meta[e.key]!.name}.');
      }
    }

    final rows = <ClosingRow>[];
    for (final entry in shift.meta.entries) {
      final id = entry.key;
      final meta = entry.value;
      final expected = shift.balanceOf(id);
      final actual = actualCounts[id];
      final diff = actual == null ? 0 : actual - expected;
      final reason = (reasons[id] ?? '').trim();
      final adjustmentsBefore = shift.adjustmentsOf(id);
      if (diff != 0) {
        _post(shift,
            ingredientId: id,
            type: MovementType.adjustment,
            delta: diff,
            employee: employee,
            refKey: 'closecount:${shift.id}:$id',
            note: 'فرق الجرد الفعلي: $reason');
      }
      rows.add(ClosingRow(
        ingredientId: id,
        name: meta.name,
        unit: meta.unit,
        bagCapacity: meta.bagCapacity,
        openingBags: shift.openingBags[id] ?? 0,
        opening: shift.openingOf(id),
        added: shift.addedOf(id),
        consumed: shift.consumedOf(id),
        reversed: shift.reversedOf(id),
        adjustments: adjustmentsBefore,
        expected: expected,
        actual: actual,
        difference: diff,
        reason: reason,
        remaining: shift.balanceOf(id),
      ));
      _post(shift,
          ingredientId: id,
          type: MovementType.closing,
          delta: 0,
          employee: employee,
          refKey: 'close:${shift.id}:$id',
          note: 'إغلاق الشيفت');
    }
    shift.closingRows = rows;
    shift.closedAt = DateTime.now();
    shift.closedBy = employee;
    _finish();
    return const InventoryResult.ok('تم إغلاق الشيفت وحفظ تقرير المخزون.');
  }

  // ───────────────────────── manager permission ─────────────────────────

  bool get hasManagerPin => (state.managerPin ?? '').isNotEmpty;

  InventoryResult unlockManager(String pin) {
    if (!hasManagerPin) return const InventoryResult.fail('لم يتم تعيين رمز المدير بعد.');
    if (pin != state.managerPin) return const InventoryResult.fail('رمز المدير غير صحيح.');
    emit(state.copyWith(managerUnlocked: true));
    return const InventoryResult.ok();
  }

  /// First-time setup is open; changing an existing PIN requires an unlocked
  /// manager session.
  InventoryResult setManagerPin(String pin) {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      return const InventoryResult.fail('الرمز يجب أن يكون من 4 إلى 8 أرقام.');
    }
    if (hasManagerPin && !state.managerUnlocked) return _denied;
    emit(state.copyWith(managerPin: pin, managerUnlocked: true));
    _persist();
    return const InventoryResult.ok('تم حفظ رمز المدير.');
  }

  void lockManager() {
    if (state.managerUnlocked) emit(state.copyWith(managerUnlocked: false));
  }

  static const _denied = InventoryResult.fail('هذه العملية تتطلب صلاحية المدير.');

  // ───────────────────────── configuration (manager only) ─────────────────────────

  InventoryResult saveIngredient(Ingredient ingredient) {
    if (!state.managerUnlocked) return _denied;
    if (ingredient.name.trim().isEmpty) return const InventoryResult.fail('اسم المكوّن مطلوب.');
    if (ingredient.unit.trim().isEmpty) return const InventoryResult.fail('وحدة القياس مطلوبة.');
    if (ingredient.bagCapacity <= 0) {
      return const InventoryResult.fail('سعة الكيس يجب أن تكون أكبر من صفر.');
    }
    if ((ingredient.minStock ?? 0) < 0) return const InventoryResult.fail('الحد الأدنى لا يمكن أن يكون سالباً.');
    final list = [...state.ingredients];
    final i = list.indexWhere((e) => e.id == ingredient.id);
    if (i >= 0) {
      list[i] = ingredient;
    } else {
      list.add(ingredient);
    }
    emit(state.copyWith(ingredients: list));
    _persist();
    return const InventoryResult.ok('تم حفظ المكوّن.');
  }

  String newIngredientId() => 'ing_${DateTime.now().microsecondsSinceEpoch}';

  InventoryResult saveRecipe(Recipe recipe) {
    if (!state.managerUnlocked) return _denied;
    if (recipe.productName.trim().isEmpty || recipe.size.trim().isEmpty) {
      return const InventoryResult.fail('اسم الصنف والحجم مطلوبان.');
    }
    if (recipe.lines.values.any((q) => q <= 0)) {
      return const InventoryResult.fail('كل كمية يجب أن تكون أكبر من صفر.');
    }
    if (recipe.lines.keys.any((id) => state.ingredient(id) == null)) {
      return const InventoryResult.fail('مكوّن غير معروف في الوصفة.');
    }
    final list = [...state.recipes];
    final i = list.indexWhere((r) => r.key == recipe.key);
    if (i >= 0) {
      list[i] = recipe;
    } else {
      list.add(recipe);
    }
    emit(state.copyWith(recipes: list));
    _persist();
    return const InventoryResult.ok('تم حفظ الوصفة.');
  }

  InventoryResult deleteRecipe(String key) {
    if (!state.managerUnlocked) return _denied;
    emit(state.copyWith(recipes: state.recipes.where((r) => r.key != key).toList()));
    _persist();
    return const InventoryResult.ok('تم حذف الوصفة.');
  }

  // ───────────────────────── adjustments (manager only) ─────────────────────────

  /// Manual adjustment of an open shift, or a correction of a closed shift
  /// (the closing snapshot is never rewritten — corrections are new entries).
  InventoryResult adjustStock({
    required int shiftId,
    required String ingredientId,
    required int delta,
    required String reason,
    required String employee,
  }) {
    if (!state.managerUnlocked) return _denied;
    final matches = state.shifts.where((s) => s.id == shiftId);
    if (matches.isEmpty) return const InventoryResult.fail('الشيفت غير موجود.');
    final shift = matches.first;
    if (!shift.meta.containsKey(ingredientId)) return const InventoryResult.fail('مكوّن غير موجود في هذا الشيفت.');
    if (delta == 0) return const InventoryResult.fail('أدخل كمية التسوية.');
    if (reason.trim().isEmpty) return const InventoryResult.fail('سبب التسوية مطلوب.');
    if (shift.balanceOf(ingredientId) + delta < 0) {
      return const InventoryResult.fail('التسوية ستجعل المخزون سالباً.');
    }
    _post(shift,
        ingredientId: ingredientId,
        type: shift.isOpen ? MovementType.adjustment : MovementType.correction,
        delta: delta,
        employee: employee,
        refKey: 'adj:${shift.id}:${state.nextMovementId + _movementSeq}',
        note: reason.trim());
    _finish();
    return const InventoryResult.ok('تم تسجيل التسوية.');
  }
}
