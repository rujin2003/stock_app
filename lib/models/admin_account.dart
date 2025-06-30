class AdminAccount {
  final String id;
  final String adminEmail;
  final String accountType;
  final DateTime createdAt;
  final String? notes;
  final String? upiQrCodeUrl;
  final String? upiId;
  final String? bankName;
  final String? ifscCode;
  final String? accountNo;
  final String? accountHolderName;
  final String? bankAddress;
  final String? walletName;
  final String? walletAddress;
  final String? walletNetwork;

  AdminAccount({
    required this.id,
    required this.adminEmail,
    required this.accountType,
    required this.createdAt,
    this.notes,
    this.upiQrCodeUrl,
    this.upiId,
    this.bankName,
    this.ifscCode,
    this.accountNo,
    this.accountHolderName,
    this.bankAddress,
    this.walletName,
    this.walletAddress,
    this.walletNetwork,
  });

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    return AdminAccount(
      id: json['id'],
      adminEmail: json['admin_email'],
      accountType: json['account_type'],
      createdAt: DateTime.parse(json['created_at']),
      notes: json['notes'],
      upiQrCodeUrl: json['upi_qr_code_url'],
      upiId: json['upi_id'],
      bankName: json['bank_name'],
      ifscCode: json['ifsc_code'],
      accountNo: json['account_no'],
      accountHolderName: json['account_holder_name'],
      bankAddress: json['bank_address'],
      walletName: json['wallet_name'],
      walletAddress: json['wallet_address'],
      walletNetwork: json['wallet_network'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_email': adminEmail,
      'account_type': accountType,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
      'upi_qr_code_url': upiQrCodeUrl,
      'upi_id': upiId,
      'bank_name': bankName,
      'ifsc_code': ifscCode,
      'account_no': accountNo,
      'account_holder_name': accountHolderName,
      'bank_address': bankAddress,
      'wallet_name': walletName,
      'wallet_address': walletAddress,
      'wallet_network': walletNetwork,
    };
  }
} 