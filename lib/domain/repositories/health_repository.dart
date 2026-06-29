import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/health.dart';
import 'persisted_json.dart';

abstract interface class HealthRepository {
  Future<HealthConnectionState> loadState();

  Future<HealthConnectionState> requestConnection();

  Future<HealthConnectionState> disconnect();
}

abstract interface class HealthDataProvider {
  String get providerLabel;

  Future<HealthPlatformAvailability> checkAvailability();

  Future<HealthAuthorizationResult> requestAuthorization(
    Set<HealthDataType> types,
  );

  Future<HealthSignalSnapshot?> readSignals(Set<HealthDataType> types);
}

class HealthPlatformAvailability {
  const HealthPlatformAvailability({
    required this.isAvailable,
    required this.supportedTypes,
    this.message,
  });

  final bool isAvailable;
  final Set<HealthDataType> supportedTypes;
  final String? message;

  static const unavailable = HealthPlatformAvailability(
    isAvailable: false,
    supportedTypes: {},
    message: 'No HealthKit or Health Connect bridge is configured.',
  );
}

enum HealthAuthorizationStatus { authorized, denied, unavailable }

class HealthAuthorizationResult {
  const HealthAuthorizationResult({
    required this.status,
    required this.grantedTypes,
    this.message,
  });

  final HealthAuthorizationStatus status;
  final Set<HealthDataType> grantedTypes;
  final String? message;

  static const denied = HealthAuthorizationResult(
    status: HealthAuthorizationStatus.denied,
    grantedTypes: {},
    message: 'Permission was denied by the mock provider.',
  );
}

class MockHealthDataProvider implements HealthDataProvider {
  const MockHealthDataProvider({
    this.availability = const HealthPlatformAvailability(
      isAvailable: true,
      supportedTypes: HealthConnectionState.mvpTypes,
      message: 'Mock health provider is available for development.',
    ),
    this.authorizationResult,
    this.signals = HealthSignalSnapshot.mock,
    this.providerLabel = 'Mock health provider',
  });

  final HealthPlatformAvailability availability;
  final HealthAuthorizationResult? authorizationResult;
  final HealthSignalSnapshot? signals;

  @override
  final String providerLabel;

  @override
  Future<HealthPlatformAvailability> checkAvailability() async {
    return availability;
  }

  @override
  Future<HealthAuthorizationResult> requestAuthorization(
    Set<HealthDataType> types,
  ) async {
    return authorizationResult ??
        HealthAuthorizationResult(
          status: availability.isAvailable
              ? HealthAuthorizationStatus.authorized
              : HealthAuthorizationStatus.unavailable,
          grantedTypes: availability.supportedTypes.intersection(types),
          message: availability.message,
        );
  }

  @override
  Future<HealthSignalSnapshot?> readSignals(Set<HealthDataType> types) async {
    if (!availability.isAvailable || types.isEmpty) {
      return null;
    }
    return signals;
  }
}

class SharedPreferencesHealthRepository implements HealthRepository {
  const SharedPreferencesHealthRepository(
    this._preferences, {
    required this.provider,
  });

  static const statusKey = 'health.connection.status.v1';
  static const enabledTypesKey = 'health.connection.enabled_types.v1';
  static const signalsKey = 'health.connection.signals.v1';

  final SharedPreferences _preferences;
  final HealthDataProvider provider;

  static Future<SharedPreferencesHealthRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesHealthRepository(
      preferences,
      provider: const MockHealthDataProvider(),
    );
  }

  @override
  Future<HealthConnectionState> loadState() async {
    final status = _storedStatus();
    if (status == HealthConnectionStatus.disconnected) {
      return HealthConnectionState.disconnected.copyWith(
        providerLabel: provider.providerLabel,
      );
    }

    final availability = await provider.checkAvailability();
    if (status == HealthConnectionStatus.unavailable &&
        availability.isAvailable) {
      return HealthConnectionState.disconnected.copyWith(
        supportedTypes: availability.supportedTypes,
        statusDetail: availability.message,
        providerLabel: provider.providerLabel,
      );
    }
    if (!availability.isAvailable) {
      return _persistedUnavailable(availability);
    }

    if (status == HealthConnectionStatus.denied) {
      return HealthConnectionState(
        status: HealthConnectionStatus.denied,
        supportedTypes: availability.supportedTypes,
        enabledTypes: {},
        statusDetail: 'Permission was previously denied.',
        providerLabel: provider.providerLabel,
      );
    }

    final enabledTypes = _storedEnabledTypes().intersection(
      availability.supportedTypes,
    );
    final signals = enabledTypes.isEmpty
        ? _storedSignals()
        : await provider.readSignals(enabledTypes) ?? _storedSignals();
    return HealthConnectionState(
      status: HealthConnectionStatus.connected,
      supportedTypes: availability.supportedTypes,
      enabledTypes: enabledTypes,
      signals: signals,
      statusDetail: availability.message,
      providerLabel: provider.providerLabel,
    );
  }

  @override
  Future<HealthConnectionState> requestConnection() async {
    final availability = await provider.checkAvailability();
    if (!availability.isAvailable) {
      return _persistedUnavailable(availability);
    }

    final requestedTypes = HealthConnectionState.mvpTypes.intersection(
      availability.supportedTypes,
    );
    final authorization = await provider.requestAuthorization(requestedTypes);
    if (authorization.status == HealthAuthorizationStatus.denied) {
      await _saveState(
        status: HealthConnectionStatus.denied,
        enabledTypes: {},
        signals: null,
      );
      return HealthConnectionState(
        status: HealthConnectionStatus.denied,
        supportedTypes: availability.supportedTypes,
        enabledTypes: {},
        statusDetail: authorization.message,
        providerLabel: provider.providerLabel,
      );
    }
    if (authorization.status == HealthAuthorizationStatus.unavailable) {
      return _persistedUnavailable(
        HealthPlatformAvailability(
          isAvailable: false,
          supportedTypes: availability.supportedTypes,
          message: authorization.message ?? availability.message,
        ),
      );
    }

    final enabledTypes = authorization.grantedTypes.intersection(
      availability.supportedTypes,
    );
    final signals = await provider.readSignals(enabledTypes);
    await _saveState(
      status: HealthConnectionStatus.connected,
      enabledTypes: enabledTypes,
      signals: signals,
    );
    return HealthConnectionState(
      status: HealthConnectionStatus.connected,
      supportedTypes: availability.supportedTypes,
      enabledTypes: enabledTypes,
      signals: signals,
      statusDetail: authorization.message,
      providerLabel: provider.providerLabel,
    );
  }

  @override
  Future<HealthConnectionState> disconnect() async {
    await _saveState(
      status: HealthConnectionStatus.disconnected,
      enabledTypes: {},
      signals: null,
    );
    return HealthConnectionState.disconnected.copyWith(
      providerLabel: provider.providerLabel,
    );
  }

  HealthConnectionStatus _storedStatus() {
    final status = _preferences.getString(statusKey);
    return HealthConnectionStatus.values.firstWhere(
      (option) => option.name == status,
      orElse: () => HealthConnectionStatus.disconnected,
    );
  }

  Set<HealthDataType> _storedEnabledTypes() {
    final values = _preferences.getStringList(enabledTypesKey) ?? const [];
    return values
        .map(_healthDataTypeFromName)
        .whereType<HealthDataType>()
        .toSet();
  }

  HealthSignalSnapshot? _storedSignals() {
    final rawSignals = _preferences.getString(signalsKey);
    if (rawSignals == null || rawSignals.isEmpty) {
      return null;
    }
    final decoded = decodePersistedJsonMap(rawSignals);
    if (decoded == null) {
      return null;
    }
    return HealthSignalSnapshot.fromJson(decoded);
  }

  Future<HealthConnectionState> _persistedUnavailable(
    HealthPlatformAvailability availability,
  ) async {
    await _saveState(
      status: HealthConnectionStatus.unavailable,
      enabledTypes: {},
      signals: null,
    );
    return HealthConnectionState(
      status: HealthConnectionStatus.unavailable,
      supportedTypes: availability.supportedTypes,
      enabledTypes: {},
      statusDetail: availability.message,
      providerLabel: provider.providerLabel,
    );
  }

  Future<void> _saveState({
    required HealthConnectionStatus status,
    required Set<HealthDataType> enabledTypes,
    required HealthSignalSnapshot? signals,
  }) async {
    await _preferences.setString(statusKey, status.name);
    await _preferences.setStringList(
      enabledTypesKey,
      enabledTypes.map((type) => type.name).toList(growable: false),
    );
    if (signals == null) {
      await _preferences.remove(signalsKey);
    } else {
      await _preferences.setString(signalsKey, jsonEncode(signals.toJson()));
    }
  }
}

class InMemoryHealthRepository implements HealthRepository {
  InMemoryHealthRepository({
    this.provider = const MockHealthDataProvider(),
    HealthConnectionState? initialState,
  }) : _state = initialState;

  final HealthDataProvider provider;
  HealthConnectionState? _state;

  @override
  Future<HealthConnectionState> loadState() async {
    final state = _state;
    if (state != null) {
      return state;
    }
    final availability = await provider.checkAvailability();
    if (!availability.isAvailable) {
      return HealthConnectionState(
        status: HealthConnectionStatus.unavailable,
        supportedTypes: availability.supportedTypes,
        enabledTypes: {},
        statusDetail: availability.message,
        providerLabel: provider.providerLabel,
      );
    }
    return HealthConnectionState.disconnected.copyWith(
      supportedTypes: availability.supportedTypes,
      providerLabel: provider.providerLabel,
    );
  }

  @override
  Future<HealthConnectionState> requestConnection() async {
    final availability = await provider.checkAvailability();
    if (!availability.isAvailable) {
      _state = HealthConnectionState(
        status: HealthConnectionStatus.unavailable,
        supportedTypes: availability.supportedTypes,
        enabledTypes: {},
        statusDetail: availability.message,
        providerLabel: provider.providerLabel,
      );
      return _state!;
    }

    final requestedTypes = HealthConnectionState.mvpTypes.intersection(
      availability.supportedTypes,
    );
    final authorization = await provider.requestAuthorization(requestedTypes);
    if (authorization.status == HealthAuthorizationStatus.denied) {
      _state = HealthConnectionState(
        status: HealthConnectionStatus.denied,
        supportedTypes: availability.supportedTypes,
        enabledTypes: {},
        statusDetail: authorization.message,
        providerLabel: provider.providerLabel,
      );
      return _state!;
    }
    if (authorization.status == HealthAuthorizationStatus.unavailable) {
      _state = HealthConnectionState(
        status: HealthConnectionStatus.unavailable,
        supportedTypes: availability.supportedTypes,
        enabledTypes: {},
        statusDetail: authorization.message,
        providerLabel: provider.providerLabel,
      );
      return _state!;
    }

    final enabledTypes = authorization.grantedTypes.intersection(
      availability.supportedTypes,
    );
    _state = HealthConnectionState(
      status: HealthConnectionStatus.connected,
      supportedTypes: availability.supportedTypes,
      enabledTypes: enabledTypes,
      signals: await provider.readSignals(enabledTypes),
      statusDetail: authorization.message,
      providerLabel: provider.providerLabel,
    );
    return _state!;
  }

  @override
  Future<HealthConnectionState> disconnect() async {
    _state = HealthConnectionState.disconnected.copyWith(
      providerLabel: provider.providerLabel,
    );
    return _state!;
  }
}

HealthDataType? _healthDataTypeFromName(String name) {
  for (final type in HealthDataType.values) {
    if (type.name == name) {
      return type;
    }
  }
  return null;
}
