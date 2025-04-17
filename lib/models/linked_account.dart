import 'package:supabase_flutter/supabase_flutter.dart';

class LinkedAccount {
  final String id;
  final String email;
  final String? photoUrl;
  final DateTime addedAt;
  final String? refreshToken;
  final String? accessToken;

  LinkedAccount({
    required this.id,
    required this.email,
    this.photoUrl,
    this.refreshToken,
    this.accessToken,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory LinkedAccount.fromUser(User user,
      {String? refreshToken, String? accessToken}) {
    return LinkedAccount(
      id: user.id,
      email: user.email ?? user.userMetadata?['email'] ?? 'Unknown',
      photoUrl: user.userMetadata?['avatar_url'],
      refreshToken: refreshToken,
      accessToken: accessToken,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'photoUrl': photoUrl,
      'addedAt': addedAt.toIso8601String(),
      'refreshToken': refreshToken,
      'accessToken': accessToken,
    };
  }

  factory LinkedAccount.fromJson(Map<String, dynamic> json) {
    return LinkedAccount(
      id: json['id'],
      email: json['email'],
      photoUrl: json['photoUrl'],
      addedAt: DateTime.parse(json['addedAt']),
      refreshToken: json['refreshToken'],
      accessToken: json['accessToken'],
    );
  }
}
