enum HealthDataType { weight, activity, workouts, sleep }

extension HealthDataTypeLabel on HealthDataType {
  String get label {
    return switch (this) {
      HealthDataType.weight => 'Weight',
      HealthDataType.activity => 'Activity',
      HealthDataType.workouts => 'Workouts',
      HealthDataType.sleep => 'Sleep',
    };
  }
}

enum HealthConnectionStatus { disconnected, connected, denied, unavailable }

class HealthSignalSnapshot {
  const HealthSignalSnapshot({
    this.weightKg,
    this.activeMinutes,
    this.workoutCount,
    this.sleepHours,
    this.capturedAt,
  });

  final double? weightKg;
  final int? activeMinutes;
  final int? workoutCount;
  final double? sleepHours;
  final DateTime? capturedAt;

  bool get hasSignals =>
      weightKg != null ||
      activeMinutes != null ||
      workoutCount != null ||
      sleepHours != null;

  Map<String, Object?> toJson() {
    return {
      'weightKg': weightKg,
      'activeMinutes': activeMinutes,
      'workoutCount': workoutCount,
      'sleepHours': sleepHours,
      'capturedAt': capturedAt?.toIso8601String(),
    };
  }

  factory HealthSignalSnapshot.fromJson(Map<String, Object?> json) {
    return HealthSignalSnapshot(
      weightKg: _doubleFromJson(json['weightKg']),
      activeMinutes: _intFromJson(json['activeMinutes']),
      workoutCount: _intFromJson(json['workoutCount']),
      sleepHours: _doubleFromJson(json['sleepHours']),
      capturedAt: _dateFromJson(json['capturedAt']),
    );
  }

  static const mock = HealthSignalSnapshot(
    weightKg: 78.4,
    activeMinutes: 42,
    workoutCount: 1,
    sleepHours: 6.8,
  );
}

class HealthConnectionState {
  const HealthConnectionState({
    required this.status,
    required this.supportedTypes,
    required this.enabledTypes,
    this.signals,
    this.statusDetail,
    this.providerLabel = 'Mock health provider',
  });

  final HealthConnectionStatus status;
  final Set<HealthDataType> supportedTypes;
  final Set<HealthDataType> enabledTypes;
  final HealthSignalSnapshot? signals;
  final String? statusDetail;
  final String providerLabel;

  static const mvpTypes = {
    HealthDataType.weight,
    HealthDataType.activity,
    HealthDataType.workouts,
    HealthDataType.sleep,
  };

  static const disconnected = HealthConnectionState(
    status: HealthConnectionStatus.disconnected,
    supportedTypes: mvpTypes,
    enabledTypes: {},
    providerLabel: 'Mock health provider',
  );

  bool get isConnected => status == HealthConnectionStatus.connected;

  bool get canRequestConnection =>
      status == HealthConnectionStatus.disconnected ||
      status == HealthConnectionStatus.denied;

  String get statusLabel {
    return switch (status) {
      HealthConnectionStatus.connected => 'Connected',
      HealthConnectionStatus.disconnected => 'Disconnected',
      HealthConnectionStatus.denied => 'Permission denied',
      HealthConnectionStatus.unavailable => 'Unavailable',
    };
  }

  String get explainer {
    return switch (status) {
      HealthConnectionStatus.connected =>
        'Selected health signals can now inform mock meal suggestions. Disconnect removes this app connection state.',
      HealthConnectionStatus.disconnected =>
        'Health connection is optional. The app works with manual and local nutrition data until you choose Connect.',
      HealthConnectionStatus.denied =>
        'Health permission was denied. Keep using manual logging or change permission in platform settings before trying again.',
      HealthConnectionStatus.unavailable =>
        'Health connection is not available in this build or on this platform. Manual and local nutrition data still work.',
    };
  }

  HealthConnectionState copyWith({
    HealthConnectionStatus? status,
    Set<HealthDataType>? supportedTypes,
    Set<HealthDataType>? enabledTypes,
    HealthSignalSnapshot? signals,
    String? statusDetail,
    String? providerLabel,
  }) {
    return HealthConnectionState(
      status: status ?? this.status,
      supportedTypes: supportedTypes ?? this.supportedTypes,
      enabledTypes: enabledTypes ?? this.enabledTypes,
      signals: signals ?? this.signals,
      statusDetail: statusDetail ?? this.statusDetail,
      providerLabel: providerLabel ?? this.providerLabel,
    );
  }
}

double? _doubleFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

int? _intFromJson(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return null;
}

DateTime? _dateFromJson(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
