# Canonical Riverpod Implementation Plan: Display Detection

## Executive Summary

Transform the current display detection implementation into THE canonical example of Riverpod architecture for Goodbar. This implementation will establish patterns for all future features and must demonstrate every architectural principle from `docs/rules/riverpod.md`.

## Current State Analysis

### What We Have
-  Working display detection via MethodChannel
-  MacOSScreenService with logger injection
-  Result pattern (using freezed)
-  FakeScreenService for testing
-  Native Swift implementation working
- L Direct service instantiation in widgets
- L StatefulWidget with setState
- L No DI/provider pattern
- L No stream subscription for display changes
- L Limited test coverage

### Critical Success Factors
1. **Exemplary Code**: Every line must be production-quality and copyable
2. **Complete Testing**: Unit, widget, integration, and HowTo tests
3. **Performance**: Demonstrate select() and optimization patterns
4. **Documentation**: Inline comments explaining WHY (not what)
5. **Error Handling**: Show all error scenarios properly handled

---

## Implementation Phases

## Phase 1: Infrastructure Setup (30 min)

| Task | File | Status | Notes |
|------|------|--------|-------|
| 1.1 Add dependencies | `pubspec.yaml` | [ ] | result_dart, riverpod_annotation, etc. |
| 1.2 Configure linting | `analysis_options.yaml` | [ ] | custom_lint with riverpod_lint |
| 1.3 Update justfile | `justfile` | [ ] | gen, gen:watch, lint:riverpod commands |
| 1.4 Run initial codegen | - | [ ] | `just gen` to verify setup |

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

## Phase 2: Migrate Error Handling (45 min)

| Task | File | Status | Notes |
|------|------|--------|-------|
| 2.1 Create failure types | `lib/src/core/failures/screen_failures.dart` | [ ] | Sealed class hierarchy |
| 2.2 Update ScreenService | `lib/src/services/screen/screen_service.dart` | [ ] | Use result_dart Result |
| 2.3 Update MacOSScreenService | `lib/src/services/screen/macos_screen_service.dart` | [ ] | Success/Failure returns |
| 2.4 Update FakeScreenService | `lib/src/services/screen/fake_screen_service.dart` | [ ] | Test scenarios |

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

## Phase 3: Service Layer DI (30 min)

| Task | File | Status | Notes |
|------|------|--------|-------|
| 3.1 Create service providers | `lib/src/bootstrap/services.dart` | [ ] | @Riverpod(keepAlive: true) |
| 3.2 Add provider observer | `lib/src/bootstrap/observers.dart` | [ ] | Debug logging |
| 3.3 Run codegen | - | [ ] | Generate .g.dart files |
| 3.4 Verify generation | - | [ ] | Check services.g.dart created |

### 3.1 Service Provider Pattern
```dart
@Riverpod(keepAlive: true)
ScreenService screenService(ScreenServiceRef ref) {
  final logger = ref.watch(loggerProvider('ScreenService'));
  return MacOSScreenService(logger: logger);
}
```

---

## Phase 4: Display Feature with AsyncNotifier (1 hour)

| Task | File | Status | Notes |
|------|------|--------|-------|
| 4.1 Create feature structure | `lib/src/features/displays/` | [ ] | providers/, widgets/, models/ |
| 4.2 Displays AsyncNotifier | `.../providers/displays_provider.dart` | [ ] | Main state management |
| 4.3 Selected display provider | `.../providers/selected_display_provider.dart` | [ ] | UI selection state |
| 4.4 Main screen widget | `.../widgets/displays_screen.dart` | [ ] | Replace TestDisplayDetection |
| 4.5 Display card widget | `.../widgets/display_card.dart` | [ ] | Individual display UI |
| 4.6 Display list widget | `.../widgets/display_list.dart` | [ ] | List composition |
| 4.7 Error view widget | `.../widgets/display_error_view.dart` | [ ] | Error states |
| 4.8 Run codegen | - | [ ] | Generate provider code |

### 4.2 AsyncNotifier Pattern
```dart
@riverpod
class Displays extends _$Displays {
  StreamSubscription<DisplayChangeEvent>? _subscription;
  
  @override
  FutureOr<List<Display>> build() async {
    final service = ref.watch(screenServiceProvider);
    final result = await service.getDisplays();
    
    // Subscribe to changes
    _subscription?.cancel();
    _subscription = service.displayChanges().listen((_) => _refresh());
    
    // Cleanup
    ref.onDispose(() {
      _subscription?.cancel();
    });
    
    return result.fold(
      (displays) => displays,
      (failure) => throw failure,
    );
  }
  
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

### 4.3 Cross-Provider Synchronization
```dart
@riverpod
class SelectedDisplay extends _$SelectedDisplay {
  @override
  String? build() {
    // React to display removal
    ref.listen(displaysProvider, (previous, next) {
      next.whenData((displays) {
        if (state != null && !displays.any((d) => d.id == state)) {
          state = null;
        }
      });
    });
    
    return null;
  }
  
  void select(String? displayId) {
    state = displayId;
  }
}
```

### 4.5 Performance Optimization with select()
```dart
class DisplayCard extends ConsumerWidget {
  final Display display;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuild when selection state changes
    final isSelected = ref.watch(
      selectedDisplayProvider.select((selected) => selected == display.id),
    );
    
    return Card(
      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      // ... rest of UI
    );
  }
}
```

---

## Phase 5: Testing Infrastructure (1.5 hours)

| Task | File | Status | Notes |
|------|------|--------|-------|
| 5.1 Unit tests | `test/features/displays/providers/displays_provider_test.dart` | [ ] | ProviderContainer tests |
| 5.2 Widget tests | `test/features/displays/widgets/displays_screen_test.dart` | [ ] | UI state tests |
| 5.3 Integration test | `integration_test/displays_integration_test.dart` | [ ] | Real platform test |
| 5.4 HowTo test | `test/howto/display_detection_workflow_test.dart` | [ ] | Executable documentation |
| 5.5 Test helpers | `test/helpers/test_displays.dart` | [ ] | Shared test data |
| 5.6 Flutter test config | `test/flutter_test_config.dart` | [ ] | Font loading for goldens |

### 5.1 Unit Test Pattern
```dart
void main() {
  group('DisplaysProvider', () {
    late ProviderContainer container;
    late FakeScreenService fakeService;
    
    setUp(() {
      fakeService = FakeScreenService();
      container = ProviderContainer(
        overrides: [
          screenServiceProvider.overrideWithValue(fakeService),
        ],
      );
    });
    
    tearDown(() {
      container.dispose();
    });
    
    test('loads displays on initialization', () async {
      fakeService.setDisplays(testDisplays);
      
      final subscription = container.listen(displaysProvider, (_, __) {});
      await container.pump();
      
      expect(container.read(displaysProvider).requireValue, testDisplays);
      subscription.close();
    });
    
    test('handles platform failure gracefully', () async {
      fakeService.setFailure(PlatformChannelFailure('Connection lost'));
      
      final subscription = container.listen(displaysProvider, (_, __) {});
      await container.pump();
      
      expect(container.read(displaysProvider).hasError, isTrue);
      expect(
        container.read(displaysProvider).error,
        isA<PlatformChannelFailure>(),
      );
      subscription.close();
    });
    
    test('refreshes on display change event', () async {
      fakeService.setDisplays([display1]);
      
      final subscription = container.listen(displaysProvider, (_, __) {});
      await container.pump();
      expect(container.read(displaysProvider).requireValue.length, 1);
      
      // Simulate display change
      fakeService.emitDisplayChange([display1, display2]);
      await container.pump();
      
      expect(container.read(displaysProvider).requireValue.length, 2);
      subscription.close();
    });
  });
}
```

### 5.4 HowTo Test (Executable Documentation)
```dart
/// Demonstrates the complete display detection workflow using Riverpod.
/// This test serves as executable documentation for the canonical pattern.
void main() {
  group('Display Detection Workflow - Canonical Riverpod Pattern', () {
    test('complete workflow with DI, streaming, and error handling', () async {
      // === SETUP: Dependency Injection ===
      // Shows how to override services for testing
      final fakeService = FakeScreenService(displays: []);
      final container = ProviderContainer(
        overrides: [
          screenServiceProvider.overrideWithValue(fakeService),
        ],
      );
      
      // === INITIAL STATE ===
      // AsyncNotifier starts in loading state
      expect(container.read(displaysProvider).isLoading, isTrue);
      
      // === INITIALIZATION ===
      // After build() completes, displays are loaded
      await container.pump();
      expect(container.read(displaysProvider).hasValue, isTrue);
      expect(container.read(displaysProvider).requireValue, isEmpty);
      
      // === REACTIVE UPDATES ===
      // Display changes are reflected automatically via stream subscription
      fakeService.addDisplay(createTestDisplay('1'));
      await container.pump();
      expect(container.read(displaysProvider).requireValue.length, 1);
      
      // === ERROR HANDLING ===
      // Services return Result<T,E>, providers transform to AsyncError
      fakeService.setFailure(PlatformChannelFailure('Connection lost'));
      await container.read(displaysProvider.notifier).refresh();
      await container.pump();
      
      expect(container.read(displaysProvider).hasError, isTrue);
      expect(
        container.read(displaysProvider).error,
        isA<PlatformChannelFailure>(),
      );
      
      // === ERROR RECOVERY ===
      // Errors can be cleared and state recovered
      fakeService.clearFailure();
      fakeService.setDisplays([createTestDisplay('1'), createTestDisplay('2')]);
      
      // Two ways to recover:
      // 1. Call refresh() method
      await container.read(displaysProvider.notifier).refresh();
      await container.pump();
      expect(container.read(displaysProvider).hasValue, isTrue);
      
      // 2. Or invalidate the provider
      container.invalidate(displaysProvider);
      await container.pump();
      expect(container.read(displaysProvider).requireValue.length, 2);
      
      // === SELECTION STATE ===
      // Cross-provider communication via ref.listen
      container.read(selectedDisplayProvider.notifier).select('1');
      expect(container.read(selectedDisplayProvider), '1');
      
      // When display is removed, selection is cleared
      fakeService.setDisplays([createTestDisplay('2')]);
      await container.pump();
      expect(container.read(selectedDisplayProvider), isNull);
      
      // === CLEANUP ===
      container.dispose();
      
      /// This test demonstrates:
      /// 1. Dependency injection via provider overrides
      /// 2. AsyncNotifier lifecycle and state management
      /// 3. Reactive stream handling with automatic updates
      /// 4. Functional error handling with Result<T,E>
      /// 5. Error recovery patterns
      /// 6. Cross-provider synchronization
      /// 7. Testing with ProviderContainer
    });
  });
}
```

---

## Phase 6: Update Main App (15 min)

| Task | File | Status | Notes |
|------|------|--------|-------|
| 6.1 Update main.dart | `lib/main.dart` | [ ] | Use DisplaysScreen |
| 6.2 Remove old widget | `lib/src/test_display_detection.dart` | [ ] | Delete file |
| 6.3 Test app startup | - | [ ] | `just run-macos` |
| 6.4 Verify hot reload | - | [ ] | Test development experience |

### 6.1 Main App Structure
```dart
void main() {
  final rootLog = AppLogger(appName: 'goodbar', fileName: 'app.log');
  
  FlutterError.onError = (details) {
    rootLog.e('FlutterError', details.exception, details.stack);
  };
  
  runApp(
    ProviderScope(
      overrides: [
        loggerRootProvider.overrideWithValue(rootLog),
      ],
      observers: kDebugMode ? [RiverpodLogger()] : [],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goodbar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DisplaysScreen(),
    );
  }
}
```

---

## Phase 7: Performance & Observability (30 min)

| Task | File | Status | Notes |
|------|------|--------|-------|
| 7.1 Add ProviderObserver | `lib/src/bootstrap/observers.dart` | [ ] | Debug logging |
| 7.2 Implement select() patterns | Various widgets | [ ] | Minimize rebuilds |
| 7.3 Add performance metrics | `.../providers/display_metrics_provider.dart` | [ ] | Monitor performance |
| 7.4 Test performance | - | [ ] | Verify optimizations |

### 7.1 Provider Observer for Debugging
```dart
class RiverpodLogger extends ProviderObserver {
  final _updateCounts = <String, int>{};
  
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    final name = provider.name ?? provider.runtimeType.toString();
    _updateCounts[name] = (_updateCounts[name] ?? 0) + 1;
    
    if (kDebugMode) {
      print('[$name] Update #${_updateCounts[name]}: $newValue');
    }
    
    // Warn on excessive updates
    if (_updateCounts[name]! > 100) {
      print('  Provider $name has updated ${_updateCounts[name]} times');
    }
  }
  
  @override
  void providerDidFail(
    ProviderBase provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    print('L Provider ${provider.name} failed: $error');
  }
}
```

---

## Phase 8: Documentation (30 min)

| Task | File | Status | Notes |
|------|------|--------|-------|
| 8.1 Update CLAUDE.md | `CLAUDE.md` | [ ] | Reference canonical example |
| 8.2 Inline documentation | All new files | [ ] | Explain WHY, not what |
| 8.3 Create ADR | `docs/adrs/003-riverpod-patterns.md` | [ ] | Document decisions |
| 8.4 Update README | `README.md` | [ ] | Note test commands |

### 8.2 Documentation Standards
```dart
/// Manages display detection state for the application.
/// 
/// This provider demonstrates the canonical Riverpod pattern for Goodbar:
/// - AsyncNotifier for complex stateful operations
/// - Stream subscription with proper cleanup
/// - Result<T,E> transformation to AsyncValue
/// - Reactive updates via displayChanges stream
/// 
/// WHY AsyncNotifier: We need to manage a stream subscription and provide
/// mutation methods (refresh). FutureProvider wouldn't give us the lifecycle
/// hooks or mutation capability we need.
/// 
/// Testing: Override screenServiceProvider with FakeScreenService
/// to test all scenarios including errors and stream updates.
@riverpod
class Displays extends _$Displays {
  // Implementation...
}
```

---

## Success Criteria Checklist

### Architecture (from docs/rules/riverpod.md)
- [ ] All services injected via providers
- [ ] Layer separation maintained (UI ’ Providers ’ Services ’ Platform)
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
lib/src/
   core/failures/screen_failures.dart
   bootstrap/
      services.dart
      observers.dart
   features/displays/
       providers/
          displays_provider.dart
          selected_display_provider.dart
          display_metrics_provider.dart
       widgets/
           displays_screen.dart
           display_card.dart
           display_list.dart
           display_error_view.dart

test/
   features/displays/
      providers/
         displays_provider_test.dart
      widgets/
          displays_screen_test.dart
   howto/
      display_detection_workflow_test.dart
   helpers/
      test_displays.dart
   flutter_test_config.dart

integration_test/
   displays_integration_test.dart
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

## Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Infrastructure | 30 min | 30 min |
| Phase 2: Error Handling | 45 min | 1h 15m |
| Phase 3: Service DI | 30 min | 1h 45m |
| Phase 4: AsyncNotifier | 1 hour | 2h 45m |
| Phase 5: Testing | 1.5 hours | 4h 15m |
| Phase 6: Main App | 15 min | 4h 30m |
| Phase 7: Performance | 30 min | 5h |
| Phase 8: Documentation | 30 min | 5h 30m |
| **Total** | **5.5 hours** | - |

---

## Notes

1. **Code Generation**: Run `just gen:watch` during development for automatic regeneration
2. **Testing Strategy**: Write tests alongside implementation, not after
3. **Performance**: Use select() from the start, don't optimize later
4. **Documentation**: Document WHY decisions were made, not just what the code does
5. **Error Handling**: Every Result must be handled explicitly - no silent failures

---

## References

- [docs/rules/riverpod.md](../../rules/riverpod.md) - Canonical Riverpod patterns
- [docs/rules/service-layer.md](../../rules/service-layer.md) - Service layer architecture
- [docs/rules/rules-idioms-architecture.md](../../rules/rules-idioms-architecture.md) - Overall architecture

---

*This plan establishes the canonical Riverpod implementation for Goodbar. Every future feature should reference this implementation as the standard.*