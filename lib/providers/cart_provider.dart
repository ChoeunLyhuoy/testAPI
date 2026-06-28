// lib/providers/cart_provider.dart
//
// FIXES in this revision:
// 1. syncPreview() item matching uses BOTH productCode AND promotionId — because
//    the same productCode can appear twice in the cart (with and without a promotion).
//    The server response now includes promotionId per item so we can match correctly.
// 2. setDiscount() clamps against effectiveSubtotal when server pricing is available.
// 3. Concurrent syncPreview() calls are guarded — a pending flag re-runs once done.
// 4. checkout() posts cart then creates order (two-step: POST /carts → POST /orders).
// 5. clear() resets _previewSyncing so the spinner never gets stuck.
// 6. quantityOf() never throws — uses explicit loop.

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  double _discount       = 0;
  bool   _syncing        = false;
  bool   _previewSyncing = false;
  bool   _previewPending = false;

  // Server-confirmed cart total (post-promotion); null until first sync.
  double? _serverTotal;

  List<CartItemModel> get items         => List.unmodifiable(_items);
  double              get discount      => _discount;
  bool                get syncing       => _syncing;
  bool                get previewSyncing=> _previewSyncing;
  bool                get isEmpty       => _items.isEmpty;
  int                 get totalQuantity => _items.fold(0, (s, i) => s + i.quantity);

  // Local estimates (no promotion awareness)
  double get subtotal      => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get discountAmount=> _discount;
  double get total         => (subtotal - discountAmount).clamp(0, double.infinity);

  // Server-confirmed (promotion-aware) figures
  double get effectiveSubtotal => _items.fold(0.0, (s, i) => s + i.effectiveSubtotal);
  double get effectiveTotal    =>
      _serverTotal ?? (effectiveSubtotal - discountAmount).clamp(0, double.infinity);
  bool   get hasServerPricing  => _serverTotal != null;
  bool   get hasAnyPromotion   => _items.any((i) => i.hasPromotion);

  // ── Mutators ──────────────────────────────────────────────────────────────

  void addItem(ProductModel product, ProductOptionModel option) {
    // Key is product_option so the same option without promotion is separate
    // from the same option WITH a promotion — promotionId is null here (added
    // from the product grid; promotion is picked later in the cart sheet).
    final key = '${product.id}_${option.id}';
    final idx = _items.indexWhere((i) => i.key == key && !i.hasPromotion);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(
        quantity: _items[idx].quantity + 1,
        clearServerPricing: true,
      );
    } else {
      _items.add(CartItemModel(product: product, option: option));
    }
    _serverTotal = null;
    notifyListeners();
  }

  void increment(String key) {
    final idx = _items.indexWhere((i) => i.key == key);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(
      quantity: _items[idx].quantity + 1,
      clearServerPricing: true,
    );
    _serverTotal = null;
    notifyListeners();
  }

  void decrement(String key) {
    final idx = _items.indexWhere((i) => i.key == key);
    if (idx == -1) return;
    if (_items[idx].quantity <= 1) {
      _items.removeAt(idx);
    } else {
      _items[idx] = _items[idx].copyWith(
        quantity: _items[idx].quantity - 1,
        clearServerPricing: true,
      );
    }
    _serverTotal = null;
    notifyListeners();
  }

  void setQuantity(String key, int quantity) {
    final idx = _items.indexWhere((i) => i.key == key);
    if (idx == -1) return;
    if (quantity <= 0) {
      _items.removeAt(idx);
    } else {
      _items[idx] = _items[idx].copyWith(
        quantity: quantity,
        clearServerPricing: true,
      );
    }
    _serverTotal = null;
    notifyListeners();
  }

  void remove(String key) {
    _items.removeWhere((i) => i.key == key);
    _serverTotal = null;
    notifyListeners();
  }

  void setPromotion(String key, int? promotionId, {String? promotionName}) {
    final idx = _items.indexWhere((i) => i.key == key);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(
      promotionId:    promotionId,
      promotionName:  promotionName,
      clearPromotion: promotionId == null,
      clearServerPricing: true,
    );
    _serverTotal = null;
    notifyListeners();
  }

  /// FIX: clamp against best-known subtotal (server-confirmed when available).
  void setDiscount(double amount) {
    final base = hasServerPricing ? effectiveSubtotal : subtotal;
    _discount = amount.clamp(0, base);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _discount       = 0;
    _serverTotal    = null;
    _previewSyncing = false; // never leave spinner stuck after clear
    _previewPending = false;
    notifyListeners();
  }

  int quantityOf(String key) {
    for (final item in _items) {
      if (item.key == key) return item.quantity;
    }
    return 0;
  }

  // ── Server preview ────────────────────────────────────────────────────────
  //
  // Guards against concurrent calls — if a sync is in flight, marks
  // _previewPending = true and the running sync re-runs once it finishes.

  Future<void> syncPreview() async {
    if (_items.isEmpty) return;
    if (_previewSyncing) {
      _previewPending = true;
      return;
    }

    _previewSyncing = true;
    notifyListeners();

    try {
      await _doSyncPreview();
    } finally {
      _previewSyncing = false;
      final needsRetry = _previewPending;
      _previewPending  = false;
      notifyListeners();
      if (needsRetry && _items.isNotEmpty) syncPreview();
    }
  }

  Future<void> _doSyncPreview() async {
    final res = await ApiService.addToCart(_items.map((i) => i.toApiMap()).toList());
    if (!ApiService.isSuccess(res)) return;

    final data        = ApiService.extractData(res);
    final serverItems = (data?['items'] as List?) ?? const [];

    for (final raw in serverItems) {
      final m           = raw as Map<String, dynamic>;
      final code        = m['productCode']?.toString();
      // FIX: match by productCode AND promotionId together, because the same
      // productCode can appear twice (once with a promotion, once without).
      final serverPromo = (m['promotionId'] as num?)?.toInt();

      final idx = _items.indexWhere((i) =>
          i.option.productCode == code &&
          i.promotionId        == serverPromo);

      if (idx != -1) {
        _items[idx] = _items[idx].copyWith(
          serverUnitPrice: (m['unitPrice'] as num?)?.toDouble(),
          serverSubtotal:  (m['subTotal']  as num?)?.toDouble(),
        );
      }
    }
    _serverTotal = (data?['totalAmount'] as num?)?.toDouble();
  }

  // ── Checkout ──────────────────────────────────────────────────────────────
  //
  // Flow:
  //   1. POST /carts  { items: [{productCode, quantity, promotionId?}] }
  //   2. POST /orders { paymentId, discount? }

  Future<OrderModel?> checkout({required int paymentId}) async {
    if (_items.isEmpty) return null;
    _syncing = true;
    notifyListeners();

    try {
      // Step 1: sync cart to server
      final cartRes = await ApiService.addToCart(
        _items.map((i) => i.toApiMap()).toList(),
      );
      if (!ApiService.isSuccess(cartRes)) return null;

      // Step 2: create order
      final orderRes = await ApiService.createOrder(
        paymentId: paymentId,
        discount:  _discount > 0 ? _discount : null,
      );

      if (ApiService.isSuccess(orderRes)) {
        final data = ApiService.extractData(orderRes);
        final order = data != null ? OrderModel.fromMap(data) : null;
        clear();
        return order;
      }
      return null;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
