import 'package:goodbar/src/core/failures/screen_failures.dart';

/// Factory methods for creating test failures
/// 
/// Provides convenient ways to create failure instances
/// for testing error handling in display-related features.
class TestFailures {
  /// Creates a platform channel failure
  /// 
  /// Simulates communication errors with the native platform.
  static PlatformChannelFailure platformChannel([String? message]) {
    return PlatformChannelFailure(
      message ?? 'Platform channel communication failed',
    );
  }
  
  /// Creates a display not found failure
  /// 
  /// Simulates attempts to access non-existent displays.
  static DisplayNotFoundFailure displayNotFound([String? id]) {
    return DisplayNotFoundFailure(id ?? 'unknown');
  }
  
  /// Creates an unknown screen failure
  /// 
  /// Simulates unexpected errors in display operations.
  static UnknownScreenFailure unknown([String? message]) {
    return UnknownScreenFailure(
      message ?? 'An unexpected error occurred',
    );
  }
}