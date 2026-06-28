// lib/models/customer_model.dart
// Matches CustomerResponse: { id, firstName, lastName, userName, email,
//   phoneNumber, password, address, role }

class CustomerModel {
  final String id;
  final String firstName;
  final String lastName;
  final String userName;
  final String email;
  final String phone;
  final String? address;

  const CustomerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.email,
    required this.phone,
    this.address,
  });

  static String? _clean(dynamic val) {
    if (val == null) return null;
    final s = val.toString().trim();
    if (s.toLowerCase() == 'null' || s.isEmpty) return null;
    return s;
  }

  factory CustomerModel.fromMap(Map<String, dynamic> m) => CustomerModel(
        id: _clean(m['id']) ?? '',
        firstName: _clean(m['firstName']) ?? '',
        lastName: _clean(m['lastName']) ?? '',
        userName: _clean(m['userName']) ?? '',
        email: _clean(m['email']) ?? '',
        phone: _clean(m['phoneNumber']) ?? _clean(m['phone']) ?? '',
        address: _clean(m['address']),
      );

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return (f + l).toUpperCase().isNotEmpty ? (f + l).toUpperCase() : 'C';
  }
}
