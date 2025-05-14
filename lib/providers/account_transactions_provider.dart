import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/models/account_transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final accountTransactionsProvider = FutureProvider<List<AccountTransaction>>((ref) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('account_transactions')
      .select('*, user_account:user_accounts(*)')
      .order('created_at', ascending: false);
  
  return (response as List)
      .map((json) => AccountTransaction.fromJson(json))
      .toList();
});

final pendingTransactionsProvider = FutureProvider<List<AccountTransaction>>((ref) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('account_transactions')
      .select('*, user_account:user_accounts(*)')
      .eq('verified', false)
      .order('created_at', ascending: false);
  
  return (response as List)
      .map((json) => AccountTransaction.fromJson(json))
      .toList();
});

final verifyTransactionProvider = FutureProvider.family<void, String>((ref, transactionId) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  
  if (currentUser == null) {
    throw Exception('User not authenticated');
  }
  
  // Get the transaction details
  final transaction = await supabase
      .from('account_transactions')
      .select('*')
      .eq('id', transactionId)
      .single();
  
  if (transaction == null) {
    throw Exception('Transaction not found');
  }
  
  // Update the transaction as verified
  await supabase
      .from('account_transactions')
      .update({
        'verified': true,
        'verified_by': currentUser.id,
        'verified_time': DateTime.now().toIso8601String(),
      })
      .eq('id', transactionId);
  
  // The trigger will automatically update the balance
});

final verifiedTransactionsProvider = FutureProvider<List<AccountTransaction>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('account_transactions')
      .select('*, user_account:user_accounts(*), admin_account:admin_accounts(*)')
      .eq('verified', true)
      .order('verified_time', ascending: false);
  
  if (response == null) return [];
  
  return (response as List)
      .map((json) => AccountTransaction.fromJson(json))
      .toList();
});

final userVerifiedTransactionsProvider = FutureProvider<List<AccountTransaction>>((ref) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  
  if (currentUser == null) return [];
  
  final response = await supabase
      .from('account_transactions')
      .select('*, user_account:user_accounts(*), admin_account:admin_accounts(*)')
      .eq('user_id', currentUser.id)
      .eq('verified', true)
      .order('verified_time', ascending: false);
  
  if (response == null) return [];
  
  return (response as List)
      .map((json) => AccountTransaction.fromJson(json))
      .toList();
});

final combinedTransactionsProvider = FutureProvider<List<AccountTransaction>>((ref) async {
  final supabase = Supabase.instance.client;
  final currentUser = supabase.auth.currentUser;
  
  if (currentUser == null) {
    return [];
  }
  
  try {
    final response = await supabase
        .from('account_transactions')
        .select('*, user_account:user_accounts(*), admin_account:admin_accounts(*)')
        .eq('user_id', currentUser.id)
        .order('created_at', ascending: false);
    
    if (response == null || response.isEmpty) {
      return [];
    }
    
    return (response as List)
        .map((json) => AccountTransaction.fromJson(json))
        .toList();
  } catch (e) {
    print('Error loading transactions: $e');
    return [];
  }
}); 