import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local_storage_service.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/order.dart';
import 'cart_state.dart';

/// Builds the display key used to group identical picks in the cart.
/// Items sold with a generic single size ("عادي"/"وجبة"/"طاجن") are keyed by
/// name alone; items with a real size variant are keyed as "name (size)".
String buildCartKey(String name, String size) {
  const genericSizes = {'عادي', 'وجبة', 'طاجن'};
  return genericSizes.contains(size) ? name : '$name ($size)';
}

class CartCubit extends Cubit<CartState> {
  final LocalStorageService _storage;

  CartCubit(this._storage) : super(CartState.initial) {
    _load();
  }

  Future<void> _load() async {
    final (items, orderTypeName) = await _storage.loadCart();
    emit(
      state.copyWith(
        items: items,
        orderType: OrderType.values.byName(orderTypeName),
        isLoading: false,
      ),
    );
  }

  void _persist() => _storage.saveCart(state.items, state.orderType.name);

  void setOrderType(OrderType type) {
    emit(state.copyWith(orderType: type));
    _persist();
  }

  void addItem({
    required String name,
    required String size,
    required double price,
    required String category,
  }) {
    final key = buildCartKey(name, size);
    final items = [...state.items];
    final index = items.indexWhere((i) => i.key == key);
    if (index >= 0) {
      items[index] = items[index].copyWith(qty: items[index].qty + 1);
    } else {
      items.add(CartItem(
        key: key,
        name: name,
        size: size,
        price: price,
        qty: 1,
        category: category,
      ));
    }
    emit(state.copyWith(items: items));
    _persist();
  }

  void changeQty(int index, int delta) {
    final items = [...state.items];
    final newQty = items[index].qty + delta;
    if (newQty <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(qty: newQty);
    }
    emit(state.copyWith(items: items));
    _persist();
  }

  void clear() {
    emit(state.copyWith(items: const []));
    _persist();
  }
}
