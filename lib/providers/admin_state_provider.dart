import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stock_app/models/admin_state.dart';
import 'package:stock_app/services/admin_service.dart';

part 'admin_state_provider.g.dart';

@riverpod
class AdminStateNotifier extends _$AdminStateNotifier {
  late final AdminService _adminService = AdminService();

  @override
  AdminState build() {
    return const AdminState();
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AdminStatus.authenticating);

    try {
      if (email == 'dev.keshwani345@gmail.com') {
        await _adminService.signIn(
          email: email,
          password: password,
        );
        state = state.copyWith(status: AdminStatus.authenticated);
      } else {
        throw 'Only authorized admins can access this section';
      }
    } catch (e) {
      state = state.copyWith(
        status: AdminStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void signOut() {
    state = state.copyWith(status: AdminStatus.unauthenticated);
  }
}
