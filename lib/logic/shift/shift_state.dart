import 'package:equatable/equatable.dart';

import '../../data/models/order.dart';

class ShiftItemSales {
  final String category;
  final String itemKey;
  int restQty = 0;
  double restPrice = 0;
  int gohaQty = 0;
  double gohaPrice = 0;

  ShiftItemSales(this.category, this.itemKey);
}

class ShiftState extends Equatable {
  final List<Order> orders;
  final int orderCounter;
  final Set<int> expandedOrderIds;
  final bool isLoading;

  const ShiftState({
    required this.orders,
    required this.orderCounter,
    required this.expandedOrderIds,
    this.isLoading = false,
  });

  static const initial = ShiftState(
    orders: [],
    orderCounter: 1,
    expandedOrderIds: {},
    isLoading: true,
  );

  double get restaurantRevenue => orders
      .where((o) => o.type == OrderType.restaurant)
      .fold(0.0, (sum, o) => sum + o.total);

  double get gohaRevenue => orders
      .where((o) => o.type == OrderType.goha)
      .fold(0.0, (sum, o) => sum + o.total);

  double get grandTotal => restaurantRevenue + gohaRevenue;

  /// category -> itemKey -> aggregated sales, split by order type.
  Map<String, Map<String, ShiftItemSales>> get salesByCategory {
    final result = <String, Map<String, ShiftItemSales>>{};
    for (final order in orders) {
      for (final item in order.items) {
        final categoryMap = result.putIfAbsent(item.category, () => {});
        final sales = categoryMap.putIfAbsent(
          item.key,
          () => ShiftItemSales(item.category, item.key),
        );
        if (order.type == OrderType.restaurant) {
          sales.restQty += item.qty;
          sales.restPrice += item.total;
        } else {
          sales.gohaQty += item.qty;
          sales.gohaPrice += item.total;
        }
      }
    }
    return result;
  }

  ShiftState copyWith({
    List<Order>? orders,
    int? orderCounter,
    Set<int>? expandedOrderIds,
    bool? isLoading,
  }) =>
      ShiftState(
        orders: orders ?? this.orders,
        orderCounter: orderCounter ?? this.orderCounter,
        expandedOrderIds: expandedOrderIds ?? this.expandedOrderIds,
        isLoading: isLoading ?? this.isLoading,
      );

  @override
  List<Object?> get props => [orders, orderCounter, expandedOrderIds, isLoading];
}
