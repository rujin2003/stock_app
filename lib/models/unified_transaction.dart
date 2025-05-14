
import 'package:flutter/material.dart'; // For DateTimeRange

// Helper to categorize the source of the transaction
enum TransactionSource {
  account, // From account_transactions (deposits, withdrawals)
  system,  // From transactions (trade-related, fees, etc.)
}

// Helper to give a more specific type, especially for UI logic (e.g., icons, colors)
enum UnifiedTransactionCategory {
  deposit,
  withdraw,
  profit,
  loss,
  fee,
  commission,
  interest,
  dividend,
  adjustment,
  other,
}

class UnifiedTransaction {
  final String id;
  final String userId;
  final DateTime createdAt;
  final double amount; // Positive for credits to user, negative for debits
  final String displayType; // User-friendly type string, e.g., "Deposit", "Trade Profit"
  final TransactionSource source;
  final UnifiedTransactionCategory category;
  final String? originalTypeFromDb; // The raw 'type' or 'transaction_type' from DB

  final String? description;

  // Fields specific to account_transactions (source == TransactionSource.account)
  final bool? isVerified;
  final String? paymentProofUrl;
  final String? notes; // Can be part of description or separate
  final DateTime? verifiedTime;

  // Fields specific to transactions (source == TransactionSource.system)
  final String? relatedTradeId;

  UnifiedTransaction({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.amount,
    required this.displayType,
    required this.source,
    required this.category,
    this.originalTypeFromDb,
    this.description,
    this.isVerified,
    this.paymentProofUrl,
    this.notes,
    this.verifiedTime,
    this.relatedTradeId,
  });

  // Factory constructor for transactions from 'transactions' table
  factory UnifiedTransaction.fromSystemTransaction(Map<String, dynamic> data) {
    final rawType = data['type'] as String? ?? 'unknown';
    double originalAmount = (data['amount'] as num? ?? 0.0).toDouble();

    // Determine category and adjust amount sign if necessary
    // This logic depends on how 'amount' and 'type' are stored in 'transactions'
    // Assuming 'amount' is signed for profits/losses, or positive and type indicates debit.
    // For simplicity, let's assume 'amount' from DB is already correctly signed.
    // If not, adjust here based on 'rawType'. E.g.:
    // if (rawType == 'loss' && originalAmount > 0) originalAmount = -originalAmount;

    UnifiedTransactionCategory category;
    switch (rawType.toLowerCase()) {
      case 'profit':
      case 'trade_profit':
        category = UnifiedTransactionCategory.profit;
        break;
      case 'loss':
      case 'trade_loss':
        category = UnifiedTransactionCategory.loss;
        // Ensure amount is negative for losses if not already
        if (originalAmount > 0) originalAmount = -originalAmount;
        break;
      case 'fee':
        category = UnifiedTransactionCategory.fee;
        if (originalAmount > 0) originalAmount = -originalAmount;
        break;
      case 'commission':
        category = UnifiedTransactionCategory.commission;
        if (originalAmount > 0) originalAmount = -originalAmount;
        break;
      // Add more cases as per your 'transactions.type' possible values
      default:
        category = UnifiedTransactionCategory.other;
    }
    
    return UnifiedTransaction(
      id: data['id'] as String,
      userId: data['user_id'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      amount: originalAmount,
      displayType: rawType.replaceAll('_', ' ').capitalizeFirstLetter(),
      source: TransactionSource.system,
      category: category,
      originalTypeFromDb: rawType,
      description: data['description'] as String?,
      relatedTradeId: data['related_trade_id']?.toString(),
    );
  }

  // Factory constructor for transactions from 'account_transactions' table
  factory UnifiedTransaction.fromAccountTransaction(Map<String, dynamic> data) {
    final rawType = data['transaction_type'] as String; // 'deposit' or 'withdraw'
    final originalAmount = (data['amount'] as num? ?? 0.0).toDouble();
    
    final double amount = rawType == 'withdraw' ? -originalAmount : originalAmount;
    final UnifiedTransactionCategory category = rawType == 'deposit' 
        ? UnifiedTransactionCategory.deposit 
        : UnifiedTransactionCategory.withdraw;

    return UnifiedTransaction(
      id: data['id'] as String,
      userId: data['user_id'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
      amount: amount,
      displayType: rawType.capitalizeFirstLetter(),
      source: TransactionSource.account,
      category: category,
      originalTypeFromDb: rawType,
      description: data['notes'] as String?, // Using 'notes' as primary description
      isVerified: data['verified'] as bool?,
      paymentProofUrl: data['payment_proof'] as String?,
      notes: data['notes'] as String?,
      verifiedTime: data['verified_time'] == null ? null : DateTime.parse(data['verified_time'] as String),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}"; // Allow non-lowercase tail
  }
}
