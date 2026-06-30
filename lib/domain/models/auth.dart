enum AuthProvider { local, firebase, supabase }

extension AuthProviderLabel on AuthProvider {
  String get label {
    return switch (this) {
      AuthProvider.local => 'Local account',
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
    provider: AuthProvider.local,
    statusDetail: 'Enter your local account to continue.',
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
        'Sign in or register with a local account before using nutrition features.',
      AuthConnectionStatus.signedIn =>
        'Your V1 account is local to this device. Nutrition logs stay on this device unless you allow platform backup.',
      AuthConnectionStatus.providerUnavailable =>
        '${provider.label} is not configured for this build. Use the local account boundary for V1.',
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
      provider: _authProviderFromJson(providerName),
      userLabel: _stringOrNull(json['userLabel']),
      statusDetail: _stringOrNull(json['statusDetail']),
    );
  }
}

class LocalAccountRecord {
  const LocalAccountRecord({
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  final String email;
  final String displayName;
  final DateTime createdAt;

  String get normalizedEmail => normalizeAccountEmail(email);

  Map<String, Object?> toJson() {
    return {
      'email': normalizedEmail,
      'displayName': displayName.trim(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalAccountRecord.fromJson(Map<String, Object?> json) {
    final email = _stringOrNull(json['email']) ?? '';
    final displayName = _stringOrNull(json['displayName']) ?? 'Local user';
    final createdAtValue = _stringOrNull(json['createdAt']);
    return LocalAccountRecord(
      email: normalizeAccountEmail(email),
      displayName: displayName,
      createdAt: DateTime.tryParse(createdAtValue ?? '') ?? DateTime(1970),
    );
  }
}

class AuthSignInResult {
  const AuthSignInResult._({required this.state, this.errorMessage});

  final AuthAccountState state;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;

  factory AuthSignInResult.success(AuthAccountState state) {
    return AuthSignInResult._(state: state);
  }

  factory AuthSignInResult.failure({
    required AuthAccountState state,
    required String message,
  }) {
    return AuthSignInResult._(state: state, errorMessage: message);
  }
}

String normalizeAccountEmail(String email) => email.trim().toLowerCase();

AuthProvider _authProviderFromJson(Object? value) {
  if (value == 'mock') {
    return AuthProvider.local;
  }
  return AuthProvider.values.firstWhere(
    (provider) => provider.name == value,
    orElse: () => AuthProvider.local,
  );
}

String? _stringOrNull(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
