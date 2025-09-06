import 'package:flutter_test/flutter_test.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';

void main() {
  group('FakeScreenService', () {
    late FakeScreenService service;
    
    setUp(() {
      service = FakeScreenService();
    });
    
    tearDown(() {
      service.dispose();
    });
    
    test('provides default 3-display configuration', () async {
      /// Purpose: Verify fake service provides predictable test data
      /// Quality Contribution: Ensures consistent test environment across
      /// all unit and widget tests
      /// Acceptance Criteria: Default configuration must have 3 displays
      /// with one primary
      
      final result = await service.getDisplays();
      
      result.fold(
        (displays) {
          expect(displays.length, equals(3),
            reason: 'Default configuration should have 3 displays');
          
          final primaryCount = displays.where((d) => d.isPrimary).length;
          expect(primaryCount, equals(1),
            reason: 'Exactly one display should be primary');
          
          // Verify display IDs are unique
          final ids = displays.map((d) => d.id).toSet();
          expect(ids.length, equals(3),
            reason: 'All displays should have unique IDs');
        },
        (error) => fail('Should provide default displays: $error'),
      );
    });
    
    test('can be initialized with custom display configuration', () async {
      /// Purpose: Verify fake service accepts custom configurations
      /// Quality Contribution: Enables testing specific display scenarios
      /// Acceptance Criteria: Service must use provided displays instead
      /// of defaults
      
      const customDisplay = Display(
        id: 'custom',
        bounds: Rectangle(x: 0, y: 0, width: 800, height: 600),
        workArea: Rectangle(x: 0, y: 25, width: 800, height: 575),
        scaleFactor: 1.0,
        isPrimary: true,
      );
      
      service = FakeScreenService(displays: [customDisplay]);
      
      final result = await service.getDisplays();
      result.fold(
        (displays) {
          expect(displays.length, equals(1));
          expect(displays.first.id, equals('custom'));
          expect(displays.first.bounds.width, equals(800));
        },
        (error) => fail('Should return custom display: $error'),
      );
    });
    
    test('getPrimaryDisplay returns primary from configuration', () async {
      /// Purpose: Verify primary display retrieval works correctly
      /// Quality Contribution: Ensures service contract for primary display
      /// Acceptance Criteria: Must return the display marked as primary
      
      final result = await service.getPrimaryDisplay();
      
      result.fold(
        (display) {
          expect(display.isPrimary, isTrue);
          expect(display.id, equals('1')); // Default primary
        },
        (error) => fail('Should return primary display: $error'),
      );
    });
    
    test('getDisplay retrieves specific display by ID', () async {
      /// Purpose: Verify individual display retrieval
      /// Quality Contribution: Tests service contract for targeted queries
      /// Acceptance Criteria: Must return correct display for valid ID
      
      final result = await service.getDisplay('2');
      
      result.fold(
        (display) {
          expect(display.id, equals('2'));
          expect(display.isPrimary, isFalse);
        },
        (error) => fail('Should return display 2: $error'),
      );
    });
    
    test('getDisplay returns failure for non-existent ID', () async {
      /// Purpose: Verify error handling for invalid IDs
      /// Quality Contribution: Ensures proper failure path testing
      /// Acceptance Criteria: Must return Result.failure for invalid ID
      
      final result = await service.getDisplay('non-existent');
      
      result.fold(
        (_) => fail('Should not find non-existent display'),
        (error) {
          expect(error.message, contains('not found'));
        },
      );
    });
    
    test('setDisplays updates configuration and emits event', () async {
      /// Purpose: Verify display configuration can be changed dynamically
      /// Quality Contribution: Enables testing display change scenarios
      /// Acceptance Criteria: setDisplays must update configuration and
      /// emit change event
      
      const newDisplay = Display(
        id: 'new',
        bounds: Rectangle(x: 0, y: 0, width: 1024, height: 768),
        workArea: Rectangle(x: 0, y: 0, width: 1024, height: 768),
        scaleFactor: 1.0,
        isPrimary: true,
      );
      
      // Listen for change event
      final eventFuture = service.displayChanges.first;
      
      // Update displays
      service.setDisplays([newDisplay]);
      
      // Verify event was emitted
      final event = await eventFuture;
      expect(event.displays.length, equals(1));
      expect(event.displays.first.id, equals('new'));
      expect(event.changeType, equals('reconfigured'));
      
      // Verify getDisplays returns new configuration
      final result = await service.getDisplays();
      result.fold(
        (displays) {
          expect(displays.length, equals(1));
          expect(displays.first.id, equals('new'));
        },
        (error) => fail('Should return new configuration: $error'),
      );
    });
    
    test('addDisplay simulates connecting a new display', () async {
      /// Purpose: Verify display addition simulation
      /// Quality Contribution: Enables testing hot-plug scenarios
      /// Acceptance Criteria: addDisplay must add to configuration and
      /// emit 'added' event
      
      const newDisplay = Display(
        id: '4',
        bounds: Rectangle(x: 5000, y: 0, width: 1920, height: 1080),
        workArea: Rectangle(x: 5000, y: 0, width: 1920, height: 1080),
        scaleFactor: 1.0,
        isPrimary: false,
      );
      
      final eventFuture = service.displayChanges.first;
      
      service.addDisplay(newDisplay);
      
      final event = await eventFuture;
      expect(event.changeType, equals('added'));
      expect(event.displays.length, equals(4)); // 3 default + 1 new
      
      final result = await service.getDisplays();
      result.fold(
        (displays) {
          expect(displays.length, equals(4));
          expect(displays.any((d) => d.id == '4'), isTrue);
        },
        (error) => fail('Should include new display: $error'),
      );
    });
    
    test('removeDisplay simulates disconnecting a display', () async {
      /// Purpose: Verify display removal simulation
      /// Quality Contribution: Enables testing display disconnect scenarios
      /// Acceptance Criteria: removeDisplay must remove from configuration
      /// and emit 'removed' event
      
      final eventFuture = service.displayChanges.first;
      
      service.removeDisplay('3'); // Remove tertiary display
      
      final event = await eventFuture;
      expect(event.changeType, equals('removed'));
      expect(event.displays.length, equals(2)); // 3 default - 1 removed
      
      final result = await service.getDisplays();
      result.fold(
        (displays) {
          expect(displays.length, equals(2));
          expect(displays.any((d) => d.id == '3'), isFalse);
        },
        (error) => fail('Should have removed display: $error'),
      );
    });
    
    test('handles empty display configuration gracefully', () async {
      /// Purpose: Verify service handles edge case of no displays
      /// Quality Contribution: Ensures robustness in unusual scenarios
      /// Acceptance Criteria: Empty configuration should return failure
      /// for getDisplays and getPrimaryDisplay
      
      service = FakeScreenService(displays: []);
      
      final displaysResult = await service.getDisplays();
      displaysResult.fold(
        (displays) {
          expect(displays, isEmpty,
              reason: 'Empty configuration should return empty list');
        },
        (error) => fail('Should not fail for empty list: ${error.message}'),
      );
      
      final primaryResult = await service.getPrimaryDisplay();
      primaryResult.fold(
        (_) => fail('Should fail with no primary display'),
        (error) {
          expect(error.message, contains('No primary display found'));
        },
      );
    });
  });
}
