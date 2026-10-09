import 'ingredient.dart';
import 'stock_movement.dart';

/// What one order line consumed, frozen at consumption time so later recipe
/// edits don't distort reversals/edits of already-consumed orders.
class LineConsumption {
  final int qty;
  final Map<String, int> perUnit; // ingredientId -> milli per 1 item

  const LineConsumption({required this.qty, required this.perUnit});

  Map<String, dynamic> toJson() => {'qty': qty, 'perUnit': perUnit};

  factory LineConsumption.fromJson(Map<String, dynamic> j) => LineConsumption(
        qty: j['qty'] as int,
        perUnit: (j['perUnit'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      );
}

/// Permanent per-ingredient closing snapshot.
class ClosingRow {
  final String ingredientId;
  final String name;
  final String unit;
  final int bagCapacity;
  final int openingBags;
  final int opening;
  final int added;
  final int consumed;
  final int reversed;
  final int adjustments; // adjustments made before the physical count
  final int expected;
  final int? actual;
  final int difference; // actual - expected (0 when no count was entered)
  final String reason;
  final int remaining;

  const ClosingRow({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.bagCapacity,
    required this.openingBags,
    required this.opening,
    required this.added,
    required this.consumed,
    required this.reversed,
    required this.adjustments,
    required this.expected,
    required this.actual,
    required this.difference,
    required this.reason,
    required this.remaining,
  });

  Map<String, dynamic> toJson() => {
        'ingredientId': ingredientId,
        'name': name,
        'unit': unit,
        'bagCapacity': bagCapacity,
        'openingBags': openingBags,
        'opening': opening,
        'added': added,
        'consumed': consumed,
        'reversed': reversed,
        'adjustments': adjustments,
        'expected': expected,
        'actual': actual,
        'difference': difference,
        'reason': reason,
        'remaining': remaining,
      };

  factory ClosingRow.fromJson(Map<String, dynamic> j) => ClosingRow(
        ingredientId: j['ingredientId'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        bagCapacity: j['bagCapacity'] as int,
        openingBags: j['openingBags'] as int,
        opening: j['opening'] as int,
        added: j['added'] as int,
        consumed: j['consumed'] as int,
        reversed: j['reversed'] as int,
        adjustments: j['adjustments'] as int,
        expected: j['expected'] as int,
        actual: j['actual'] as int?,
        difference: j['difference'] as int,
        reason: j['reason'] as String? ?? '',
        remaining: j['remaining'] as int,
      );
}

class InventoryShift {
  final int id;
  final DateTime openedAt;
  final String openedBy;
  final Map<String, int> openingBags; // immutable after creation
  final Map<String, IngredientMeta> meta;

  /// Recipes frozen when the shift opened (recipeKey -> ingredient lines), so
  /// recipe edits only apply from the next shift. Null on shifts saved before
  /// this existed (they fall back to the live recipes).
  final Map<String, Map<String, int>>? recipes;
  final List<StockMovement> movements = [];
  final Map<int, Map<String, LineConsumption>> orderConsumption = {};
  final Set<String> refKeys = {};
  DateTime? closedAt;
  String? closedBy;
  List<ClosingRow>? closingRows;

  InventoryShift({
    required this.id,
    required this.openedAt,
    required this.openedBy,
    required this.openingBags,
    required this.meta,
    this.recipes,
  });

  bool get isOpen => closedAt == null;

  int balanceOf(String ingredientId) {
    for (var i = movements.length - 1; i >= 0; i--) {
      if (movements[i].ingredientId == ingredientId) return movements[i].after;
    }
    return 0;
  }

  int _sum(String ingredientId, bool Function(StockMovement) test) => movements
      .where((m) => m.ingredientId == ingredientId && test(m))
      .fold(0, (s, m) => s + m.delta);

  int openingOf(String id) => _sum(id, (m) => m.type == MovementType.opening);
  int addedOf(String id) => _sum(id, (m) => m.type == MovementType.addition);
  int consumedOf(String id) => -_sum(id, (m) => m.type == MovementType.orderConsumption);
  int reversedOf(String id) => _sum(id, (m) => m.type == MovementType.orderReversal);
  int adjustmentsOf(String id) =>
      _sum(id, (m) => m.type == MovementType.adjustment || m.type == MovementType.correction);

  Map<String, dynamic> toJson() => {
        'id': id,
        'openedAt': openedAt.toIso8601String(),
        'openedBy': openedBy,
        'openingBags': openingBags,
        'meta': meta.map((k, v) => MapEntry(k, v.toJson())),
        'recipes': recipes,
        'movements': movements.map((m) => m.toJson()).toList(),
        'orderConsumption': orderConsumption.map((o, lines) =>
            MapEntry('$o', lines.map((k, v) => MapEntry(k, v.toJson())))),
        'closedAt': closedAt?.toIso8601String(),
        'closedBy': closedBy,
        'closingRows': closingRows?.map((r) => r.toJson()).toList(),
      };

  factory InventoryShift.fromJson(Map<String, dynamic> j) {
    final s = InventoryShift(
      id: j['id'] as int,
      openedAt: DateTime.parse(j['openedAt'] as String),
      openedBy: j['openedBy'] as String? ?? '',
      openingBags: (j['openingBags'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      meta: (j['meta'] as Map)
          .map((k, v) => MapEntry(k as String, IngredientMeta.fromJson(v as Map<String, dynamic>))),
      recipes: (j['recipes'] as Map?)?.map((k, v) =>
          MapEntry(k as String, (v as Map).map((a, b) => MapEntry(a as String, b as int)))),
    );
    for (final m in (j['movements'] as List)) {
      final mv = StockMovement.fromJson(m as Map<String, dynamic>);
      s.movements.add(mv);
      s.refKeys.add(mv.refKey);
    }
    (j['orderConsumption'] as Map).forEach((o, lines) {
      s.orderConsumption[int.parse(o as String)] = (lines as Map).map(
        (k, v) => MapEntry(k as String, LineConsumption.fromJson(v as Map<String, dynamic>)),
      );
    });
    if (j['closedAt'] != null) s.closedAt = DateTime.parse(j['closedAt'] as String);
    s.closedBy = j['closedBy'] as String?;
    s.closingRows = (j['closingRows'] as List?)
        ?.map((r) => ClosingRow.fromJson(r as Map<String, dynamic>))
        .toList();
    return s;
  }
}
