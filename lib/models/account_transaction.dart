import 'package:stock_app/models/user_account.dart';
import 'package:stock_app/models/admin_account.dart';

class AccountTransaction {
  final String id;
  final String userId;
  final String? verifiedBy;
  final DateTime createdAt;
  final DateTime? verifiedTime;
  final String transactionType;
  final double amount;
  final bool verified;
  final String? paymentProof;
  final double? userCurrentBalance;
  final String? accountBalanceId;
  final String? notes;
  final String? accountInfoId;
  final String? adminAccountInfoId;
  final Map<String, dynamic>? userAccount;
  final Map<String, dynamic>? adminAccount;

  AccountTransaction({
    required this.id,
    required this.userId,
    this.verifiedBy,
    required this.createdAt,
    this.verifiedTime,
    required this.transactionType,
    required this.amount,
    required this.verified,
    this.paymentProof,
    this.userCurrentBalance,
    this.accountBalanceId,
    this.notes,
    this.accountInfoId,
    this.adminAccountInfoId,
    this.userAccount,
    this.adminAccount,
  });

  factory AccountTransaction.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AccountTransaction(
        id: '',
        userId: '',
        createdAt: DateTime.now(),
        transactionType: 'deposit',
        amount: 0,
        verified: false,
      );
    }

    return AccountTransaction(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      verifiedBy: json['verified_by']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      verifiedTime: json['verified_time'] != null 
          ? DateTime.tryParse(json['verified_time'] as String)
          : null,
      transactionType: json['transaction_type']?.toString() ?? 'deposit',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      verified: json['verified'] as bool? ?? false,
      paymentProof: json['payment_proof']?.toString(),
      userCurrentBalance: (json['user_current_balance'] as num?)?.toDouble(),
      accountBalanceId: json['account_balance_id']?.toString(),
      notes: json['notes']?.toString(),
      accountInfoId: json['account_info_id']?.toString(),
      adminAccountInfoId: json['admin_account_info_id']?.toString(),
      userAccount: json['user_account'] as Map<String, dynamic>?,
      adminAccount: json['admin_account'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'verified_by': verifiedBy,
      'created_at': createdAt.toIso8601String(),
      'verified_time': verifiedTime?.toIso8601String(),
      'transaction_type': transactionType,
      'amount': amount,
      'verified': verified,
      'payment_proof': paymentProof,
      'user_current_balance': userCurrentBalance,
      'account_balance_id': accountBalanceId,
      'notes': notes,
      'account_info_id': accountInfoId,
      'admin_account_info_id': adminAccountInfoId,
    };
  }
} 