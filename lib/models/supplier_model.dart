// lib/models/supplier_model.dart
// Matches SupplierResponse: { supplierName, contactName, contactEmail,
//   contactPhone, image }
//
// NOTE: the sample list response has no "id" field at all:
//   { "supplierName": "Ko", "contactName": "ja", ... }  ← no id
// but update/delete both require {{supplierId}} in the URL path. If the
// backend really omits id on the list endpoint, update/delete can't work
// for any supplier loaded from that list — this needs a backend fix.
// In the meantime, fromMap checks a few likely alternate key names so the
// screen at least works if the API uses a different field name than "id".

class SupplierModel {
  final String id;
  final String name;       // supplierName
  final String? contactName;
  final String phone;      // contactPhone
  final String email;      // contactEmail
  final String? imageUrl;

  const SupplierModel({
    required this.id,
    required this.name,
    this.contactName,
    required this.phone,
    required this.email,
    this.imageUrl,
  });

  static String? _clean(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (s.toLowerCase() == 'null' || s.isEmpty) return null;
    return s;
  }

  factory SupplierModel.fromMap(Map<String, dynamic> m) => SupplierModel(
    id: _clean(m['id']) ??
        _clean(m['supplierId']) ??
        _clean(m['_id']) ??
        '',
    name: _clean(m['supplierName']) ?? _clean(m['name']) ?? '',
    contactName: _clean(m['contactName']),
    phone: _clean(m['contactPhone']) ?? '',
    email: _clean(m['contactEmail']) ?? '',
    imageUrl: _clean(m['image']),
  );

  String get initials => name.isNotEmpty ? name[0].toUpperCase() : 'S';
}