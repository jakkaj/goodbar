import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/logging/app_logger.dart';

/// Root logger provider for the application.
/// 
/// This can be overridden in main.dart for production configuration
/// or in tests for custom logging behavior.
/// 
/// Example override in main.dart:
/// ```dart
/// ProviderScope(
///   overrides: [
///     loggerRootProvider.overrideWithValue(
///       AppLogger(appName: 'goodbar', fileName: 'app.log')
///     ),
///   ],
///   child: MyApp(),
/// )
/// ```
final loggerRootProvider = Provider<AppLogger>((ref) {
  // Safe default for dev; main() overrides for release file logging
  return AppLogger(appName: 'goodbar');
});

/// Tagged logger provider for feature/service specific logging.
/// 
/// Creates a tagged logger instance derived from the root logger.
/// Each service/feature should use this to get its own tagged logger.
/// 
/// Usage:
/// ```dart
/// final screenServiceProvider = Provider<ScreenService>((ref) {
///   final log = ref.watch(loggerProvider('ScreenService'));
///   return MacScreenService(log: log);
/// });
/// ```
final loggerProvider = Provider.family<AppLogger, String>((ref, tag) {
  final root = ref.watch(loggerRootProvider);
  return root.tag(tag);
});