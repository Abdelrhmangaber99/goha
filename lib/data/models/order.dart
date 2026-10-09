import 'package:equatable/equatable.dart';
import 'cart_item.dart';

enum OrderType { restaurant, goha }

extension OrderTypeLabel on OrderType {
  String get arabicLabel => this == OrderType.restaurant ? 'المطعم' : 'جحا';
}

class Order extends Equatable {
  final int id;
  final OrderType type;
  final List<CartItem> items;
  final DateTime time;
  final String cashierName;

  /// Inventory shift whose stock this order was deducted from (null when no
  /// inventory shift was open at checkout).
  final int? inventoryShiftId;

  const Order({
    required this.id,
    required this.type,
    required this.items,
    required this.time,
    required this.cashierName,
    this.inventoryShiftId,
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.total);

  Order copyWith({List<CartItem>? items}) => Order(
        id: id,
        type: type,
        items: items ?? this.items,
        time: time,
        cashierName: cashierName,
        inventoryShiftId: inventoryShiftId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'items': items.map((e) => e.toJson()).toList(),
        'time': time.toIso8601String(),
        'cashierName': cashierName,
        'inventoryShiftId': inventoryShiftId,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        type: OrderType.values.byName(json['type'] as String),
        items: (json['items'] as List)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        time: DateTime.parse(json['time'] as String),
        cashierName: json['cashierName'] as String? ?? '',
        inventoryShiftId: json['inventoryShiftId'] as int?,
      );

  @override
  List<Object?> get props => [id, type, items, time, cashierName, inventoryShiftId];
}
