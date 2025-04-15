import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/models/linked_account.dart';
import 'package:stock_app/services/auth_service.dart';

final linkedAccountsProvider =
    FutureProvider.autoDispose<List<LinkedAccount>>((ref) async {
  final authService = AuthService();
  return authService.getLinkedAccounts();
});

// Provider to track the current account operation state
final accountSwitchStateProvider = StateProvider<AccountSwitchState>((ref) {
  return AccountSwitchState.idle;
});

enum AccountSwitchState { idle, switching, error }
