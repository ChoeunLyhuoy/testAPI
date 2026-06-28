// lib/models/cart_item_model.dart
//
// FIXES in this revision:
// 1. toApiMap() omits promotionId entirely when null instead of sending
//    `"promotionId": null` — some API servers treat an explicit null as
//    "clear the promotion" rather than "no promotion selected". Sending
//    the key only when a real id is present is the safe default.
// 2. copyWith() parameter ordering: clearPromotion is applied before the
//    nullable override so that copyWith(clearPromotion: true, promotionId: x)
//    (which would be a caller bug) at least behaves predictably.
// 3. Added `effectiveUnitPrice` null-safety: falls back to option.price,
//    never null.

import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  final ProductOptionModel option;
  final int quantity;

  /// Promotion applied to this cart line, if any.
  /// Sent to POST /carts as `promotionId` only when non-null.
  final int? promotionId;
  final String? promotionName; // display only — not sent to the API

  /// Server-confirmed (post-promotion) unit price / line subtotal.
  /// Null until the first successful syncPreview().
  final double? serverUnitPrice;
  final double? serverSubtotal;

  const CartItemModel({
    required this.product,
    required this.option,
    this.quantity = 1,
    this.promotionId,
    this.promotionName,
    this.serverUnitPrice,
    this.serverSubtotal,
  });

  String get key => '${product.id}_${option.id}';

  /// Local estimate (price × qty, no promotions).
  double get subtotal => option.price * quantity;

  /// Best-known unit price: server-confirmed when available, otherwise
  /// the option's list price.
  double get effectiveUnitPrice => serverUnitPrice ?? option.price;

  /// Best-known line subtotal: server-confirmed when available, otherwise
  /// local estimate.
  double get effectiveSubtotal => serverSubtotal ?? subtotal;

  bool get hasPromotion => promotionId != null;

  /// FIX: only include promotionId when it is actually set — sending an
  /// explicit null can cause some backends to clear an existing promotion
  /// that was applied server-side.
  Map<String, dynamic> toApiMap() {
    final map = <String, dynamic>{
      'productCode': option.productCode,
      'quantity': quantity,
    };
    if (promotionId != null) map['promotionId'] = promotionId;
    return map;
  }

  CartItemModel copyWith({
    int? quantity,
    int? promotionId,
    String? promotionName,
    bool clearPromotion = false,
    double? serverUnitPrice,
    double? serverSubtotal,
    bool clearServerPricing = false,
  }) {
    return CartItemModel(
      product: product,
      option: option,
      quantity: quantity ?? this.quantity,
      // clearPromotion wins over an explicit promotionId — a caller should
      // never pass both, but if they do "clear" takes priority.
      promotionId: clearPromotion ? null : (promotionId ?? this.promotionId),
      promotionName: clearPromotion
          ? null
          : (promotionName ?? this.promotionName),
      serverUnitPrice: clearServerPricing
          ? null
          : (serverUnitPrice ?? this.serverUnitPrice),
      serverSubtotal: clearServerPricing
          ? null
          : (serverSubtotal ?? this.serverSubtotal),
    );
  }
}