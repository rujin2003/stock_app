import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/transactions/transaction_history_page.dart';
import 'package:stock_app/services/auth_service.dart';
import 'package:stock_app/models/linked_account.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  LinkedAccount? _selectedAccount;
  String _selectedTransactionType = 'UPI';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<LinkedAccount> _linkedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedAccounts();
  }

  Future<void> _loadLinkedAccounts() async {
    final accounts = await _authService.getLinkedAccounts();
    setState(() {
      _linkedAccounts = accounts;
      if (accounts.isNotEmpty) {
        _selectedAccount = accounts.first;
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitTransaction() {
    if (_formKey.currentState!.validate()) {
      // TODO: Implement transaction submission
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction submitted successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Account Selection Dropdown
              DropdownButtonFormField<LinkedAccount>(
                value: _selectedAccount,
                decoration: const InputDecoration(
                  labelText: 'Select Account',
                  border: OutlineInputBorder(),
                ),
                items: _linkedAccounts.map((account) {
                  return DropdownMenuItem(
                    value: account,
                    child: Text(account.email),
                  );
                }).toList(),
                onChanged: (LinkedAccount? value) {
                  setState(() {
                    _selectedAccount = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select an account';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Transaction Type Selection
              DropdownButtonFormField<String>(
                value: _selectedTransactionType,
                decoration: const InputDecoration(
                  labelText: 'Transaction Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'UPI',
                    child: Text('UPI'),
                  ),
                  DropdownMenuItem(
                    value: 'Crypto',
                    child: Text('Crypto'),
                  ),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _selectedTransactionType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Amount Input
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description Input
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _submitTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Submit Transaction',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 