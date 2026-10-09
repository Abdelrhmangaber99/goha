import 'package:equatable/equatable.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/order.dart';

class CartState extends Equatable {
  final List<CartItem> items;
  final OrderType orderType;
  final bool isLoading;

  const CartState({
    required this.items,
    required this.orderType,
    this.isLoading = false,
  });

  static const initial = CartState(
    items: [],
    orderType: OrderType.restaurant,
    isLoading: true,
  );

  double get total => items.fold(0.0, (sum, item) => sum + item.total);

  CartState copyWith({
    List<CartItem>? items,
    OrderType? orderType,
    bool? isLoading,
  }) =>
      CartState(
        items: items ?? this.items,
        orderType: orderType ?? this.orderType,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [items, orderType, isLoading];
}
