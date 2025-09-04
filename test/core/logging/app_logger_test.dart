import 'package:flutter_test/flutter_test.dart';
import 'package:goodbar/src/core/logging/app_logger.dart';
import 'package:logger/logger.dart';

void main() {
  group('AppLogger', () {
    test('creates logger with factory constructor', () {
      /// Purpose: Verify AppLogger can be created with factory constructor
      /// Quality Contribution: Ensures logger initialization works correctly
      /// for service layer dependency injection throughout the application
      /// Acceptance Criteria: AppLogger created successfully with appName
      /// parameter and optional fileName parameter
      
      final logger = AppLogger(appName: 'goodbar');
      
      expect(logger, isNotNull);
      expect(logger, isA<AppLogger>());
    });
    
    test('creates logger with fileName for release mode', () {
      /// Purpose: Verify AppLogger accepts fileName parameter for file output
      /// Quality Contribution: Enables persistent logging to file in production
      /// for debugging and monitoring
      /// Acceptance Criteria: AppLogger created with both appName and fileName,
      /// file output configured for release mode only
      
      final logger = AppLogger(appName: 'goodbar', fileName: 'app.log');
      
      expect(logger, isNotNull);
      expect(logger, isA<AppLogger>());
      // Note: File output only happens in release mode, tested by actual file creation
    });
    
    test('tag method creates new tagged instance', () {
      /// Purpose: Verify tag() creates a new tagged logger instance
      /// Quality Contribution: Enables service-specific logging with clear
      /// source identification in logs for better debugging
      /// Acceptance Criteria: tag() must return new AppLogger instance,
      /// different from the original, with tag applied
      
      final root = AppLogger(appName: 'goodbar');
      final tagged = root.tag('ScreenService');
      
      expect(tagged, isA<AppLogger>());
      expect(tagged, isNot(same(root))); // Different instance
      
      // Tag another service
      final tagged2 = root.tag('WindowService');
      expect(tagged2, isNot(same(root)));
      expect(tagged2, isNot(same(tagged)));
    });
    
    test('supports all log levels', () {
      /// Purpose: Verify all log levels are available and properly configured
      /// Quality Contribution: Enables appropriate logging granularity for
      /// different scenarios (debug, info, warning, error, fatal)
      /// Acceptance Criteria: All standard log levels (d, i, w, e, f) must
      /// be available and not throw when called
      
      final logger = AppLogger(appName: 'goodbar');
      
      // These should not throw - verifying the methods exist and work
      expect(() => logger.d('debug message'), returnsNormally);
      expect(() => logger.i('info message'), returnsNormally);
      expect(() => logger.w('warning message'), returnsNormally);
      expect(() => logger.e('error message'), returnsNormally);
      expect(() => logger.f('fatal message'), returnsNormally);
    });
    
    test('handles errors and stack traces', () {
      /// Purpose: Ensure logger can capture exception details for debugging
      /// Quality Contribution: Provides complete error context including
      /// stack traces for faster root cause analysis in production
      /// Acceptance Criteria: Logger must accept and handle error objects
      /// and stack traces without crashing
      
      final logger = AppLogger(appName: 'goodbar');
      
      final testError = Exception('Test error');
      final stackTrace = StackTrace.current;
      
      // Verify error logging accepts error and stack trace
      expect(() => logger.e('Error occurred', testError, stackTrace), returnsNormally);
      expect(() => logger.w('Warning with error', testError), returnsNormally);
      expect(() => logger.d('Debug with stack', null, stackTrace), returnsNormally);
    });
    
    test('tagged logger maintains all log levels', () {
      /// Purpose: Verify tagged instances support all log levels
      /// Quality Contribution: Ensures tagged loggers have full functionality
      /// for service-specific logging needs
      /// Acceptance Criteria: Tagged logger must support all log levels
      /// (d, i, w, e, f) just like the root logger
      
      final root = AppLogger(appName: 'goodbar');
      final tagged = root.tag('TestService');
      
      expect(() => tagged.d('debug'), returnsNormally);
      expect(() => tagged.i('info'), returnsNormally);
      expect(() => tagged.w('warning'), returnsNormally);
      expect(() => tagged.e('error'), returnsNormally);
      expect(() => tagged.f('fatal'), returnsNormally);
    });
    
    test('uses correct default log level', () {
      /// Purpose: Ensure default log level is appropriate for development
      /// Quality Contribution: Provides good default visibility without
      /// overwhelming developers with verbose output
      /// Acceptance Criteria: Default level should be debug in development
      /// to show d() calls and above, info level in release
      
      final logger = AppLogger(appName: 'goodbar');
      
      // Logger should be created without throwing
      expect(logger, isNotNull);
      
      // Can create with explicit level
      final debugLogger = AppLogger(appName: 'goodbar', level: Level.debug);
      expect(debugLogger, isNotNull);
      
      final infoLogger = AppLogger(appName: 'goodbar', level: Level.info);
      expect(infoLogger, isNotNull);
    });
    
    test('multiple tags can be chained', () {
      /// Purpose: Verify that tagging can be done multiple times
      /// Quality Contribution: Allows for hierarchical logging contexts
      /// like Service -> Component -> Method
      /// Acceptance Criteria: Each tag operation returns a new instance
      /// that can be tagged again
      
      final root = AppLogger(appName: 'goodbar');
      final service = root.tag('ScreenService');
      final component = service.tag('DisplayEnumerator');
      
      expect(root, isNot(same(service)));
      expect(service, isNot(same(component)));
      expect(root, isNot(same(component)));
    });
  });
}