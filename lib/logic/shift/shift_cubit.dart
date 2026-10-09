import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local_storage_service.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/order.dart';
import '../inventory/inventory_cubit.dart';
import 'shift_state.dart';

/// Result of an order operation. [error] is user-facing Arabic when blocked
/// (e.g. insufficient ingredient stock); the order list is left untouched.
class OrderResult {
  final int? orderId;
  final String? error;

  /// True when the order was refused because no inventory shift is open.
  final bool needsShift;

  /// Ingredients that were short (to offer "إضافة أكياس" for them).
  final List<String> shortIds;
  const OrderResult.ok([this.orderId])
      : error = null,
        needsShift = false,
        shortIds = const [];
  const OrderResult.blocked(this.error, {this.shortIds = const []})
      : orderId = null,
        needsShift = false;
  const OrderResult.noShift()
      : error = 'افتح الشيفت أولاً',
        orderId = null,
        needsShift = true,
        shortIds = const [];
  bool get ok => error == null;
}

class ShiftCubit extends Cubit<ShiftState> {
  final LocalStorageService _storage;
  final InventoryCubit? _inventory;

  ShiftCubit(this._storage, [this._inventory]) : super(ShiftState.initial) {
    _load();
  }

  Future<void> _load() async {
    final (orders, counter) = await _storage.loadShift();
    emit(state.copyWith(
      orders: orders,
      orderCounter: counter,
      isLoading: false,
    ));
  }

  void _persist() => _storage.saveShift(state.orders, state.orderCounter);

  /// Applies the stock effect of [items] for [order]; empty [items] reverses.
  InventoryResult _syncStock(Order order, List<CartItem> items) =>
      _inventory?.syncOrder(
        orderId: order.id,
        orderShiftId: order.inventoryShiftId,
        items: items,
        employee: order.cashierName,
      ) ??
      const InventoryResult.ok();

  /// Registers a completed order from the cart. Stock is deducted at this
  /// moment (the order is final once registered); if any ingredient is short
  /// the order is NOT registered and the cart is kept.
  OrderResult checkout({
    required List<CartItem> items,
    required OrderType type,
    required String cashierName,
  }) {
    // An open inventory shift is mandatory: every order must be able to
    // deduct its ingredients.
    if (_inventory != null && _inventory.state.activeShift == null) {
      return const OrderResult.noShift();
    }
    final order = Order(
      id: state.orderCounter,
      type: type,
      items: List.of(items),
      time: DateTime.now(),
      cashierName: cashierName,
      inventoryShiftId: _inventory?.state.activeShift?.id,
    );
    final stock = _syncStock(order, order.items);
    if (!stock.ok) return OrderResult.blocked(stock.message, shortIds: stock.shortIds);
    emit(state.copyWith(
      orders: [...state.orders, order],
      orderCounter: state.orderCounter + 1,
    ));
    _persist();
    return OrderResult.ok(order.id);
  }

  OrderResult cancelOrder(int orderId) {
    final order = state.orders.where((o) => o.id == orderId).firstOrNull;
    if (order != null) _syncStock(order, const []); // reversal never fails
    emit(state.copyWith(
      orders: state.orders.where((o) => o.id != orderId).toList(),
    ));
    _persist();
    return const OrderResult.ok();
  }

  OrderResult removeItemFromOrder(int orderId, int itemIndex) {
    final order = state.orders.firstWhere((o) => o.id == orderId);
    final items = [...order.items]..removeAt(itemIndex);
    final stock = _syncStock(order, items);
    if (!stock.ok) return OrderResult.blocked(stock.message, shortIds: stock.shortIds);
    final orders = state.orders.map((o) => o.id == orderId ? o.copyWith(items: items) : o).toList()
      ..removeWhere((o) => o.id == orderId && o.items.isEmpty);
    emit(state.copyWith(orders: orders));
    _persist();
    return const OrderResult.ok();
  }

  OrderResult updateOrderItemQty(int orderId, int itemIndex, int delta) {
    final order = state.orders.firstWhere((o) => o.id == orderId);
    final items = [...order.items];
    final newQty = items[itemIndex].qty + delta;
    if (newQty <= 0) {
      items.removeAt(itemIndex);
    } else {
      items[itemIndex] = items[itemIndex].copyWith(qty: newQty);
    }
    final stock = _syncStock(order, items);
    if (!stock.ok) return OrderResult.blocked(stock.message, shortIds: stock.shortIds);
    final orders = <Order>[];
    for (final o in state.orders) {
      if (o.id != orderId) {
        orders.add(o);
      } else if (items.isNotEmpty) {
        orders.add(o.copyWith(items: items));
      }
    }
    emit(state.copyWith(orders: orders));
    _persist();
    return const OrderResult.ok();
  }

  void toggleExpanded(int orderId) {
    final expanded = {...state.expandedOrderIds};
    if (!expanded.remove(orderId)) expanded.add(orderId);
    emit(state.copyWith(expandedOrderIds: expanded));
  }

  /// Clears the order log. Blocked while an inventory shift is open, because
  /// removing orders would silently orphan their ingredient consumption.
  Future<String?> resetShift() async {
    if (_inventory?.state.activeShift != null) {
      return 'أغلق الشيفت (تقرير المخزون) أولاً قبل تصفير الطلبات.';
    }
    emit(state.copyWith(
      orders: const [],
      orderCounter: 1,
      expandedOrderIds: const {},
    ));
    await _storage.clearShift();
    return null;
  }
}
