import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock_app/services/auth_service.dart';

part 'auth_provider.g.dart';

@riverpod
class Auth extends _$Auth {
  late final AuthService _authService = AuthService();
  
  @override
  User? build() {
    return _authService.getCurrentUser();
  }
}