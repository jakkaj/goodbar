import 'dart:async';

/// Generic pump utilities for controlled async resolution in tests
/// 
/// These utilities help manage asynchronous operations in tests,
/// providing controlled timing and condition-based waiting.
/// 
/// Usage:
/// ```dart
/// await PumpUtilities.pumpWithDelay(Duration(milliseconds: 100));
/// await PumpUtilities.pumpUntil(() => widget.isReady);
/// ```

class PumpUtilities {
  /// Pumps with a specific delay
  /// 
  /// Useful when you need to wait for a known duration,
  /// such as animation timings or debounce delays.
  static Future<void> pumpWithDelay(Duration delay) async {
    await Future<void>.delayed(delay);
  }
  
  /// Pumps until a condition is met or timeout occurs
  /// 
  /// Repeatedly checks the condition at intervals until it returns true
  /// or the timeout is reached. Throws TimeoutException if condition
  /// is not met within the timeout period.
  /// 
  /// Example:
  /// ```dart
  /// await PumpUtilities.pumpUntil(
  ///   () => container.read(myProvider).hasData,
  ///   timeout: Duration(seconds: 3),
  /// );
  /// ```
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
  
  /// Pumps for a single microtask
  /// 
  /// Useful for allowing stream events to be delivered or
  /// synchronous callbacks to complete.
  static Future<void> pumpMicrotask() async {
    await Future<void>.delayed(Duration.zero);
  }
}