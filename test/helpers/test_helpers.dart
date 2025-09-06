import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';
import 'package:goodbar/src/core/failures/screen_failures.dart';
import 'package:goodbar/src/providers/services.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';

/// Custom matchers for AsyncValue states
/// 
/// These matchers provide readable assertions for provider state testing.
/// They improve test readability and provide better error messages.
Matcher isLoading<T>() => isA<AsyncLoading<T>>();

Matcher isData<T>(dynamic Function(T) predicate) => 
    isA<AsyncData<T>>().having(
      (d) => predicate(d.value), 
      'predicate matches', 
      isTrue,
    );

Matcher isDataWithValue<T>(T expected) => 
    isA<AsyncData<T>>().having(
      (d) => d.value, 
      'value', 
      equals(expected),
    );

Matcher isError<T>() => isA<AsyncError<T>>();

Matcher isErrorWithType<T, E>() => 
    isA<AsyncError<T>>().having(
      (e) => e.error, 
      'error', 
      isA<E>(),
    );

Matcher isErrorWithMessage<T>(String message) => 
    isA<AsyncError<T>>().having(
      (e) => e.error.toString(), 
      'error message', 
      contains(message),
    );

/// Test data builders for Display models
/// 
/// These builders provide sensible defaults while allowing specific overrides.
/// They represent realistic display configurations from actual macOS systems.
class DisplayBuilders {
  /// Creates a MacBook Pro 16" built-in Retina display (primary)
  static Display macBookPro16({
    String id = '1',
    bool isPrimary = true,
  }) {
    return Display(
      id: id,
      bounds: const Rectangle(x: 0, y: 0, width: 3456, height: 2234),
      workArea: const Rectangle(x: 0, y: 25, width: 3456, height: 2184),
      scaleFactor: 2.0,
      isPrimary: isPrimary,
    );
  }

  /// Creates a 4K external monitor
  static Display external4K({
    String id = '2',
    double x = 3456,
    double y = 0,
  }) {
    return Display(
      id: id,
      bounds: Rectangle(x: x, y: y, width: 3840, height: 2160),
      workArea: Rectangle(x: x, y: y, width: 3840, height: 2160),
      scaleFactor: 2.0,
      isPrimary: false,
    );
  }

  /// Creates a 1080p external monitor
  static Display external1080p({
    String id = '3',
    double x = 0,
    double y = -1080,
  }) {
    return Display(
      id: id,
      bounds: Rectangle(x: x, y: y, width: 1920, height: 1080),
      workArea: Rectangle(x: x, y: y, width: 1920, height: 1080),
      scaleFactor: 1.0,
      isPrimary: false,
    );
  }

  /// Creates a standard 3-display development setup
  static List<Display> threeDisplaySetup() {
    return [
      macBookPro16(),
      external4K(),
      external1080p(),
    ];
  }

  /// Creates a custom display with specific properties
  static Display custom({
    required String id,
    required double width,
    required double height,
    double x = 0,
    double y = 0,
    double scaleFactor = 1.0,
    bool isPrimary = false,
    double menuBarHeight = 25,
  }) {
    return Display(
      id: id,
      bounds: Rectangle(x: x, y: y, width: width, height: height),
      workArea: Rectangle(
        x: x, 
        y: y + (isPrimary ? menuBarHeight : 0), 
        width: width, 
        height: height - (isPrimary ? menuBarHeight : 0),
      ),
      scaleFactor: scaleFactor,
      isPrimary: isPrimary,
    );
  }
}

/// Container setup helpers for common test scenarios
class TestContainers {
  /// Creates a container with a successful FakeScreenService
  static ProviderContainer withSuccessfulService({
    List<Display>? displays,
  }) {
    final service = FakeScreenService(displays: displays);
    return ProviderContainer(
      overrides: [
        screenServiceProvider.overrideWithValue(service),
      ],
    );
  }

  /// Creates a container with a failing FakeScreenService
  static ProviderContainer withFailingService(ScreenFailure failure) {
    final service = FakeScreenService();
    service.setFailure(failure);
    return ProviderContainer(
      overrides: [
        screenServiceProvider.overrideWithValue(service),
      ],
    );
  }

  /// Creates a container with custom overrides
  static ProviderContainer withOverrides(List<Override> overrides) {
    return ProviderContainer(overrides: overrides);
  }
}

/// Extension methods for testing async providers
/// 
/// Usage patterns for state assertions:
/// 
/// Use `containsAllInOrder` when:
/// - You care about the sequence but may have intermediate states
/// - Testing state machines with predictable transitions
/// - Example: expect(states, containsAllInOrder([loading, data]))
/// 
/// Use direct list equality when:
/// - You need to verify exact state count and sequence
/// - Testing that no unexpected states occurred
/// - Example: expect(states, [loading, data]) // exactly 2 states
extension AsyncProviderTestExtensions on ProviderContainer {
  /// Pumps the container to resolve async operations
  /// 
  /// This is the canonical way to wait for async providers to resolve
  /// in tests. It ensures all microtasks are completed.
  Future<void> pump() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  /// Listens to a provider and collects all state transitions
  /// 
  /// Returns a list that will be populated with all state changes.
  /// Useful for verifying the complete sequence of AsyncValue transitions.
  /// 
  /// IMPORTANT: Subscriptions are automatically cleaned up when the
  /// container is disposed. No manual cleanup is needed.
  List<T> collectStates<T>(ProviderListenable<T> provider) {
    final states = <T>[];
    listen(provider, (previous, next) {
      states.add(next);
    }, fireImmediately: true);
    
    // Subscriptions are automatically cleaned up when container is disposed
    // No need to track them separately
    
    return states;
  }
}

/// Test failure builders for common error scenarios
class TestFailures {
  static PlatformChannelFailure platformChannel([String? message]) {
    return PlatformChannelFailure(
      message ?? 'Platform channel communication failed',
    );
  }

  static DisplayNotFoundFailure displayNotFound([String? id]) {
    return DisplayNotFoundFailure(id ?? 'unknown');
  }

  static UnknownScreenFailure unknown([String? message]) {
    return UnknownScreenFailure(
      message ?? 'An unexpected error occurred',
    );
  }
}

/// Pump utilities for controlled async resolution
class PumpUtilities {
  /// Pumps with a specific delay
  static Future<void> pumpWithDelay(Duration delay) async {
    await Future<void>.delayed(delay);
  }

  /// Pumps until a condition is met or timeout
  static Future<void> pumpUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (!condition() && stopwatch.elapsed < timeout) {
      await Future<void>.delayed(interval);
    }
    
    if (!condition()) {
      throw TimeoutException('Condition not met within timeout', timeout);
    }
  }
}

/// Test assertions for Display properties
class DisplayAssertions {
  /// Asserts that display properties are valid
  static void assertValidDisplay(Display display) {
    expect(display.id, isNotEmpty, reason: 'Display must have an ID');
    expect(display.width, greaterThan(0), reason: 'Width must be positive');
    expect(display.height, greaterThan(0), reason: 'Height must be positive');
    expect(display.scaleFactor, greaterThan(0), reason: 'Scale factor must be positive');
    expect(display.workArea.width, lessThanOrEqualTo(display.bounds.width),
        reason: 'Work area width cannot exceed bounds width');
    expect(display.workArea.height, lessThanOrEqualTo(display.bounds.height),
        reason: 'Work area height cannot exceed bounds height');
  }

  /// Asserts that a display is primary with expected characteristics
  static void assertPrimaryDisplay(Display display) {
    expect(display.isPrimary, isTrue, reason: 'Display should be primary');
    expect(display.menuBarHeight, greaterThan(0), 
        reason: 'Primary display should have menu bar');
  }

  /// Asserts display arrangement relationships
  static void assertDisplayArrangement(List<Display> displays) {
    // Verify exactly one primary
    final primaryCount = displays.where((d) => d.isPrimary).length;
    expect(primaryCount, equals(1), 
        reason: 'There should be exactly one primary display');
    
    // Verify unique IDs
    final ids = displays.map((d) => d.id).toSet();
    expect(ids.length, equals(displays.length), 
        reason: 'All display IDs should be unique');
    
    // Verify no overlapping bounds (simplified check)
    for (var i = 0; i < displays.length; i++) {
      for (var j = i + 1; j < displays.length; j++) {
        final d1 = displays[i];
        final d2 = displays[j];
        final overlap = _rectanglesOverlap(d1.bounds, d2.bounds);
        expect(overlap, isFalse, 
            reason: 'Display ${d1.id} and ${d2.id} should not overlap');
      }
    }
  }

  static bool _rectanglesOverlap(Rectangle r1, Rectangle r2) {
    return !(r1.right <= r2.left || 
             r2.right <= r1.left || 
             r1.bottom <= r2.top || 
             r2.bottom <= r1.top);
  }
}