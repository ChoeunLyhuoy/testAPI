// lib/models/payment_model.dart
// Matches PaymentResponse: { name, description, active, image }

class PaymentModel {
  final String id;
  final String name;
  final String? description;
  final bool active;
  final String? imageUrl;

  const PaymentModel({
    required this.id,
    required this.name,
    this.description,
    this.active = true,
    this.imageUrl,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> m) => PaymentModel(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        description: m['description']?.toString(),
        active: m['active'] as bool? ?? true,
        imageUrl: m['image']?.toString(),
      );
}
