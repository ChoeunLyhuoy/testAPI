// lib/models/promotion_model.dart

class PromotionProductModel {
  final int    productPromotionId;
  final String productCode;
  final String productName;
  final int    quantity;

  const PromotionProductModel({
    required this.productPromotionId,
    required this.productCode,
    required this.productName,
    required this.quantity,
  });

  factory PromotionProductModel.fromMap(Map<String, dynamic> m) =>
      PromotionProductModel(
        productPromotionId: (m['productPromotionId'] as num?)?.toInt() ?? 0,
        productCode: m['productCode']?.toString() ?? '',
        productName: m['productName']?.toString() ?? '',
        quantity:    (m['quantity'] as num?)?.toInt() ?? 0,
      );
}

class PromotionModel {
  final String  id;
  final String  name;
  final String? description;
  final double  discountAmount;
  final String  discountType;    // 'PERCENTAGE' | 'FIXED'
  final DateTime? startDate;
  final DateTime? endDate;
  final List<PromotionProductModel> products;

  const PromotionModel({
    required this.id,
    required this.name,
    this.description,
    required this.discountAmount,
    required this.discountType,
    this.startDate,
    this.endDate,
    required this.products,
  });

  /// Human-readable discount label: "10%" or "\$5.00"
  String get discountLabel {
    if (discountType == 'PERCENTAGE') {
      return '${discountAmount.toStringAsFixed(discountAmount.truncateToDouble() == discountAmount ? 0 : 2)}%';
    }
    return '\$${discountAmount.toStringAsFixed(2)}';
  }

  bool get isActive {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate   != null && now.isAfter(endDate!))    return false;
    return true;
  }

  factory PromotionModel.fromMap(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try { return DateTime.parse(v.toString()); } catch (_) { return null; }
    }

    final rawProducts = m['products'] as List? ?? [];
    return PromotionModel(
      id:             m['id']?.toString() ?? '',
      name:           m['name']?.toString() ?? '',
      description:    m['description']?.toString(),
      discountAmount: (m['discountAmount'] as num?)?.toDouble() ?? 0,
      discountType:   m['discountType']?.toString() ?? 'PERCENTAGE',
      startDate:      parseDate(m['startDate']),
      endDate:        parseDate(m['endDate']),
      products:       rawProducts
          .map((e) => PromotionProductModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
