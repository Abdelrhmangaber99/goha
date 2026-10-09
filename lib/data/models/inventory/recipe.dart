/// Ingredient consumption of ONE unit of a product in one size.
/// [lines] maps ingredientId -> milli quantity.
class Recipe {
  final String productName;
  final String size;
  final Map<String, int> lines;

  const Recipe({required this.productName, required this.size, required this.lines});

  String get key => recipeKey(productName, size);

  Recipe copyWith({Map<String, int>? lines}) =>
      Recipe(productName: productName, size: size, lines: lines ?? this.lines);

  Map<String, dynamic> toJson() => {'productName': productName, 'size': size, 'lines': lines};

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        productName: j['productName'] as String,
        size: j['size'] as String,
        lines: (j['lines'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      );
}

String recipeKey(String productName, String size) => '$productName|$size';
