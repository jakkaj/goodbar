import 'package:flutter_test/flutter_test.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';
import '../../features/displays/support/fixtures.dart';
import '../../features/displays/support/assertions.dart';

void main() {
  group('Display Freezed Model', () {
    late Display testDisplay;
    
    setUp(() {
      testDisplay = const Display(
        id: 'test-id',
        bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
        workArea: Rectangle(x: 0, y: 25, width: 1920, height: 1055),
        scaleFactor: 1.0,
        isPrimary: true,
      );
    });
    
    group('copyWith', () {
      test('creates new instance with updated values', () {
        /// Purpose: Verify Freezed copyWith generates correctly
        /// Quality Contribution: Ensures immutability patterns work as expected
        /// Acceptance Criteria: copyWith must create new instance with changes
        
        final updated = testDisplay.copyWith(
          id: 'new-id',
          isPrimary: false,
        );
        
        // New instance should have updated values
        expect(updated.id, 'new-id');
        expect(updated.isPrimary, false);
        
        // Original should be unchanged
        expect(testDisplay.id, 'test-id');
        expect(testDisplay.isPrimary, true);
        
        // Unchanged values should be preserved
        expect(updated.bounds, testDisplay.bounds);
        expect(updated.workArea, testDisplay.workArea);
        expect(updated.scaleFactor, testDisplay.scaleFactor);
      });
      
      test('creates different instance even with no changes', () {
        /// Purpose: Verify copyWith always creates new instance
        /// Quality Contribution: Validates immutability guarantees
        /// Acceptance Criteria: copyWith() with no args must create new instance
        
        final copy = testDisplay.copyWith();
        
        expect(identical(testDisplay, copy), isFalse);
        expect(testDisplay == copy, isTrue); // Equal but not identical
      });
      
      test('allows nested updates of Rectangle objects', () {
        /// Purpose: Verify deep copying of nested Freezed objects
        /// Quality Contribution: Ensures complete immutability through object graph
        /// Acceptance Criteria: Nested objects must be properly copied
        
        final newBounds = const Rectangle(x: 100, y: 100, width: 2560, height: 1440);
        final updated = testDisplay.copyWith(bounds: newBounds);
        
        expect(updated.bounds, newBounds);
        expect(updated.bounds.x, 100);
        expect(updated.bounds.width, 2560);
        
        // Original bounds unchanged
        expect(testDisplay.bounds.x, 0);
        expect(testDisplay.bounds.width, 1920);
      });
    });
    
    group('equality', () {
      test('equals when all properties match', () {
        /// Purpose: Verify Freezed equality implementation
        /// Quality Contribution: Enables reliable display comparison
        /// Acceptance Criteria: Identical properties must result in equality
        
        final display1 = const Display(
          id: '1',
          bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
          workArea: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
          scaleFactor: 1.0,
          isPrimary: false,
        );
        
        final display2 = const Display(
          id: '1',
          bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
          workArea: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
          scaleFactor: 1.0,
          isPrimary: false,
        );
        
        expect(display1, equals(display2));
        expect(display1.hashCode, equals(display2.hashCode));
      });
      
      test('not equal when any property differs', () {
        /// Purpose: Verify equality is sensitive to all properties
        /// Quality Contribution: Ensures accurate change detection
        /// Acceptance Criteria: Any property difference must break equality
        
        final base = DisplayBuilders.macBookPro16();
        
        // Test each property difference
        final differentId = base.copyWith(id: 'different');
        expect(base == differentId, isFalse);
        
        final differentPrimary = base.copyWith(isPrimary: false);
        expect(base == differentPrimary, isFalse);
        
        final differentScale = base.copyWith(scaleFactor: 3.0);
        expect(base == differentScale, isFalse);
        
        final differentBounds = base.copyWith(
          bounds: const Rectangle(x: 10, y: 0, width: 3456, height: 2234),
        );
        expect(base == differentBounds, isFalse);
      });
      
      test('handles const constructor optimization', () {
        /// Purpose: Verify const constructors create identical instances
        /// Quality Contribution: Validates memory efficiency optimizations
        /// Acceptance Criteria: Const instances with same values must be identical
        
        const display1 = Display(
          id: 'const-test',
          bounds: Rectangle(x: 0, y: 0, width: 100, height: 100),
          workArea: Rectangle(x: 0, y: 0, width: 100, height: 100),
          scaleFactor: 1.0,
          isPrimary: false,
        );
        
        const display2 = Display(
          id: 'const-test',
          bounds: Rectangle(x: 0, y: 0, width: 100, height: 100),
          workArea: Rectangle(x: 0, y: 0, width: 100, height: 100),
          scaleFactor: 1.0,
          isPrimary: false,
        );
        
        // Const instances should be identical (same memory location)
        expect(identical(display1, display2), isTrue);
      });
    });
    
    group('computed properties', () {
      test('width and height derived from bounds', () {
        /// Purpose: Verify computed property implementation
        /// Quality Contribution: Ensures convenient accessors work correctly
        /// Acceptance Criteria: Width/height must match bounds dimensions
        
        final display = DisplayBuilders.external4K();
        
        expect(display.width, display.bounds.width);
        expect(display.height, display.bounds.height);
        expect(display.width, 3840);
        expect(display.height, 2160);
      });
      
      test('menuBarHeight calculated for primary display', () {
        /// Purpose: Verify menu bar height calculation logic
        /// Quality Contribution: Critical for accurate window positioning
        /// Acceptance Criteria: Primary display must show correct menu bar height
        
        final primary = DisplayBuilders.macBookPro16(isPrimary: true);
        final secondary = DisplayBuilders.external4K();
        
        // Primary display should have menu bar
        expect(primary.menuBarHeight, 25); // workArea.y(25) - bounds.y(0) = 25 points
        
        // Secondary display should have no menu bar
        expect(secondary.menuBarHeight, 0);
      });
      
      test('work area dimensions', () {
        /// Purpose: Verify work area accessors
        /// Quality Contribution: Provides usable screen area for window placement
        /// Acceptance Criteria: Work dimensions must match workArea rectangle
        
        final display = DisplayBuilders.macBookPro16();
        
        expect(display.workWidth, display.workArea.width);
        expect(display.workHeight, display.workArea.height);
        
        // Work area should be smaller than bounds (menu bar)
        expect(display.workHeight < display.height, isTrue);
      });
    });
    
    group('toString', () {
      test('provides readable debug output', () {
        /// Purpose: Verify debug string generation
        /// Quality Contribution: Aids in debugging display issues
        /// Acceptance Criteria: toString must include key identifying information
        
        final display = DisplayBuilders.macBookPro16();
        final str = display.toString();
        
        // Should include class name and key properties
        expect(str, contains('Display'));
        expect(str, contains('id: 1'));
        expect(str, contains('isPrimary: true'));
        
        // Freezed includes all properties in toString
        expect(str, contains('bounds:'));
        expect(str, contains('workArea:'));
        expect(str, contains('scaleFactor:'));
      });
    });
    
    group('Rectangle geometry', () {
      test('edge calculations work correctly', () {
        /// Purpose: Verify Rectangle computed properties
        /// Quality Contribution: Essential for display arrangement calculations
        /// Acceptance Criteria: Edge properties must correctly calculate boundaries
        
        const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
        
        expect(rect.left, 10);
        expect(rect.top, 20);
        expect(rect.right, 110); // x + width
        expect(rect.bottom, 70);  // y + height
      });
      
      test('center point calculation', () {
        /// Purpose: Verify center point computation
        /// Quality Contribution: Used for window centering logic
        /// Acceptance Criteria: Center must be at geometric center
        
        const rect = Rectangle(x: 0, y: 0, width: 100, height: 100);
        
        expect(rect.center.x, 50);
        expect(rect.center.y, 50);
        
        // Test with offset rectangle
        const offset = Rectangle(x: 100, y: 200, width: 100, height: 100);
        expect(offset.center.x, 150); // 100 + 100/2
        expect(offset.center.y, 250); // 200 + 100/2
      });
      
      test('contains point checking', () {
        /// Purpose: Verify point containment logic
        /// Quality Contribution: Used for hit testing and cursor position
        /// Acceptance Criteria: Must correctly identify points inside/outside
        
        const rect = Rectangle(x: 10, y: 10, width: 100, height: 100);
        
        // Points inside
        expect(rect.contains(const Point(x: 50, y: 50)), isTrue);
        expect(rect.contains(const Point(x: 10, y: 10)), isTrue); // Top-left corner
        expect(rect.contains(const Point(x: 110, y: 110)), isTrue); // Bottom-right corner
        
        // Points outside
        expect(rect.contains(const Point(x: 0, y: 0)), isFalse);
        expect(rect.contains(const Point(x: 111, y: 111)), isFalse);
      });
    });
    
    group('real-world scenarios', () {
      test('handles typical macOS display configurations', () {
        /// Purpose: Verify model handles real configurations
        /// Quality Contribution: Validates against actual use cases
        /// Acceptance Criteria: Must represent real macOS display setups accurately
        
        final displays = DisplayBuilders.threeDisplaySetup();
        
        // Verify realistic setup
        expect(displays.length, 3);
        
        // Check primary display (MacBook)
        final primary = displays.firstWhere((d) => d.isPrimary);
        expect(primary.scaleFactor, 2.0); // Retina
        expect(primary.menuBarHeight, greaterThan(0));
        
        // Check external displays
        final externals = displays.where((d) => !d.isPrimary).toList();
        expect(externals.length, 2);
        expect(externals.every((d) => d.menuBarHeight == 0), isTrue);
        
        // Verify display arrangement is valid
        DisplayAssertions.assertSinglePrimary(displays);
        DisplayAssertions.assertValidPositioning(displays);
      });
      
      test('handles edge cases like vertical monitors', () {
        /// Purpose: Verify model handles unusual configurations
        /// Quality Contribution: Ensures robustness with edge cases
        /// Acceptance Criteria: Must handle non-standard orientations
        
        final vertical = DisplayBuilders.custom(
          id: 'vertical',
          width: 1080,  // Width < Height = vertical
          height: 1920,
          x: -1080,
          y: 0,
        );
        
        expect(vertical.width < vertical.height, isTrue);
        expect(vertical.bounds.x, isNegative); // Left of primary
        
        DisplayAssertions.assertValidDisplay(vertical);
      });
    });
  });
}