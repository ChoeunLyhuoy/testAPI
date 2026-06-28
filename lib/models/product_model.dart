// lib/models/product_model.dart
// Synced with actual API JSON response

class ProductOptionModel {
  final String id;          // optionId from API
  final String productCode; // required for cart API
  final double price;
  final double? unitCost;   // e.g. 56.99 — internal cost, optional
  final int quantity;       // stock qty for this option
  final String? imageUrl;
  final String? ramSize;    // e.g. "RAM_8GB"
  final String? storageSize;// e.g. "STORAGE_128GB"

  const ProductOptionModel({
    required this.id,
    required this.productCode,
    required this.price,
    this.unitCost,
    required this.quantity,
    this.imageUrl,
    this.ramSize,
    this.storageSize,
  });

  int get stock => quantity;

  /// Profit margin per unit (price - unitCost), null if unitCost is unknown
  double? get margin => unitCost != null ? price - unitCost! : null;

  // Display label: "8GB / 128GB"
  String get specLabel {
    final ram = ramSize?.replaceAll('RAM_', '').replaceAll('GB', 'GB RAM');
    final storage = storageSize?.replaceAll('STORAGE_', '');
    if (ram != null && storage != null) return '$ram / $storage';
    if (ram != null) return ram;
    if (storage != null) return storage;
    return productCode;
  }

  factory ProductOptionModel.fromMap(Map<String, dynamic> m) =>
      ProductOptionModel(
        // API returns optionId (not id) inside options array
        id: m['optionId']?.toString() ?? m['id']?.toString() ?? '',
        productCode: m['productCode']?.toString() ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
        // FIX: the API writes this field as "unitCost" on create/update
        // (confirmed in Postman) but reads it back as "unitPrice" on the
        // list/get response (confirmed in the actual JSON payload). Reading
        // only "unitCost" meant this was always null after a fresh load —
        // check both names so it works regardless of which one the server
        // uses for a given endpoint.
        unitCost: (m['unitPrice'] as num?)?.toDouble() ??
            (m['unitCost'] as num?)?.toDouble(),
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        imageUrl: _parseUrl(m['image']),
        ramSize: m['ramSize']?.toString(),
        storageSize: m['storageSize']?.toString(),
      );

  static String? _parseUrl(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    // Store the raw URL — ImageHelper.resolve() will fix localhost at render time
    return s;
  }

  ProductOptionModel copyWith({
    String? id,
    String? productCode,
    double? price,
    double? unitCost,
    int? quantity,
    String? imageUrl,
    String? ramSize,
    String? storageSize,
  }) {
    return ProductOptionModel(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      price: price ?? this.price,
      unitCost: unitCost ?? this.unitCost,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      ramSize: ramSize ?? this.ramSize,
      storageSize: storageSize ?? this.storageSize,
    );
  }
}

class ProductModel {
  final String id;
  final String name;
  final String? description;
  final String? category;     // category name string from API
  final String? categoryId;   // not returned by API list, only on create
  final int totalQuantity;    // sum of all option qtys
  final String? supplierName;
  final List<ProductOptionModel> options;

  const ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.categoryId,
    required this.totalQuantity,
    this.supplierName,
    required this.options,
  });

  /// Constructs a minimal ProductModel from a barcode / option-lookup response.
  /// The /products/options/code/{code} endpoint returns option-level data;
  /// we build the parent ProductModel from the product fields nested inside it.
  factory ProductModel.fromOptionLookup(Map<String, dynamic> m) {
    // The lookup response may nest product info under a 'product' key,
    // or inline it at the top level — handle both shapes.
    final p = (m['product'] as Map<String, dynamic>?) ?? m;
    final option = ProductOptionModel.fromMap(m);
    return ProductModel(
      id: p['id']?.toString() ?? p['productId']?.toString() ?? '',
      name: p['name']?.toString() ?? p['productName']?.toString() ?? '',
      description: p['description']?.toString(),
      category: p['category']?.toString(),
      categoryId: p['categoryId']?.toString(),
      totalQuantity: option.quantity,
      supplierName: p['supplierName']?.toString(),
      options: [option],
    );
  }

  factory ProductModel.fromMap(Map<String, dynamic> m) {
    final opts = (m['options'] as List?)
        ?.map((o) => ProductOptionModel.fromMap(o as Map<String, dynamic>))
        .toList() ??
        [];
    return ProductModel(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString(),
      category: m['category']?.toString(),
      // API list response does NOT return categoryId — only category name
      categoryId: m['categoryId']?.toString(),
      totalQuantity: (m['quantity'] as num?)?.toInt() ??
          (m['totalQuantity'] as num?)?.toInt() ??
          0,
      supplierName: m['supplierName']?.toString(),
      options: opts,
    );
  }

  ProductOptionModel? get firstOption =>
      options.isNotEmpty ? options.first : null;

  double get price => firstOption?.price ?? 0.0;

  double? get unitCost => firstOption?.unitCost;

  /// Returns first non-null image URL across all options
  String? get imageUrl {
    for (final opt in options) {
      if (opt.imageUrl != null && opt.imageUrl!.isNotEmpty) {
        return opt.imageUrl;
      }
    }
    return null;
  }

  int get stock => totalQuantity;

  @override
  String toString() => 'ProductModel($id, $name, opts:${options.length})';
}