class AdminAccount {
  final String id;
  final String accountName;
  final String accountNumber;
  final String accountType;
  final String? bankName;
  final String? ifscCode;
  final String? upiId;
  final String? cryptoAddress;
  final String? cryptoType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AdminAccount({
    required this.id,
    required this.accountName,
    required this.accountNumber,
    required this.accountType,
    this.bankName,
    this.ifscCode,
    this.upiId,
    this.cryptoAddress,
    this.cryptoType,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory AdminAccount.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AdminAccount(
        id: '',
        accountName: '',
        accountNumber: '',
        accountType: 'bank',
        isActive: true,
        createdAt: DateTime.now(),
      );
    }

    return AdminAccount(
      id: json['id']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      accountType: json['account_type']?.toString() ?? 'bank',
      bankName: json['bank_name']?.toString(),
      ifscCode: json['ifsc_code']?.toString(),
      upiId: json['upi_id']?.toString(),
      cryptoAddress: json['crypto_address']?.toString(),
      cryptoType: json['crypto_type']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
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
      'account_name': accountName,
      'account_number': accountNumber,
      'account_type': accountType,
      'bank_name': bankName,
      'ifsc_code': ifscCode,
      'upi_id': upiId,
      'crypto_address': cryptoAddress,
      'crypto_type': cryptoType,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
} 