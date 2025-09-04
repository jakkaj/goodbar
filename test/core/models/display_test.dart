import 'package:flutter_test/flutter_test.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';

void main() {
  group('Display', () {
    test('creates display with required properties', () {
      /// Purpose: Verify Display model holds all required display metadata
      /// Quality Contribution: Ensures complete display representation for
      /// accurate window positioning and multi-monitor support
      /// Acceptance Criteria: Display must store id, bounds, workArea,
      /// scaleFactor, and primary status
      
      const display = Display(
        id: 'display-1',
        bounds: Rectangle(x: 0, y: 0, width: 2560, height: 1440),
        workArea: Rectangle(x: 0, y: 25, width: 2560, height: 1415),
        scaleFactor: 2.0,
        isPrimary: true,
      );
      
      expect(display.id, equals('display-1'));
      expect(display.bounds.width, equals(2560));
      expect(display.bounds.height, equals(1440));
      expect(display.workArea.height, equals(1415));
      expect(display.scaleFactor, equals(2.0));
      expect(display.isPrimary, isTrue);
    });
    
    test('calculates convenience properties correctly', () {
      /// Purpose: Verify derived properties provide useful display metrics
      /// Quality Contribution: Simplifies taskbar positioning calculations
      /// by providing pre-computed common measurements
      /// Acceptance Criteria: Width/height shortcuts and menubar/dock
      /// heights must calculate correctly from bounds and workArea
      
      const display = Display(
        id: 'display-1',
        bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
        workArea: Rectangle(x: 0, y: 25, width: 1920, height: 1030),
        scaleFactor: 1.0,
        isPrimary: true,
      );
      
      // Convenience width/height
      expect(display.width, equals(1920));
      expect(display.height, equals(1080));
      expect(display.workWidth, equals(1920));
      expect(display.workHeight, equals(1030));
      
      // System UI heights (25px menubar, 25px dock)
      expect(display.menuBarHeight, equals(25)); // workArea.y (25) - bounds.y (0)
      expect(display.dockHeight, equals(25)); // bounds.bottom (1080) - workArea.bottom (1055)
    });
    
    test('handles secondary display positioning', () {
      /// Purpose: Verify Display correctly represents non-origin displays
      /// Quality Contribution: Essential for multi-display taskbar positioning
      /// where displays are arranged horizontally or vertically
      /// Acceptance Criteria: Display must preserve coordinate system
      /// positioning for displays not at origin (0,0)
      
      const secondary = Display(
        id: 'display-2',
        bounds: Rectangle(x: 2560, y: 0, width: 1920, height: 1080),
        workArea: Rectangle(x: 2560, y: 0, width: 1920, height: 1055),
        scaleFactor: 1.0,
        isPrimary: false,
      );
      
      expect(secondary.bounds.x, equals(2560));
      expect(secondary.bounds.y, equals(0));
      expect(secondary.isPrimary, isFalse);
      
      // Bounds should be relative to global coordinate system
      expect(secondary.bounds.left, equals(2560));
      expect(secondary.bounds.right, equals(4480));
    });
    
    test('serializes to and from JSON', () {
      /// Purpose: Verify Display can be serialized for IPC with native code
      /// Quality Contribution: Enables passing display data between Flutter
      /// and platform channels without data loss
      /// Acceptance Criteria: Round-trip serialization must preserve all
      /// properties exactly
      
      const original = Display(
        id: 'display-test',
        bounds: Rectangle(x: 100, y: 200, width: 1920, height: 1080),
        workArea: Rectangle(x: 100, y: 225, width: 1920, height: 1055),
        scaleFactor: 1.5,
        isPrimary: false,
      );
      
      final json = original.toJson();
      final restored = Display.fromJson(json);
      
      expect(restored.id, equals(original.id));
      expect(restored.bounds, equals(original.bounds));
      expect(restored.workArea, equals(original.workArea));
      expect(restored.scaleFactor, equals(original.scaleFactor));
      expect(restored.isPrimary, equals(original.isPrimary));
    });
    
    test('supports equality comparison', () {
      /// Purpose: Verify Freezed generates proper equality for Display
      /// Quality Contribution: Enables detecting display configuration changes
      /// by comparing Display objects
      /// Acceptance Criteria: Displays with same properties must be equal,
      /// different properties must not be equal
      
      const display1 = Display(
        id: 'display-1',
        bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
        workArea: Rectangle(x: 0, y: 25, width: 1920, height: 1055),
        scaleFactor: 1.0,
        isPrimary: true,
      );
      
      const display2 = Display(
        id: 'display-1',
        bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
        workArea: Rectangle(x: 0, y: 25, width: 1920, height: 1055),
        scaleFactor: 1.0,
        isPrimary: true,
      );
      
      const display3 = Display(
        id: 'display-2',
        bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
        workArea: Rectangle(x: 0, y: 25, width: 1920, height: 1055),
        scaleFactor: 1.0,
        isPrimary: true,
      );
      
      expect(display1, equals(display2));
      expect(display1, isNot(equals(display3)));
    });
  });
  
  group('DisplayChangeEvent', () {
    test('creates event with display list and metadata', () {
      /// Purpose: Verify DisplayChangeEvent captures display changes
      /// Quality Contribution: Enables reactive UI updates when monitors
      /// are connected, disconnected, or rearranged
      /// Acceptance Criteria: Event must include displays list, change type,
      /// and timestamp
      
      final now = DateTime.now();
      final event = DisplayChangeEvent(
        displays: const [
          Display(
            id: 'display-1',
            bounds: Rectangle(x: 0, y: 0, width: 1920, height: 1080),
            workArea: Rectangle(x: 0, y: 25, width: 1920, height: 1055),
            scaleFactor: 1.0,
            isPrimary: true,
          ),
        ],
        changeType: 'added',
        timestamp: now,
      );
      
      expect(event.displays, hasLength(1));
      expect(event.changeType, equals('added'));
      expect(event.timestamp, equals(now));
    });
    
    test('serializes to and from JSON', () {
      /// Purpose: Verify DisplayChangeEvent can be sent via platform channels
      /// Quality Contribution: Enables native code to notify Flutter of
      /// display configuration changes
      /// Acceptance Criteria: Round-trip serialization must preserve event
      /// data including nested Display objects
      
      final original = DisplayChangeEvent(
        displays: const [
          Display(
            id: 'display-1',
            bounds: Rectangle(x: 0, y: 0, width: 2560, height: 1440),
            workArea: Rectangle(x: 0, y: 25, width: 2560, height: 1415),
            scaleFactor: 2.0,
            isPrimary: true,
          ),
        ],
        changeType: 'reconfigured',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );
      
      final json = original.toJson();
      final restored = DisplayChangeEvent.fromJson(json);
      
      expect(restored.displays.length, equals(1));
      expect(restored.displays.first.id, equals('display-1'));
      expect(restored.changeType, equals('reconfigured'));
      expect(restored.timestamp, equals(original.timestamp));
    });
  });
  
  group('Rectangle', () {
    test('calculates edges correctly', () {
      /// Purpose: Verify Rectangle edge calculations for positioning
      /// Quality Contribution: Provides intuitive API for calculating
      /// taskbar placement relative to display edges
      /// Acceptance Criteria: Left/top/right/bottom must calculate correctly
      /// from x, y, width, height
      
      const rect = Rectangle(x: 100, y: 200, width: 300, height: 400);
      
      expect(rect.left, equals(100));
      expect(rect.top, equals(200));
      expect(rect.right, equals(400));
      expect(rect.bottom, equals(600));
    });
    
    test('calculates center point', () {
      /// Purpose: Verify Rectangle center calculation for window centering
      /// Quality Contribution: Enables centering UI elements on displays
      /// Acceptance Criteria: Center must be at midpoint of rectangle
      
      const rect = Rectangle(x: 0, y: 0, width: 100, height: 200);
      
      expect(rect.center.x, equals(50));
      expect(rect.center.y, equals(100));
    });
    
    test('contains point check works correctly', () {
      /// Purpose: Verify point containment for hit testing
      /// Quality Contribution: Enables determining which display contains
      /// a given screen coordinate for window placement
      /// Acceptance Criteria: Must correctly identify points inside/outside
      /// rectangle boundaries
      
      const rect = Rectangle(x: 10, y: 20, width: 100, height: 50);
      
      // Points inside
      expect(rect.contains(const Point(x: 50, y: 40)), isTrue);
      expect(rect.contains(const Point(x: 10, y: 20)), isTrue);
      expect(rect.contains(const Point(x: 110, y: 70)), isTrue);
      
      // Points outside
      expect(rect.contains(const Point(x: 5, y: 40)), isFalse);
      expect(rect.contains(const Point(x: 50, y: 75)), isFalse);
      expect(rect.contains(const Point(x: 115, y: 40)), isFalse);
    });
  });
}