import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/widgets/displays_screen.dart';
import 'package:goodbar/src/providers/services.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mock_providers.dart';

void main() {
  group('DisplaysScreen Widget', () {
    late FakeScreenService service;
    
    setUp(() {
      service = FakeScreenService();
    });
    
    /// Helper to create a testable app with DisplaysScreen
    Widget createTestApp({List<Override>? overrides}) {
      return ProviderScope(
        overrides: overrides ?? [
          screenServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: DisplaysScreen(),
        ),
      );
    }
    
    group('loading state', () {
      testWidgets('shows loading indicator on initial load', (tester) async {
        /// Purpose: Verify loading UI appears during data fetch
        /// Quality Contribution: Ensures user sees feedback during async operations
        /// Acceptance Criteria: Must show CircularProgressIndicator and loading text
        
        await tester.pumpWidget(createTestApp());
        
        // Should show loading state immediately
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading displays...'), findsOneWidget);
        
        // Should not show error or data widgets
        expect(find.byIcon(Icons.error_outline), findsNothing);
        expect(find.byType(Card), findsNothing);
      });
      
      testWidgets('loading state has correct layout', (tester) async {
        /// Purpose: Verify loading UI is properly centered
        /// Quality Contribution: Ensures consistent UI presentation
        /// Acceptance Criteria: Loading widgets must be centered vertically
        
        await tester.pumpWidget(createTestApp());
        
        // Find the loading widget by key
        final loadingWidget = find.byKey(const Key('displays_loading'));
        expect(loadingWidget, findsOneWidget);
        
        // Verify column with loading content
        final columnFinder = find.descendant(
          of: loadingWidget,
          matching: find.byType(Column),
        );
        expect(columnFinder, findsOneWidget);
        
        // Verify vertical centering
        final column = tester.widget<Column>(columnFinder);
        expect(column.mainAxisAlignment, MainAxisAlignment.center);
      });
    });
    
    group('data state', () {
      testWidgets('displays list of detected displays', (tester) async {
        /// Purpose: Verify successful display rendering
        /// Quality Contribution: Core functionality - showing display information
        /// Acceptance Criteria: Must show cards for each display with correct info
        
        await tester.pumpWidget(createTestApp());
        
        // Wait for async load
        await tester.pumpAndSettle();
        
        // Should show 3 display cards (default fake data)
        expect(find.byType(Card), findsNWidgets(3));
        expect(find.byKey(const Key('display_card_1')), findsOneWidget);
        expect(find.byKey(const Key('display_card_2')), findsOneWidget);
        expect(find.byKey(const Key('display_card_3')), findsOneWidget);
        
        // Verify display IDs are shown
        expect(find.text('Display 1'), findsOneWidget);
        expect(find.text('Display 2'), findsOneWidget);
        expect(find.text('Display 3'), findsOneWidget);
        
        // Verify primary display has chip
        expect(find.text('Primary'), findsOneWidget);
      });
      
      testWidgets('shows display details correctly', (tester) async {
        /// Purpose: Verify display properties are rendered
        /// Quality Contribution: Ensures all display info is accessible to users
        /// Acceptance Criteria: Each card must show position, size, scale, etc.
        
        final customDisplay = DisplayBuilders.macBookPro16();
        service.setDisplays([customDisplay]);
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Verify display properties are shown
        expect(find.text('Position'), findsOneWidget);
        expect(find.text('(0, 0)'), findsOneWidget); // Position value
        
        expect(find.text('Size'), findsOneWidget);
        expect(find.text('3456 × 2234'), findsOneWidget); // Size value
        
        expect(find.text('Scale Factor'), findsOneWidget);
        expect(find.text('2.0×'), findsOneWidget); // Scale value
        
        expect(find.text('Menu Bar Height'), findsOneWidget);
        expect(find.text('Work Area'), findsOneWidget);
      });
      
      testWidgets('primary display has visual distinction', (tester) async {
        /// Purpose: Verify primary display is visually highlighted
        /// Quality Contribution: Helps users identify main display
        /// Acceptance Criteria: Primary display must have colored icon and chip
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Find the primary display card by key
        final primaryCard = find.byKey(const Key('display_card_1'));
        expect(primaryCard, findsOneWidget);
        
        // Primary display should have Primary chip
        final primaryChip = find.text('Primary');
        expect(primaryChip, findsOneWidget);
        
        // Verify chip is in primary card
        expect(
          find.descendant(of: primaryCard, matching: primaryChip),
          findsOneWidget,
        );
      });
      
      testWidgets('handles empty display list', (tester) async {
        /// Purpose: Verify graceful handling of no displays
        /// Quality Contribution: Prevents crash in edge cases
        /// Acceptance Criteria: Must show "No displays detected" message
        
        service.setDisplays([]);
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        expect(find.text('No displays detected'), findsOneWidget);
        expect(find.byType(Card), findsNothing);
      });
    });
    
    group('error state', () {
      testWidgets('shows error UI when loading fails', (tester) async {
        /// Purpose: Verify error state presentation
        /// Quality Contribution: Ensures errors are communicated to users
        /// Acceptance Criteria: Must show error icon, message, and retry button
        
        service.setFailure(TestFailures.platformChannel('Test error'));
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Should show error UI
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Error loading displays'), findsOneWidget);
        expect(find.textContaining('Test error'), findsOneWidget);
        
        // Should have retry button
        expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
        
        // Should not show loading or data
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(Card), findsNothing);
      });
      
      testWidgets('retry button triggers refresh', (tester) async {
        /// Purpose: Verify error recovery mechanism
        /// Quality Contribution: Enables users to recover from transient errors
        /// Acceptance Criteria: Retry must clear error and reload data
        
        service.setFailure(TestFailures.unknown('Network error'));
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Verify error state
        expect(find.textContaining('Network error'), findsOneWidget);
        
        // Clear error for retry
        service.clearFailure();
        
        // Tap retry button
        await tester.tap(find.byKey(const Key('retry_button')));
        await tester.pump(); // Start loading
        
        // Should show loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        await tester.pumpAndSettle(); // Complete loading
        
        // Should now show data
        expect(find.byType(Card), findsNWidgets(3));
        expect(find.textContaining('Network error'), findsNothing);
      });
    });
    
    group('refresh functionality', () {
      testWidgets('refresh button in app bar triggers reload', (tester) async {
        /// Purpose: Verify manual refresh capability
        /// Quality Contribution: Allows users to update display configuration
        /// Acceptance Criteria: Refresh icon must trigger provider refresh
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Initial data should be loaded
        expect(find.text('Display 1'), findsOneWidget);
        
        // Change the service data
        service.setDisplays(TestScenarios.dockedSingleMonitor());
        
        // Tap refresh button
        await tester.tap(find.byKey(const Key('refresh_button')));
        await tester.pump(); // Start refresh
        
        // Should show loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        await tester.pumpAndSettle(); // Complete refresh
        
        // Should show updated data (2 displays instead of 3)
        expect(find.byType(Card), findsNWidgets(2));
      });
      
      testWidgets('refresh works from error state', (tester) async {
        /// Purpose: Verify refresh from app bar works in error state
        /// Quality Contribution: Provides alternative recovery method
        /// Acceptance Criteria: App bar refresh must work even when in error
        
        service.setFailure(TestFailures.platformChannel());
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Should be in error state
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        
        // Clear error
        service.clearFailure();
        
        // Use app bar refresh (not retry button)
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
        
        // Should recover to data state
        expect(find.byType(Card), findsNWidgets(3));
      });
    });
    
    group('state transitions', () {
      testWidgets('transitions from loading to data', (tester) async {
        /// Purpose: Verify smooth state transitions
        /// Quality Contribution: Ensures UI updates correctly through state changes
        /// Acceptance Criteria: Must transition loading → data without flicker
        
        await tester.pumpWidget(createTestApp());
        
        // Initially loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Complete the async operation
        await tester.pumpAndSettle();
        
        // Should transition to data
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(Card), findsNWidgets(3));
      });
      
      testWidgets('transitions from loading to error', (tester) async {
        /// Purpose: Verify error transition handling
        /// Quality Contribution: Ensures errors are properly surfaced
        /// Acceptance Criteria: Must transition loading → error cleanly
        
        // Set up delayed failure
        service.setFailure(TestFailures.displayNotFound('test'));
        
        await tester.pumpWidget(createTestApp());
        
        // Initially loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        await tester.pumpAndSettle();
        
        // Should transition to error
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    });
    
    group('provider integration', () {
      testWidgets('uses overridden providers correctly', (tester) async {
        /// Purpose: Verify DI override mechanism works in widgets
        /// Quality Contribution: Validates testability of widget layer
        /// Acceptance Criteria: Widget must use overridden provider data
        
        final customDisplays = TestScenarios.presentationMode();
        
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              MockProviders.successfulDisplaysProvider(customDisplays),
            ],
            child: const MaterialApp(
              home: DisplaysScreen(),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Should show custom display configuration
        expect(find.byType(Card), findsNWidgets(2));
        expect(find.text('Display projector'), findsOneWidget);
      });
      
      testWidgets('responds to provider state changes', (tester) async {
        /// Purpose: Verify widget rebuilds on provider updates
        /// Quality Contribution: Ensures reactive UI updates
        /// Acceptance Criteria: UI must update when provider state changes
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Initial state
        expect(find.byType(Card), findsNWidgets(3));
        
        // Simulate display configuration change
        service.emitDisplayChange(TestScenarios.laptopOnly());
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
        
        // Should show updated configuration
        expect(find.byType(Card), findsOneWidget);
      });
    });
    
    group('accessibility', () {
      testWidgets('has semantic labels for screen readers', (tester) async {
        /// Purpose: Verify accessibility support
        /// Quality Contribution: Ensures app is usable with assistive technology
        /// Acceptance Criteria: Key elements must be accessible
        
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // App bar should be accessible
        expect(find.text('Display Detection - Riverpod'), findsOneWidget);
        
        // Refresh action should be findable
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        
        // Display information should be readable
        expect(find.textContaining('Display'), findsWidgets);
        expect(find.text('Primary'), findsOneWidget);
      });
    });
  });
}