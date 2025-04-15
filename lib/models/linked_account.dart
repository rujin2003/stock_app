import 'package:supabase_flutter/supabase_flutter.dart';

class LinkedAccount {
  final String id;
  final String email;
  final String? photoUrl;
  final DateTime addedAt;

  LinkedAccount({
    required this.id,
    required this.email,
    this.photoUrl,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory LinkedAccount.fromUser(User user) {
    return LinkedAccount(
      id: user.id,
      email: user.email ?? 'Unknown',
      photoUrl: user.userMetadata?['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'photoUrl': photoUrl,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory LinkedAccount.fromJson(Map<String, dynamic> json) {
    return LinkedAccount(
      id: json['id'],
      email: json['email'],
      photoUrl: json['photoUrl'],
      addedAt: DateTime.parse(json['addedAt']),
    );
  }
}
