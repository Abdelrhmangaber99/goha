/// A tracked ingredient portion ("برسلة"). [bagCapacity] and [minStock] are
/// in milli units (see core/quantity.dart).
class Ingredient {
  final String id;
  final String name;
  final String unit;
  final int bagCapacity;
  final int? minStock;
  final bool active;

  const Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.bagCapacity,
    this.minStock,
    this.active = true,
  });

  Ingredient copyWith({
    String? name,
    String? unit,
    int? bagCapacity,
    int? minStock,
    bool clearMinStock = false,
    bool? active,
  }) =>
      Ingredient(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        bagCapacity: bagCapacity ?? this.bagCapacity,
        minStock: clearMinStock ? null : (minStock ?? this.minStock),
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'bagCapacity': bagCapacity,
        'minStock': minStock,
        'active': active,
      };

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        bagCapacity: j['bagCapacity'] as int,
        minStock: j['minStock'] as int?,
        active: j['active'] as bool? ?? true,
      );
}

/// Name/unit/capacity of an ingredient as they were when a shift used it, so
/// later edits never change a shift's numbers or report.
class IngredientMeta {
  final String name;
  final String unit;
  final int bagCapacity;

  const IngredientMeta({required this.name, required this.unit, required this.bagCapacity});

  factory IngredientMeta.of(Ingredient i) =>
      IngredientMeta(name: i.name, unit: i.unit, bagCapacity: i.bagCapacity);

  Map<String, dynamic> toJson() => {'name': name, 'unit': unit, 'bagCapacity': bagCapacity};

  factory IngredientMeta.fromJson(Map<String, dynamic> j) => IngredientMeta(
        name: j['name'] as String,
        unit: j['unit'] as String,
        bagCapacity: j['bagCapacity'] as int,
      );
}
