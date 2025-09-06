import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/providers/services.dart';

part 'displays_provider.g.dart';

/// Simple AsyncNotifier for display detection
/// 
/// This provider demonstrates the canonical Riverpod pattern for Goodbar:
/// - AsyncNotifier for stateful operations
/// - Dependency injection (service gets logger via DI)
/// - Result<T,E> transformation to AsyncValue
/// 
/// WHY AsyncNotifier: We need the refresh() method for manual updates.
/// A simple FutureProvider wouldn't give us mutation capability.
/// 
/// Testing: Override screenServiceProvider with FakeScreenService
/// to test all scenarios including errors.
@Riverpod(keepAlive: true)
class Displays extends _$Displays {
  @override
  FutureOr<List<Display>> build() async {
    // Get the service (with logger already injected via DI)
    final service = ref.watch(screenServiceProvider);
    
    // Query displays from platform
    final result = await service.getDisplays();
    
    // Transform Result to exception (AsyncNotifier pattern)
    return result.fold(
      (displays) => displays,
      (failure) => throw failure,
    );
  }
  
  /// Manually refresh the display list
  Future<void> refresh() async {
    state = const AsyncLoading();
    // Give the UI a chance to render the loading state
    await Future<void>.delayed(Duration.zero);
    // Re-run build() by invalidating self; let Riverpod manage the future
    ref.invalidateSelf();
    // Await the new computation to finish, ignoring thrown errors since
    // AsyncNotifier will reflect them in `state` as AsyncError
    try {
      await future;
    } catch (_) {
      // no-op: state already updated to AsyncError
    }
  }
  
  /// Get a specific display by ID
  Future<Display> getDisplay(String displayId) async {
    final service = ref.read(screenServiceProvider);
    final result = await service.getDisplay(displayId);
    
    return result.fold(
      (display) => display,
      (failure) => throw failure,
    );
  }
  
  /// Get the primary display
  Future<Display> getPrimaryDisplay() async {
    final service = ref.read(screenServiceProvider);
    final result = await service.getPrimaryDisplay();
    
    return result.fold(
      (display) => display,
      (failure) => throw failure,
    );
  }
}
