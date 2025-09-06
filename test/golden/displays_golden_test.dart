/// Golden Tests for DisplaysScreen
/// 
/// This file contains visual regression tests using golden_toolkit.
/// Golden tests capture screenshots of widgets and compare them against
/// reference images to detect unintended visual changes.
/// 
/// ## Strategy
/// 
/// We use golden_toolkit for its features:
/// - Font loading for consistent text rendering
/// - Device-agnostic testing with testGoldens
/// - Multi-scenario testing with GoldenBuilder
/// - Configurable image comparison tolerances
/// 
/// ## CI Configuration
/// 
/// For CI stability:
/// 1. Fonts are loaded via loadAppFonts() to ensure consistent rendering
/// 2. Platform is explicitly set in flutter_test_config.dart
/// 3. Goldens are generated on same OS as CI (macOS)
/// 4. Consider migration to Alchemist for better cross-platform stability
/// 
/// ## Updating Goldens
/// 
/// To update golden files after intentional UI changes:
/// ```bash
/// flutter test --update-goldens test/golden/displays_golden_test.dart
/// ```
/// 
/// ## Future Improvements
/// 
/// Consider migrating to Alchemist for:
/// - Platform-independent rendering (uses Impeller)
/// - Built-in CI mode with tolerance settings
/// - Better accessibility testing integration
/// - Automatic golden management

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:goodbar/src/widgets/displays_screen.dart';
import 'package:goodbar/src/providers/services.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mock_providers.dart';

void main() {
  // Configure golden toolkit for CI stability
  // This ensures fonts are loaded consistently across test runs
  setUpAll(() async {
    await loadAppFonts();
  });

  /// Helper to create themed app for consistent goldens
  Widget createGoldenApp({
      required Widget child,
      List<Override>? overrides,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return ProviderScope(
        overrides: overrides ?? [],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: child,
        ),
      );
    }
    
  group('DisplaysScreen Golden Tests', () {
    group('loading state', () {
      testGoldens('displays loading indicator correctly', (tester) async {
        /// Purpose: Visual regression test for loading state
        /// Quality Contribution: Ensures consistent loading UI across changes
        /// Acceptance Criteria: Loading state must match golden image
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [MockProviders.loadingDisplaysProvider()],
          ),
          surfaceSize: const Size(400, 600),
        );
        
        await screenMatchesGolden(tester, 'displays_screen_loading');
      });
    });
    
    group('data state', () {
      testGoldens('displays single display correctly', (tester) async {
        /// Purpose: Visual test for minimal display configuration
        /// Quality Contribution: Validates single display UI layout
        /// Acceptance Criteria: Single display card must match golden
        
        final service = FakeScreenService(
          displays: TestScenarios.laptopOnly(),
        );
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
          ),
          surfaceSize: const Size(400, 600),
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_single');
      });
      
      testGoldens('displays multiple displays with primary', (tester) async {
        /// Purpose: Visual test for multi-display configuration
        /// Quality Contribution: Validates complex display list rendering
        /// Acceptance Criteria: Multiple display cards with primary indicator
        
        final service = FakeScreenService(
          displays: TestScenarios.developerSetup(),
        );
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
          ),
          surfaceSize: const Size(400, 800),
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_multiple');
      });
      
      testGoldens('displays empty state correctly', (tester) async {
        /// Purpose: Visual test for no displays edge case
        /// Quality Contribution: Ensures graceful empty state presentation
        /// Acceptance Criteria: Empty state message must match golden
        
        final service = FakeScreenService(displays: []);
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
          ),
          surfaceSize: const Size(400, 600),
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_empty');
      });
    });
    
    group('error state', () {
      testGoldens('displays error state with retry button', (tester) async {
        /// Purpose: Visual test for error state UI
        /// Quality Contribution: Validates error communication design
        /// Acceptance Criteria: Error UI with retry must match golden
        
        final service = FakeScreenService();
        service.setFailure(TestFailures.platformChannel(
          'Failed to communicate with platform channel',
        ));
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
          ),
          surfaceSize: const Size(400, 600),
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_error');
      });
    });
    
    group('theme variations', () {
      testGoldens('renders correctly in dark mode', (tester) async {
        /// Purpose: Visual test for dark theme support
        /// Quality Contribution: Ensures accessibility in dark mode
        /// Acceptance Criteria: Dark mode must be visually correct
        
        final service = FakeScreenService(
          displays: TestScenarios.dockedSingleMonitor(),
        );
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
            themeMode: ThemeMode.dark,
          ),
          surfaceSize: const Size(400, 700),
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_dark');
      });
    });
    
    group('responsive layouts', () {
      testGoldens('adapts to narrow screens', (tester) async {
        /// Purpose: Visual test for responsive design
        /// Quality Contribution: Validates mobile-friendly layout
        /// Acceptance Criteria: Must be readable on narrow screens
        
        final service = FakeScreenService(
          displays: TestScenarios.developerSetup(),
        );
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
          ),
          surfaceSize: const Size(320, 800), // Narrow phone
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_narrow');
      });
      
      testGoldens('adapts to wide screens', (tester) async {
        /// Purpose: Visual test for tablet/desktop layout
        /// Quality Contribution: Validates wide screen optimization
        /// Acceptance Criteria: Must use space efficiently on wide screens
        
        final service = FakeScreenService(
          displays: TestScenarios.developerSetup(),
        );
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
          ),
          surfaceSize: const Size(800, 600), // Wide tablet/desktop
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_wide');
      });
    });
    
    group('edge cases', () {
      testGoldens('handles unusual display configurations', (tester) async {
        /// Purpose: Visual test for edge case configurations
        /// Quality Contribution: Ensures robustness with unusual setups
        /// Acceptance Criteria: Must render correctly with edge cases
        
        final service = FakeScreenService(
          displays: TestScenarios.edgeCase(),
        );
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
          ),
          surfaceSize: const Size(400, 900),
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_edge_case');
      });
      
      testGoldens('handles very long display information', (tester) async {
        /// Purpose: Visual test for text overflow handling
        /// Quality Contribution: Validates text wrapping and overflow
        /// Acceptance Criteria: Long text must not break layout
        
        final customDisplay = DisplayBuilders.custom(
          id: 'very-long-display-id-that-might-overflow',
          width: 9999,
          height: 9999,
          scaleFactor: 3.5,
          isPrimary: true,
        );
        
        final service = FakeScreenService(displays: [customDisplay]);
        
        await tester.pumpWidgetBuilder(
          const DisplaysScreen(),
          wrapper: (child) => createGoldenApp(
            child: child,
            overrides: [
              screenServiceProvider.overrideWithValue(service),
            ],
          ),
          surfaceSize: const Size(400, 600),
        );
        
        await tester.pumpAndSettle();
        await screenMatchesGolden(tester, 'displays_screen_overflow');
      });
    });
  });
  
  group('DisplaysScreen Component Goldens', () {
    testGoldens('display card variations', (tester) async {
      /// Purpose: Component-level visual testing
      /// Quality Contribution: Validates individual card designs
      /// Acceptance Criteria: Each card type must render correctly
      
      final displays = [
        DisplayBuilders.macBookPro16(isPrimary: true),
        DisplayBuilders.external4K(),
        DisplayBuilders.external1080p(),
        DisplayBuilders.custom(
          id: 'vertical',
          width: 1080,
          height: 1920,
          isPrimary: false,
        ),
      ];
      
      final service = FakeScreenService(displays: displays);
      
      await tester.pumpWidgetBuilder(
        const DisplaysScreen(),
        wrapper: (child) => createGoldenApp(
          child: child,
          overrides: [
            screenServiceProvider.overrideWithValue(service),
          ],
        ),
        surfaceSize: const Size(400, 1200),
      );
      
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'display_card_variations');
    });
  });
}