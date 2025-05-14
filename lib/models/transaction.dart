import 'package:flutter/material.dart';
import 'account_balance.dart';

class Transaction {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String? description;
  final String? relatedTradeId;
  final DateTime createdAt;
  final bool verified;
  final String? verifiedBy;
  final DateTime? verifiedTime;
  final String? paymentProof;
  final double? userCurrentBalance;
  final String? accountBalanceId;
  final String? accountInfoId;
  final String? adminAccountInfoId;

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.description,
    this.relatedTradeId,
    required this.createdAt,
    this.verified = false,
    this.verifiedBy,
    this.verifiedTime,
    this.paymentProof,
    this.userCurrentBalance,
    this.accountBalanceId,
    this.accountInfoId,
    this.adminAccountInfoId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'].toString(),
      userId: json['user_id'],
      type: TransactionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      amount: json['amount'].toDouble(),
      description: json['description'],
      relatedTradeId: json['related_trade_id'],
      createdAt: DateTime.parse(json['created_at']),
      verified: json['verified'] ?? false,
      verifiedBy: json['verified_by'],
      verifiedTime: json['verified_time'] != null ? DateTime.parse(json['verified_time']) : null,
      paymentProof: json['payment_proof'],
      userCurrentBalance: json['user_current_balance']?.toDouble(),
      accountBalanceId: json['account_balance_id'],
      accountInfoId: json['account_info_id'],
      adminAccountInfoId: json['admin_account_info_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.toString().split('.').last,
      'amount': amount,
      'description': description,
      'related_trade_id': relatedTradeId,
      'created_at': createdAt.toIso8601String(),
      'verified': verified,
      'verified_by': verifiedBy,
      'verified_time': verifiedTime?.toIso8601String(),
      'payment_proof': paymentProof,
      'user_current_balance': userCurrentBalance,
      'account_balance_id': accountBalanceId,
      'account_info_id': accountInfoId,
      'admin_account_info_id': adminAccountInfoId,
    };
  }

  // Get color based on transaction type
  Color getColor(BuildContext context) {
    final theme = Theme.of(context);

    switch (type) {
      case TransactionType.deposit:
      case TransactionType.profit:
      case TransactionType.credit:
        return Colors.green;
      case TransactionType.withdrawal:
      case TransactionType.loss:
      case TransactionType.fee:
        return Colors.red;
      case TransactionType.adjustment:
        return theme.colorScheme.primary;
    }
  }

  // Get icon based on transaction type
  IconData getIcon() {
    switch (type) {
      case TransactionType.deposit:
        return Icons.arrow_downward;
      case TransactionType.withdrawal:
        return Icons.arrow_upward;
      case TransactionType.profit:
        return Icons.trending_up;
      case TransactionType.loss:
        return Icons.trending_down;
      case TransactionType.credit:
        return Icons.credit_card;
      case TransactionType.fee:
        return Icons.money_off;
      case TransactionType.adjustment:
        return Icons.settings;
    }
  }

  // Get display name for transaction type
  String getTypeDisplayName() {
    switch (type) {
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.profit:
        return 'Profit';
      case TransactionType.loss:
        return 'Loss';
      case TransactionType.credit:
        return 'Credit';
      case TransactionType.fee:
        return 'Fee';
      case TransactionType.adjustment:
        return 'Adjustment';
    }
  }

  // Get verification status display
  String getVerificationStatus() {
    if (!verified) return 'Pending';
    return 'Verified';
  }

  // Get verification status color
  Color getVerificationStatusColor() {
    return verified ? Colors.green : Colors.orange;
  }
} 