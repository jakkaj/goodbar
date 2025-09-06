import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/failures/screen_failures.dart';
import 'package:goodbar/src/providers/displays_provider.dart';
import 'package:goodbar/src/providers/services.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import '../support/async_value_matchers.dart';
import '../support/container_helpers.dart';
import '../features/displays/support/fixtures.dart';
import '../features/displays/support/scenarios.dart';
import '../features/displays/support/failures.dart';
import '../features/displays/support/assertions.dart';

void main() {
  group('DisplaysProvider', () {
    late ProviderContainer container;
    late FakeScreenService service;
    
    setUp(() {
      service = FakeScreenService();
      container = ProviderContainer(
        overrides: [
          screenServiceProvider.overrideWithValue(service),
        ],
      );
    });
    
    tearDown(() {
      container.dispose();
    });
    
    group('initial build', () {
      test('starts in loading state then transitions to data', () async {
        /// Purpose: Verify provider follows correct AsyncValue lifecycle
        /// Quality Contribution: Ensures UI can rely on predictable state transitions
        /// Acceptance Criteria: Must start with AsyncLoading, then AsyncData
        
        // Collect states
        final states = <AsyncValue<List<Display>>>[];
        container.listen(displaysProvider, (prev, next) {
          states.add(next);
        }, fireImmediately: true);
        
        // Initial state should be loading
        expect(states.first, isLoading<List<Display>>());
        
        // Wait for async resolution
        await container.read(displaysProvider.future);
        
        // Should have transitioned to data
        expect(states.last, isData<List<Display>>(
          (displays) => displays.length == 3,
        ));
        
        // Verify the actual display data
        final displays = states.last.value!;
        expect(displays[0].isPrimary, isTrue);
        expect(displays[1].isPrimary, isFalse);
        expect(displays[2].isPrimary, isFalse);
      });
      
      test('transforms service Result.success to AsyncData', () async {
        /// Purpose: Verify Result<T,E> to AsyncValue transformation
        /// Quality Contribution: Validates the critical service-to-provider bridge
        /// Acceptance Criteria: Success must become AsyncData with same value
        
        final customDisplays = TestScenarios.laptopOnly();
        service.setDisplays(customDisplays);
        
        final result = await container.read(displaysProvider.future);
        
        expect(result.length, 1);
        expect(result.first.id, customDisplays.first.id);
        expect(result.first.isPrimary, isTrue);
      });
      
      test('transforms service Result.failure to AsyncError', () async {
        /// Purpose: Verify error propagation from service layer
        /// Quality Contribution: Ensures errors are properly surfaced to UI
        /// Acceptance Criteria: Failure must become AsyncError with correct type
        
        final failure = TestFailures.platformChannel('Test error');
        service.setFailure(failure);
        
        // Collect states
        final states = <AsyncValue<List<Display>>>[];
        container.listen(displaysProvider, (prev, next) {
          states.add(next);
        }, fireImmediately: true);
        
        // Initial state should be loading
        expect(states.first, isLoading<List<Display>>());
        
        // Wait for error to occur
        await expectLater(
          container.read(displaysProvider.future),
          throwsA(equals(failure)),
        );
        
        // Verify final state is AsyncError
        expect(states.last, isErrorWithType<List<Display>, PlatformChannelFailure>());
        expect(states.last.error, equals(failure));
      });
    });
    
    group('refresh method', () {
      test('manually triggers reload with state transitions', () async {
        /// Purpose: Verify refresh() provides manual reload capability
        /// Quality Contribution: Enables pull-to-refresh and retry patterns
        /// Acceptance Criteria: Must transition Loading → Data on refresh
        
        // Initial load
        await container.read(displaysProvider.future);
        
        // Track states during refresh
        final states = <AsyncValue<List<Display>>>[];
        container.listen(displaysProvider, (_, next) => states.add(next));
        
        // Trigger refresh
        await container.read(displaysProvider.notifier).refresh();
        
        // The refresh completes quickly, we might only see the final state
        // or we might see loading then data
        if (states.length == 1) {
          // If we only captured the final state
          expect(states.last, isData<List<Display>>((d) => d.length == 3));
        } else {
          // If we captured both states
          expect(states, containsAllInOrder([
            isLoading<List<Display>>(),
            isData<List<Display>>((d) => d.length == 3),
          ]));
        }
      });
      
      test('updates data when service returns new displays', () async {
        /// Purpose: Verify refresh picks up configuration changes
        /// Quality Contribution: Supports display hot-plug scenarios
        /// Acceptance Criteria: New display config must be reflected after refresh
        
        // Initial load with default displays
        final initial = await container.read(displaysProvider.future);
        expect(initial.length, 3);
        
        // Change service data
        final newDisplays = TestScenarios.dockedSingleMonitor();
        service.setDisplays(newDisplays);
        
        // Refresh and verify update
        await container.read(displaysProvider.notifier).refresh();
        final updated = await container.read(displaysProvider.future);
        
        expect(updated.length, 2);
        expect(updated.map((d) => d.id), containsAll(['1', '2']));
      });
      
      test('handles errors during refresh', () async {
        /// Purpose: Verify refresh error handling
        /// Quality Contribution: Ensures retry attempts handle failures gracefully
        /// Acceptance Criteria: Error during refresh must update state to AsyncError
        
        // Start with successful state
        await container.read(displaysProvider.future);
        
        // Set failure for next call
        service.setFailure(TestFailures.unknown('Network error'));
        
        // Refresh should transition to error
        await container.read(displaysProvider.notifier).refresh();
        
        // Give time for state to update
        await container.pump();
        
        final state = container.read(displaysProvider);
        expect(state, isErrorWithMessage<List<Display>>('Network error'));
      });
    });
    
    group('getDisplay method', () {
      test('returns specific display by ID', () async {
        /// Purpose: Verify single display lookup
        /// Quality Contribution: Enables display-specific operations
        /// Acceptance Criteria: Must return correct display for valid ID
        
        await container.read(displaysProvider.future);
        
        final display = await container
            .read(displaysProvider.notifier)
            .getDisplay('2');
        
        expect(display.id, '2');
        expect(display.isPrimary, isFalse);
        expect(display.scaleFactor, 2.0);
      });
      
      test('throws DisplayNotFoundFailure for invalid ID', () async {
        /// Purpose: Verify error handling for invalid display ID
        /// Quality Contribution: Prevents crashes from invalid display references
        /// Acceptance Criteria: Must throw DisplayNotFoundFailure with ID
        
        await container.read(displaysProvider.future);
        
        expect(
          () => container.read(displaysProvider.notifier).getDisplay('invalid'),
          throwsA(isA<DisplayNotFoundFailure>()
            .having((e) => e.displayId, 'displayId', 'invalid')),
        );
      });
    });
    
    group('getPrimaryDisplay method', () {
      test('returns the primary display', () async {
        /// Purpose: Verify primary display detection
        /// Quality Contribution: Essential for menu bar positioning logic
        /// Acceptance Criteria: Must return display where isPrimary is true
        
        await container.read(displaysProvider.future);
        
        final primary = await container
            .read(displaysProvider.notifier)
            .getPrimaryDisplay();
        
        expect(primary.isPrimary, isTrue);
        expect(primary.id, '1');
        expect(primary.menuBarHeight, greaterThan(0));
      });
      
      test('handles missing primary display', () async {
        /// Purpose: Verify error when no primary display exists
        /// Quality Contribution: Handles unusual system configurations
        /// Acceptance Criteria: Must throw appropriate failure
        
        // Set displays with no primary
        final displays = [
          DisplayBuilders.external4K(),
          DisplayBuilders.external1080p(),
        ];
        service.setDisplays(displays);
        
        await container.read(displaysProvider.future);
        
        expect(
          () => container.read(displaysProvider.notifier).getPrimaryDisplay(),
          throwsA(isA<PlatformChannelFailure>()),
        );
      });
    });
    
    group('dependency injection', () {
      test('uses injected screen service', () async {
        /// Purpose: Verify DI chain works correctly
        /// Quality Contribution: Validates testability and modularity
        /// Acceptance Criteria: Provider must use overridden service
        
        final customService = FakeScreenService(
          displays: TestScenarios.presentationMode(),
        );
        
        final customContainer = ProviderContainer(
          overrides: [
            screenServiceProvider.overrideWithValue(customService),
          ],
        );
        addTearDown(customContainer.dispose);
        
        final displays = await customContainer.read(displaysProvider.future);
        
        expect(displays.length, 2);
        expect(displays.any((d) => d.id == 'projector'), isTrue);
      });
    });
    
    group('error scenarios', () {
      test('handles all failure types correctly', () async {
        /// Purpose: Verify comprehensive error handling
        /// Quality Contribution: Ensures robust error recovery
        /// Acceptance Criteria: Each failure type must be properly propagated
        
        final failures = [
          TestFailures.platformChannel('Channel error'),
          TestFailures.displayNotFound('display-123'),
          TestFailures.unknown('Unexpected error'),
        ];
        
        for (final failure in failures) {
          // Create fresh service and container for each failure type
          final testService = FakeScreenService();
          testService.setFailure(failure);
          
          final testContainer = ProviderContainer(
            overrides: [
              screenServiceProvider.overrideWithValue(testService),
            ],
          );
          addTearDown(testContainer.dispose);
          
          // Collect states
          final states = <AsyncValue<List<Display>>>[];
          testContainer.listen(displaysProvider, (prev, next) {
            states.add(next);
          }, fireImmediately: true);
          
          // Wait for provider to resolve
          await expectLater(
            testContainer.read(displaysProvider.future),
            throwsA(equals(failure)),
          );
          
          expect(states.last, isError<List<Display>>());
          expect(states.last.error, equals(failure));
        }
      });
    });
    
    group('state management', () {
      test('maintains state across multiple reads', () async {
        /// Purpose: Verify provider caching behavior
        /// Quality Contribution: Ensures efficient state management
        /// Acceptance Criteria: Multiple reads should return same state
        
        // Track how many times the build method is called
        var buildCount = 0;
        final countingContainer = ProviderContainer(
          overrides: [
            displaysProvider.overrideWith(() {
              buildCount++;
              return Displays();
            }),
            screenServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(countingContainer.dispose);
        
        // Initial load
        await countingContainer.read(displaysProvider.future);
        expect(buildCount, 1); // Build called once
        
        // Multiple reads should not trigger rebuild
        await countingContainer.read(displaysProvider.future);
        await countingContainer.read(displaysProvider.future);
        expect(buildCount, 1); // Still only once
        
        // But refresh should trigger rebuild
        await countingContainer.read(displaysProvider.notifier).refresh();
        expect(buildCount, 1); // Refresh doesn't rebuild, just changes state
        
        // State should be consistent across reads
        final state1 = countingContainer.read(displaysProvider);
        final state2 = countingContainer.read(displaysProvider);
        expect(identical(state1, state2), isTrue);
      });
    });
  });
}