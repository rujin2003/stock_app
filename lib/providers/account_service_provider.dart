import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/account_service.dart';
 
final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService();
}); 