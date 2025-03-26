import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stock_app/models/verification_state.dart';
import 'package:stock_app/services/user_verification_service.dart';
import 'package:stock_app/providers/auth_provider.dart';

part 'user_verification_provider.g.dart';

@riverpod
class UserVerification extends _$UserVerification {
  late final UserVerificationService _verificationService =
      UserVerificationService();

  @override
  VerificationState build() {
    _checkVerificationStatus();
    return const VerificationState();
  }

  Future<void> _checkVerificationStatus() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final status = await _verificationService.getVerificationStatus(user.id);
    if (status != null) {
      state = state.copyWith(
        status: _mapStatusString(status['status']),
        documentType: status['document_type'],
        documentUrl: status['document_url'],
      );
    }
  }

  VerificationStatus _mapStatusString(String status) {
    switch (status) {
      case 'pending':
        return VerificationStatus.submitted;
      case 'approved':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.initial;
    }
  }

  Future<void> submitVerification(File document, String documentType) async {
    try {
      state = state.copyWith(status: VerificationStatus.uploading);

      final user = ref.read(authProvider);
      if (user == null) throw 'User not authenticated';

      final documentUrl = await _verificationService.uploadDocument(
        document,
        user.id,
        documentType,
      );

      await _verificationService.submitVerification(
        user.id,
        documentType,
        documentUrl,
      );

      state = state.copyWith(
        status: VerificationStatus.submitted,
        documentUrl: documentUrl,
        documentType: documentType,
      );
    } catch (e) {
      state = state.copyWith(
        status: VerificationStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(
      status: VerificationStatus.initial,
      errorMessage: null,
    );
  }
}
