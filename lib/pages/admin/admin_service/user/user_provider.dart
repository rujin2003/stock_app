import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/pages/admin/models/user_model.dart';
import 'package:stock_app/pages/admin/admin_service/user/user_service.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

final usersProvider = FutureProvider<List<User>>((ref) async {
  final userService = ref.read(userServiceProvider);
  return await userService.fetchUsers();
});