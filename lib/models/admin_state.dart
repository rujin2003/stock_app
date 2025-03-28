enum AdminStatus {
  initial,
  authenticating,
  authenticated,
  error,
  unauthenticated,
}

class AdminState {
  final AdminStatus status;
  final String? errorMessage;

  const AdminState({
    this.status = AdminStatus.initial,
    this.errorMessage,
  });

  AdminState copyWith({
    AdminStatus? status,
    String? errorMessage,
  }) {
    return AdminState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
