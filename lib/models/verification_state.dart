enum VerificationStatus {
  initial,
  uploading,
  submitted,
  approved,
  rejected,
  error,
}

class VerificationState {
  final VerificationStatus status;
  final String? errorMessage;
  final String? documentUrl;
  final String? documentType;

  const VerificationState({
    this.status = VerificationStatus.initial,
    this.errorMessage,
    this.documentUrl,
    this.documentType,
  });

  VerificationState copyWith({
    VerificationStatus? status,
    String? errorMessage,
    String? documentUrl,
    String? documentType,
  }) {
    return VerificationState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      documentUrl: documentUrl ?? this.documentUrl,
      documentType: documentType ?? this.documentType,
    );
  }
}
