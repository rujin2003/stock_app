import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:stock_app/pages/transactions/transaction_history_page.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  File? _paymentProof;
  String? _selectedAccountType;
  String? _selectedAdminAccountId;
  String? _selectedUserAccountId;
  bool _isLoading = false;
  bool _isAddingNewAccount = false;
  double _userBalance = 0.0;

  // New account form controllers
  final _bankNameController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _bankAddressController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _walletAddressController = TextEditingController();

  List<Map<String, dynamic>> _adminAccounts = [];
  List<Map<String, dynamic>> _userAccounts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminAccounts();
    _loadUserAccounts();
    _loadUserBalance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _bankNameController.dispose();
    _ifscCodeController.dispose();
    _bankAddressController.dispose();
    _accountNoController.dispose();
    _fullNameController.dispose();
    _upiIdController.dispose();
    _walletAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminAccounts() async {
    try {
      final response = await Supabase.instance.client
          .from('admin_accounts')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _adminAccounts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading admin accounts: $e')),
        );
      }
    }
  }

  Future<void> _loadUserAccounts() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('user_accounts')
          .select()
          .eq('user_id', user.id);
      setState(() {
        _userAccounts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user accounts: $e')),
        );
      }
    }
  }

  Future<void> _loadUserBalance() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('account_balances')
          .select('balance')
          .eq('user_id', user.id)
          .single();
      
      setState(() {
        _userBalance = (response['balance'] as num).toDouble();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading balance: $e')),
        );
      }
    }
  }

  Future<void> _pickPaymentProof() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _paymentProof = File(image.path);
      });
    }
  }

  Future<String?> _uploadPaymentProof(File file) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';
      final filePath = 'payment_proofs/$fileName';

      await Supabase.instance.client.storage
          .from('payments')
          .upload(filePath, file);

      final url = Supabase.instance.client.storage
          .from('payments')
          .getPublicUrl(filePath);

      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading payment proof: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your account')),
      );
      return;
    }
    if (_selectedAdminAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an admin account')),
      );
      return;
    }
    if (_paymentProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload payment proof')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get current balance
      final balanceResponse = await Supabase.instance.client
          .from('account_balances')
          .select('balance')
          .eq('user_id', user.id)
          .single();
      
      final currentBalance = (balanceResponse['balance'] as num).toDouble();

      // Upload payment proof first
      final paymentProofUrl = await _uploadPaymentProof(_paymentProof!);
      if (paymentProofUrl == null) {
        throw Exception('Failed to upload payment proof');
      }

      // Create transaction with payment proof URL
      await Supabase.instance.client.from('account_transactions').insert({
        'user_id': user.id,
        'transaction_type': 'deposit',
        'amount': double.parse(_amountController.text),
        'payment_proof': paymentProofUrl,
        'user_current_balance': currentBalance,
        'account_balance_id': null, // Will be set by trigger
        'account_info_id': _selectedUserAccountId!.replaceAll('account_', ''), // User's account ID
        'admin_account_info_id': _selectedAdminAccountId!.replaceAll('account_', ''), // Admin's account ID
      });

      if (mounted) {
        // Use GoRouter for navigation
        context.go('/transaction_success');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting deposit: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitWithdraw() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account type')),
      );
      return;
    }
    if (_selectedUserAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a withdrawal account')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get current balance
      final balanceResponse = await Supabase.instance.client
          .from('account_balances')
          .select('balance')
          .eq('user_id', user.id)
          .single();
      
      final currentBalance = (balanceResponse['balance'] as num).toDouble();

      // Create transaction
      await Supabase.instance.client.from('account_transactions').insert({
        'user_id': user.id,
        'transaction_type': 'withdraw',
        'amount': double.parse(_amountController.text),
        'user_current_balance': currentBalance,
        'account_balance_id': null, // Will be set by trigger
        'account_info_id': _selectedUserAccountId!.replaceAll('account_', ''), // User's account ID
        'admin_account_info_id': null, // No admin account for withdrawals
      });

      if (mounted) {
        // Use GoRouter for navigation
        context.go('/transaction_success');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting withdrawal: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      Map<String, dynamic> accountData = {
        'user_id': user.id,
        'account_type': _selectedAccountType,
      };

      if (_selectedAccountType == 'bank_transfer') {
        accountData.addAll({
          'bank_name': _bankNameController.text,
          'ifsc_code': _ifscCodeController.text,
          'bank_address': _bankAddressController.text,
          'account_no': _accountNoController.text,
          'full_name': _fullNameController.text,
        });
      } else if (_selectedAccountType == 'upi') {
        accountData['upi_id'] = _upiIdController.text;
        accountData['full_name'] = _fullNameController.text;
      } else if (_selectedAccountType == 'crypto_wallet') {
        accountData['wallet_address'] = _walletAddressController.text;
        accountData['full_name'] = _fullNameController.text;
      }

      await Supabase.instance.client.from('user_accounts').insert(accountData);
      await _loadUserAccounts();

      setState(() {
        _isAddingNewAccount = false;
        _selectedUserAccountId = _userAccounts.first['id'].toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding account: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deposit Instructions'),
        content: const Text(
          'Please deposit the amount to the selected account and upload the payment proof screenshot. '
          'Your deposit will be processed after verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.go('/');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transactions'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
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
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Deposit'),
              Tab(text: 'Withdraw'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Deposit Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedAccountType,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(
                            value: 'bank_transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(
                            value: 'crypto_wallet', child: Text('Crypto Wallet')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountType = value;
                          _selectedUserAccountId = null;
                          _isAddingNewAccount = false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedAccountType != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedUserAccountId,
                            decoration: const InputDecoration(
                              labelText: 'Select Account',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'new_account',
                                child: Text('Add New Account'),
                              ),
                              ..._userAccounts
                                  .where((account) =>
                                      account['account_type'] == _selectedAccountType)
                                  .map((account) => DropdownMenuItem<String>(
                                        value: 'account_${account['id']}',
                                        child: Text(
                                            '${account['full_name'] ?? account['upi_id'] ?? account['wallet_address']}'),
                                      ))
                                  .toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedUserAccountId = value;
                                _isAddingNewAccount = value == 'new_account';
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_isAddingNewAccount) ...[
                            TextFormField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_selectedAccountType == 'bank_transfer') ...[
                              TextFormField(
                                controller: _bankNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Name',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter bank name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _ifscCodeController,
                                decoration: const InputDecoration(
                                  labelText: 'IFSC Code',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter IFSC code';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _accountNoController,
                                decoration: const InputDecoration(
                                  labelText: 'Account Number',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter account number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _bankAddressController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Address',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter bank address';
                                  }
                                  return null;
                                },
                              ),
                            ] else if (_selectedAccountType == 'upi') ...[
                              TextFormField(
                                controller: _upiIdController,
                                decoration: const InputDecoration(
                                  labelText: 'UPI ID',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter UPI ID';
                                  }
                                  return null;
                                },
                              ),
                            ] else if (_selectedAccountType == 'crypto_wallet') ...[
                              TextFormField(
                                controller: _walletAddressController,
                                decoration: const InputDecoration(
                                  labelText: 'Wallet Address',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter wallet address';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _addNewAccount,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Add Account'),
                            ),
                          ] else if (_selectedUserAccountId != null && !_isAddingNewAccount) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Account Details',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    if (_selectedAccountType == 'upi') ...[
                                      _buildDetailRow('UPI ID', _userAccounts
                                          .firstWhere((a) =>
                                              a['id'].toString() ==
                                              _selectedUserAccountId!.replaceAll('account_', ''))['upi_id']),
                                    ] else if (_selectedAccountType == 'bank_transfer') ...[
                                      _buildDetailRow(
                                          'Bank Name',
                                          _userAccounts
                                              .firstWhere((a) =>
                                                  a['id'].toString() ==
                                                  _selectedUserAccountId!.replaceAll('account_', ''))[
                                                  'bank_name']),
                                      _buildDetailRow(
                                          'Account Holder',
                                          _userAccounts
                                              .firstWhere((a) =>
                                                  a['id'].toString() ==
                                                  _selectedUserAccountId!.replaceAll('account_', ''))[
                                                  'full_name']),
                                      _buildDetailRow(
                                          'Account Number',
                                          _userAccounts
                                              .firstWhere((a) =>
                                                  a['id'].toString() ==
                                                  _selectedUserAccountId!.replaceAll('account_', ''))[
                                                  'account_no']),
                                      _buildDetailRow(
                                          'IFSC Code',
                                          _userAccounts
                                              .firstWhere((a) =>
                                                  a['id'].toString() ==
                                                  _selectedUserAccountId!.replaceAll('account_', ''))[
                                                  'ifsc_code']),
                                      _buildDetailRow(
                                          'Bank Address',
                                          _userAccounts
                                              .firstWhere((a) =>
                                                  a['id'].toString() ==
                                                  _selectedUserAccountId!.replaceAll('account_', ''))[
                                                  'bank_address']),
                                    ] else if (_selectedAccountType == 'crypto_wallet') ...[
                                      _buildDetailRow(
                                          'Wallet Address',
                                          _userAccounts
                                              .firstWhere((a) =>
                                                  a['id'].toString() ==
                                                  _selectedUserAccountId!.replaceAll('account_', ''))[
                                                  'wallet_address']),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedAdminAccountId,
                              decoration: const InputDecoration(
                                labelText: 'Select Admin Account',
                                border: OutlineInputBorder(),
                              ),
                              items: _adminAccounts
                                  .where((account) =>
                                      account['account_type'] == _selectedAccountType)
                                  .map((account) => DropdownMenuItem<String>(
                                        value: 'account_${account['id']}',
                                        child: Text(
                                            '${account['account_holder_name'] ?? account['upi_id'] ?? account['wallet_address']}'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedAdminAccountId = value;
                                });
                              },
                            ),
                            if (_selectedAdminAccountId != null) ...[
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Admin Account Details',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      if (_selectedAccountType == 'upi') ...[
                                        _buildDetailRow('UPI ID', _adminAccounts
                                            .firstWhere((a) =>
                                                a['id'].toString() ==
                                                _selectedAdminAccountId!.replaceAll('account_', ''))['upi_id']),
                                        if (_adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                            'upi_qr_code_url'] !=
                                            null)
                                          Center(
                                            child: Image.network(
                                              _adminAccounts
                                                  .firstWhere((a) =>
                                                      a['id'].toString() ==
                                                      _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                          'upi_qr_code_url']
                                                  .toString(),
                                              height: 200,
                                            ),
                                          ),
                                      ] else if (_selectedAccountType == 'bank_transfer') ...[
                                        _buildDetailRow(
                                            'Bank Name',
                                            _adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                    'bank_name']),
                                        _buildDetailRow(
                                            'Account Holder',
                                            _adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                    'account_holder_name']),
                                        _buildDetailRow(
                                            'Account Number',
                                            _adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                    'account_no']),
                                        _buildDetailRow(
                                            'IFSC Code',
                                            _adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                    'ifsc_code']),
                                        _buildDetailRow(
                                            'Bank Address',
                                            _adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                    'bank_address']),
                                      ] else if (_selectedAccountType == 'crypto_wallet') ...[
                                        _buildDetailRow(
                                            'Wallet Name',
                                            _adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                    'wallet_name']),
                                        _buildDetailRow(
                                            'Wallet Address',
                                            _adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                    'wallet_address']),
                                        _buildDetailRow(
                                            'Network',
                                            _adminAccounts
                                                .firstWhere((a) =>
                                                    a['id'].toString() ==
                                                    _selectedAdminAccountId!.replaceAll('account_', ''))[
                                                    'wallet_network']),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                border: OutlineInputBorder(),
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
                            ElevatedButton.icon(
                              onPressed: _pickPaymentProof,
                              icon: const Icon(Icons.upload_file),
                              label: Text(_paymentProof == null
                                  ? 'Upload Payment Proof'
                                  : 'Change Payment Proof'),
                            ),
                            if (_paymentProof != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _paymentProof!.path.split('/').last,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: (_isLoading || _paymentProof == null || _selectedAdminAccountId == null) ? null : _submitDeposit,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Submit Deposit Request'),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Withdraw Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Balance',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_userBalance.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedAccountType,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'upi', child: Text('UPI')),
                        DropdownMenuItem(
                            value: 'bank_transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(
                            value: 'crypto_wallet', child: Text('Crypto Wallet')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountType = value;
                          _selectedUserAccountId = null;
                          _isAddingNewAccount = false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedAccountType != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedUserAccountId,
                            decoration: const InputDecoration(
                              labelText: 'Select Withdrawal Account',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'new_account',
                                child: Text('Add New Account'),
                              ),
                              ..._userAccounts
                                  .where((account) =>
                                      account['account_type'] == _selectedAccountType)
                                  .map((account) => DropdownMenuItem<String>(
                                        value: 'account_${account['id']}',
                                        child: Text(
                                            '${account['full_name'] ?? account['upi_id'] ?? account['wallet_address']}'),
                                      ))
                                  .toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedUserAccountId = value;
                                _isAddingNewAccount = value == 'new_account';
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_isAddingNewAccount) ...[
                            TextFormField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_selectedAccountType == 'bank_transfer') ...[
                              TextFormField(
                                controller: _bankNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Name',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter bank name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _ifscCodeController,
                                decoration: const InputDecoration(
                                  labelText: 'IFSC Code',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter IFSC code';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _accountNoController,
                                decoration: const InputDecoration(
                                  labelText: 'Account Number',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter account number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _bankAddressController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Address',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter bank address';
                                  }
                                  return null;
                                },
                              ),
                            ] else if (_selectedAccountType == 'upi') ...[
                              TextFormField(
                                controller: _upiIdController,
                                decoration: const InputDecoration(
                                  labelText: 'UPI ID',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter UPI ID';
                                  }
                                  return null;
                                },
                              ),
                            ] else if (_selectedAccountType == 'crypto_wallet') ...[
                              TextFormField(
                                controller: _walletAddressController,
                                decoration: const InputDecoration(
                                  labelText: 'Wallet Address',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter wallet address';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _addNewAccount,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Add Account'),
                            ),
                          ] else if (_selectedUserAccountId != null && !_isAddingNewAccount) ...[
                            TextFormField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an amount';
                                }
                                final amount = double.tryParse(value);
                                if (amount == null) {
                                  return 'Please enter a valid number';
                                }
                                if (amount > _userBalance) {
                                  return 'Amount cannot exceed available balance';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _submitWithdraw,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Submit Withdrawal Request'),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }
}

class TransactionSuccessPage extends StatefulWidget {
  const TransactionSuccessPage({super.key});

  @override
  State<TransactionSuccessPage> createState() => _TransactionSuccessPageState();
}

class _TransactionSuccessPageState extends State<TransactionSuccessPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.go('/');
        return false;
      },
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.1),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 100,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Transaction Submitted Successfully!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Your payment is being processed and will be verified soon. You will receive a notification once the verification is complete.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verification usually takes 1-2 hours',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _fadeAnimation,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 