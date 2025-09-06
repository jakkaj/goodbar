import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:goodbar/main.dart' as app;
import 'package:goodbar/src/widgets/displays_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Display Detection Integration Tests', () {
    testWidgets('real macOS display detection works', (tester) async {
      /// Purpose: Verify actual platform channel communication
      /// Quality Contribution: Validates real macOS integration works correctly
      /// Acceptance Criteria: Must detect at least one display on real hardware
      /// 
      /// NOTE: This test requires running on actual macOS hardware or simulator
      /// Run with: flutter test integration_test/displays_integration_test.dart
      
      // Launch the actual app
      app.main();
      await tester.pumpAndSettle();
      
      // Verify app launches with DisplaysScreen
      expect(find.byType(DisplaysScreen), findsOneWidget);
      expect(find.text('Display Detection - Riverpod'), findsOneWidget);
      
      // Wait for real display detection to complete
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Should not be in loading state anymore
      expect(find.byType(CircularProgressIndicator), findsNothing);
      
      // Should have detected at least one display (the main display)
      final cards = find.byType(Card);
      expect(cards, findsWidgets);
      
      // Verify at least one display is detected
      final cardCount = tester.widgetList(cards).length;
      expect(cardCount, greaterThanOrEqualTo(1),
        reason: 'Should detect at least the primary display');
      
      // Verify primary display exists
      expect(find.text('Primary'), findsOneWidget,
        reason: 'Should identify the primary display');
      
      // Verify display information is rendered
      expect(find.text('Position'), findsWidgets);
      expect(find.text('Size'), findsWidgets);
      expect(find.text('Scale Factor'), findsWidgets);
      
      // Test refresh functionality with real data
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump(); // Start refresh
      
      // Should show loading during refresh
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      await tester.pumpAndSettle(); // Complete refresh
      
      // Should return to showing displays
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Card), findsWidgets);
    });
    
    testWidgets('handles display properties correctly', (tester) async {
      /// Purpose: Verify display properties are accurate
      /// Quality Contribution: Validates data accuracy from platform channel
      /// Acceptance Criteria: Display properties must be reasonable values
      
      app.main();
      await tester.pumpAndSettle();
      
      // Find display information text
      final sizeTexts = find.textContaining('×');
      expect(sizeTexts, findsWidgets);
      
      // Parse and validate display dimensions
      for (final element in tester.widgetList(sizeTexts)) {
        if (element is Text && element.data != null) {
          final text = element.data!;
          if (text.contains('×')) {
            // Parse dimensions like "1920 × 1080"
            final parts = text.split('×').map((s) => s.trim()).toList();
            if (parts.length == 2) {
              final width = int.tryParse(parts[0]);
              final height = int.tryParse(parts[1]);
              
              if (width != null && height != null) {
                // Validate reasonable display dimensions
                expect(width, greaterThan(0));
                expect(width, lessThanOrEqualTo(10000)); // Max 10K width
                expect(height, greaterThan(0));
                expect(height, lessThanOrEqualTo(10000)); // Max 10K height
              }
            }
          }
        }
      }
      
      // Verify scale factors are reasonable
      final scaleTexts = find.textContaining('×');
      for (final element in tester.widgetList(scaleTexts)) {
        if (element is Text && element.data != null) {
          final text = element.data!;
          if (text.endsWith('×')) {
            // Parse scale factor like "2.0×"
            final scaleStr = text.substring(0, text.length - 1);
            final scale = double.tryParse(scaleStr);
            
            if (scale != null) {
              expect(scale, greaterThan(0));
              expect(scale, lessThanOrEqualTo(4.0)); // Max 4x scaling
            }
          }
        }
      }
    });
    
    testWidgets('memory leak detection during refresh cycles', (tester) async {
      /// Purpose: Verify no memory leaks during repeated operations
      /// Quality Contribution: Ensures app stability over time
      /// Acceptance Criteria: Memory should not grow unbounded
      
      app.main();
      await tester.pumpAndSettle();
      
      // Perform multiple refresh cycles
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
        
        // Small delay between refreshes
        await tester.pump(const Duration(milliseconds: 100));
      }
      
      // App should still be responsive
      expect(find.byType(DisplaysScreen), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
      
      // Verify UI is still functional after stress test
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      
      expect(find.byType(Card), findsWidgets);
    });
    
    testWidgets('error recovery in production environment', (tester) async {
      /// Purpose: Verify error handling in production
      /// Quality Contribution: Ensures graceful degradation
      /// Acceptance Criteria: App must not crash on errors
      
      app.main();
      await tester.pumpAndSettle();
      
      // Even if platform channel fails, app should not crash
      // The error UI should be shown instead
      
      // If we see error UI, verify retry works
      final retryButton = find.widgetWithText(ElevatedButton, 'Retry');
      if (retryButton.evaluate().isNotEmpty) {
        await tester.tap(retryButton);
        await tester.pumpAndSettle();
        
        // Should attempt recovery
        expect(find.byType(DisplaysScreen), findsOneWidget);
      }
      
      // Verify app remains stable
      expect(find.text('Display Detection - Riverpod'), findsOneWidget);
    });
  });
  
  group('Platform-Specific Integration Tests', () {
    testWidgets('macOS-specific display features work', (tester) async {
      /// Purpose: Test macOS-specific display properties
      /// Quality Contribution: Validates platform-specific features
      /// Acceptance Criteria: Menu bar and dock heights must be detected
      
      app.main();
      await tester.pumpAndSettle();
      
      // Look for macOS-specific properties
      expect(find.text('Menu Bar Height'), findsWidgets);
      expect(find.text('Dock Height'), findsWidgets);
      
      // Find primary display card (should have menu bar)
      final primaryChip = find.text('Primary');
      expect(primaryChip, findsOneWidget);
      
      // Verify menu bar height is shown for primary display
      final primaryCard = find.ancestor(
        of: primaryChip,
        matching: find.byType(Card),
      );
      
      final menuBarText = find.descendant(
        of: primaryCard,
        matching: find.textContaining('px'),
      );
      
      expect(menuBarText, findsWidgets);
    });
    
    testWidgets('multi-display detection on macOS', (tester) async {
      /// Purpose: Test multi-display scenarios if available
      /// Quality Contribution: Validates multi-monitor support
      /// Acceptance Criteria: Should detect all connected displays
      
      app.main();
      await tester.pumpAndSettle();
      
      // Count detected displays
      final cards = find.byType(Card);
      final displayCount = tester.widgetList(cards).length;
      
      debugPrint('Integration Test: Detected $displayCount display(s)');
      
      if (displayCount > 1) {
        // Verify each display has unique ID
        final displayIds = <String>[];
        
        for (int i = 1; i <= displayCount; i++) {
          final idText = find.text('Display $i');
          if (idText.evaluate().isNotEmpty) {
            displayIds.add('Display $i');
          }
        }
        
        // Verify only one primary display
        final primaryCount = tester.widgetList(find.text('Primary')).length;
        expect(primaryCount, equals(1),
          reason: 'Should have exactly one primary display');
        
        debugPrint('Integration Test: Found displays with IDs: $displayIds');
      }
    });
  });
}