/// Failure types for screen/display operations.
/// 
/// This follows the canonical error handling pattern from docs/rules/riverpod.md
/// using sealed classes for exhaustive pattern matching.
sealed class ScreenFailure implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  
  const ScreenFailure(this.message, {this.cause, this.stackTrace});
  
  @override
  String toString() => message;
}

/// Failure when platform channel communication fails.
final class PlatformChannelFailure extends ScreenFailure {
  const PlatformChannelFailure(super.message, {super.cause, super.stackTrace});
}

/// Failure when a specific display cannot be found.
final class DisplayNotFoundFailure extends ScreenFailure {
  final String displayId;
  
  const DisplayNotFoundFailure(this.displayId, {Object? cause, StackTrace? stackTrace})
      : super('Display $displayId not found', cause: cause, stackTrace: stackTrace);
}

/// Failure when display configuration changes cannot be monitored.
final class DisplayMonitoringFailure extends ScreenFailure {
  const DisplayMonitoringFailure(super.message, {super.cause, super.stackTrace});
}

/// Generic/unknown screen service failure.
final class UnknownScreenFailure extends ScreenFailure {
  const UnknownScreenFailure(super.message, {super.cause, super.stackTrace});
}