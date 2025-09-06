import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generic container helpers for Riverpod testing
/// 
/// These utilities provide common patterns for working with ProviderContainer
/// in tests. They are domain-agnostic and focus on container lifecycle
/// and state management patterns.

/// Extension methods for ProviderContainer
extension ContainerTestExtensions on ProviderContainer {
  /// Pumps the container to allow async operations to complete
  /// 
  /// This is a convenience method that waits for a microtask,
  /// allowing provider state changes to propagate.
  Future<void> pump() async {
    await Future<void>.delayed(Duration.zero);
  }
  
  /// Collects state transitions for a provider
  /// 
  /// Returns a list that will be populated with all state changes
  /// for the given provider. Useful for verifying state sequences.
  /// 
  /// Example:
  /// ```dart
  /// final states = container.collectStates(myProvider);
  /// await container.read(myProvider.future);
  /// expect(states, [isLoading(), isData()]);
  /// ```
  List<T> collectStates<T>(ProviderListenable<T> provider, {
    bool fireImmediately = true,
  }) {
    final states = <T>[];
    
    listen(provider, (previous, next) {
      states.add(next);
    }, fireImmediately: fireImmediately);
    
    return states;
  }
}

/// Helper for creating test containers with automatic disposal
/// 
/// Ensures containers are properly disposed after tests to prevent
/// memory leaks and test interference.
class TestContainer {
  /// Creates a container and ensures it's disposed after the test
  /// 
  /// Example:
  /// ```dart
  /// final container = TestContainer.create(
  ///   overrides: [myProvider.overrideWith(...)],
  /// );
  /// ```
  static ProviderContainer create({
    List<Override> overrides = const [],
    List<ProviderObserver>? observers,
  }) {
    final container = ProviderContainer(
      overrides: overrides,
      observers: observers ?? [],
    );
    
    // Automatically dispose when test completes
    addTearDown(container.dispose);
    
    return container;
  }
  
  /// Creates a scoped container with automatic disposal
  /// 
  /// Useful for testing scoped providers or creating
  /// isolated provider contexts within a test.
  static ProviderContainer createScoped({
    required ProviderContainer parent,
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(
      parent: parent,
      overrides: overrides,
    );
    
    addTearDown(container.dispose);
    
    return container;
  }
}