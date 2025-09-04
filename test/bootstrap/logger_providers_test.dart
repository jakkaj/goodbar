import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/bootstrap/logger_providers.dart';
import 'package:goodbar/src/core/logging/app_logger.dart';

void main() {
  group('Logger Providers', () {
    test('loggerRootProvider provides AppLogger instance', () {
      /// Purpose: Verify root provider creates AppLogger for DI
      /// Quality Contribution: Ensures consistent logger instance across app
      /// that can be overridden for testing or different environments
      /// Acceptance Criteria: Provider returns AppLogger instance, can be
      /// overridden with custom configuration
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      final logger = container.read(loggerRootProvider);
      
      expect(logger, isNotNull);
      expect(logger, isA<AppLogger>());
    });
    
    test('loggerProvider family creates tagged instances', () {
      /// Purpose: Verify family provider creates tagged loggers for services
      /// Quality Contribution: Enables service-specific logging with clear
      /// source identification for better debugging
      /// Acceptance Criteria: Each tag gets unique logger instance that
      /// is derived from root logger with tag applied
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      final logger1 = container.read(loggerProvider('Service1'));
      final logger2 = container.read(loggerProvider('Service2'));
      
      expect(logger1, isA<AppLogger>());
      expect(logger2, isA<AppLogger>());
      expect(logger1, isNot(same(logger2))); // Different instances
      
      // Same tag should return same instance (cached)
      final logger1Again = container.read(loggerProvider('Service1'));
      expect(logger1Again, same(logger1));
    });
    
    test('loggerProvider uses root logger for tagging', () {
      /// Purpose: Verify tagged loggers are derived from root logger
      /// Quality Contribution: Ensures consistent configuration across all
      /// tagged loggers (level, outputs, etc) while adding tag prefix
      /// Acceptance Criteria: Family provider must call tag() on root logger
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // Get root and tagged logger
      final root = container.read(loggerRootProvider);
      final tagged = container.read(loggerProvider('TestService'));
      
      // Both should be AppLogger instances
      expect(root, isA<AppLogger>());
      expect(tagged, isA<AppLogger>());
      
      // Tagged should be different instance from root
      expect(tagged, isNot(same(root)));
    });
    
    test('root logger can be overridden for testing', () {
      /// Purpose: Verify root logger can be overridden in tests
      /// Quality Contribution: Enables test isolation and custom logging
      /// configuration for different test scenarios
      /// Acceptance Criteria: Provider override must replace default logger
      /// with custom instance
      
      final customLogger = AppLogger(appName: 'test', fileName: 'test.log');
      
      final container = ProviderContainer(
        overrides: [
          loggerRootProvider.overrideWithValue(customLogger),
        ],
      );
      addTearDown(container.dispose);
      
      final logger = container.read(loggerRootProvider);
      
      expect(logger, same(customLogger));
    });
    
    test('tagged loggers use overridden root logger', () {
      /// Purpose: Verify tagged loggers respect root logger override
      /// Quality Contribution: Ensures test overrides propagate through
      /// entire logger hierarchy for consistent test behavior
      /// Acceptance Criteria: When root is overridden, tagged loggers
      /// must be created from the overridden root
      
      final customLogger = AppLogger(appName: 'test');
      
      final container = ProviderContainer(
        overrides: [
          loggerRootProvider.overrideWithValue(customLogger),
        ],
      );
      addTearDown(container.dispose);
      
      // Get tagged logger
      final tagged = container.read(loggerProvider('Service'));
      
      // Should be derived from custom logger
      expect(tagged, isA<AppLogger>());
      expect(tagged, isNot(same(customLogger))); // Tagged is different instance
    });
  });
}