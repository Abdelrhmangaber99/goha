import '../data/models/cart_item.dart';

/// A cart/order item paired with its original position in the source list,
/// so callers can still address it (qty change, removal) after grouping.
class GroupedCartItem {
  final int originalIndex;
  final CartItem item;

  const GroupedCartItem(this.originalIndex, this.item);
}

/// Groups items by [CartItem.category], preserving each item's original
/// index. Groups are ordered by first appearance, so any category —
/// including ones not known ahead of time — falls into its own section
/// automatically without extra configuration.
Map<String, List<GroupedCartItem>> groupItemsByCategory(List<CartItem> items) {
  final grouped = <String, List<GroupedCartItem>>{};
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    grouped.putIfAbsent(item.category, () => []).add(GroupedCartItem(i, item));
  }
  return grouped;
}
