import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/failures/screen_failures.dart';
import 'package:goodbar/src/providers/displays_provider.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import '../../../support/container_helpers.dart';

/// State transition helpers for testing AsyncValue changes
/// 
/// These helpers simulate realistic state transitions that occur
/// during actual app usage, ensuring tests cover real scenarios.
class StateTransitions {
  /// Simulates a successful load sequence
  /// 
  /// Transitions: Loading → Data
  static Future<void> simulateSuccessfulLoad(
    ProviderContainer container,
    FakeScreenService service, {
    List<Display>? displays,
  }) async {
    // Start in loading
    container.read(displaysProvider.notifier).state = const AsyncLoading();
    await container.pump();
    
    // Transition to data
    if (displays != null) {
      service.setDisplays(displays);
    }
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
  
  /// Simulates an error during load
  /// 
  /// Transitions: Loading → Error
  static Future<void> simulateErrorLoad(
    ProviderContainer container,
    FakeScreenService service,
    ScreenFailure failure,
  ) async {
    // Start in loading
    container.read(displaysProvider.notifier).state = const AsyncLoading();
    await container.pump();
    
    // Set failure
    service.setFailure(failure);
    
    // Trigger refresh which will encounter the error
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
  
  /// Simulates error recovery
  /// 
  /// Transitions: Error → Loading → Data
  static Future<void> simulateErrorRecovery(
    ProviderContainer container,
    FakeScreenService service, {
    List<Display>? displays,
  }) async {
    // Clear the failure
    service.clearFailure();
    
    // Set new displays if provided
    if (displays != null) {
      service.setDisplays(displays);
    }
    
    // Trigger refresh for recovery
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
  
  /// Simulates display hot-plug event
  /// 
  /// Adds a display and refreshes the provider
  static Future<void> simulateDisplayAdded(
    ProviderContainer container,
    FakeScreenService service,
    Display newDisplay,
  ) async {
    // Add display to service
    service.addDisplay(newDisplay);
    
    // Refresh provider to pick up change
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
  
  /// Simulates display removal event
  /// 
  /// Removes a display and refreshes the provider
  static Future<void> simulateDisplayRemoved(
    ProviderContainer container,
    FakeScreenService service,
    String displayId,
  ) async {
    // Remove display from service
    service.removeDisplay(displayId);
    
    // Refresh provider to pick up change
    await container.read(displaysProvider.notifier).refresh();
    await container.pump();
  }
  
  /// Tracks state transitions for a provider operation
  /// 
  /// Returns a list of states that occurred during the operation.
  /// Useful for verifying complete state sequences.
  static Future<List<AsyncValue<List<Display>>>> trackTransitions(
    ProviderContainer container,
    Future<void> Function() operation,
  ) async {
    final states = <AsyncValue<List<Display>>>[];
    
    // Start listening
    final subscription = container.listen(
      displaysProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    
    // Perform operation
    await operation();
    
    // Clean up
    subscription.close();
    
    return states;
  }
}