// lib/providers/order_provider.dart

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'load_state.dart';

class OrderProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  List<OrderModel> _orders = [];

  LoadState get state  => _state;
  bool get isLoading   => _state == LoadState.loading;
  List<OrderModel> get orders => _orders;
  double get totalRevenue =>
      _orders.fold(0.0, (s, o) => s + o.totalAmount);

  // ── Load list  GET /api/v1/orders ────────────────────────────────────────
  Future<void> load({
    String? query,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 100,
  }) async {
    _setState(LoadState.loading);
    final res = await ApiService.getOrders(
      query: query,
      from:  from,
      to:    to,
      page:  page,
      size:  size,
    );
    _orders = ApiService.extractList(res)
        .map((e) => OrderModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _setState(LoadState.success);
  }

  // ── Fetch single  GET /api/v1/orders/{id} ────────────────────────────────
  // Response shape:
  // {
  //   "status": 200,
  //   "data": {           ← single object, NOT a list
  //     "id": 1,
  //     "transactionRef": "TRANS-...",
  //     "paymentName": "ABA",
  //     "subtotalAmount": 1999.98,
  //     "totalAmount": 1999.98,
  //     "items": [ { "productName": "Samsung A 15", ... } ]
  //   }
  // }
  Future<OrderModel> fetchById(int id) async {
    final res = await ApiService.getOrderById(id);

    // ── guard: null response (network / timeout) ─────────────────
    if (res == null) {
      throw Exception('No response from server for order #$id');
    }

    // ── guard: server returned an error field ────────────────────
    if (res['error'] != null) {
      throw Exception(res['error'].toString());
    }

    // ── extract "data" — must be a Map, never a List here ────────
    final raw = res['data'];
    debugPrint('[OrderProvider] fetchById raw type: ${raw.runtimeType}');
    debugPrint('[OrderProvider] fetchById raw: $raw');

    if (raw == null) {
      throw Exception('Order #$id not found (data is null)');
    }

    // The API wraps the single order directly in "data": { … }
    // If for some reason it came back as a List (shouldn't happen),
    // take the first element so we don't crash.
    final Map<String, dynamic> map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is List && raw.isNotEmpty) {
      map = raw.first as Map<String, dynamic>;
    } else {
      throw Exception('Unexpected data format for order #$id');
    }

    // ── debug: log the keys we're about to parse ─────────────────
    debugPrint('[OrderProvider] fetchById keys: ${map.keys.toList()}');
    debugPrint('[OrderProvider] transactionRef: ${map['transactionRef']}');
    debugPrint('[OrderProvider] paymentName: ${map['paymentName']}');
    debugPrint('[OrderProvider] totalAmount: ${map['totalAmount']}');
    debugPrint('[OrderProvider] items count: ${(map['items'] as List?)?.length}');

    return OrderModel.fromMap(map);
  }

  void _setState(LoadState s) { _state = s; notifyListeners(); }
}