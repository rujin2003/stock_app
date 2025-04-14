import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stock_app/services/admin_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'admin_state_provider.g.dart';

class AdminState {
  final bool isLoggedIn;
  final User? user;
  final bool isSuperAdmin;

  AdminState({
    required this.isLoggedIn,
    this.user,
    this.isSuperAdmin = false,
  });

  AdminState copyWith({
    bool? isLoggedIn,
    User? user,
    bool? isSuperAdmin,
  }) =>
      AdminState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        user: user ?? this.user,
        isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      );
}

@riverpod
class AdminStateNotifier extends _$AdminStateNotifier {
  final AdminService _adminService = AdminService();

  @override
  AdminState build() => AdminState(isLoggedIn: false);

  Future<void> signIn(String email, String password) async {
    
    await _adminService.signIn(email: email, password: password);

    final user = Supabase.instance.client.auth.currentUser;
    final isSuperAdmin = await _adminService.isAdmin(user!.id);

    state = AdminState(
      isLoggedIn: true,
      user: user,
      isSuperAdmin: isSuperAdmin,
    );
  }

  Future<void> signOut() async {
    await _adminService.signOut();
    state = AdminState(isLoggedIn: false, user: null, isSuperAdmin: false);
  }
}
