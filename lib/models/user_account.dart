class UserAccount {
  final String id;
  final String userId;
  final String accountNumber;
  final String accountName;
  final String bankName;
  final String? branchName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserAccount({
    required this.id,
    required this.userId,
    required this.accountNumber,
    required this.accountName,
    required this.bankName,
    this.branchName,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserAccount.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return UserAccount(
        id: '',
        userId: '',
        accountNumber: '',
        accountName: '',
        bankName: '',
        createdAt: DateTime.now(),
      );
    }

    return UserAccount(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      branchName: json['branch_name']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'account_number': accountNumber,
      'account_name': accountName,
      'bank_name': bankName,
      'branch_name': branchName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
} 