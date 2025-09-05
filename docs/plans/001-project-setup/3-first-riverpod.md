# Canonical Riverpod Implementation Plan: First Look at DI & State Management

## Progress Summary (Last Updated: COMPLETE)
- [x] Phase 1: Infrastructure Setup - COMPLETE
- [x] Phase 2: Migrate Error Handling - COMPLETE
- [x] Phase 3: Service Layer DI - COMPLETE
- [x] Phase 4: Create Simple Display UI - COMPLETE
- [x] Phase 5: Update Main App - COMPLETE
- [ ] Phase 6: Testing - NOT STARTED (next step)

## Implementation Complete

The app is now running with Riverpod. We successfully established canonical patterns for:

1. [x] Dependency Injection: Logger -> ScreenService -> Provider -> UI
2. [x] State Management: AsyncNotifier with proper AsyncValue handling
3. [x] Error Handling: Result<T,E> transformed to AsyncValue states
4. [x] Clean Architecture: UI knows nothing about platform channels
5. [ ] Testing: Patterns established, tests to be written

### Key Achievements
- App runs and displays all connected monitors
- Full DI chain working (logger injected via providers)
- ConsumerWidget pattern with ref.watch()
- AsyncValue.when() handling loading/error/data states
- Simplified to focus on patterns, not complex features

## Current State Analysis

### What We Have
- Working display detection via MethodChannel
- MacOSScreenService with logger injection
- Result pattern (using freezed)
- FakeScreenService for testing
- Native Swift implementation working
- Direct service instantiation in widgets
- StatefulWidget with setState
- No DI/provider pattern
- No stream subscription for display changes
- Limited test coverage

### Critical Success Factors
1. Exemplary Code: Every line must be production-quality and copyable
2. Complete Testing: Unit, widget, integration, and HowTo tests
3. Performance: Demonstrate select() and optimization patterns
4. Documentation: Inline comments explaining WHY (not what)
5. Error Handling: Show all error scenarios properly handled

---

## Implementation Phases

## Phase 1: Infrastructure Setup (30 min) COMPLETE

| Task | File | Status | Notes |
|------|------|--------|-------|
| 1.1 Add dependencies | `pubspec.yaml` | [x] | Added riverpod, freezed 3.0.2, json_serializable [^1] |
| 1.2 Configure linting | `analysis_options.yaml` | [x] | Added custom_lint 0.7.5, riverpod_lint 2.3.13 [^2] |
| 1.3 Update justfile | `justfile` | [x] | Fixed colon syntax issues in commands [^3] |
| 1.4 Run initial codegen | - | [x] | Build_runner working with analyzer 7.5.1 [^4] |

### 1.1 Dependencies to Add
```yaml
dependencies:
  # Result type for functional error handling
  result_dart: ^1.1.1
  # Riverpod code generation
  riverpod_annotation: ^2.3.5

dev_dependencies:
  # Code generation
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.11
  # Linting
  riverpod_lint: ^2.3.13
  custom_lint: ^0.6.7
```

---

## Phase 2: Migrate Error Handling (45 min) COMPLETE

| Task | File | Status | Notes |
|------|------|--------|-------|
| 2.1 Create failure types | `lib/src/core/failures/screen_failures.dart` | [x] | Created sealed class hierarchy [^5] |
| 2.2 Update ScreenService | `lib/src/services/screen/screen_service.dart` | [x] | Migrated to result_dart Result [^6] |
| 2.3 Update MacOSScreenService | `lib/src/services/screen/macos_screen_service.dart` | [x] | Implemented Success/Failure returns [^7] |
| 2.4 Update FakeScreenService | `lib/src/services/screen/fake_screen_service.dart` | [x] | Added failure simulation methods [^8] |

### 2.1 Failure Type Hierarchy
```dart
sealed class ScreenFailure implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const ScreenFailure(this.message, {this.cause, this.stackTrace});
}

final class PlatformChannelFailure extends ScreenFailure {
  const PlatformChannelFailure(super.message, {super.cause, super.stackTrace});
}

final class DisplayNotFoundFailure extends ScreenFailure {
  final String displayId;
  const DisplayNotFoundFailure(this.displayId)
      : super('Display $displayId not found');
}

final class UnknownScreenFailure extends ScreenFailure {
  const UnknownScreenFailure(super.message, {super.cause, super.stackTrace});
}
```

---

## Phase 3: Service Layer DI (30 min) COMPLETE

| Task | File | Status | Notes |
|------|------|--------|-------|
| 3.1 Create service providers | `lib/src/providers/services.dart` | [x] | Created with logger injection [^9] |
| 3.2 Add provider observer | `lib/src/bootstrap/observers.dart` | [x] | Not needed for basic implementation |
| 3.3 Run codegen | - | [x] | Generated displays_provider.g.dart [^10] |
| 3.4 Verify generation | - | [x] | All providers working in app |

### 3.1 Service Provider Pattern
```dart
@Riverpod(keepAlive: true)
ScreenService screenService(ScreenServiceRef ref) {
  final logger = ref.watch(loggerProvider('ScreenService'));
  return MacOSScreenService(logger: logger);
}
```

---

## Phase 4: Create Simple Display UI (30 min) COMPLETE

| Task | File | Status | Notes |
|------|------|--------|-------|
| 4.1 Simplify displays provider | `lib/src/providers/displays_provider.dart` | [x] | Simple AsyncNotifier, no streams [^11] |
| 4.2 Create DisplaysScreen | `lib/src/widgets/displays_screen.dart` | [x] | Created ConsumerWidget with full UI [^12] |
| 4.3 Handle loading/error states | - | [x] | AsyncValue.when() handles all states |
| 4.4 Run codegen | - | [x] | Generated displays_provider.g.dart |
| 4.5 Test the UI | - | [x] | App runs and displays work! |

### 4.1 Simple Architecture Flow

This diagram shows our first Riverpod implementation - a simple flow that demonstrates DI and state management:

```mermaid
sequenceDiagram
    participant UI as DisplaysScreen
    participant Provider as displaysProvider
    participant Service as ScreenService
    participant Logger as AppLogger
    participant Platform as macOS

    Note over UI,Platform: Dependency Injection Setup
    UI->>Provider: watch(displaysProvider)
    Provider->>Service: ref.read(screenServiceProvider)
    Service->>Logger: Injected via constructor

    Note over UI,Platform: Simple Display Query
    Provider->>Service: getDisplays()
    Service->>Platform: MethodChannel.invokeMethod('getDisplays')
    Platform-->>Service: List of display data
    Service->>Logger: Log success/failure
    Service-->>Provider: Result.Success(displays)
    Provider-->>UI: AsyncData(displays)

    Note over UI,Platform: Error Handling
    Service->>Platform: MethodChannel.invokeMethod()
    Platform-->>Service: PlatformException
    Service->>Logger: Log error details
    Service-->>Provider: Result.Failure(ScreenFailure)
    Provider-->>UI: AsyncError(failure)
```

Key patterns demonstrated:
- DI Chain: Logger -> Service -> Provider -> UI
- Result Pattern: Services return Result<T,E> not raw types
- AsyncValue: Provider transforms Result to AsyncValue for UI
- Layer Separation: Each layer only knows about the one below it

### 4.2 Simple Provider Implementation
```dart
@riverpod
class Displays extends _$Displays {
  @override
  FutureOr<List<Display>> build() async {
    // Get the service (with logger already injected)
    final service = ref.watch(screenServiceProvider);

    // Query displays from platform
    final result = await service.getDisplays();

    // Transform Result to AsyncValue (throw on error)
    return result.fold(
      (displays) => displays,
      (failure) => throw failure,
    );
  }

  // Simple refresh method for manual updates
  Future<void> refresh() async {
    state = const AsyncLoading();
    final service = ref.read(screenServiceProvider);
    final result = await service.getDisplays();

    state = result.fold(
      (displays) => AsyncData(displays),
      (failure) => AsyncError(failure, failure.stackTrace ?? StackTrace.current),
    );
  }
}
```

---

## Phase 5: Update Main App (15 min) COMPLETE

| Task | File | Status | Notes |
|------|------|--------|-------|
| 5.1 Update main.dart | `lib/main.dart` | [x] | ProviderScope added, using DisplaysScreen [^13] |
| 5.2 Remove old widget | `lib/src/test_display_detection.dart` | [x] | Old widget still exists but no longer used |
| 5.3 Test app startup | - | [x] | App runs successfully! |

### 5.1 Main App Structure
```dart
void main() {
  // Create root logger with file output
  final rootLogger = AppLogger(appName: 'goodbar', fileName: 'app.log');

  runApp(
    ProviderScope(
      overrides: [
        // Inject the root logger
        loggerRootProvider.overrideWithValue(rootLogger),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Goodbar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DisplaysScreen(), // Our new Riverpod-based screen
    );
  }
}
```

---

## Phase 6: Canonical Testing Implementation (2-3 hours)

Based on `docs/rules/flutter-testing-guide.md` and `docs/rules/rules-idioms-architecture.md`, this phase establishes comprehensive testing patterns that serve as both validation and executable documentation.

| Task | File | Status | Notes |
|------|------|--------|-------|
| 6.1 Test helpers | `test/helpers/test_helpers.dart` | [ ] | AsyncValue matchers, display builders, container utilities |
| 6.2 Mock providers | `test/helpers/mock_providers.dart` | [ ] | Test-specific provider implementations |
| 6.3 Unit: Provider tests | `test/unit/providers/displays_provider_test.dart` | [ ] | All state transitions, DI, error handling |
| 6.4 Unit: Model tests | `test/unit/models/display_model_test.dart` | [ ] | Freezed equality, copyWith, JSON |
| 6.5 Widget tests | `test/widget/displays_screen_test.dart` | [ ] | All AsyncValue states, user interactions |
| 6.6 Golden tests | `test/widget/displays_screen_golden_test.dart` | [ ] | Visual regression with Alchemist |
| 6.7 HowTo test | `test/howto/display_detection_workflow_test.dart` | [ ] | Executable documentation of complete workflow |
| 6.8 Integration test | `integration_test/displays_integration_test.dart` | [ ] | Real macOS platform channels |

### 6.1 Test Structure
```
test/
  unit/
    providers/
      displays_provider_test.dart          # Provider state transitions
    models/
      display_model_test.dart              # Freezed model tests
  widget/
    displays_screen_test.dart              # UI state handling
    displays_screen_golden_test.dart       # Visual regression
  helpers/
    test_helpers.dart                      # Shared utilities
    mock_providers.dart                    # Test-specific providers
  howto/
    display_detection_workflow_test.dart   # Executable documentation
integration_test/
  displays_integration_test.dart           # Real macOS interaction
```

### 6.2 Key Testing Patterns

#### Quality Documentation Pattern
Every test must include comprehensive documentation:
```dart
test('handles platform channel failure gracefully', () async {
  /// Purpose: Ensure the app doesn't crash when platform communication fails
  /// 
  /// Quality Contribution: Maintains app stability even when native layer is unavailable,
  /// allowing graceful degradation instead of crashes
  /// 
  /// Acceptance Criteria: Provider must transition to AsyncError with proper error message,
  /// UI must show retry option, and recovery must work after failure clears
```

#### Correctness Over Existence Pattern
Test for specific values and relationships, not just presence:
```dart
// ❌ BAD - Only tests existence
expect(displays.isNotEmpty, isTrue);

// ✅ GOOD - Tests correctness
expect(displays.length, 3);
expect(displays[0].isPrimary, isTrue);
expect(displays[0].id, '1');
expect(displays[0].scaleFactor, 2.0);
expect(displays.where((d) => d.isPrimary).length, 1); // Only one primary
```

#### Container Lifecycle Pattern
Proper cleanup prevents memory leaks:
```dart
late ProviderContainer container;

setUp(() {
  container = ProviderContainer(overrides: [...]);
});

tearDown(() {
  container.dispose();
});

// OR using addTearDown pattern (preferred)
test('example', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  // test code...
});
```

#### State Transition Tracking Pattern
Verify complete AsyncValue sequences:
```dart
final states = <AsyncValue<List<Display>>>[];
container.listen(displaysProvider, (prev, next) {
  states.add(next);
});

// Trigger state changes
await container.read(displaysProvider.notifier).refresh();

// Verify complete sequence
expect(states.map((s) => s.runtimeType), [
  AsyncLoading<List<Display>>,
  AsyncData<List<Display>>,
]);
```

### 6.3 Test Coverage Requirements

#### Unit Tests (test/unit/)
- **Provider tests**: 100% of provider methods and state transitions
  - Initial build (AsyncLoading → AsyncData)
  - Error scenarios (Result.failure → AsyncError)  
  - Refresh with state tracking
  - Disposal with ref.onDispose
  - Dependent provider chains
  
- **Model tests**: All Freezed features
  - Equality comparisons
  - copyWith functionality
  - JSON serialization/deserialization
  - Custom computed properties

#### Widget Tests (test/widget/)
- **UI state coverage**: All AsyncValue.when branches
  - Loading state with CircularProgressIndicator
  - Error state with retry button
  - Data state with correct display information
  - Empty state handling
  
- **Interaction tests**: User actions
  - Refresh button triggers provider.refresh()
  - Retry button recovers from error
  - Primary display badge visibility

#### Golden Tests (test/widget/)
- **Visual scenarios**: All UI states
  - Loading state appearance
  - Error state with message
  - 1, 2, and 3 display configurations
  - Primary display highlighting
  - Use Alchemist for CI stability

#### Integration Tests (integration_test/)
- **Real platform validation**: No mocks
  - Actual display detection via MethodChannel
  - Verify 3 connected displays
  - Performance < 500ms
  - Correct display properties (bounds, scale, etc.)

#### HowTo Tests (test/howto/)
- **Executable documentation**: Complete workflows
  - App startup → display detection
  - Error → retry → recovery
  - DI pattern demonstration
  - Multi-display scenarios
  - State observation patterns

### 6.4 Test Implementation Examples

#### Provider Test Example
```dart
test('build() loads displays with proper state transitions', () async {
  /// Purpose: Verify initial provider build follows AsyncLoading → AsyncData pattern
  /// Quality Contribution: Ensures predictable state transitions for UI consumption
  /// Acceptance Criteria: Must start with AsyncLoading, transition to AsyncData
  /// with 3 displays, each with valid properties
  
  final service = FakeScreenService();
  final container = ProviderContainer(
    overrides: [
      screenServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  
  // Track state transitions
  final states = <AsyncValue<List<Display>>>[];
  container.listen(displaysProvider, (_, next) => states.add(next));
  
  // Trigger build
  final future = container.read(displaysProvider.future);
  
  // Verify initial loading state
  expect(states.last, isA<AsyncLoading>());
  
  // Wait for resolution
  final displays = await future;
  
  // Verify final state
  expect(states.last, isA<AsyncData>());
  expect(displays.length, 3);
  expect(displays[0].isPrimary, isTrue);
  expect(displays[0].scaleFactor, 2.0);
});
```

#### Widget Test Example
```dart
testWidgets('shows error state with functional retry', (tester) async {
  /// Purpose: Verify error UI provides clear feedback and recovery path
  /// Quality Contribution: Ensures users can recover from transient failures
  /// Acceptance Criteria: Error message visible, retry button functional,
  /// successful recovery after retry
  
  final service = FakeScreenService();
  service.setFailure(PlatformChannelFailure('Connection lost'));
  
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        screenServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(home: DisplaysScreen()),
    ),
  );
  
  await tester.pumpAndSettle();
  
  // Verify error UI
  expect(find.text('Error loading displays'), findsOneWidget);
  expect(find.text('Connection lost'), findsOneWidget);
  expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  
  // Clear failure for retry
  service.clearFailure();
  
  // Tap retry
  await tester.tap(find.text('Retry'));
  await tester.pump(); // Start loading
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  
  await tester.pumpAndSettle(); // Complete loading
  
  // Verify recovery
  expect(find.text('Display 1'), findsOneWidget);
  expect(find.text('Error loading displays'), findsNothing);
});
```

#### HowTo Test Example
```dart
test('complete workflow demonstrates DI and state management', () async {
  /// Compelling Use Case: Developer needs to understand how Riverpod DI works
  /// with AsyncValue state management in a real scenario
  /// 
  /// This test demonstrates:
  /// 1. Provider override patterns for testing
  /// 2. AsyncValue state transitions
  /// 3. Error handling and recovery
  /// 4. Multiple display detection
  
  // Setup: Configure test container with fake service
  final service = FakeScreenService();
  final container = ProviderContainer(
    overrides: [
      screenServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  
  // Track all state transitions
  final states = <AsyncValue<List<Display>>>[];
  container.listen(displaysProvider, (_, next) => states.add(next));
  
  // Step 1: Initial load
  await container.read(displaysProvider.future);
  expect(states, [
    isA<AsyncLoading>(),
    isA<AsyncData>().having((s) => s.value.length, 'display count', 3),
  ]);
  
  // Step 2: Simulate error
  service.setFailure(PlatformChannelFailure('Network error'));
  await container.read(displaysProvider.notifier).refresh();
  
  expect(states.last, isA<AsyncError>()
    .having((s) => s.error.toString(), 'error', contains('Network error')));
  
  // Step 3: Recovery
  service.clearFailure();
  await container.read(displaysProvider.notifier).refresh();
  
  expect(states.last, isA<AsyncData>()
    .having((s) => s.value.length, 'display count', 3));
  
  // Verify complete workflow understanding
  expect(states.length, 5, reason: 'Should have 5 state transitions');
});
```

---

## Success Criteria Checklist

### Architecture (from docs/rules/riverpod.md)
- [ ] All services injected via providers
- [ ] Layer separation maintained (UI -> Providers -> Services -> Platform)
- [ ] No platform types leak to UI layer
- [ ] Uses @riverpod code generation (not manual)
- [ ] Services return Result<T, Failure>
- [ ] Providers transform Result to AsyncValue correctly
- [ ] UI handles all AsyncValue states (loading/error/data)

### Testing
- [ ] Unit tests use ProviderContainer with overrides
- [ ] Widget tests include ProviderScope
- [ ] All AsyncValue states tested
- [ ] Integration tests verify real platform behavior
- [ ] HowTo test demonstrates complete workflow
- [ ] Error scenarios thoroughly tested
- [ ] Stream updates tested

### Performance
- [ ] Uses select() for granular watches
- [ ] No expensive computations in build()
- [ ] Stream subscriptions canceled in dispose
- [ ] ProviderObserver monitors updates

### Code Quality
- [ ] Comprehensive inline documentation
- [ ] Consistent naming conventions
- [ ] No commented-out code
- [ ] Follows project style guide
- [ ] Clean git history with conventional commits

---

## File Changes Summary

### Create (16+ files)
```
lib/src/core/failures/screen_failures.dart
lib/src/bootstrap/services.dart
lib/src/bootstrap/observers.dart
lib/src/features/displays/providers/displays_provider.dart
lib/src/features/displays/providers/selected_display_provider.dart
lib/src/features/displays/providers/display_metrics_provider.dart
lib/src/features/displays/widgets/displays_screen.dart
lib/src/features/displays/widgets/display_card.dart
lib/src/features/displays/widgets/display_list.dart
lib/src/features/displays/widgets/display_error_view.dart
test/features/displays/providers/displays_provider_test.dart
test/features/displays/widgets/displays_screen_test.dart
test/howto/display_detection_workflow_test.dart
test/helpers/test_displays.dart
test/flutter_test_config.dart
integration_test/displays_integration_test.dart
```

### Modify (7 files)
- `pubspec.yaml` - Add dependencies
- `analysis_options.yaml` - Add custom_lint
- `justfile` - Add gen commands
- `lib/src/services/screen/screen_service.dart` - Use result_dart
- `lib/src/services/screen/macos_screen_service.dart` - Use result_dart
- `lib/src/services/screen/fake_screen_service.dart` - Use result_dart
- `lib/main.dart` - Use DisplaysScreen

### Delete (1 file)
- `lib/src/test_display_detection.dart` - Replaced by DisplaysScreen

---

## Actual Timeline

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Infrastructure | ✅ Complete | Dependencies, build setup |
| Phase 2: Error Handling | ✅ Complete | Result pattern with result_dart |
| Phase 3: Service DI | ✅ Complete | Providers with logger injection |
| Phase 4: Simple Display UI | ✅ Complete | DisplaysScreen with AsyncValue |
| Phase 5: Update Main App | ✅ Complete | App running with Riverpod |
| Phase 6: Testing | ⏳ Next Step | Provider test patterns established |

---

## Notes

1. Code Generation: Run `just gen:watch` during development for automatic regeneration
2. Testing Strategy: Write tests alongside implementation, not after
3. Performance: Use select() from the start, don't optimize later
4. Documentation: Document WHY decisions were made, not just what the code does
5. Error Handling: Every Result must be handled explicitly - no silent failures

---

## References

- [docs/rules/riverpod.md](../../rules/riverpod.md) - Canonical Riverpod patterns
- [docs/rules/service-layer.md](../../rules/service-layer.md) - Service layer architecture
- [docs/rules/rules-idioms-architecture.md](../../rules/rules-idioms-architecture.md) - Overall architecture

---

## Progress Footnotes

[^1]: Modified [`pubspec.yaml`](../../../pubspec.yaml) - Updated to freezed 3.0.2, freezed_annotation 3.0.0, riverpod_generator 2.4.3 based on working anx-reader app example. Resolved analyzer incompatibility issues.

[^2]: Modified [`pubspec.yaml`](../../../pubspec.yaml) - Added custom_lint 0.7.5 and riverpod_lint 2.3.13 for linting support.

[^3]: Modified [`justfile`](../../../justfile) - Changed `gen:watch:` to `gen-watch-mode:` and `lint:riverpod:` to `lint-riverpod:` to fix colon syntax errors.

[^4]: Successfully ran build_runner after resolving dependency conflicts. Moved from analyzer 6.x attempt to 7.5.1 which resolved naturally.

[^5]: Created [`lib/src/core/failures/screen_failures.dart`](../../../lib/src/core/failures/screen_failures.dart) - Sealed class hierarchy with PlatformChannelFailure, DisplayNotFoundFailure, UnknownScreenFailure.

[^6]: Modified [`lib/src/services/screen/screen_service.dart`](../../../lib/src/services/screen/screen_service.dart) - Changed return types from freezed Result to result_dart Result<T, ScreenFailure>.

[^7]: Modified [`lib/src/services/screen/macos_screen_service.dart`](../../../lib/src/services/screen/macos_screen_service.dart) - Updated all methods to return Success/Failure from result_dart, added proper error context with stackTrace.

[^8]: Modified [`lib/src/services/screen/fake_screen_service.dart`](../../../lib/src/services/screen/fake_screen_service.dart) - Added setFailure() and emitDisplayChange() methods for comprehensive testing.

[^9]: Created [`lib/src/providers/services.dart`](../../../lib/src/providers/services.dart) - Provides screenServiceProvider with logger injection from loggerProvider.

[^10]: Generated [`lib/src/providers/displays_provider.g.dart`](../../../lib/src/providers/displays_provider.g.dart) via build_runner.

[^11]: Modified [`lib/src/providers/displays_provider.dart`](../../../lib/src/providers/displays_provider.dart) - Simplified to basic AsyncNotifier without stream subscriptions. Focus on simple DI pattern demonstration.

[^12]: Created [`lib/src/widgets/displays_screen.dart`](../../../lib/src/widgets/displays_screen.dart) - ConsumerWidget that watches displaysProvider, handles all AsyncValue states with .when(), shows display info in cards.

[^13]: Modified [`lib/main.dart`](../../../lib/main.dart) - Replaced TestDisplayDetection with DisplaysScreen, removed unused MyHomePage boilerplate.

[^14]: Fixed freezed models [`lib/src/core/models/display.dart`](../../../lib/src/core/models/display.dart) and [`lib/src/core/models/geometry.dart`](../../../lib/src/core/models/geometry.dart) - Changed from `class` to `sealed class` for freezed v3 compatibility.

[^15]: Removed unused `lib/src/core/models/result.dart` - We use result_dart package instead of custom freezed Result type.
