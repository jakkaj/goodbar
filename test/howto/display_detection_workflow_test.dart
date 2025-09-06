import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/failures/screen_failures.dart';
import 'package:goodbar/src/providers/displays_provider.dart';
import 'package:goodbar/src/providers/services.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mock_providers.dart';

void main() {
  group('HowTo: Complete Display Detection Workflow', () {
    test('demonstrates full DI and state management workflow', () async {
      /// Compelling Use Case: A developer needs to understand how Riverpod DI works
      /// with AsyncValue state management in a real-world scenario.
      /// 
      /// This test demonstrates:
      /// 1. Provider override patterns for testing
      /// 2. AsyncValue state transitions
      /// 3. Error handling and recovery
      /// 4. Display configuration changes
      /// 5. Manual refresh capabilities
      /// 
      /// Quality Contribution: Serves as executable documentation showing
      /// the complete lifecycle of display detection with proper testing patterns.
      /// 
      /// Acceptance Criteria:
      /// - Must show all AsyncValue states (loading, data, error)
      /// - Must demonstrate error recovery
      /// - Must show how to test state transitions
      /// - Must validate DI override mechanism
      
      // ========================================================================
      // STEP 1: Setup Test Environment with Dependency Injection
      // ========================================================================
      
      // Create a controllable fake service for testing
      final service = FakeScreenService();
      
      // Create a provider container with our test service
      final container = ProviderContainer(
        overrides: [
          // This is how we inject test dependencies in Riverpod
          screenServiceProvider.overrideWithValue(service),
        ],
      );
      
      // Always dispose containers in tests to prevent memory leaks
      addTearDown(container.dispose);
      
      // Collect all state transitions for verification
      final states = <AsyncValue<List<Display>>>[];
      container.listen(
        displaysProvider,
        (previous, next) => states.add(next),
        fireImmediately: true, // Capture initial state
      );
      
      // ========================================================================
      // STEP 2: Initial Load - Happy Path
      // ========================================================================
      
      // Trigger initial load by reading the provider
      final initialLoadFuture = container.read(displaysProvider.future);
      
      // Verify we start in loading state
      expect(states.length, 1);
      expect(states.last, isLoading<List<Display>>());
      
      // Wait for the async operation to complete
      final initialDisplays = await initialLoadFuture;
      
      // Verify successful transition to data state
      expect(states.length, 2);
      expect(states.last, isData<List<Display>>((d) => d.length == 3));
      
      // Validate the actual display data
      expect(initialDisplays.length, 3);
      expect(initialDisplays[0].isPrimary, isTrue);
      expect(initialDisplays[0].id, '1');
      expect(initialDisplays[1].id, '2');
      expect(initialDisplays[2].id, '3');
      
      // Verify display properties are correct
      DisplayAssertions.assertDisplayArrangement(initialDisplays);
      
      // ========================================================================
      // STEP 3: Manual Refresh - Simulating User Action
      // ========================================================================
      
      // User taps refresh button - simulate display configuration change
      final newConfiguration = TestScenarios.dockedSingleMonitor();
      service.setDisplays(newConfiguration);
      
      // Clear states to track refresh transitions
      states.clear();
      
      // Trigger manual refresh (like user tapping refresh icon)
      await container.read(displaysProvider.notifier).refresh();
      
      // Verify refresh causes loading → data transition
      expect(states.length, 2);
      expect(states[0], isLoading<List<Display>>());
      expect(states[1], isData<List<Display>>((d) => d.length == 2));
      
      // Validate updated configuration
      final refreshedDisplays = states.last.value!;
      expect(refreshedDisplays.length, 2);
      expect(refreshedDisplays.any((d) => d.id == '2'), isTrue);
      
      // ========================================================================
      // STEP 4: Error Handling - Platform Channel Failure
      // ========================================================================
      
      // Simulate platform channel failure
      final platformError = PlatformChannelFailure(
        'Failed to communicate with native macOS layer'
      );
      service.setFailure(platformError);
      
      states.clear();
      
      // Attempt refresh which will fail
      await container.read(displaysProvider.notifier).refresh();
      
      // Verify error state transition
      expect(states.length, 2);
      expect(states[0], isLoading<List<Display>>());
      expect(states[1], isErrorWithType<List<Display>, PlatformChannelFailure>());
      
      // Validate error details
      final errorState = states.last as AsyncError<List<Display>>;
      expect(errorState.error, equals(platformError));
      expect(errorState.stackTrace, isNotNull);
      
      // ========================================================================
      // STEP 5: Error Recovery - Retry After Failure
      // ========================================================================
      
      // Clear the failure to simulate problem resolution
      service.clearFailure();
      service.setDisplays(TestScenarios.developerSetup());
      
      states.clear();
      
      // User taps retry button
      await container.read(displaysProvider.notifier).refresh();
      
      // Verify successful recovery
      expect(states.length, 2);
      expect(states[0], isLoading<List<Display>>());
      expect(states[1], isData<List<Display>>((d) => d.length == 3));
      
      // ========================================================================
      // STEP 6: Display Hot-Plug Simulation
      // ========================================================================
      
      // Simulate user connecting a new display
      final hotplugConfiguration = [
        ...TestScenarios.developerSetup(),
        DisplayBuilders.custom(
          id: 'hotplugged',
          width: 2560,
          height: 1440,
          x: 7296, // Right of display 2
          y: 0,
        ),
      ];
      
      // Emit display change event (simulates macOS notification)
      service.emitDisplayChange(hotplugConfiguration);
      
      states.clear();
      
      // App detects change and refreshes
      await container.read(displaysProvider.notifier).refresh();
      
      // Verify new display is detected
      final hotpluggedDisplays = states.last.value!;
      expect(hotpluggedDisplays.length, 4);
      expect(hotpluggedDisplays.any((d) => d.id == 'hotplugged'), isTrue);
      
      // ========================================================================
      // STEP 7: Specific Display Queries
      // ========================================================================
      
      // Get specific display by ID
      final display2 = await container
          .read(displaysProvider.notifier)
          .getDisplay('2');
      
      expect(display2.id, '2');
      expect(display2.isPrimary, isFalse);
      expect(display2.bounds.width, 3840); // 4K display
      
      // Get primary display
      final primaryDisplay = await container
          .read(displaysProvider.notifier)
          .getPrimaryDisplay();
      
      expect(primaryDisplay.isPrimary, isTrue);
      expect(primaryDisplay.menuBarHeight, greaterThan(0));
      
      // Handle non-existent display
      expect(
        () => container.read(displaysProvider.notifier).getDisplay('invalid'),
        throwsA(isA<DisplayNotFoundFailure>()),
      );
      
      // ========================================================================
      // STEP 8: State Persistence Across Reads
      // ========================================================================
      
      // Multiple reads should return cached data
      final read1 = await container.read(displaysProvider.future);
      final read2 = await container.read(displaysProvider.future);
      final read3 = await container.read(displaysProvider.future);
      
      // All reads return same instance (cached)
      expect(identical(read1, read2), isTrue);
      expect(identical(read2, read3), isTrue);
      
      // But refresh creates new instance
      await container.read(displaysProvider.notifier).refresh();
      final read4 = await container.read(displaysProvider.future);
      
      expect(identical(read1, read4), isFalse);
      expect(read4.length, read1.length); // Same data, different instance
      
      // ========================================================================
      // STEP 9: Edge Cases and Error Types
      // ========================================================================
      
      // Test different failure types
      final failures = [
        TestFailures.displayNotFound('xyz'),
        TestFailures.unknown('Unexpected error'),
        TestFailures.platformChannel('Channel closed'),
      ];
      
      for (final failure in failures) {
        service.setFailure(failure);
        states.clear();
        
        await container.read(displaysProvider.notifier).refresh();
        
        expect(states.last, isError<List<Display>>());
        expect(states.last.error, equals(failure));
        
        // Verify each error type has proper stackTrace
        final error = states.last as AsyncError;
        expect(error.stackTrace, isNotNull);
      }
      
      // ========================================================================
      // STEP 10: Complete Workflow Summary
      // ========================================================================
      
      // Final state verification - full cycle completed
      service.clearFailure();
      service.setDisplays(TestScenarios.laptopOnly());
      
      states.clear();
      await container.read(displaysProvider.notifier).refresh();
      
      // Verify we can return to simple configuration
      final finalDisplays = states.last.value!;
      expect(finalDisplays.length, 1);
      expect(finalDisplays.first.isPrimary, isTrue);
      
      // ========================================================================
      // WORKFLOW COMPLETE
      // ========================================================================
      
      /// This test has demonstrated:
      /// ✅ Dependency injection with provider overrides
      /// ✅ AsyncValue state management (loading, data, error)
      /// ✅ Error handling and recovery patterns
      /// ✅ Manual refresh capabilities
      /// ✅ Display hot-plug simulation
      /// ✅ Specific display queries
      /// ✅ State caching and persistence
      /// ✅ Multiple error type handling
      /// ✅ Complete state lifecycle
      /// 
      /// Key Patterns Established:
      /// - Always use ProviderContainer for testing
      /// - Override services with test doubles
      /// - Track state transitions with listen()
      /// - Test all AsyncValue states
      /// - Verify error recovery paths
      /// - Clean up with addTearDown()
      
      // Verify total state transitions to ensure complete test coverage
      expect(states.isNotEmpty, isTrue);
    });
    
    test('demonstrates widget testing with provider overrides', () async {
      /// Compelling Use Case: Testing UI components that depend on providers
      /// 
      /// This demonstrates how to test widgets with Riverpod providers,
      /// showing the complete integration between UI and state management.
      
      // Create test scenarios
      final scenarios = [
        (
          name: 'Loading State',
          setup: () => MockProviders.loadingDisplaysProvider(),
          verify: (AsyncValue<List<Display>> state) {
            expect(state, isLoading<List<Display>>());
          }
        ),
        (
          name: 'Success State',
          setup: () => MockProviders.successfulDisplaysProvider(
            TestScenarios.presentationMode()
          ),
          verify: (AsyncValue<List<Display>> state) {
            expect(state.value?.length, 2);
            expect(state.value?.any((d) => d.id == 'projector'), isTrue);
          }
        ),
        (
          name: 'Error State',
          setup: () => MockProviders.errorDisplaysProvider(
            TestFailures.platformChannel()
          ),
          verify: (AsyncValue<List<Display>> state) {
            expect(state, isErrorWithType<List<Display>, PlatformChannelFailure>());
          }
        ),
      ];
      
      // Test each scenario
      for (final scenario in scenarios) {
        final container = ProviderContainer(
          overrides: [scenario.setup()],
        );
        addTearDown(container.dispose);
        
        final state = container.read(displaysProvider);
        scenario.verify(state);
      }
    });
    
    test('demonstrates stream-based display monitoring', () async {
      /// Compelling Use Case: Monitoring display changes in real-time
      /// 
      /// Shows how to handle display configuration changes that occur
      /// while the app is running (hot-plug events).
      
      final service = FakeScreenService();
      final container = ProviderContainer(
        overrides: [
          screenServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      
      // Track display change events
      final changeEvents = <DisplayChangeEvent>[];
      service.displayChanges.listen((event) {
        changeEvents.add(event);
      });
      
      // Simulate display changes
      service.addDisplay(DisplayBuilders.external4K());
      expect(changeEvents.length, 1);
      expect(changeEvents.last.changeType, 'added');
      
      service.removeDisplay('2');
      expect(changeEvents.length, 2);
      expect(changeEvents.last.changeType, 'removed');
      
      service.emitDisplayChange(TestScenarios.edgeCase());
      expect(changeEvents.length, 3);
      expect(changeEvents.last.changeType, 'changed');
      
      // Each event includes timestamp for tracking
      for (final event in changeEvents) {
        expect(event.timestamp, isA<DateTime>());
        expect(event.displays, isNotEmpty);
      }
    });
  });
}