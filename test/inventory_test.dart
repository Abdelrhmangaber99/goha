import 'package:casher_goha/core/quantity.dart';
import 'package:casher_goha/data/default_recipes.dart';
import 'package:casher_goha/data/local_storage_service.dart';
import 'package:casher_goha/data/models/cart_item.dart';
import 'package:casher_goha/data/models/inventory/recipe.dart';
import 'package:casher_goha/data/models/inventory/stock_movement.dart';
import 'package:casher_goha/data/models/order.dart';
import 'package:casher_goha/logic/cart/cart_cubit.dart';
import 'package:casher_goha/logic/inventory/inventory_cubit.dart';
import 'package:casher_goha/logic/shift/shift_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bas = InventorySeed.basturma;
const sau = InventorySeed.sausage;
const chk = InventorySeed.chicken;
const pcs = InventorySeed.sausagePieces;
const moz = InventorySeed.mozzarella;

CartItem item(String name, String size, int qty) => CartItem(
      key: buildCartKey(name, size),
      name: name,
      size: size,
      price: 100,
      qty: qty,
      category: 'x',
    );

int g(num v) => milli(v);

/// Bag capacities are not seeded; a manager enters them in settings.
const capacities = {bas: 500, sau: 500, chk: 500, 'minced_meat': 500, pcs: 20, moz: 1000};

void configure(InventoryCubit inv) {
  expect(inv.setManagerPin('1234').ok, isTrue);
  capacities.forEach((id, cap) {
    expect(inv.saveIngredient(inv.state.ingredient(id)!.copyWith(bagCapacity: g(cap))).ok, isTrue);
  });
  inv.lockManager();
}

Future<(InventoryCubit, ShiftCubit)> make({Map<String, Object> prefs = const {}, bool setup = true}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = LocalStorageService();
  final inv = InventoryCubit(storage);
  while (inv.state.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
  if (setup) configure(inv);
  final shift = ShiftCubit(storage, inv);
  while (shift.state.isLoading) {
    await Future<void>.delayed(Duration.zero);
  }
  return (inv, shift);
}

/// Opens a shift with plenty of everything unless overridden.
InventoryResult open(InventoryCubit inv, {Map<String, int>? bags}) => inv.openShift(
      bags: bags ?? {bas: 4, sau: 4, chk: 4, 'minced_meat': 4, pcs: 4, moz: 4},
      employee: 'أحمد',
    );

int bal(InventoryCubit inv, String id) => inv.state.activeShift!.balanceOf(id);

void main() {
  group('opening & bag conversion', () {
    test('seeds ingredients and recipes on first run', () async {
      final (inv, _) = await make();
      expect(inv.state.ingredients.length, 6);
      expect(inv.state.recipeFor('بيتزا بسطرمة', 'صغير')!.lines, {bas: g(25), moz: g(100)});
      expect(inv.state.recipeFor('فطيرة سجق', 'كبير')!.lines, {sau: g(200), moz: g(160)});
    });

    test('1. opening with several bags + 2. bags convert to quantity', () async {
      final (inv, _) = await make();
      expect(open(inv).ok, isTrue);
      expect(bal(inv, bas), g(2000)); // 4 x 500 g
      expect(bal(inv, moz), g(4000)); // 4 x 1000 g
      expect(bal(inv, pcs), g(80)); // 4 x 20 pieces
      expect(inv.state.activeShift!.openingBags[bas], 4);
    });

    test('zero stock allowed; negative rejected', () async {
      final (inv, _) = await make();
      expect(inv.openShift(bags: {bas: -1}, employee: 'أ').ok, isFalse);
      expect(inv.state.activeShift, isNull);
      expect(inv.openShift(bags: {bas: 0}, employee: 'أ').ok, isTrue);
      expect(bal(inv, bas), 0);
    });

    test('15. second opening is rejected while a shift is active', () async {
      final (inv, _) = await make();
      expect(open(inv).ok, isTrue);
      expect(open(inv).ok, isFalse);
      expect(inv.state.shifts.length, 1);
    });
  });

  group('consumption', () {
    test('3/5. single small basturma pizza: basturma + mozzarella only', () async {
      final (inv, shift) = await make();
      open(inv);
      final r = shift.checkout(
          items: [item('بيتزا بسطرمة', 'صغير', 1)], type: OrderType.restaurant, cashierName: 'أ');
      expect(r.ok, isTrue);
      expect(bal(inv, bas), g(2000 - 25));
      expect(bal(inv, moz), g(4000 - 100));
      expect(bal(inv, sau), g(2000));
      expect(bal(inv, chk), g(2000));
      expect(bal(inv, 'minced_meat'), g(2000));
    });

    test('4/7. mixed order from the spec example', () async {
      final (inv, shift) = await make();
      open(inv);
      shift.checkout(items: [
        item('بيتزا بسطرمة', 'صغير', 2),
        item('بيتزا فراخ صدور', 'كبير', 1),
        item('بيتزا سجق', 'وسط', 3),
      ], type: OrderType.restaurant, cashierName: 'أ');
      expect(bal(inv, bas), g(2000 - 50));
      expect(bal(inv, chk), g(2000 - 160));
      expect(bal(inv, sau), g(2000 - 300));
      expect(bal(inv, moz), g(4000 - 725));
    });

    test('5. pies consume meat + mozzarella', () async {
      final (inv, shift) = await make();
      open(inv);
      shift.checkout(
          items: [item('فطيرة فراخ', 'كبير', 1), item('فطيرة بسطرمة', 'وسط', 2)],
          type: OrderType.goha,
          cashierName: 'أ');
      expect(bal(inv, chk), g(2000 - 200));
      expect(bal(inv, bas), g(2000 - 100));
      expect(bal(inv, moz), g(4000 - 160 - 250));
    });

    test('6. sausage pieces incl. 1.5 stay in pieces', () async {
      final (inv, shift) = await make();
      open(inv);
      shift.checkout(
          items: [item('بيتزا سوسيس', 'صغير', 1), item('بيتزا سوسيس', 'وسط', 1), item('بيتزا سوسيس', 'كبير', 1)],
          type: OrderType.restaurant,
          cashierName: 'أ');
      expect(bal(inv, pcs), g(80 - 4.5));
      expect(formatMilli(bal(inv, pcs)), '75.5');
    });

    test('items without a recipe consume nothing and still sell', () async {
      final (inv, shift) = await make();
      open(inv);
      expect(shift.checkout(items: [item('فرخة كاملة', 'وجبة', 2)], type: OrderType.restaurant, cashierName: 'أ').ok, isTrue);
      expect(inv.state.activeShift!.movements.where((m) => m.type == MovementType.orderConsumption), isEmpty);
    });

    test('1. no open shift: order is blocked, nothing is registered', () async {
      final (inv, shift) = await make();
      final r = shift.checkout(items: [item('بيتزا بسطرمة', 'صغير', 1)], type: OrderType.restaurant, cashierName: 'أ');
      expect(r.ok, isFalse);
      expect(r.needsShift, isTrue);
      expect(r.error, 'افتح الشيفت أولاً');
      expect(shift.state.orders, isEmpty);
      expect(shift.state.orderCounter, 1);
      expect(inv.state.shifts, isEmpty);
      // once a shift is open the very same order goes through
      open(inv);
      expect(shift.checkout(items: [item('بيتزا بسطرمة', 'صغير', 1)], type: OrderType.restaurant, cashierName: 'أ').ok, isTrue);
    });
  });

  group('additions & remaining', () {
    test('8/9. extra bags + remaining after several orders', () async {
      final (inv, shift) = await make();
      open(inv, bags: {bas: 1, moz: 1});
      shift.checkout(items: [item('بيتزا بسطرمة', 'كبير', 2)], type: OrderType.restaurant, cashierName: 'أ');
      expect(bal(inv, bas), g(400));
      final add = inv.addStock(ingredientId: bas, bags: 2, employee: 'أ', requestKey: 'k1', note: 'من المخزن');
      expect(add.ok, isTrue);
      expect(bal(inv, bas), g(1400));
      shift.checkout(items: [item('بيتزا بسطرمة', 'وسط', 1)], type: OrderType.restaurant, cashierName: 'أ');
      expect(bal(inv, bas), g(1365));
      final s = inv.state.activeShift!;
      expect(s.openingOf(bas), g(500));
      expect(s.addedOf(bas), g(1000));
      expect(s.consumedOf(bas), g(135));
      final b = bagBreakdown(bal(inv, bas), g(500));
      expect((b.fullBags, b.looseMilli), (2, g(365)));
    });

    test('a deliberate second addition of the same amount is recorded (new request key)', () async {
      final (inv, _) = await make();
      open(inv, bags: {bas: 1});
      expect(inv.addStock(ingredientId: bas, bags: 2, employee: 'أ', requestKey: 'first').ok, isTrue);
      expect(inv.addStock(ingredientId: bas, bags: 2, employee: 'أ', requestKey: 'second').ok, isTrue);
      expect(inv.addStock(ingredientId: bas, bags: 2, employee: 'أ', requestKey: 'second').ok, isFalse); // accidental repeat
      final adds = inv.state.activeShift!.movements.where((m) => m.type == MovementType.addition).toList();
      expect(adds.length, 2);
      expect(bal(inv, bas), g(500 + 2000));
    });

    test('duplicate submission of the same addition is rejected', () async {
      final (inv, _) = await make();
      open(inv, bags: {bas: 1});
      expect(inv.addStock(ingredientId: bas, bags: 1, employee: 'أ', requestKey: 'same').ok, isTrue);
      expect(inv.addStock(ingredientId: bas, bags: 1, employee: 'أ', requestKey: 'same').ok, isFalse);
      expect(bal(inv, bas), g(1000));
    });

    test('addition validates bags and shift state', () async {
      final (inv, _) = await make();
      expect(inv.addStock(ingredientId: bas, bags: 1, employee: 'أ', requestKey: 'a').ok, isFalse);
      open(inv);
      expect(inv.addStock(ingredientId: bas, bags: 0, employee: 'أ', requestKey: 'b').ok, isFalse);
      expect(inv.addStock(ingredientId: bas, bags: -2, employee: 'أ', requestKey: 'c').ok, isFalse);
    });
  });

  group('order lifecycle', () {
    test('10. cancelling reverses consumption (history kept)', () async {
      final (inv, shift) = await make();
      open(inv);
      final id = shift.checkout(items: [item('بيتزا سجق', 'وسط', 2)], type: OrderType.restaurant, cashierName: 'أ').orderId!;
      expect(bal(inv, sau), g(1800));
      shift.cancelOrder(id);
      expect(bal(inv, sau), g(2000));
      expect(bal(inv, moz), g(4000));
      final types = inv.state.activeShift!.movements.map((m) => m.type);
      expect(types, containsAll([MovementType.orderConsumption, MovementType.orderReversal]));
    });

    test('11. retrying the same order sync never double-deducts', () async {
      final (inv, shift) = await make();
      open(inv);
      final items = [item('بيتزا سجق', 'صغير', 1)];
      final id = shift.checkout(items: items, type: OrderType.restaurant, cashierName: 'أ').orderId!;
      final sid = shift.state.orders.single.inventoryShiftId;
      for (var i = 0; i < 3; i++) {
        inv.syncOrder(orderId: id, orderShiftId: sid, items: items, employee: 'أ');
      }
      expect(bal(inv, sau), g(1930));
      expect(inv.state.activeShift!.movements.where((m) => m.type == MovementType.orderConsumption).length, 2);
    });

    test('12. editing a consumed order applies only the difference', () async {
      final (inv, shift) = await make();
      open(inv);
      final id = shift.checkout(items: [item('بيتزا سجق', 'وسط', 2)], type: OrderType.restaurant, cashierName: 'أ').orderId!;
      expect(bal(inv, sau), g(1800));
      shift.updateOrderItemQty(id, 0, 1); // 3
      expect(bal(inv, sau), g(1700));
      expect(bal(inv, moz), g(4000 - 375));
      shift.updateOrderItemQty(id, 0, -2); // 1
      expect(bal(inv, sau), g(1900));
      shift.removeItemFromOrder(id, 0); // order removed
      expect(bal(inv, sau), g(2000));
      expect(shift.state.orders, isEmpty);
    });

    test('editing after a recipe change uses the frozen original recipe', () async {
      final (inv, shift) = await make();
      open(inv);
      final id = shift.checkout(items: [item('بيتزا سجق', 'وسط', 1)], type: OrderType.restaurant, cashierName: 'أ').orderId!;
      inv.unlockManager('1234');
      inv.saveRecipe(Recipe(productName: 'بيتزا سجق', size: 'وسط', lines: {sau: g(999), moz: g(1)}));
      shift.cancelOrder(id);
      expect(bal(inv, sau), g(2000));
      expect(bal(inv, moz), g(4000));
    });

    test('13/14. insufficient stock blocks checkout and edits, never negative', () async {
      final (inv, shift) = await make();
      open(inv, bags: {bas: 1, moz: 2}); // 500 g basturma, 2000 g mozzarella
      final r = shift.checkout(items: [item('بيتزا بسطرمة', 'كبير', 11)], type: OrderType.restaurant, cashierName: 'أ');
      expect(r.ok, isFalse);
      expect(r.error, contains('المخزون غير كافٍ'));
      expect(shift.state.orders, isEmpty);
      expect(shift.state.orderCounter, 1);
      expect(bal(inv, bas), g(500));
      // exactly fits: 10 x 50 g
      final ok = shift.checkout(items: [item('بيتزا بسطرمة', 'كبير', 10)], type: OrderType.restaurant, cashierName: 'أ');
      expect(ok.ok, isTrue);
      expect(bal(inv, bas), 0);
      final edit = shift.updateOrderItemQty(ok.orderId!, 0, 1);
      expect(edit.ok, isFalse);
      expect(shift.state.orders.single.items.single.qty, 10);
      expect(bal(inv, bas), 0);
    });

    test('19. failed multi-ingredient op leaves no partial deduction', () async {
      final (inv, shift) = await make();
      open(inv, bags: {bas: 4, moz: 0}); // mozzarella is empty
      final before = inv.state.activeShift!.movements.length;
      final r = shift.checkout(items: [item('بيتزا بسطرمة', 'صغير', 1)], type: OrderType.restaurant, cashierName: 'أ');
      expect(r.ok, isFalse);
      expect(bal(inv, bas), g(2000));
      expect(inv.state.activeShift!.movements.length, before);
      expect(inv.state.activeShift!.orderConsumption, isEmpty);
    });

    test('order from an old shift never touches a new shift', () async {
      final (inv, shift) = await make();
      open(inv);
      final id = shift.checkout(items: [item('بيتزا سجق', 'وسط', 1)], type: OrderType.restaurant, cashierName: 'أ').orderId!;
      inv.closeShift(employee: 'أ');
      open(inv);
      shift.cancelOrder(id);
      expect(bal(inv, sau), g(2000));
      expect(inv.state.closedShifts.single.balanceOf(sau), g(1900));
    });
  });

  group('closing & reports', () {
    test('16. final calculation: opening + added + reversed - consumed', () async {
      final (inv, shift) = await make();
      open(inv, bags: {bas: 2, moz: 2});
      final a = shift.checkout(items: [item('بيتزا بسطرمة', 'كبير', 4)], type: OrderType.restaurant, cashierName: 'أ').orderId!;
      inv.addStock(ingredientId: bas, bags: 1, employee: 'أ', requestKey: 'x');
      shift.cancelOrder(a); // reversed 200
      shift.checkout(items: [item('بيتزا بسطرمة', 'صغير', 2)], type: OrderType.restaurant, cashierName: 'أ'); // 50
      expect(inv.closeShift(employee: 'أ').ok, isTrue);
      final row = inv.state.closedShifts.single.closingRows!.firstWhere((r) => r.ingredientId == bas);
      expect(row.opening, g(1000));
      expect(row.added, g(500));
      expect(row.reversed, g(200));
      expect(row.consumed, g(250));
      expect(row.remaining, g(1000 + 500 + 200 - 250));
      expect(row.remaining, row.opening + row.added + row.reversed - row.consumed);
      expect(inv.state.activeShift, isNull);
    });

    test('15. closing twice is rejected; closed shift ignores order ops', () async {
      final (inv, shift) = await make();
      open(inv);
      final id = shift.checkout(items: [item('بيتزا سجق', 'صغير', 1)], type: OrderType.restaurant, cashierName: 'أ').orderId!;
      expect(inv.closeShift(employee: 'أ').ok, isTrue);
      expect(inv.closeShift(employee: 'أ').ok, isFalse);
      final movesBefore = inv.state.shifts.single.movements.length;
      shift.cancelOrder(id);
      expect(inv.state.shifts.single.movements.length, movesBefore);
      expect(inv.addStock(ingredientId: sau, bags: 1, employee: 'أ', requestKey: 'late').ok, isFalse);
    });

    test('17. physical count discrepancy is a recorded adjustment with a reason', () async {
      final (inv, shift) = await make();
      open(inv, bags: {sau: 1, moz: 1});
      shift.checkout(items: [item('بيتزا سجق', 'صغير', 1)], type: OrderType.restaurant, cashierName: 'أ'); // sausage 430 left
      final noReason = inv.closeShift(employee: 'أ', actualCounts: {sau: g(400)});
      expect(noReason.ok, isFalse);
      expect(inv.state.activeShift, isNotNull);
      expect(inv.closeShift(employee: 'أ', actualCounts: {sau: g(400)}, reasons: {sau: 'هالك'}).ok, isTrue);
      final shiftDone = inv.state.closedShifts.single;
      final row = shiftDone.closingRows!.firstWhere((r) => r.ingredientId == sau);
      expect(row.expected, g(430));
      expect(row.actual, g(400));
      expect(row.difference, -g(30));
      expect(row.reason, 'هالك');
      expect(row.remaining, g(400));
      final adj = shiftDone.movements.where((m) => m.type == MovementType.adjustment).single;
      expect(adj.delta, -g(30));
      expect(adj.employee, 'أ');
      expect(adj.note, contains('هالك'));
    });

    test('20. closed report is unchanged by later recipe/capacity edits', () async {
      final (inv, shift) = await make();
      open(inv);
      shift.checkout(items: [item('بيتزا سجق', 'وسط', 1)], type: OrderType.restaurant, cashierName: 'أ');
      inv.closeShift(employee: 'أ');
      final before = inv.state.closedShifts.single.closingRows!.map((r) => r.toJson().toString()).join();
      inv.unlockManager('1234');
      inv.saveRecipe(Recipe(productName: 'بيتزا سجق', size: 'وسط', lines: {sau: g(1), moz: g(1)}));
      inv.saveIngredient(inv.state.ingredient(sau)!.copyWith(bagCapacity: g(750), name: 'اسم جديد'));
      final after = inv.state.closedShifts.single.closingRows!.map((r) => r.toJson().toString()).join();
      expect(after, before);
      expect(inv.state.closedShifts.single.meta[sau]!.bagCapacity, g(500));
    });
  });

  group('permissions', () {
    test('18. config and adjustments are denied without manager unlock', () async {
      final (inv, _) = await make();
      open(inv);
      final ing = inv.state.ingredient(bas)!;
      expect(inv.saveIngredient(ing.copyWith(bagCapacity: g(1))).ok, isFalse);
      expect(inv.saveRecipe(const Recipe(productName: 'x', size: 'y', lines: {})).ok, isFalse);
      expect(inv.deleteRecipe('بيتزا بسطرمة|صغير').ok, isFalse);
      expect(
          inv.adjustStock(shiftId: 1, ingredientId: bas, delta: g(10), reason: 'ت', employee: 'أ').ok, isFalse);
      expect(inv.state.ingredient(bas)!.bagCapacity, g(500));
      expect(bal(inv, bas), g(2000));
    });

    test('PIN flow, adjustment and post-close correction (snapshot untouched)', () async {
      final (inv, _) = await make(setup: false);
      expect(inv.unlockManager('1111').ok, isFalse); // no PIN yet
      expect(inv.setManagerPin('12').ok, isFalse);
      configure(inv); // sets PIN 1234 + capacities, then locks
      open(inv);
      expect(inv.unlockManager('0000').ok, isFalse);
      expect(inv.setManagerPin('9999').ok, isFalse); // changing needs unlock
      expect(inv.unlockManager('1234').ok, isTrue);

      expect(inv.adjustStock(shiftId: 1, ingredientId: bas, delta: -g(5000), reason: 'x', employee: 'م').ok, isFalse);
      expect(inv.adjustStock(shiftId: 1, ingredientId: bas, delta: -g(100), reason: '', employee: 'م').ok, isFalse);
      expect(inv.adjustStock(shiftId: 1, ingredientId: bas, delta: -g(100), reason: 'تلف', employee: 'م').ok, isTrue);
      expect(bal(inv, bas), g(1900));

      inv.closeShift(employee: 'أ');
      final snapshot = inv.state.closedShifts.single.closingRows!.firstWhere((r) => r.ingredientId == bas).remaining;
      expect(inv.adjustStock(shiftId: 1, ingredientId: bas, delta: g(50), reason: 'تصحيح', employee: 'م').ok, isTrue);
      final closed = inv.state.closedShifts.single;
      expect(closed.movements.last.type, MovementType.correction);
      expect(closed.closingRows!.firstWhere((r) => r.ingredientId == bas).remaining, snapshot);
    });

    test('ingredient validation', () async {
      final (inv, _) = await make();
      inv.unlockManager('1234');
      final ing = inv.state.ingredient(bas)!;
      expect(inv.saveIngredient(ing.copyWith(bagCapacity: 0)).ok, isFalse);
      expect(inv.saveIngredient(ing.copyWith(name: ' ')).ok, isFalse);
      expect(inv.saveIngredient(ing.copyWith(bagCapacity: g(250))).ok, isTrue);
    });
  });

  group('user-controlled sizes, grams and bags', () {
    test('bag capacity is not seeded; bags need a capacity', () async {
      final (inv, _) = await make(setup: false);
      expect(inv.state.ingredients.every((i) => i.bagCapacity == 0 && i.minStock == null), isTrue);
      final r = inv.openShift(bags: {bas: 2}, employee: 'أ');
      expect(r.ok, isFalse);
      expect(r.message, contains('سعة الكيس غير محددة'));
      expect(inv.state.activeShift, isNull);
      expect(inv.openShift(bags: {bas: 0}, employee: 'أ').ok, isTrue); // zero bags is fine
    });

    test('quantity = bags x the capacity the manager entered', () async {
      final (inv, _) = await make();
      inv.unlockManager('1234');
      inv.saveIngredient(inv.state.ingredient(bas)!.copyWith(bagCapacity: g(750)));
      inv.saveIngredient(inv.state.ingredient(pcs)!.copyWith(bagCapacity: g(12)));
      expect(inv.openShift(bags: {bas: 3, pcs: 5}, employee: 'أ').ok, isTrue);
      expect(bal(inv, bas), g(2250));
      expect(bal(inv, pcs), g(60));
      expect(inv.state.activeShift!.openingBags[bas], 3);
    });

    test('pizza small/medium/large deduct their own grams', () async {
      for (final c in [('صغير', 70, 100), ('وسط', 100, 125), ('كبير', 140, 150)]) {
        final (inv, shift) = await make();
        open(inv);
        shift.checkout(items: [item('بيتزا سجق', c.$1, 1)], type: OrderType.restaurant, cashierName: 'أ');
        expect(bal(inv, sau), g(2000 - c.$2), reason: c.$1);
        expect(bal(inv, moz), g(4000 - c.$3), reason: c.$1);
      }
    });

    test('pie medium/large deduct their own grams; no small pie recipe exists', () async {
      for (final c in [('وسط', 140, 125), ('كبير', 200, 160)]) {
        final (inv, shift) = await make();
        open(inv);
        shift.checkout(items: [item('فطيرة سجق', c.$1, 1)], type: OrderType.restaurant, cashierName: 'أ');
        expect(bal(inv, sau), g(2000 - c.$2), reason: c.$1);
        expect(bal(inv, moz), g(4000 - c.$3), reason: c.$1);
      }
      final (inv, _) = await make();
      expect(inv.state.recipeFor('فطيرة سجق', 'صغير'), isNull);
      expect(inv.hasRecipe('فطيرة سجق', 'صغير'), isFalse);
    });

    test('a manager can define any recipe (e.g. a small pie) with custom grams', () async {
      final (inv, shift) = await make();
      inv.unlockManager('1234');
      expect(inv.saveRecipe(Recipe(productName: 'فطيرة سجق', size: 'صغير', lines: {sau: g(90), moz: g(60.5)})).ok, isTrue);
      open(inv);
      shift.checkout(items: [item('فطيرة سجق', 'صغير', 2)], type: OrderType.restaurant, cashierName: 'أ');
      expect(bal(inv, sau), g(2000 - 180));
      expect(bal(inv, moz), g(4000 - 121));
    });

    test('products without a recipe are reported and consume nothing', () async {
      final (inv, shift) = await make();
      open(inv);
      for (final c in [('بيتزا تشيز', 'وسط'), ('بيتزا زنجر حار', 'كبير'), ('فطيرة سوسيس', 'وسط')]) {
        expect(inv.hasRecipe(c.$1, c.$2), isFalse, reason: c.$1);
        expect(shift.checkout(items: [item(c.$1, c.$2, 1)], type: OrderType.restaurant, cashierName: 'أ').ok, isTrue);
      }
      expect(bal(inv, moz), g(4000));
    });

    test('recipe/capacity edits do not touch the open shift, apply to the next', () async {
      final (inv, shift) = await make();
      open(inv);
      inv.unlockManager('1234');
      inv.saveRecipe(Recipe(productName: 'بيتزا سجق', size: 'وسط', lines: {sau: g(999), moz: g(1)}));
      inv.saveIngredient(inv.state.ingredient(sau)!.copyWith(bagCapacity: g(800)));
      shift.checkout(items: [item('بيتزا سجق', 'وسط', 1)], type: OrderType.restaurant, cashierName: 'أ');
      expect(bal(inv, sau), g(1900)); // still the 100 g recipe, 500 g bags
      inv.closeShift(employee: 'أ');
      inv.openShift(bags: {sau: 1, moz: 1}, employee: 'أ');
      expect(bal(inv, sau), g(800)); // new capacity
      // the new 999 g recipe now applies, and 999 g > 800 g in stock -> blocked, unchanged
      final next = shift.checkout(items: [item('بيتزا سجق', 'وسط', 1)], type: OrderType.restaurant, cashierName: 'أ');
      expect(next.ok, isFalse);
      expect(next.shortIds, [sau]);
      expect(bal(inv, sau), g(800));
    });
  });

  group('shortage -> add bags -> order succeeds', () {
    test('shortage names the ingredient; adding bags lets the same order pass', () async {
      final (inv, shift) = await make();
      open(inv, bags: {bas: 1, moz: 0});
      final order = [item('بيتزا بسطرمة', 'كبير', 2)]; // 100 g basturma + 300 g mozzarella
      final blocked = shift.checkout(items: order, type: OrderType.restaurant, cashierName: 'أ');
      expect(blocked.ok, isFalse);
      expect(blocked.shortIds, [moz]);
      expect(blocked.error, contains('موتزاريلا'));
      expect(blocked.error, isNot(contains('بسطرمة (')));
      expect(shift.state.orders, isEmpty);

      final add = inv.addStock(ingredientId: blocked.shortIds.first, bags: 1, employee: 'أ', requestKey: 'short-1');
      expect(add.ok, isTrue);
      final retry = shift.checkout(items: order, type: OrderType.restaurant, cashierName: 'أ');
      expect(retry.ok, isTrue);
      expect(bal(inv, moz), g(700));
      expect(bal(inv, bas), g(400));
      // the same dialog submission cannot add twice
      expect(inv.addStock(ingredientId: moz, bags: 1, employee: 'أ', requestKey: 'short-1').ok, isFalse);
      expect(bal(inv, moz), g(700));
      // recorded as its own movement type and shown in the closing report
      expect(inv.state.activeShift!.movements.where((m) => m.type == MovementType.addition).length, 1);
      inv.closeShift(employee: 'أ');
      expect(inv.state.closedShifts.single.closingRows!.firstWhere((r) => r.ingredientId == moz).added, g(1000));
    });

    test('there is no override: edit that exceeds stock stays rejected until bags are added', () async {
      final (inv, shift) = await make();
      open(inv, bags: {bas: 1, moz: 1});
      final id = shift.checkout(items: [item('بيتزا بسطرمة', 'كبير', 6)], type: OrderType.restaurant, cashierName: 'أ').orderId!; // 900 g moz
      final edit = shift.updateOrderItemQty(id, 0, 1);
      expect(edit.ok, isFalse);
      expect(edit.shortIds, [moz]);
      inv.addStock(ingredientId: moz, bags: 1, employee: 'أ', requestKey: 'e1');
      expect(shift.updateOrderItemQty(id, 0, 1).ok, isTrue);
      expect(bal(inv, moz), g(2000 - 1050));
    });
  });

  group('persistence & helpers', () {
    test('state survives a restart (ledger, bags, consumption)', () async {
      final (inv, shift) = await make();
      open(inv);
      final id = shift.checkout(items: [item('بيتزا سجق', 'وسط', 2)], type: OrderType.restaurant, cashierName: 'أ').orderId!;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final prefs = await SharedPreferences.getInstance();
      final saved = {for (final k in prefs.getKeys()) k: prefs.get(k)!};
      final (inv2, shift2) = await make(prefs: saved, setup: false);
      expect(bal(inv2, sau), g(1800));
      shift2.cancelOrder(id);
      expect(bal(inv2, sau), g(2000));
    });

    test('quantity parsing and formatting', () {
      expect(parseMilli('1.5'), 1500);
      expect(parseMilli('٢٥'), 25000);
      expect(parseMilli('1٫25'), 1250);
      expect(parseMilli('-3'), isNull);
      expect(parseMilli('abc'), isNull);
      expect(parseMilli('1.2345'), isNull);
      expect(parseWhole('2.5'), isNull);
      expect(formatMilli(1500), '1.5');
      expect(formatMilli(25000), '25');
      expect(milli(0.1) * 3, milli(0.3));
    });
  });
}
