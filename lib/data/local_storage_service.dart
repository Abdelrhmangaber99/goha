import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/cart_item.dart';
import 'models/order.dart';

/// Persists cashier/cart/shift state to disk (SharedPreferences) so nothing
/// is lost when the app is closed, killed, or backgrounded.
class LocalStorageService {
  static const _kCashierName = 'cashier_name';
  static const _kCartItems = 'cart_items';
  static const _kOrderType = 'order_type';
  static const _kOrdersLog = 'orders_log';
  static const _kOrderCounter = 'order_counter';
  static const _kInventory = 'inventory_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveCashierName(String name) async {
    final prefs = await _prefs;
    await prefs.setString(_kCashierName, name);
  }

  Future<String?> loadCashierName() async {
    final prefs = await _prefs;
    return prefs.getString(_kCashierName);
  }

  Future<void> saveCart(List<CartItem> items, String orderType) async {
    final prefs = await _prefs;
    await prefs.setString(
      _kCartItems,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(_kOrderType, orderType);
  }

  Future<(List<CartItem>, String)> loadCart() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kCartItems);
    final orderType = prefs.getString(_kOrderType) ?? 'restaurant';
    if (raw == null || raw.isEmpty) return (<CartItem>[], orderType);
    final list = (jsonDecode(raw) as List)
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (list, orderType);
  }

  Future<void> saveShift(List<Order> orders, int orderCounter) async {
    final prefs = await _prefs;
    await prefs.setString(
      _kOrdersLog,
      jsonEncode(orders.map((e) => e.toJson()).toList()),
    );
    await prefs.setInt(_kOrderCounter, orderCounter);
  }

  Future<(List<Order>, int)> loadShift() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kOrdersLog);
    final counter = prefs.getInt(_kOrderCounter) ?? 1;
    if (raw == null || raw.isEmpty) return (<Order>[], counter);
    final list = (jsonDecode(raw) as List)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
    return (list, counter);
  }

  Future<void> clearShift() async {
    final prefs = await _prefs;
    await prefs.remove(_kOrdersLog);
    await prefs.setInt(_kOrderCounter, 1);
  }

  Future<void> saveInventory(String json) async {
    final prefs = await _prefs;
    await prefs.setString(_kInventory, json);
  }

  Future<String?> loadInventory() async {
    final prefs = await _prefs;
    return prefs.getString(_kInventory);
  }
}
