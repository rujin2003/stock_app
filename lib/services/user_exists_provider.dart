import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_app/services/user_kyc.dart';
// Ensure this import path matches the location of the service file

final checkUserServiceProvider = Provider<CheckUserServiceProvider>((ref) {
  return CheckUserServiceProvider();
});

final userExistsProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final service = ref.read(checkUserServiceProvider);
  return await service.checkUserExists(userId);
});
