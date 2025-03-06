class UserBalance {
  final String userId;
  final double balance;
  final DateTime lastUpdated;

  UserBalance({
    required this.userId,
    required this.balance,
    required this.lastUpdated,
  });

  factory UserBalance.fromJson(Map<String, dynamic> json) {
    return UserBalance(
      userId: json['user_id'],
      balance: json['balance'].toDouble(),
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'balance': balance,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
