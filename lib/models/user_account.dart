class UserAccount {
  final String id;
  final String userId;
  final String? bankName;
  final String? ifscCode;
  final String? bankAddress;
  final String? accountNo;
  final String? fullName;
  final String accountType;
  final String? upiId;
  final String? walletAddress;
  final DateTime createdAt;

  UserAccount({
    required this.id,
    required this.userId,
    this.bankName,
    this.ifscCode,
    this.bankAddress,
    this.accountNo,
    this.fullName,
    required this.accountType,
    this.upiId,
    this.walletAddress,
    required this.createdAt,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'],
      userId: json['user_id'],
      bankName: json['bank_name'],
      ifscCode: json['ifsc_code'],
      bankAddress: json['bank_address'],
      accountNo: json['account_no'],
      fullName: json['full_name'],
      accountType: json['account_type'],
      upiId: json['upi_id'],
      walletAddress: json['wallet_address'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bank_name': bankName,
      'ifsc_code': ifscCode,
      'bank_address': bankAddress,
      'account_no': accountNo,
      'full_name': fullName,
      'account_type': accountType,
      'upi_id': upiId,
      'wallet_address': walletAddress,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 