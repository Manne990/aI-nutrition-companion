enum AuthProvider { mock, firebase, supabase }

extension AuthProviderLabel on AuthProvider {
  String get label {
    return switch (this) {
      AuthProvider.mock => 'Mock local auth',
      AuthProvider.firebase => 'Firebase Auth',
      AuthProvider.supabase => 'Supabase Auth',
    };
  }
}

enum AuthConnectionStatus { signedOut, signedIn, providerUnavailable }

class AuthAccountState {
  const AuthAccountState({
    required this.status,
    required this.provider,
    this.userLabel,
    this.statusDetail,
  });

  final AuthConnectionStatus status;
  final AuthProvider provider;
  final String? userLabel;
  final String? statusDetail;

  static const signedOut = AuthAccountState(
    status: AuthConnectionStatus.signedOut,
    provider: AuthProvider.mock,
    statusDetail:
        'Nutrition logs remain local. Sign-in is optional and sync is not enabled in V1.',
  );

  bool get isSignedIn => status == AuthConnectionStatus.signedIn;

  String get statusLabel {
    return switch (status) {
      AuthConnectionStatus.signedOut => 'Signed out',
      AuthConnectionStatus.signedIn => 'Signed in',
      AuthConnectionStatus.providerUnavailable => 'Provider unavailable',
    };
  }

  String get explainer {
    return switch (status) {
      AuthConnectionStatus.signedOut =>
        'Use the app signed out. Mock local auth is available for tests and development without a backend.',
      AuthConnectionStatus.signedIn =>
        'This local mock account only proves the auth boundary. Nutrition logs still stay on this device.',
      AuthConnectionStatus.providerUnavailable =>
        '${provider.label} is not configured for this build. Keep using local nutrition flows or switch back to mock auth.',
    };
  }

  AuthAccountState copyWith({
    AuthConnectionStatus? status,
    AuthProvider? provider,
    String? userLabel,
    String? statusDetail,
  }) {
    return AuthAccountState(
      status: status ?? this.status,
      provider: provider ?? this.provider,
      userLabel: userLabel ?? this.userLabel,
      statusDetail: statusDetail ?? this.statusDetail,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'status': status.name,
      'provider': provider.name,
      'userLabel': userLabel,
      'statusDetail': statusDetail,
    };
  }

  factory AuthAccountState.fromJson(Map<String, Object?> json) {
    final statusName = json['status'];
    final providerName = json['provider'];
    return AuthAccountState(
      status: AuthConnectionStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => AuthConnectionStatus.signedOut,
      ),
      provider: AuthProvider.values.firstWhere(
        (provider) => provider.name == providerName,
        orElse: () => AuthProvider.mock,
      ),
      userLabel: _stringOrNull(json['userLabel']),
      statusDetail: _stringOrNull(json['statusDetail']),
    );
  }
}

String? _stringOrNull(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
