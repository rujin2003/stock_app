import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:stock_app/pages/transactions/transaction_history_page.dart';
import 'package:stock_app/models/user_account.dart';
import 'package:stock_app/models/admin_account.dart';

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
      final supabase = Supabase.instance.client;
      if (_selectedAccountType == null) return;
      
      final response = await supabase
          .from('admin_accounts')
          .select()
          .eq('account_type', _selectedAccountType!)
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
      final supabase = Supabase.instance.client;
      if (_selectedAccountType == null) return;
      
      final response = await supabase
          .from('user_accounts')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('account_type', _selectedAccountType!)
          .order('created_at', ascending: false);

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
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('account_balances')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .single();

      setState(() {
        _userBalance = response['balance']?.toDouble() ?? 0.0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user balance: $e')),
        );
      }
    }
  }

  Future<void> _addNewAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final accountData = {
        'user_id': supabase.auth.currentUser!.id,
        'account_type': _selectedAccountType,
        'bank_name': _bankNameController.text,
        'ifsc_code': _ifscCodeController.text,
        'bank_address': _bankAddressController.text,
        'account_no': _accountNoController.text,
        'full_name': _fullNameController.text,
        'upi_id': _upiIdController.text,
        'wallet_address': _walletAddressController.text,
      };

      await supabase.from('user_accounts').insert(accountData);
      await _loadUserAccounts();

      // Reset form
      _bankNameController.clear();
      _ifscCodeController.clear();
      _bankAddressController.clear();
      _accountNoController.clear();
      _fullNameController.clear();
      _upiIdController.clear();
      _walletAddressController.clear();

      setState(() {
        _isAddingNewAccount = false;
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
      setState(() {
        _isLoading = false;
      });
    }
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
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildDepositTab(),
                _buildWithdrawTab(),
              ],
            ),
            if (_isAddingNewAccount) _buildAddAccountDialog(),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Balance: \$${_userBalance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Account Type Selection
            DropdownButtonFormField<String>(
              value: _selectedAccountType,
              decoration: const InputDecoration(
                labelText: 'Select Account Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'upi',
                  child: Text('UPI'),
                ),
                DropdownMenuItem(
                  value: 'bank_transfer',
                  child: Text('Bank Transfer'),
                ),
                DropdownMenuItem(
                  value: 'crypto_wallet',
                  child: Text('Crypto Wallet'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAccountType = value;
                  _selectedUserAccountId = null;
                  _selectedAdminAccountId = null;
                });
                _loadAdminAccounts();
                _loadUserAccounts();
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select an account type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // User Account Selection
            if (_selectedAccountType != null) ...[
              if (_userAccounts.isEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAddingNewAccount = true;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Account'),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: _selectedUserAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Select Your Account',
                    border: OutlineInputBorder(),
                  ),
                  items: _userAccounts.map((account) {
                    return DropdownMenuItem(
                      value: account['id'].toString(),
                      child: Text(
                        _selectedAccountType == 'upi'
                            ? account['upi_id'] ?? 'UPI Account'
                            : _selectedAccountType == 'bank_transfer'
                                ? '${account['bank_name']} - ${account['account_no']}'
                                : '${account['wallet_name']} - ${account['wallet_address']}',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserAccountId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an account';
                    }
                    return null;
                  },
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAddingNewAccount = true;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Account'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            // Admin Account Selection
            if (_selectedAccountType != null && _adminAccounts.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedAdminAccountId,
                decoration: const InputDecoration(
                  labelText: 'Select Admin Account',
                  border: OutlineInputBorder(),
                ),
                items: _adminAccounts.map((account) {
                  return DropdownMenuItem(
                    value: account['id'].toString(),
                    child: Text(
                      _selectedAccountType == 'upi'
                          ? account['upi_id'] ?? 'UPI Account'
                          : _selectedAccountType == 'bank_transfer'
                              ? '${account['bank_name']} - ${account['account_no']}'
                              : '${account['wallet_name']} - ${account['wallet_address']}',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAdminAccountId = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an admin account';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 16),
            // Amount Input
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Payment Proof Upload
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickPaymentProof,
              icon: const Icon(Icons.upload_file),
              label: Text(_paymentProof == null
                  ? 'Upload Payment Proof'
                  : 'Change Payment Proof'),
            ),
            if (_paymentProof != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected file: ${path.basename(_paymentProof!.path)}',
                style: const TextStyle(color: Colors.green),
              ),
            ],
            const SizedBox(height: 24),
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitDeposit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Deposit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Balance: \$${_userBalance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Account Type Selection
            DropdownButtonFormField<String>(
              value: _selectedAccountType,
              decoration: const InputDecoration(
                labelText: 'Select Account Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'upi',
                  child: Text('UPI'),
                ),
                DropdownMenuItem(
                  value: 'bank_transfer',
                  child: Text('Bank Transfer'),
                ),
                DropdownMenuItem(
                  value: 'crypto_wallet',
                  child: Text('Crypto Wallet'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAccountType = value;
                  _selectedUserAccountId = null;
                  _selectedAdminAccountId = null;
                });
                _loadAdminAccounts();
                _loadUserAccounts();
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select an account type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // User Account Selection
            if (_selectedAccountType != null) ...[
              if (_userAccounts.isEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAddingNewAccount = true;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Account'),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: _selectedUserAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Select Your Account',
                    border: OutlineInputBorder(),
                  ),
                  items: _userAccounts.map((account) {
                    return DropdownMenuItem(
                      value: account['id'].toString(),
                      child: Text(
                        _selectedAccountType == 'upi'
                            ? account['upi_id'] ?? 'UPI Account'
                            : _selectedAccountType == 'bank_transfer'
                                ? '${account['bank_name']} - ${account['account_no']}'
                                : '${account['wallet_name']} - ${account['wallet_address']}',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserAccountId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an account';
                    }
                    return null;
                  },
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isAddingNewAccount = true;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Account'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            // Amount Input
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                if (amount > _userBalance) {
                  return 'Insufficient balance';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitWithdraw,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Withdrawal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paymentProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload payment proof')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final amount = double.parse(_amountController.text);

      // Upload payment proof
      final fileExt = path.extension(_paymentProof!.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath = 'payment_proofs/$fileName';

      await supabase.storage.from('payments').upload(filePath, _paymentProof!);
      final paymentProofUrl = supabase.storage.from('payments').getPublicUrl(filePath);

      // Create deposit transaction
      await supabase.from('account_transactions').insert({
        'user_id': supabase.auth.currentUser!.id,
        'transaction_type': 'deposit',
        'amount': amount,
        'payment_proof': paymentProofUrl,
        'account_info_id': _selectedUserAccountId,
        'admin_account_info_id': _selectedAdminAccountId,
        'verified': false,
      });

      // Reset form
      _amountController.clear();
      setState(() {
        _paymentProof = null;
        _selectedUserAccountId = null;
        _selectedAdminAccountId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deposit request submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting deposit: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitWithdraw() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final amount = double.parse(_amountController.text);

      // Create withdrawal transaction
      await supabase.from('account_transactions').insert({
        'user_id': supabase.auth.currentUser!.id,
        'transaction_type': 'withdraw',
        'amount': amount,
        'account_info_id': _selectedUserAccountId,
        'verified': false,
      });

      // Reset form
      _amountController.clear();
      setState(() {
        _selectedUserAccountId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal request submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting withdrawal: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickPaymentProof() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _paymentProof = File(pickedFile.path);
      });
    }
  }

  Widget _buildAddAccountDialog() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add New ${_selectedAccountType?.toUpperCase() ?? ''} Account',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Holder Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter account holder name';
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
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isAddingNewAccount = false;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _addNewAccount,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Add Account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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