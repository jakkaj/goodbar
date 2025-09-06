import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/failures/screen_failures.dart';
import 'package:goodbar/src/providers/displays_provider.dart';
import 'package:goodbar/src/providers/services.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import 'fixtures.dart';
import 'failures.dart';

/// Mock provider factories for testing different AsyncValue states
/// 
/// These factories create providers pre-configured for specific test scenarios.
/// They eliminate boilerplate in tests and ensure consistent test setup.
class MockProviders {
  /// Creates a provider stuck in loading state
  /// 
  /// Useful for testing loading UI and ensuring loading indicators appear.
  static Override loadingDisplaysProvider() {
    return displaysProvider.overrideWith(() => _LoadingDisplays());
  }
  
  /// Creates a provider with successful display data
  /// 
  /// Accepts optional custom displays or uses default test data.
  /// Useful for testing happy path UI and display list rendering.
  static Override successfulDisplaysProvider([List<Display>? displays]) {
    final testDisplays = displays ?? DisplayBuilders.threeDisplaySetup();
    return displaysProvider.overrideWith(() => _SuccessDisplays(testDisplays));
  }
  
  /// Creates a provider with an error state
  /// 
  /// Accepts a specific failure or uses a default platform channel failure.
  /// Useful for testing error UI and retry mechanisms.
  static Override errorDisplaysProvider([ScreenFailure? failure]) {
    final error = failure ?? TestFailures.platformChannel();
    return displaysProvider.overrideWith(() => _ErrorDisplays(error));
  }
  
  /// Creates a provider with a controllable fake service
  /// 
  /// Returns both the override and the service for test manipulation.
  /// Useful for complex scenarios requiring state changes during tests.
  static ({Override override, FakeScreenService service}) controllableServiceProvider({
    List<Display>? initialDisplays,
  }) {
    final service = FakeScreenService(displays: initialDisplays);
    final override = screenServiceProvider.overrideWithValue(service);
    return (override: override, service: service);
  }
}

/// A Displays notifier that never completes build(), keeping the state loading.
class _LoadingDisplays extends Displays {
  @override
  Future<List<Display>> build() async {
    // Return a Future that never completes to hold the loading state
    final completer = Completer<List<Display>>();
    return completer.future;
  }
}

/// A Displays notifier that immediately yields AsyncData with provided displays.
class _SuccessDisplays extends Displays {
  _SuccessDisplays(this._displays);
  final List<Display> _displays;
  @override
  Future<List<Display>> build() async {
    state = AsyncData(_displays);
    return _displays;
  }
}

/// A Displays notifier that immediately errors with the provided failure.
class _ErrorDisplays extends Displays {
  _ErrorDisplays(this._failure);
  final ScreenFailure _failure;
  @override
  Future<List<Display>> build() async {
    throw _failure;
  }
}

/// Pre-configured test containers for common scenarios
/// 
/// These containers come with all necessary overrides pre-applied.
/// They reduce boilerplate and ensure consistent test environments.
class MockContainers {
  /// Container with displays in loading state
  static ProviderContainer loading() {
    return ProviderContainer(
      overrides: [MockProviders.loadingDisplaysProvider()],
    );
  }
  
  /// Container with successful display detection
  static ProviderContainer withDisplays([List<Display>? displays]) {
    return ProviderContainer(
      overrides: [MockProviders.successfulDisplaysProvider(displays)],
    );
  }
  
  /// Container with error state
  static ProviderContainer withError([ScreenFailure? failure]) {
    return ProviderContainer(
      overrides: [MockProviders.errorDisplaysProvider(failure)],
    );
  }
  
  /// Container with controllable service for complex scenarios
  static ({ProviderContainer container, FakeScreenService service}) controllable({
    List<Display>? initialDisplays,
  }) {
    final result = MockProviders.controllableServiceProvider(
      initialDisplays: initialDisplays,
    );
    
    final container = ProviderContainer(
      overrides: [result.override],
    );
    
    return (container: container, service: result.service);
  }
}