// lib/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatar;
  final String accessToken;
  final String refreshToken;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    required this.accessToken,
    required this.refreshToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
        id: m['id']?.toString() ?? '',
        email: m['email']?.toString() ?? '',
        name: m['name']?.toString() ?? m['username']?.toString() ?? '',
        avatar: m['avatar']?.toString(),
        accessToken: m['accessToken']?.toString() ?? '',
        refreshToken: m['refreshToken']?.toString() ?? '',
      );

  @override
  String toString() => 'UserModel(id: $id, email: $email, name: $name)';
}
