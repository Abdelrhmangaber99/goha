/// A single sellable menu item with one price per size/variant label.
/// Example: "1/2 فرخة مشوية" -> {"وجبة": 200}
class MenuItem {
  final String name;
  final String? description;
  final Map<String, double> prices;

  const MenuItem({required this.name, this.description, required this.prices});
}
