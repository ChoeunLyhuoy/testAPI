// lib/models/purchase_model.dart

class PurchaseItemModel {
  final String productName;
  final String productCode;
  final int quantity;
  final double unitCost;
  final double unitPrice;
  // ADDED: the detail endpoint (GET /purchases/{id}) returns these per
  // item, but they were never parsed, so the purchase screen couldn't
  // show which variant an item was, or its photo.
  final String? ramSize;     // raw enum from API, e.g. "RAM_32GB"
  final String? storageSize; // raw enum from API, e.g. "STORAGE_1TB"
  final String? imageUrl;    // mapped from API field "image"

  const PurchaseItemModel({
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitCost,
    required this.unitPrice,
    this.ramSize,
    this.storageSize,
    this.imageUrl,
  });

  factory PurchaseItemModel.fromMap(Map<String, dynamic> m) =>
      PurchaseItemModel(
        productName: m['productName']?.toString() ?? m['name']?.toString() ?? '',
        productCode: m['productCode']?.toString() ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        unitCost: (m['unitCost'] as num?)?.toDouble() ?? 0,
        unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
        ramSize: m['ramSize']?.toString(),
        storageSize: m['storageSize']?.toString(),
        imageUrl: m['image']?.toString(),
      );

  /// "32GB RAM / 1TB" — lets two items that share a product name (e.g. two
  /// "kok" lines, one 32GB/1TB and one 32GB/512GB) be told apart in the
  /// purchase history UI instead of looking identical.
  String get specLabel {
    final parts = <String>[];
    if (ramSize != null && ramSize!.isNotEmpty) {
      parts.add('${ramSize!.replaceFirst('RAM_', '')} RAM');
    }
    if (storageSize != null && storageSize!.isNotEmpty) {
      parts.add(storageSize!.replaceFirst('STORAGE_', ''));
    }
    return parts.join(' / ');
  }

// FIX (kept from previous revision): removed the broken `get price =>
// null;` stub. It returned null unconditionally, so `item.price *
// item.quantity` crashed at runtime (null has no operator*). Purchases
// record what was paid to the supplier, so `unitCost` is the correct
// field — use `unitPrice` only if you specifically need the sale price.
}

class PurchaseModel {
  final String id;
  final String? purchaseNumber;
  final String? supplierName;
  final String? note;
  final double totalAmount;
  final DateTime createdAt;
  final List<PurchaseItemModel> items;

  const PurchaseModel({
    required this.id,
    this.purchaseNumber,
    this.supplierName,
    this.note,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  static String? _clean(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (s.toLowerCase() == 'null' || s.isEmpty) return null;
    return s;
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> m) {
    DateTime dt;
    try { dt = DateTime.parse(m['createdAt']?.toString() ?? ''); }
    catch (_) { dt = DateTime.now(); }
    return PurchaseModel(
      id: _clean(m['id']) ?? '',
      purchaseNumber: _clean(m['purchaseNumber']),
      supplierName: _clean(m['supplierName']) ?? _clean(m['supplier']),
      note: _clean(m['note']),
      totalAmount: (m['totalAmount'] as num?)?.toDouble() ??
          (m['total'] as num?)?.toDouble() ?? 0,
      createdAt: dt,
      items: (m['items'] as List? ?? [])
          .map((i) => PurchaseItemModel.fromMap(i as Map<String, dynamic>))
          .toList(),
    );
  }
}