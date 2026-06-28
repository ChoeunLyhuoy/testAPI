// lib/models/order_model.dart
//
// LIST  GET /api/v1/orders  → ListOrderResponse shape:
//   { id, transactionRef, userId, paymentName,
//     subtotalAmount, discountAmount, totalAmount, createdAt }
//
// DETAIL GET /api/v1/orders/{id}  → OrderResponse shape:
//   { id, transactionRef, userId, paymentId, paymentName,
//     subtotalAmount, promotionDiscountAmount, extraDiscountAmount,
//     totalAmount, appliedPromotionIds, createdAt, items: [...] }

class OrderItemModel {
  final String  id;
  final int     productOptionId;
  final String  productName;          // JSON: "productName"
  final String  productCode;          // JSON: "productCode"
  final int     quantity;             // JSON: "quantity"
  final double  unitPrice;            // JSON: "unitPrice"
  final double  discountedUnitPrice;  // JSON: "discountedUnitPrice"
  final double  subTotal;             // JSON: "subTotal"
  final String? imageUrl;             // JSON: "image"
  final int?    promotionId;          // JSON: "promotionId"

  const OrderItemModel({
    required this.id,
    required this.productOptionId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    required this.discountedUnitPrice,
    required this.subTotal,
    this.imageUrl,
    this.promotionId,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> m) {
    return OrderItemModel(
      id:                  m['id']?.toString() ?? '',
      productOptionId:     (m['productOptionId'] as num?)?.toInt() ?? 0,
      productName:         m['productName']?.toString() ?? '',
      productCode:         m['productCode']?.toString() ?? '',
      quantity:            (m['quantity'] as num?)?.toInt() ?? 0,
      unitPrice:           (m['unitPrice'] as num?)?.toDouble() ?? 0.0,
      discountedUnitPrice: (m['discountedUnitPrice'] as num?)?.toDouble() ?? 0.0,
      subTotal:            (m['subTotal'] as num?)?.toDouble() ?? 0.0,
      imageUrl:            m['image']?.toString(),
      promotionId:         (m['promotionId'] as num?)?.toInt(),
    );
  }
}

class OrderModel {
  final String  id;                          // JSON: "id"
  final String  transactionRef;              // JSON: "transactionRef"
  final int?    userId;                      // JSON: "userId"
  final int?    paymentId;                   // JSON: "paymentId"   (detail only)
  final String? paymentName;                 // JSON: "paymentName"
  final double  subtotalAmount;              // JSON: "subtotalAmount"

  /// LIST  → comes as "discountAmount" (promotion + extra merged)
  /// DETAIL → computed from "promotionDiscountAmount" + "extraDiscountAmount"
  final double  promotionDiscountAmount;     // JSON: "promotionDiscountAmount" (detail)
  final double  extraDiscountAmount;         // JSON: "extraDiscountAmount"     (detail)

  final double  totalAmount;                 // JSON: "totalAmount"
  final List<int> appliedPromotionIds;       // JSON: "appliedPromotionIds"     (detail only)
  final List<OrderItemModel> items;          // JSON: "items"                   (detail only)
  final DateTime? createdAt;                 // JSON: "createdAt"

  const OrderModel({
    required this.id,
    required this.transactionRef,
    this.userId,
    this.paymentId,
    this.paymentName,
    required this.subtotalAmount,
    required this.promotionDiscountAmount,
    required this.extraDiscountAmount,
    required this.totalAmount,
    this.appliedPromotionIds = const [],
    this.items = const [],
    this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> m) {
    // ── createdAt ──────────────────────────────────────────────────────────
    DateTime? dt;
    final rawDate = m['createdAt']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try { dt = DateTime.parse(rawDate); } catch (_) {}
    }

    // ── discount fields ────────────────────────────────────────────────────
    // DETAIL shape has both fields split out.
    // LIST shape only has "discountAmount" (merged); treat it as promotionDiscount.
    final double promotionDiscount =
        (m['promotionDiscountAmount'] as num?)?.toDouble()
            ?? (m['discountAmount']        as num?)?.toDouble()
            ?? 0.0;

    final double extraDiscount =
        (m['extraDiscountAmount'] as num?)?.toDouble() ?? 0.0;

    // ── items (detail only — list response has no items field) ─────────────
    final rawItems = m['items'];
    final List<OrderItemModel> itemList = rawItems is List
        ? rawItems
        .whereType<Map<String, dynamic>>()
        .map(OrderItemModel.fromMap)
        .toList()
        : [];

    // ── appliedPromotionIds (detail only) ──────────────────────────────────
    final rawPromos = m['appliedPromotionIds'];
    final List<int> promoIds = rawPromos is List
        ? rawPromos.map((e) => (e as num).toInt()).toList()
        : [];

    return OrderModel(
      id:                       m['id']?.toString() ?? '',
      transactionRef:           m['transactionRef']?.toString() ?? '',
      userId:                   (m['userId']    as num?)?.toInt(),
      paymentId:                (m['paymentId'] as num?)?.toInt(),
      paymentName:              m['paymentName']?.toString(),
      subtotalAmount:           (m['subtotalAmount'] as num?)?.toDouble() ?? 0.0,
      promotionDiscountAmount:  promotionDiscount,
      extraDiscountAmount:      extraDiscount,
      totalAmount:              (m['totalAmount'] as num?)?.toDouble()
          ?? (m['total']       as num?)?.toDouble() ?? 0.0,
      appliedPromotionIds:      promoIds,
      items:                    itemList,
      createdAt:                dt,
    );
  }

  /// Total discount shown in UI (both sources combined)
  double get discountTotal => promotionDiscountAmount + extraDiscountAmount;
}