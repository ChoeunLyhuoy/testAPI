// lib/models/category_model.dart
// Matches CategoryResponse: { id, name, description, image }

class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        description: m['description']?.toString(),
        imageUrl: m['image']?.toString(),
      );
}
