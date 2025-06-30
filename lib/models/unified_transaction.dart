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
  final double amount;
  final String displayType;
  final String? description;
  final String? relatedTradeId;
  final DateTime createdAt;
  final TransactionSource source;
  final UnifiedTransactionCategory category;
  final String? originalTypeFromDb;
  final String? notes;

  UnifiedTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.displayType,
    this.description,
    this.relatedTradeId,
    required this.createdAt,
    required this.source,
    required this.category,
    this.originalTypeFromDb,
    this.notes,
  });

  factory UnifiedTransaction.fromJson(Map<String, dynamic> json) {
    return UnifiedTransaction(
      id: json['id'],
      userId: json['user_id'],
      amount: (json['amount'] as num).toDouble(),
      displayType: json['type'] ?? 'Unknown',
      description: json['description'],
      relatedTradeId: json['related_trade_id'],
      createdAt: DateTime.parse(json['created_at']),
      source: json['source'] == 'account' ? TransactionSource.account : TransactionSource.system,
      category: _getCategoryFromType(json['type']),
      originalTypeFromDb: json['type'],
      notes: json['notes'],
    );
  }

  static UnifiedTransactionCategory _getCategoryFromType(String? type) {
    if (type == null) return UnifiedTransactionCategory.other;
    
    switch (type.toLowerCase()) {
      case 'profit':
        return UnifiedTransactionCategory.profit;
      case 'loss':
        return UnifiedTransactionCategory.loss;
      case 'fee':
        return UnifiedTransactionCategory.fee;
      case 'commission':
        return UnifiedTransactionCategory.commission;
      case 'dividend':
        return UnifiedTransactionCategory.dividend;
      case 'interest':
        return UnifiedTransactionCategory.interest;
      case 'adjustment':
        return UnifiedTransactionCategory.adjustment;
      default:
        return UnifiedTransactionCategory.other;
    }
  }

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
      amount: originalAmount,
      displayType: rawType.replaceAll('_', ' ').capitalizeFirstLetter(),
      source: TransactionSource.system,
      category: category,
      originalTypeFromDb: rawType,
      description: data['description'] as String?,
      relatedTradeId: data['related_trade_id']?.toString(),
      createdAt: DateTime.parse(data['created_at'] as String),
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
      amount: amount,
      displayType: rawType.capitalizeFirstLetter(),
      source: TransactionSource.account,
      category: category,
      originalTypeFromDb: rawType,
      description: data['notes'] as String?, // Using 'notes' as primary description
      relatedTradeId: data['related_trade_id']?.toString(),
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}"; // Allow non-lowercase tail
  }
}
