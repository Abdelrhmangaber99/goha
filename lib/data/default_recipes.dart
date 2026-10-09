import '../core/quantity.dart';
import 'models/inventory/ingredient.dart';
import 'models/inventory/recipe.dart';

/// Initial inventory seed. Applied once, when no inventory data exists yet.
/// Recipes are editable defaults (settings screen). Bag capacity is left at 0
/// (= "not set") on purpose: the manager must enter the real value.
class InventorySeed {
  static const gram = 'جرام';
  static const piece = 'قطعة';

  static const basturma = 'basturma';
  static const sausage = 'sausage';
  static const chicken = 'chicken';
  static const minced = 'minced_meat';
  static const sausagePieces = 'sausage_pieces';
  static const mozzarella = 'mozzarella';

  static List<Ingredient> ingredients() => [
        Ingredient(id: basturma, name: 'بسطرمة', unit: gram, bagCapacity: 0),
        Ingredient(id: sausage, name: 'سجق', unit: gram, bagCapacity: 0),
        Ingredient(id: chicken, name: 'فراخ', unit: gram, bagCapacity: 0),
        Ingredient(id: minced, name: 'لحم مفروم', unit: gram, bagCapacity: 0),
        Ingredient(id: sausagePieces, name: 'سوسيس (قطع)', unit: piece, bagCapacity: 0),
        Ingredient(id: mozzarella, name: 'موتزاريلا', unit: gram, bagCapacity: 0),
      ];

  // product -> main ingredient id
  static const _pizzas = {
    'بيتزا بسطرمة': basturma,
    'بيتزا سجق': sausage,
    'بيتزا فراخ صدور': chicken,
    'بيتزا لحم مفروم': minced,
    'بيتزا سوسيس': sausagePieces,
  };

  static const _pies = {
    'فطيرة بسطرمة': basturma,
    'فطيرة بسطرمة كيري': basturma,
    'فطيرة سجق': sausage,
    'فطيرة سجق كيري': sausage,
    'فطيرة فراخ': chicken,
    'فطيرة لحم مفروم': minced,
  };

  // size -> {ingredient: quantity}
  static const _pizzaSizes = <String, Map<String, num>>{
    'صغير': {basturma: 25, sausage: 70, chicken: 80, minced: 80, sausagePieces: 1, mozzarella: 100},
    'وسط': {basturma: 35, sausage: 100, chicken: 120, minced: 120, sausagePieces: 1.5, mozzarella: 125},
    'كبير': {basturma: 50, sausage: 140, chicken: 160, minced: 160, sausagePieces: 2, mozzarella: 150},
  };

  static const _pieSizes = <String, Map<String, num>>{
    'وسط': {basturma: 50, sausage: 140, chicken: 160, minced: 160, mozzarella: 125},
    'كبير': {basturma: 75, sausage: 200, chicken: 200, minced: 200, mozzarella: 160},
  };

  static List<Recipe> recipes() {
    final out = <Recipe>[];
    void build(Map<String, String> products, Map<String, Map<String, num>> sizes) {
      products.forEach((product, main) {
        sizes.forEach((size, table) {
          out.add(Recipe(
            productName: product,
            size: size,
            lines: {
              main: milli(table[main]!),
              mozzarella: milli(table[mozzarella]!),
            },
          ));
        });
      });
    }

    build(_pizzas, _pizzaSizes);
    build(_pies, _pieSizes);
    return out;
  }
}
