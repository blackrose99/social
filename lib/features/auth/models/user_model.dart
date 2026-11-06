// lib/features/auth/models/user_model.dart
class UserModel {
  final String id;
  final String username;
  final String passwordHash;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'username': username.toLowerCase().trim(),
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['_id']?.toString() ?? '',
      username: map['username'] ?? '',
      passwordHash: map['password_hash'] ?? '',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
