import 'package:ai_nutrition_companion/domain/models/health.dart';
import 'package:ai_nutrition_companion/domain/repositories/health_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('InMemoryHealthRepository', () {
    test('starts disconnected without reading health signals', () async {
      final provider = _CountingHealthDataProvider();
      final repository = InMemoryHealthRepository(provider: provider);

      final state = await repository.loadState();

      expect(state.status, HealthConnectionStatus.disconnected);
      expect(state.signals, isNull);
      expect(provider.authorizationRequests, 0);
      expect(provider.signalReads, 0);
    });

    test('connect requests permission and exposes mock MVP signals', () async {
      final repository = InMemoryHealthRepository(
        provider: const MockHealthDataProvider(),
      );

      final state = await repository.requestConnection();

      expect(state.status, HealthConnectionStatus.connected);
      expect(state.enabledTypes, HealthConnectionState.mvpTypes);
      expect(state.signals?.sleepHours, 6.8);
      expect(state.signals?.activeMinutes, 42);
    });

    test('denied permission keeps signals disconnected', () async {
      final repository = InMemoryHealthRepository(
        provider: const MockHealthDataProvider(
          authorizationResult: HealthAuthorizationResult.denied,
        ),
      );

      final state = await repository.requestConnection();

      expect(state.status, HealthConnectionStatus.denied);
      expect(state.enabledTypes, isEmpty);
      expect(state.signals, isNull);
    });

    test('unavailable provider reports platform gap', () async {
      final repository = InMemoryHealthRepository(
        provider: const MockHealthDataProvider(
          availability: HealthPlatformAvailability.unavailable,
        ),
      );

      final state = await repository.loadState();

      expect(state.status, HealthConnectionStatus.unavailable);
      expect(state.canRequestConnection, isFalse);
      expect(state.explainer, contains('not available'));
    });
  });

  group('SharedPreferencesHealthRepository', () {
    test('ignores corrupt persisted health signals', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesHealthRepository.statusKey: 'connected',
        SharedPreferencesHealthRepository.enabledTypesKey: ['weight'],
        SharedPreferencesHealthRepository.signalsKey: '{"weightKg":',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesHealthRepository(
        preferences,
        provider: const MockHealthDataProvider(signals: null),
      );

      final state = await repository.loadState();

      expect(state.status, HealthConnectionStatus.connected);
      expect(state.signals, isNull);
    });

    test('ignores wrong persisted health signal shape', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesHealthRepository.statusKey: 'connected',
        SharedPreferencesHealthRepository.enabledTypesKey: ['weight'],
        SharedPreferencesHealthRepository.signalsKey: '[78.4]',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesHealthRepository(
        preferences,
        provider: const MockHealthDataProvider(signals: null),
      );

      final state = await repository.loadState();

      expect(state.status, HealthConnectionStatus.connected);
      expect(state.signals, isNull);
    });

    test('loads valid legacy persisted health signals', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesHealthRepository.statusKey: 'connected',
        SharedPreferencesHealthRepository.enabledTypesKey: ['weight'],
        SharedPreferencesHealthRepository.signalsKey:
            '{"weightKg": 78.4, "capturedAt": "2026-06-29T15:30:00.000"}',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesHealthRepository(
        preferences,
        provider: const MockHealthDataProvider(signals: null),
      );

      final state = await repository.loadState();

      expect(state.status, HealthConnectionStatus.connected);
      expect(state.signals?.weightKg, 78.4);
      expect(state.signals?.capturedAt, DateTime(2026, 6, 29, 15, 30));
    });
  });
}

class _CountingHealthDataProvider implements HealthDataProvider {
  int authorizationRequests = 0;
  int signalReads = 0;

  @override
  String get providerLabel => 'Counting health provider';

  @override
  Future<HealthPlatformAvailability> checkAvailability() async {
    return const HealthPlatformAvailability(
      isAvailable: true,
      supportedTypes: HealthConnectionState.mvpTypes,
    );
  }

  @override
  Future<HealthAuthorizationResult> requestAuthorization(
    Set<HealthDataType> types,
  ) async {
    authorizationRequests += 1;
    return HealthAuthorizationResult(
      status: HealthAuthorizationStatus.authorized,
      grantedTypes: types,
    );
  }

  @override
  Future<HealthSignalSnapshot?> readSignals(Set<HealthDataType> types) async {
    signalReads += 1;
    return HealthSignalSnapshot.mock;
  }
}
