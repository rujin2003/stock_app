import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/models/account_transaction.dart';
import 'package:stock_app/providers/account_transactions_provider.dart';
import 'package:stock_app/widgets/loading_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentVerificationPage extends ConsumerWidget {
  const PaymentVerificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingTransactionsAsync = ref.watch(pendingTransactionsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            final supabase = Supabase.instance.client;
            final response = await supabase
                .from('account_transactions')
                .select('*, user_account:user_accounts(*), admin_account:admin_accounts(*)')
                .eq('verified', false)
                .order('created_at', ascending: false);
            
            if (response != null) {
              final transactions = (response as List)
                  .map((json) => AccountTransaction.fromJson(json))
                  .toList();
              ref.invalidate(pendingTransactionsProvider);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error refreshing: $e')),
              );
            }
          }
        },
        child: const Icon(Icons.refresh),
      ),
      body: pendingTransactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Text('No pending transactions'),
            );
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return TransactionCard(transaction: transaction);
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

class TransactionCard extends ConsumerStatefulWidget {
  final AccountTransaction transaction;

  const TransactionCard({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends ConsumerState<TransactionCard> {
  String? _notes;
  bool _showPaymentProof = false;
  Map<String, dynamic>? _userAccount;
  Map<String, dynamic>? _adminAccount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAccountDetails();
  }

  Future<void> _fetchAccountDetails() async {
    try {
      final supabase = Supabase.instance.client;
      
      // Fetch user account details for both deposit and withdraw
      if (widget.transaction.accountInfoId != null) {
        final userAccountResponse = await supabase
            .from('user_accounts')
            .select()
            .eq('id', widget.transaction.accountInfoId ?? '')
            .single();
        
        setState(() {
          _userAccount = userAccountResponse;
        });
      }

      // Fetch admin account details for both deposit and withdraw
      if (widget.transaction.adminAccountInfoId != null) {
        final adminAccountResponse = await supabase
            .from('admin_accounts')
            .select()
            .eq('id', widget.transaction.adminAccountInfoId ?? '')
            .single();
        
        setState(() {
          _adminAccount = adminAccountResponse;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching account details: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _shortenId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  Future<void> _verifyTransaction() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // First, get the user's current balance from appusers
      final userResponse = await supabase
          .from('appusers')
          .select('account_balance')
          .eq('user_id', widget.transaction.userId)
          .single();

      if (userResponse == null) {
        throw Exception('User not found');
      }

      // Get the account balance record for this user
      final accountBalanceResponse = await supabase
          .from('account_balances')
          .select('id, balance')
          .eq('user_id', widget.transaction.userId)
          .single();

      if (accountBalanceResponse == null) {
        throw Exception('Account balance not found');
      }

      final accountBalanceId = accountBalanceResponse['id'] as String;
      final currentBalance = (accountBalanceResponse['balance'] as num).toDouble();
      final newBalance = widget.transaction.transactionType == 'deposit'
          ? currentBalance + widget.transaction.amount
          : currentBalance - widget.transaction.amount;

      // Update account_transactions
      await supabase
          .from('account_transactions')
          .update({
            'verified': true,
            'verified_by': currentUser.id,
            'verified_time': DateTime.now().toIso8601String(),
            'notes': _notes ?? '',
            'user_current_balance': newBalance,
            'account_balance_id': accountBalanceId,
          })
          .eq('id', widget.transaction.id);

      // Update account_balances
      await supabase
          .from('account_balances')
          .update({
            'balance': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', accountBalanceId);

      // Note: The appusers.account_balance will be automatically updated by the trigger
      // trigger_update_user_balance on the account_balances table

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction verified successfully')),
        );
        ref.invalidate(pendingTransactionsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying transaction: $e')),
        );
      }
    }
  }

  Widget _buildAccountDetails(String title, Map<String, dynamic> account) {
    final accountType = account['account_type']?.toString() ?? 'bank_transfer';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            if (accountType == 'bank_transfer') ...[
              _buildDetailRow('Bank Name', account['bank_name'] ?? ''),
              _buildDetailRow('Account Holder', account['account_holder_name'] ?? ''),
              _buildDetailRow('Account Number', account['account_no'] ?? ''),
              _buildDetailRow('IFSC Code', account['ifsc_code'] ?? ''),
              _buildDetailRow('Bank Address', account['bank_address'] ?? ''),
            ] else if (accountType == 'upi') ...[
              _buildDetailRow('UPI ID', account['upi_id'] ?? ''),
              _buildDetailRow('Account Holder', account['account_holder_name'] ?? ''),
              if (account['upi_qr_code_url'] != null) ...[
                const SizedBox(height: 8),
                Image.network(
                  account['upi_qr_code_url'],
                  height: 150,
                  width: 150,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Failed to load QR code'),
                    );
                  },
                ),
              ],
            ] else if (accountType == 'crypto_wallet') ...[
              _buildDetailRow('Wallet Name', account['wallet_name'] ?? ''),
              _buildDetailRow('Wallet Address', account['wallet_address'] ?? ''),
              _buildDetailRow('Network', account['wallet_network'] ?? ''),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.all(8.0),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'ID: ${_shortenId(transaction.id)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: transaction.transactionType == 'deposit' 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    transaction.transactionType.toUpperCase(),
                    style: TextStyle(
                      color: transaction.transactionType == 'deposit' 
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Amount', '\$${transaction.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            
            // User Account Details (for both deposit and withdraw)
            if (_userAccount != null) ...[
              _buildAccountDetails(
                transaction.transactionType == 'deposit' 
                    ? 'User Account Details (From)' 
                    : 'User Account Details (To)',
                _userAccount!,
              ),
            ],

            // Admin Account Details (for both deposit and withdraw)
            if (_adminAccount != null) ...[
              _buildAccountDetails(
                transaction.transactionType == 'deposit' 
                    ? 'Admin Account Details (To)' 
                    : 'Admin Account Details (From)',
                _adminAccount!,
              ),
            ],

            // Payment Proof
            if (transaction.paymentProof != null && transaction.paymentProof!.isNotEmpty) ...[
              const Text(
                'Payment Proof:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: const Text('View Payment Proof'),
                      trailing: IconButton(
                        icon: Icon(_showPaymentProof ? Icons.expand_less : Icons.expand_more),
                        onPressed: () {
                          setState(() {
                            _showPaymentProof = !_showPaymentProof;
                          });
                        },
                      ),
                    ),
                    if (_showPaymentProof) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.network(
                          transaction.paymentProof!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text('Failed to load image'),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Verify Transaction'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Add notes for this transaction:'),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: const InputDecoration(
                                hintText: 'Enter notes...',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              onChanged: (value) {
                                setState(() {
                                  _notes = value;
                                });
                              },
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _verifyTransaction();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Verify Transaction'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 