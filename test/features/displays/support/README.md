# Display Feature Test Support

This directory contains **display-specific** test utilities for testing display detection and management features. These helpers are scoped to the displays domain and should only be used in display-related tests.

## Available Utilities

### fixtures.dart
Test data builders for creating realistic `Display` objects.

```dart
// Create specific display types
final macbook = DisplayBuilders.macBookPro16();
final external = DisplayBuilders.external4K(x: 3456, y: 0);
final monitor = DisplayBuilders.external1080p();

// Create a standard 3-display setup
final displays = DisplayBuilders.threeDisplaySetup();

// Create custom displays for edge cases
final vertical = DisplayBuilders.custom(
  id: 'vertical',
  width: 1080,
  height: 1920,  // Taller than wide
  scaleFactor: 1.0,
);
```

### scenarios.dart
Common real-world display configurations.

```dart
// Single laptop display
final laptop = TestScenarios.laptopOnly();

// Laptop + one external monitor
final docked = TestScenarios.dockedSingleMonitor();

// Full developer setup (3 displays)
final dev = TestScenarios.developerSetup();

// Presentation mode with projector
final presenting = TestScenarios.presentationMode();

// Edge cases (vertical monitors, ultra-wide)
final edge = TestScenarios.edgeCase();
```

### mocks.dart
Provider overrides and mock containers for different states.

```dart
// Provider overrides
final loading = MockProviders.loadingDisplaysProvider();
final success = MockProviders.successfulDisplaysProvider(displays);
final error = MockProviders.errorDisplaysProvider(failure);

// Pre-configured containers
final container = MockContainers.withDisplays([...]);
final errorContainer = MockContainers.withError(failure);

// Controllable service for complex scenarios
final result = MockContainers.controllable();
final service = result.service;
final container = result.container;
service.addDisplay(newDisplay);  // Manipulate during test
```

### assertions.dart
Display-specific validation helpers.

```dart
// Validate display properties
DisplayAssertions.assertValidDisplay(display);
DisplayAssertions.assertSinglePrimary(displays);
DisplayAssertions.assertValidPositioning(displays);

// Check specific properties
DisplayAssertions.assertDisplayProperties(
  display,
  id: '1',
  isPrimary: true,
  scaleFactor: 2.0,
);
```

### failures.dart
Factory methods for creating test failures.

```dart
// Create specific failure types
final channelError = TestFailures.platformChannel('Connection lost');
final notFound = TestFailures.displayNotFound('display-123');
final unknown = TestFailures.unknown('Unexpected error');
```

### transitions.dart
Helpers for simulating state transitions.

```dart
// Simulate successful load
await StateTransitions.simulateSuccessfulLoad(container, service);

// Simulate error and recovery
await StateTransitions.simulateErrorLoad(container, service, failure);
await StateTransitions.simulateErrorRecovery(container, service);

// Simulate display hot-plug
await StateTransitions.simulateDisplayAdded(container, service, newDisplay);
await StateTransitions.simulateDisplayRemoved(container, service, 'display-id');

// Track all state transitions
final states = await StateTransitions.trackTransitions(
  container,
  () async => await container.read(displaysProvider.notifier).refresh(),
);
```

## Common Test Patterns

### Testing Initial Load
```dart
test('loads displays on startup', () async {
  final container = MockContainers.withDisplays(
    TestScenarios.developerSetup()
  );
  
  final displays = await container.read(displaysProvider.future);
  DisplayAssertions.assertSinglePrimary(displays);
  DisplayAssertions.assertValidPositioning(displays);
});
```

### Testing Error Handling
```dart
test('handles platform errors gracefully', () async {
  final failure = TestFailures.platformChannel();
  final container = MockContainers.withError(failure);
  
  final state = container.read(displaysProvider);
  expect(state, isErrorWithType<List<Display>, PlatformChannelFailure>());
});
```

### Testing Display Changes
```dart
test('detects display hot-plug', () async {
  final result = MockContainers.controllable();
  final newDisplay = DisplayBuilders.external4K();
  
  await StateTransitions.simulateDisplayAdded(
    result.container,
    result.service,
    newDisplay,
  );
  
  final displays = result.container.read(displaysProvider).requireValue;
  expect(displays.any((d) => d.id == newDisplay.id), isTrue);
});
```

## Important Notes

- These utilities are **display-specific** and should not be used in other feature tests
- The `FakeScreenService` lives in `lib/` (not here) because it's also used for development/demos
- Always use `DisplayAssertions` for validation rather than manual property checks
- Prefer `TestScenarios` over manually creating display configurations