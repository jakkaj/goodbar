import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/failures/screen_failures.dart';
import 'package:goodbar/src/providers/displays_provider.dart';
import 'package:goodbar/src/providers/services.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import 'test_helpers.dart';

/// Mock provider factories for testing different AsyncValue states
/// 
/// These factories create providers pre-configured for specific test scenarios.
/// They eliminate boilerplate in tests and ensure consistent test setup.
class MockProviders {
  /// Creates a provider stuck in loading state
  /// 
  /// Useful for testing loading UI and ensuring loading indicators appear.
  static Override loadingDisplaysProvider() {
    return displaysProvider.overrideWith(() {
      return Displays()..state = const AsyncLoading();
    });
  }
  
  /// Creates a provider with successful display data
  /// 
  /// Accepts optional custom displays or uses default test data.
  /// Useful for testing happy path UI and display list rendering.
  static Override successfulDisplaysProvider([List<Display>? displays]) {
    final testDisplays = displays ?? DisplayBuilders.threeDisplaySetup();
    return displaysProvider.overrideWith(() {
      return Displays()..state = AsyncData(testDisplays);
    });
  }
  
  /// Creates a provider with an error state
  /// 
  /// Accepts a specific failure or uses a default platform channel failure.
  /// Useful for testing error UI and retry mechanisms.
  static Override errorDisplaysProvider([ScreenFailure? failure]) {
    final error = failure ?? TestFailures.platformChannel();
    return displaysProvider.overrideWith(() {
      return Displays()..state = AsyncError(error, StackTrace.current);
    });
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

/// State transition helpers for testing AsyncValue changes
/// 
/// These helpers simulate realistic state transitions that occur
/// during actual app usage, ensuring tests cover real scenarios.
class StateTransitions {
  /// Simulates a successful load sequence
  /// 
  /// Transitions: Loading → Data
  static Future<void> simulateSuccessfulLoad(
    ProviderContainer container,
    FakeScreenService service, {
    List<Display>? displays,
  }) async {
    // Start in loading
    container.read(displaysProvider.notifier).state = const AsyncLoading();
    await container.pump();
    
    // Transition to data
    if (displays != null) {
      service.setDisplays(displays);
    }
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
  
  /// Simulates an error during load
  /// 
  /// Transitions: Loading → Error
  static Future<void> simulateErrorLoad(
    ProviderContainer container,
    FakeScreenService service,
    ScreenFailure failure,
  ) async {
    // Start in loading
    container.read(displaysProvider.notifier).state = const AsyncLoading();
    await container.pump();
    
    // Transition to error
    service.setFailure(failure);
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
  
  /// Simulates error recovery
  /// 
  /// Transitions: Error → Loading → Data
  static Future<void> simulateErrorRecovery(
    ProviderContainer container,
    FakeScreenService service, {
    List<Display>? recoveredDisplays,
  }) async {
    // Clear the failure
    service.clearFailure();
    if (recoveredDisplays != null) {
      service.setDisplays(recoveredDisplays);
    }
    
    // Refresh to recover
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
  
  /// Simulates display configuration change
  /// 
  /// Useful for testing display hot-plug scenarios
  static Future<void> simulateDisplayChange(
    ProviderContainer container,
    FakeScreenService service,
    List<Display> newDisplays,
  ) async {
    service.emitDisplayChange(newDisplays);
    await container.pump();
    
    // Refresh provider to pick up changes
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
}

/// Common test scenarios as complete setups
/// 
/// These scenarios represent real-world usage patterns and ensure
/// tests cover practical use cases, not just theoretical ones.
class TestScenarios {
  /// Laptop with no external displays
  static List<Display> laptopOnly() {
    return [DisplayBuilders.macBookPro16()];
  }
  
  /// Laptop docked with single external monitor
  static List<Display> dockedSingleMonitor() {
    return [
      DisplayBuilders.macBookPro16(),
      DisplayBuilders.external4K(),
    ];
  }
  
  /// Full development setup with multiple monitors
  static List<Display> developerSetup() {
    return DisplayBuilders.threeDisplaySetup();
  }
  
  /// Presentation mode with projector
  static List<Display> presentationMode() {
    return [
      DisplayBuilders.macBookPro16(),
      DisplayBuilders.custom(
        id: 'projector',
        width: 1920,
        height: 1080,
        x: 3456,
        y: 0,
        scaleFactor: 1.0,
        isPrimary: false,
      ),
    ];
  }
  
  /// Unusual configuration for edge case testing
  static List<Display> edgeCase() {
    return [
      // Vertical monitor on left
      DisplayBuilders.custom(
        id: 'vertical',
        width: 1080,
        height: 1920,
        x: -1080,
        y: 0,
        scaleFactor: 1.0,
      ),
      // Primary in center
      DisplayBuilders.macBookPro16(),
      // Ultra-wide on right
      DisplayBuilders.custom(
        id: 'ultrawide',
        width: 5120,
        height: 1440,
        x: 3456,
        y: 0,
        scaleFactor: 1.5,
      ),
    ];
  }
}