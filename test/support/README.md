# Generic Test Support Utilities

This directory contains **domain-agnostic** test utilities that can be used across all features in the test suite. These helpers have **no dependencies on specific domain models** (no Display, no feature-specific types).

## Available Utilities

### async_value_matchers.dart
Custom matchers for Riverpod's `AsyncValue` states.

```dart
// Usage examples:
expect(state, isLoading<List<MyModel>>());
expect(state, isData<String>((s) => s.isNotEmpty));
expect(state, isDataWithValue<int>(42));
expect(state, isError<List<Item>>());
expect(state, isErrorWithType<Data, NetworkException>());
expect(state, isErrorWithMessage<User>('Connection failed'));
```

### container_helpers.dart
Utilities for managing `ProviderContainer` lifecycle and state collection.

```dart
// Auto-dispose container creation
final container = TestContainer.create(
  overrides: [myProvider.overrideWith(...)],
);
// No need to call dispose - handled automatically!

// Pump to allow async operations to complete
await container.pump();

// Collect state transitions
final states = container.collectStates(myProvider);
await someAsyncOperation();
expect(states, [isLoading(), isData()]);
```

### pump_utilities.dart
Controlled async operation helpers for tests.

```dart
// Wait for a specific duration
await PumpUtilities.pumpWithDelay(Duration(milliseconds: 100));

// Wait until a condition is met
await PumpUtilities.pumpUntil(
  () => container.read(myProvider).hasValue,
  timeout: Duration(seconds: 3),
);

// Allow microtask queue to process
await PumpUtilities.pumpMicrotask();
```

## Key Principles

1. **No Domain Dependencies**: These utilities must not import any feature-specific models or types
2. **Reusable Across Features**: Should be useful for any feature's tests
3. **Well-Documented**: Include examples in doc comments
4. **Type-Safe**: Use generics where appropriate for flexibility

## When to Add New Utilities Here

Add utilities to this directory when:
- The utility is useful across multiple features
- It has no dependencies on specific domain models
- It's a general testing pattern (not business logic)

## When NOT to Add Utilities Here

Don't add utilities here if:
- They depend on specific domain models (e.g., Display, User)
- They're only useful for one feature
- They contain business logic or domain-specific assertions

Those belong in `test/features/<feature>/support/` instead.