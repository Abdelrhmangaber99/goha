import 'package:equatable/equatable.dart';

/// An item placed in the cart or already inside a saved order.
/// [key] is the display key used for grouping (e.g. "فطيرة سجق (وسط)").
class CartItem extends Equatable {
  final String key;
  final String name;
  final String size;
  final double price;
  final int qty;
  final String category;

  const CartItem({
    required this.key,
    required this.name,
    required this.size,
    required this.price,
    required this.qty,
    required this.category,
  });

  double get total => price * qty;

  CartItem copyWith({int? qty}) => CartItem(
        key: key,
        name: name,
        size: size,
        price: price,
        qty: qty ?? this.qty,
        category: category,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'size': size,
        'price': price,
        'qty': qty,
        'category': category,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        key: json['key'] as String,
        name: json['name'] as String,
        size: json['size'] as String,
        price: (json['price'] as num).toDouble(),
        qty: json['qty'] as int,
        category: json['category'] as String,
      );

  @override
  List<Object?> get props => [key, name, size, price, qty, category];
}
