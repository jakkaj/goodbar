Below is a *complete, up‑to‑date* testing playbook for Flutter 3.x (macOS desktop) using **Riverpod 2.x + codegen (@riverpod)**, **Freezed 3.x**, and **result\_dart**, with notes for Riverpod 3.0 where it meaningfully changes testing ergonomics. It includes runnable examples (unit, widget, integration), helpers, CI, and pitfalls to avoid.

---

## 0) TL;DR — What "good" looks like

* **Unit tests**: use `ProviderContainer` with `overrides` to inject fakes; call the `notifier` and assert `AsyncValue` transitions. Add `addTearDown(container.dispose)`. ([Riverpod][1])
* **Widget tests**: wrap under `ProviderScope(overrides: [...])`, assert `AsyncValue.when(...)` branches, and test UI-driven calls to `.notifier` methods. ([Riverpod][1])
* **Integration tests (desktop)**: use the **integration\_test** package against the **real** services and platform channels, and run on the macOS device with `flutter test integration_test -d macos`. ([Flutter Docs][2])
* **Golden tests (desktop)**: prefer **Alchemist** for CI‑stable goldens (fonts/text normalized) or use **golden\_toolkit** with fonts loaded. ([GitHub][3])
* **Freezed**: test equality, `copyWith`, and JSON with simple expectations; generation via `build_runner`.
* **result\_dart**: convert `Result<T, Failure>` ↔ `AsyncValue<T>` at provider boundaries (prefer `AsyncValue.guard`). ([Dart packages][4], [Code With Andrea][5])
* **Test Quality**: Avoid "happy path testing" — verify correctness, completeness, relationships, not just existence
* **Tests as Documentation**: Every test must explain its Purpose, Quality Contribution, and Acceptance Criteria

---

## 0.1) Test Quality Assertions — Correctness Over Existence

**Avoid "happy path testing" anti‑pattern.** Always test for correctness and completeness, not just existence. Verify that data contains expected values, relationships, and patterns rather than merely checking if data exists.

```dart
// ❌ BAD - Only tests existence
test('loads displays from service', () async {
  final displays = await provider.getDisplays();
  expect(displays.isNotEmpty, true); // Too weak!
});

// ✅ GOOD - Tests correctness
test('loads displays with complete metadata', () async {
  final displays = await provider.getDisplays();
  
  // Verify specific expected displays
  expect(displays.length, 3);
  expect(displays[0].isPrimary, true);
  expect(displays[0].id, '1');
  expect(displays[0].scaleFactor, 2.0);
  
  // Verify relationships between data
  final primaryCount = displays.where((d) => d.isPrimary).length;
  expect(primaryCount, 1, reason: 'Exactly one primary display');
  
  // Verify display arrangement
  for (final display in displays) {
    expect(display.width, greaterThan(0));
    expect(display.height, greaterThan(0));
    expect(display.workArea.width, lessThanOrEqualTo(display.bounds.width),
        reason: 'Work area cannot exceed display bounds');
  }
});
```

## 0.2) Tests as Executable Documentation

**Always include detailed documentation comments** explaining why each test is needed and how it contributes to system quality. Treat these comments as acceptance criteria that validate the test truly solves the intended problem.

```dart
test('handles platform channel failure gracefully', () async {
  /// Purpose: Ensure the app doesn't crash when platform communication fails
  /// 
  /// Quality Contribution: Maintains app stability even when native layer is unavailable,
  /// allowing graceful degradation instead of crashes
  /// 
  /// Acceptance Criteria: Provider must transition to AsyncError with proper error message,
  /// UI must show retry option, and recovery must work after failure clears
  
  final service = FakeScreenService();
  service.setFailure(PlatformChannelFailure('Connection lost'));
  
  final container = ProviderContainer(
    overrides: [screenServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  
  // Verify error propagation
  await expectLater(
    container.read(displaysProvider.future),
    throwsA(isA<PlatformChannelFailure>()),
  );
  
  // Verify error state
  final state = container.read(displaysProvider);
  expect(state.hasError, true);
  expect(state.error.toString(), contains('Connection lost'));
  
  // Verify recovery
  service.clearFailure();
  await container.read(displaysProvider.notifier).refresh();
  
  final recovered = container.read(displaysProvider);
  expect(recovered.hasValue, true);
  expect(recovered.requireValue.length, 3);
});

test('display detection workflow demonstrates DI patterns', () async {
  /// Compelling Use Case: Developer needs to understand how Riverpod DI works
  /// with AsyncValue state management in a real scenario
  /// 
  /// This test demonstrates:
  /// 1. Provider override patterns for testing
  /// 2. AsyncValue state transitions
  /// 3. Error handling and recovery
  /// 4. Multi-display detection
  /// 
  /// Real-world scenario: App needs to detect and track multiple displays,
  /// handle disconnections gracefully, and provide clear feedback to users
  
  // Setup shows DI pattern
  final service = FakeScreenService();
  final container = ProviderContainer(
    overrides: [
      screenServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  
  // Track state transitions demonstrates observability
  final states = <AsyncValue<List<Display>>>[];
  container.listen(displaysProvider, (_, next) => states.add(next));
  
  // Initial load shows async pattern
  await container.read(displaysProvider.future);
  expect(states, [
    isA<AsyncLoading>(),
    isA<AsyncData>().having((s) => s.value.length, 'display count', 3),
  ]);
  
  // Error simulation shows resilience
  service.setFailure(PlatformChannelFailure('Network error'));
  await container.read(displaysProvider.notifier).refresh();
  
  expect(states.last, isA<AsyncError>()
    .having((s) => s.error.toString(), 'error', contains('Network error')));
  
  // Recovery shows proper error handling
  service.clearFailure();
  await container.read(displaysProvider.notifier).refresh();
  
  expect(states.last, isA<AsyncData>()
    .having((s) => s.value.length, 'display count', 3));
});
```

### Key Documentation Patterns

1. **Purpose**: What specific problem does this test solve?
2. **Quality Contribution**: How does this test improve system reliability/usability?
3. **Acceptance Criteria**: What must be true for this test to pass?
4. **Compelling Use Case**: For HowTo tests, what real-world scenario does this demonstrate?
5. **Real-world Scenario**: Explain the practical context where this behavior matters

---

## 1) Minimal working example (models, services, providers)

> Files shown are small and self‑contained so you can paste them into a sample app.

### `pubspec.yaml` (relevant parts)

```yaml
environment:
  sdk: ">=3.4.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1        # Riverpod 2.x runtime
  riverpod_annotation: ^2.3.5
  freezed_annotation: ^3.0.0
  result_dart: ^1.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  build_runner: ^2.4.13
  riverpod_generator: ^2.4.3
  freezed: ^3.0.2
  golden_toolkit: ^0.15.0         # or:
  alchemist: ^0.12.1
  custom_lint: ^0.7.5
  riverpod_lint: ^2.3.13
```

Enable lints (root `analysis_options.yaml`):

```yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  plugins:
    - custom_lint
```

Riverpod’s lint pack strengthens correctness and refactors (enable by adding `riverpod_lint` + `custom_lint`). ([Riverpod][6], [Dart packages][7])

---

### `lib/core/failure.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'failure.freezed.dart';
part 'failure.g.dart';

@freezed
class Failure with _$Failure {
  const factory Failure.unexpected({String? message}) = UnexpectedFailure;
  const factory Failure.network({String? message}) = NetworkFailure;

  factory Failure.fromJson(Map<String, dynamic> json) => _$FailureFromJson(json);
}
```

### `lib/system_info/system_info.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'system_info.freezed.dart';
part 'system_info.g.dart';

@freezed
class SystemInfo with _$SystemInfo {
  const factory SystemInfo({required String osVersion}) = _SystemInfo;

  factory SystemInfo.fromJson(Map<String, dynamic> json) => _$SystemInfoFromJson(json);
}
```

### `lib/system_info/system_info_service.dart`

```dart
import 'package:flutter/services.dart';
import 'package:result_dart/result_dart.dart';
import '../core/failure.dart';
import 'system_info.dart';

abstract interface class SystemInfoService {
  Future<Result<SystemInfo, Failure>> readOsVersion();
}

/// Real implementation using a platform channel (see macOS Swift below).
class MethodChannelSystemInfoService implements SystemInfoService {
  static const _channel = MethodChannel('app.system_info');
  @override
  Future<Result<SystemInfo, Failure>> readOsVersion() async {
    try {
      final version = await _channel.invokeMethod<String>('getOsVersion');
      if (version == null || version.isEmpty) {
        return Failure.unexpected(message: 'Empty version').toFailure();
      }
      return SystemInfo(osVersion: version).toSuccess();
    } on PlatformException catch (e) {
      return Failure.unexpected(message: e.message).toFailure();
    }
  }
}
```

Platform channel guidance (how/where to put macOS Swift code) is in Flutter’s official docs. We’ll add the macOS code in **Section 4**. ([Flutter Docs][8])

### `lib/system_info/system_info_providers.dart`

```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:result_dart/result_dart.dart';
import '../core/failure.dart';
import 'system_info.dart';
import 'system_info_service.dart';

part 'system_info_providers.g.dart';

@riverpod
SystemInfoService systemInfoService(SystemInfoServiceRef ref) =>
    MethodChannelSystemInfoService();

@riverpod
class SystemInfoController extends _$SystemInfoController {
  @override
  FutureOr<SystemInfo> build() async {
    final svc = ref.watch(systemInfoServiceProvider);
    final res = await svc.readOsVersion();
    // Convert Result<T, Failure> -> value or throw (to surface AsyncError).
    return res.fold((ok) => ok, (err) => throw err);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await ref.read(systemInfoServiceProvider).readOsVersion();
      return res.fold((ok) => ok, (err) => throw err);
    });
  }
}
```

`AsyncValue.guard` is the idiomatic way to produce `AsyncData/AsyncError` from an async operation inside an `AsyncNotifier`. ([Code With Andrea][5])

Run code generation before tests/builds:

```bash
dart run build_runner build -d
```

Riverpod codegen and Freezed both rely on `build_runner`. ([Riverpod][9], [GitHub][10])

---

### `lib/system_info/system_info_screen.dart` (sample UI)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'system_info_providers.dart';

class SystemInfoScreen extends ConsumerWidget {
  const SystemInfoScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemInfoControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Info'),
        actions: [
          IconButton(
            key: const Key('refresh'),
            onPressed: () => ref.read(systemInfoControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: state.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', key: const Key('error-text')),
              const SizedBox(height: 8),
              ElevatedButton(
                key: const Key('retry'),
                onPressed: () => ref.read(systemInfoControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (info) => Text('OS: ${info.osVersion}', key: const Key('data-text')),
        ),
      ),
    );
  }
}
```

---

## 2) Provider Testing (Riverpod 2.x today; 3.0 notes inline)

**Key patterns**

* Create a `ProviderContainer(overrides: [...])`, read/watch providers, and **dispose** in teardown.
* Override dependencies via `provider.overrideWith(...)` or `overrideWithValue(...)`.
* Use `container.listen` to track state transitions.
* In Riverpod **3.0**, you get convenience helpers:

  * `ProviderContainer.test()` auto‑disposes after the test, and
  * `WidgetTester.container` to grab the container in widget tests. ([Riverpod][1])

> Below tests demonstrate **initial build**, **state mutation**, **error handling**, and **disposal**.

### `test/unit/system_info_provider_test.dart`

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:result_dart/result_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/system_info/system_info.dart';
import 'package:your_app/core/failure.dart';
import 'package:your_app/system_info/system_info_service.dart';
import 'package:your_app/system_info/system_info_providers.dart';

class FakeSvc implements SystemInfoService {
  FakeSvc(this._queue);
  final Queue<Result<SystemInfo, Failure>> _queue;
  @override
  Future<Result<SystemInfo, Failure>> readOsVersion() async => _queue.removeFirst();
}

void main() {
  test('build() loads data (initial AsyncLoading -> AsyncData)', () async {
    final svc = FakeSvc(Queue()
      ..add(SystemInfo(osVersion: 'macOS 14.5').toSuccess()));
    final container = ProviderContainer(overrides: [
      systemInfoServiceProvider.overrideWith((ref) => svc),
    ]);
    addTearDown(container.dispose);

    // Before awaiting, reading .future triggers build
    final future = container.read(systemInfoControllerProvider.future);
    // Optionally, assert transient loading
    expect(container.read(systemInfoControllerProvider), isA<AsyncLoading>());

    final info = await future;
    expect(info.osVersion, 'macOS 14.5');
    expect(container.read(systemInfoControllerProvider).hasValue, true);
  });

  test('refresh() updates state', () async {
    final svc = FakeSvc(Queue()
      ..add(SystemInfo(osVersion: '14.4').toSuccess())
      ..add(SystemInfo(osVersion: '14.5').toSuccess()));
    final container = ProviderContainer(overrides: [
      systemInfoServiceProvider.overrideWith((ref) => svc),
    ]);
    addTearDown(container.dispose);

    final first = await container.read(systemInfoControllerProvider.future);
    expect(first.osVersion, '14.4');

    await container.read(systemInfoControllerProvider.notifier).refresh();
    final state = container.read(systemInfoControllerProvider);
    expect(state.requireValue.osVersion, '14.5');
  });

  test('error bubbles as AsyncError', () async {
    final svc = FakeSvc(Queue()
      ..add(Failure.unexpected(message: 'boom').toFailure()));
    final container = ProviderContainer(overrides: [
      systemInfoServiceProvider.overrideWith((ref) => svc),
    ]);
    addTearDown(container.dispose);

    try {
      await container.read(systemInfoControllerProvider.future);
      fail('expected failure');
    } catch (_) {}
    final state = container.read(systemInfoControllerProvider);
    expect(state.hasError, true);
  });

  test('disposal runs cleanup hooks', () async {
    var disposed = false;
    // Override controller to register onDispose
    final container = ProviderContainer(overrides: [
      systemInfoControllerProvider.overrideWith(
        (ref) {
          ref.onDispose(() => disposed = true);
          // mimic original build
          return Future.value(SystemInfo(osVersion: 'x'));
        },
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(systemInfoControllerProvider.future);
    container.dispose();
    expect(disposed, true);
  });
}
```

**Notes**

* Use `overrideWithValue` for simple constant instances; use `overrideWith((ref) => ...)` when you need access to `ref` or to construct lazily. ([Riverpod][11])
* In Riverpod **3.0** you may simplify container creation with `ProviderContainer.test()` and disable retries globally (`retry: (_, __) => null`) while testing to avoid exponential backoff delays. ([Riverpod][1])

**Dependent providers & streams**

* For providers that `ref.watch` other providers, override the **leaf** dependencies (services/repositories) and test the composed behavior exactly as shown above. This is the canonical pattern per Riverpod docs. ([Riverpod][11])
* For stream‑based providers (`StreamProvider` or `StreamNotifier`), feed a `StreamController` in your fake and assert emitted `AsyncValue` sequences with `container.listen` and a buffer list.

---

## 3) Widget Testing patterns

**Key points**

* Wrap your widget under `ProviderScope(overrides: [...])` to inject fakes.
* Interact with the UI to exercise provider logic; assert `.when` branches (loading/error/data).
* For accessibility assertions, use the Flutter **Accessibility Guidelines API** or `SemanticsTester`/finders if relevant to your app. ([Flutter Docs][12], [Flutter API Docs][13])

### `test/widget/system_info_screen_test.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:result_dart/result_dart.dart';
import 'package:your_app/system_info/system_info_screen.dart';
import 'package:your_app/system_info/system_info.dart';
import 'package:your_app/system_info/system_info_service.dart';
import 'package:your_app/system_info/system_info_providers.dart';
import 'package:your_app/core/failure.dart';

class ToggleSvc implements SystemInfoService {
  ToggleSvc(this.firstError);
  bool firstError;
  @override
  Future<Result<SystemInfo, Failure>> readOsVersion() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (firstError) {
      firstError = false;
      return Failure.unexpected(message: 'boom').toFailure();
    }
    return const SystemInfo(osVersion: 'macOS 14.5').toSuccess();
  }
}

Widget _wrap(ProviderOverride override) => ProviderScope(
      overrides: [override],
      child: const MaterialApp(home: SystemInfoScreen()),
    );

void main() {
  testWidgets('shows loading then data', (tester) async {
    final svc = ToggleSvc(false);
    await tester.pumpWidget(_wrap(
      systemInfoServiceProvider.overrideWith((_) => svc),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('data-text')), findsOneWidget);
    expect(find.textContaining('macOS'), findsOneWidget);
  });

  testWidgets('shows error then recovers on retry', (tester) async {
    final svc = ToggleSvc(true); // first call fails, second succeeds
    await tester.pumpWidget(_wrap(
      systemInfoServiceProvider.overrideWith((_) => svc),
    ));

    // Initial load -> fails
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error-text')), findsOneWidget);

    // Retry via button -> success
    await tester.tap(find.byKey(const Key('retry')));
    await tester.pump(); // start refresh
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('data-text')), findsOneWidget);
  });

  testWidgets('app bar refresh triggers provider.refresh()', (tester) async {
    final svc = ToggleSvc(false);
    await tester.pumpWidget(_wrap(
      systemInfoServiceProvider.overrideWith((_) => svc),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('refresh')));
    await tester.pump(); // loading visible
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

**Goldens on desktop**

* With **golden\_toolkit**, call `loadAppFonts()` and standardize sizes; but goldens may still differ across OS due to font rasterization.
* **Alchemist** generates “CI‑stable” goldens by replacing text with blocks (and even emits a secondary macOS‑specific golden to keep local DX nice). Recommended for multi‑OS CI. ([GitHub][3], [Dart packages][14])

Example with Alchemist:

```dart
// test/goldens/system_info_screen_golden_test.dart
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:your_app/system_info/system_info_screen.dart';
import 'package:your_app/system_info/system_info_providers.dart';
import 'package:your_app/system_info/system_info_service.dart';
import 'package:result_dart/result_dart.dart';
import 'package:your_app/system_info/system_info.dart';

class _OkSvc implements SystemInfoService {
  @override
  Future<Result<SystemInfo, Object>> readOsVersion() async =>
      const SystemInfo(osVersion: 'macOS 14.5').toSuccess();
}

void main() {
  goldenTest(
    'SystemInfoScreen default',
    fileName: 'system_info_screen',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'data',
          child: ProviderScope(
            overrides: [
              systemInfoServiceProvider.overrideWith((_) => _OkSvc()),
            ],
            child: const MaterialApp(home: SystemInfoScreen()),
          ),
        ),
      ],
    ),
  );
}
```

---

## 4) Integration testing (real services & macOS platform channel)

**Flutter side (Dart)**

```dart
// integration_test/system_info_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:your_app/system_info/system_info_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full flow uses real platform channel', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SystemInfoScreen())),
    );

    // First frame: likely loading
    await tester.pump(const Duration(milliseconds: 50));
    // Wait for native call to resolve
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // We don't assert a specific string, only that we got a non-empty OS.
    expect(find.byKey(const Key('data-text')), findsOneWidget);
  });
}
```

**macOS host code (Swift)**

Add to `macos/Runner/MainFlutterWindow.swift` (channel name must match Dart):

```swift
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let channel = FlutterMethodChannel(
      name: "app.system_info",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getOsVersion":
        // e.g., "Version 14.5 (Build ...)"
        result(ProcessInfo.processInfo.operatingSystemVersionString)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}
```

Flutter’s official platform channel documentation shows where to put macOS code (`MainFlutterWindow.swift`) and how to wire `FlutterMethodChannel`. ([Flutter Docs][8])

**Run the test on macOS desktop:**

```bash
flutter test integration_test -d macos
```

The **integration\_test** docs cover desktop targets and the recommended command structure. ([Flutter Docs][2])

**Test data setup/teardown**
Use `setUpAll/tearDownAll` to create/remove files, temporary directories (`dart:io`), or seed application state. Keep these *outside* widget frames to avoid pump race conditions.

---

## 5) Testing with code generation (Freezed + codegen workflow)

* Keep `*.freezed.dart`, `*.g.dart`, and Riverpod `*.g.dart` out of VCS if your team prefers generated sources to be ephemeral; otherwise commit for faster CI.
* In CI **before tests**: `dart run build_runner build -d` (or `watch` locally). ([Riverpod][9])

**Model tests (Freezed)**

```dart
// test/unit/system_info_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/system_info/system_info.dart';

void main() {
  test('equality and copyWith', () {
    const a = SystemInfo(osVersion: '14.5');
    final b = a.copyWith(osVersion: '14.6');
    expect(a, isNot(b));
    expect(a.osVersion, '14.5');
    expect(b.osVersion, '14.6');
  });
}
```

Freezed guarantees value equality and `copyWith`; JSON helpers require `part '*.g.dart'` and a `@Freezed` class.

---

## 6) Error handling — `Result<T, Failure>` ↔ `AsyncValue<T>`

**Canonical conversion**

```dart
// From Result -> AsyncValue via guard:
state = await AsyncValue.guard(() async {
  final res = await service.call();
  return res.fold((ok) => ok, (err) => throw err);
});

// From AsyncValue -> Result (if needed in a lower layer)
Result<T, Failure> toResult(AsyncValue<T> v) => switch (v) {
  AsyncData(:final value) => value.toSuccess(),
  AsyncError(:final error) => (error as Failure).toFailure(),
  _ => Failure.unexpected(message: 'loading').toFailure(),
};
```

`ResultDart` exposes `.fold`, `.map`, `.mapError`, etc., to transform results; using `AsyncValue.guard` is cleaner than manual try/catch in `AsyncNotifier`. ([Dart packages][4], [Code With Andrea][5])

---

## 7) Practical Examples (requested)

### 7.1 Unit test (AsyncNotifier provider) — **done above**

* **Initial build**: `read(provider.future)`
* **State mutation**: `notifier.refresh()`
* **Error handling**: throw `Failure` → `AsyncError`
* **Disposal**: `ref.onDispose` and `container.dispose()`

### 7.2 Widget test with overrides — **done above**

* Asserts loading/error/data; simulates retry; exercises UI → provider methods.

### 7.3 Integration test (full flow) — **done above**

* Uses the real service and real platform channel; navigates and preserves state across screens (add an extra screen/push/pop as needed).

### 7.4 Test helpers/utilities

```dart
// test/helpers/async_value_matchers.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Matcher isLoading<T>() => isA<AsyncLoading<T>>();
Matcher isData<T>(bool Function(T) predicate) => isA<AsyncData<T>>().having(
  (d) => d.value, 'value', predicate,
);
Matcher isError<T>() => isA<AsyncError<T>>();

// test/helpers/overrides.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
ProviderOverride overrideSvc<P extends ProviderOrFamily, T>(
  AutoDisposeProviderBase<T> provider,
  T value,
) => provider.overrideWith((_) => value); // For Riverpod 2.x/3.0

// test/helpers/builders.dart (Freezed test data)
import 'package:your_app/system_info/system_info.dart';
SystemInfo systemInfo({String osVersion = 'macOS 14.5'}) =>
    SystemInfo(osVersion: osVersion);
```

### 7.4.1 Test Organization Best Practice: Domain Separation

For better modularity and to prevent cross-feature leakage, organize test helpers into generic and feature-specific directories:

```
test/
  support/                        # Generic, cross-feature utilities
    async_value_matchers.dart     # isLoading/isData/isError matchers
    pump_utilities.dart           # pumpWithDelay, pumpUntil helpers
    container_helpers.dart        # TestContainer.create() with auto-dispose

  features/
    displays/
      support/                    # Display-specific helpers (scoped)
        fixtures.dart             # DisplayBuilders for test data
        scenarios.dart            # TestScenarios (laptop, docked, etc.)
        mocks.dart                # MockProviders, MockContainers
        assertions.dart           # DisplayAssertions.assertValidDisplay()
        failures.dart             # TestFailures.platformChannel()
        transitions.dart          # StateTransitions.simulateErrorRecovery()

  providers/                      # Provider unit tests
  widgets/                        # Widget tests
  howto/                          # Executable documentation tests
```

**Key Principles:**
- **Generic helpers** contain NO domain imports (no Display, no feature models)
- **Domain helpers** import only their feature's types/providers
- **No cross-feature imports** from one feature's support into another's tests
- **FakeServices** that have production use cases stay in `lib/` with documentation

**Note on FakeService Test-Only Behavior:**
- `FakeScreenService.getDisplays()` returns an empty list `[]` for empty configurations (not an error)
- This differs from real services which might throw or return a platform-specific error
- This behavior enables testing empty state UI without needing error handling
- The service has no artificial delays (immediate returns) for deterministic tests

---

## 7.5) HowTo Tests (Executable Documentation)

Write tests that serve as **executable documentation** demonstrating how the system works and how to extract maximum value from features. Place these in `test/howto/` to distinguish them from regular tests. These tests should include compelling use cases that new developers can study to understand optimal usage patterns.

```dart
// test/howto/display_detection_complete_workflow_test.dart

test('complete workflow demonstrates maximum value from display detection', () async {
  /// Compelling Use Case: Developer setting up multi-display support needs to
  /// understand the complete flow from initialization to error recovery
  /// 
  /// This test demonstrates how to:
  /// 1. Initialize display detection with DI
  /// 2. Handle multiple connected displays
  /// 3. React to display changes
  /// 4. Recover from errors gracefully
  /// 
  /// Real-world scenario: User with MacBook + 2 external monitors needs the app
  /// to track all displays, handle disconnections, and maintain state correctly
  
  // Setup: Configure DI with fake service for testing
  final service = FakeScreenService(displays: [
    DisplayBuilders.macBookPro16(),
    DisplayBuilders.external4K(),
    DisplayBuilders.external1080p(),
  ]);
  
  final container = ProviderContainer(
    overrides: [
      screenServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  
  // Maximum value 1: Initial detection of all displays
  final initialDisplays = await container.read(displaysProvider.future);
  expect(initialDisplays.length, 3, 
    reason: 'Should detect all 3 connected displays');
  expect(initialDisplays.where((d) => d.isPrimary).length, 1,
    reason: 'Exactly one primary display');
  
  // Maximum value 2: Track state transitions
  final states = <AsyncValue<List<Display>>>[];
  container.listen(displaysProvider, (_, next) => states.add(next));
  
  // Maximum value 3: Handle display disconnection
  service.removeDisplay('3'); // Simulate unplugging external 1080p
  await container.read(displaysProvider.notifier).refresh();
  
  final afterRemoval = container.read(displaysProvider).requireValue;
  expect(afterRemoval.length, 2,
    reason: 'Should update to 2 displays after disconnection');
  
  // Maximum value 4: Handle error with recovery
  service.setFailure(PlatformChannelFailure('Display driver crash'));
  await container.read(displaysProvider.notifier).refresh();
  
  expect(container.read(displaysProvider).hasError, true,
    reason: 'Should transition to error state');
  
  // Clear error and recover
  service.clearFailure();
  await container.read(displaysProvider.notifier).refresh();
  
  expect(container.read(displaysProvider).hasValue, true,
    reason: 'Should recover after error clears');
  
  // Maximum value 5: Verify complete state history
  expect(states.length, greaterThanOrEqualTo(4),
    reason: 'Should track: initial → removed → error → recovered');
  
  // Value verification: System maintains consistency
  final finalState = container.read(displaysProvider).requireValue;
  DisplayAssertions.assertDisplayArrangement(finalState);
});

test('DI patterns demonstrate testing flexibility', () async {
  /// Compelling Use Case: QA engineer needs to test various display configurations
  /// without physical hardware changes
  /// 
  /// This test demonstrates how to:
  /// 1. Override services for testing
  /// 2. Simulate different hardware configurations
  /// 3. Test edge cases impossible with real hardware
  /// 
  /// Real-world scenario: Testing app behavior with 10 displays, unusual
  /// resolutions, or rapid configuration changes
  
  // Maximum value: Test impossible configurations
  final extremeDisplays = List.generate(10, (i) => 
    DisplayBuilders.custom(
      id: 'display_$i',
      width: 800 + (i * 200),
      height: 600 + (i * 150),
      x: i * 1000,
      y: 0,
      isPrimary: i == 0,
    ),
  );
  
  final service = FakeScreenService(displays: extremeDisplays);
  final container = ProviderContainer(
    overrides: [
      screenServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  
  // Verify system handles extreme cases
  final displays = await container.read(displaysProvider.future);
  expect(displays.length, 10,
    reason: 'Should handle 10 displays');
  
  // Verify performance with many displays
  final stopwatch = Stopwatch()..start();
  await container.read(displaysProvider.notifier).refresh();
  stopwatch.stop();
  
  expect(stopwatch.elapsedMilliseconds, lessThan(100),
    reason: 'Should refresh quickly even with many displays');
});
```

### HowTo Test Best Practices

1. **Focus on complete workflows**, not isolated features
2. **Include setup and teardown** to show the full lifecycle
3. **Demonstrate error recovery** and edge cases
4. **Use meaningful variable names** that explain intent
5. **Add inline comments** explaining each step's purpose
6. **Verify actual business value**, not just technical correctness

## 8) Tools & packages — what to use in 2024/2025

* **flutter\_test**: standard unit/widget tests. ([Flutter Docs][15])
* **integration\_test**: official integration tests; supports desktop/web/device targets. ([Flutter Docs][2])
* **Mocking**:

  * Prefer **mocktail** (no codegen, null‑safe). Use **mockito** only if you need @GenerateMocks patterns. ([Dart packages][16])
* **riverpod\_test**: optional helpers exist on pub, but with ProviderContainer + overrides and Riverpod docs’ guidance, you typically don’t need it. ([Medium][17])
* **Goldens**: **alchemist** (CI‑stable) or **golden\_toolkit** (load fonts, DPI control). ([GitHub][3])
* **Accessibility**: use Flutter’s Accessibility Guideline API and semantics finders in tests for labels/roles. ([Flutter Docs][12], [Flutter API Docs][18])
* **Lints**: **riverpod\_lint** + **custom\_lint**. ([Riverpod][6])

---

## 9) Pitfalls & mitigation (crib sheet)

* **Forgetting `container.dispose()`** → memory leaks. *Mitigation*: `addTearDown(container.dispose)`. Riverpod 3.0 adds `ProviderContainer.test()`. ([Riverpod][1])
* **Async races** in tests (especially streams) → flaky tests. *Mitigation*: use explicit `pump/pumpAndSettle`, microtask delays, or fake clocks; assert sequences with `container.listen`.
* **Over‑mocking** → brittle tests. *Mitigation*: fake small service interfaces and prefer real implementations in higher‑level tests.
* **Testing implementation details** (private members) instead of behavior. *Mitigation*: assert *public state* (`AsyncValue`) and visible UI.
* **Golden diffs across OS**. *Mitigation*: use **Alchemist** (text normalization) or pin fonts and rasterization with golden\_toolkit. ([GitHub][3])
* **Not testing error boundaries**. *Mitigation*: explicitly test `AsyncError` + retry flows (examples above).
* **Provider disposal** not covered. *Mitigation*: use `ref.onDispose` and assert via disposal tests.

---

## 10) Integration & CI

**Directory layout**

```
lib/
  core/...
  featureX/...
test/
  unit/...           # pure Dart/provider tests
  widget/...         # widget tests
  goldens/...        # optional
  helpers/...
integration_test/
  <feature>_flow_test.dart
```

**GitHub Actions (macOS desktop)**

```yaml
name: Flutter CI (desktop)

on: [push, pull_request]

jobs:
  test-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Cache pub
        uses: actions/cache@v4
        with:
          path: ~/.pub-cache
          key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}

      - run: flutter pub get
      - name: Generate code
        run: dart run build_runner build -d
      - name: Analyze
        run: flutter analyze
      - name: Unit & widget tests (coverage)
        run: flutter test --coverage
      - name: Integration tests (macOS)
        run: flutter test integration_test -d macos

      - name: Report LCOV (optional gate)
        uses: zgosalvez/github-actions-report-lcov@v4
        with:
          coverage-files: coverage/lcov.info
          minimum-coverage: 60
          artifact-name: coverage-report
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

`integration_test` docs cover running on desktop; coverage reporting via LCOV actions or manual `genhtml`. ([Flutter Docs][2], [GitHub][19], [Code With Andrea][20])

**Performance**
Use test runner concurrency flags (default is parallel already). For large suites adjust `--concurrency`. ([Dart packages][21])

**Platform‑specific tests**
Use `@TestOn('mac-os')` for macOS‑only tests. ([Dart packages][21])

---

## 11) 2024/2025 “what’s new” with Riverpod & tests

* **Riverpod 3.0** adds test DX improvements (e.g., `ProviderContainer.test()`, `WidgetTester.container`), and *automatic retry* support that you may wish to **disable in tests** to prevent backoff timing from slowing/flaking tests (`retry: (_, __) => null`). These don’t change 2.x patterns, they only reduce boilerplate. ([Riverpod][1])
* **Docs emphasize provider overrides and scoping** as the canonical dependency injection/testing mechanism (unchanged). ([Riverpod][11])
* For UI tests and multi‑OS CI, **Alchemist** has matured to make desktop goldens practical across platforms. ([GitHub][3])

---

## 12) FAQ / quick answers to your research questions

**Provider Testing**

* *Idiomatic way to test @riverpod‑generated providers?*
  `ProviderContainer(overrides:[...])`, `read(provider.future)` for build, call `.notifier` for mutations, and assert `AsyncValue` transitions. Riverpod 3.0 adds `ProviderContainer.test()` sugar. ([Riverpod][1])
* *Overrides & DI?*
  Use `overrideWith((ref) => fake)`/`overrideWithValue(fake)` at the **dependency** boundary (e.g., service providers). ([Riverpod][11])
* *Lifecycle (build/dispose)?*
  Trigger with `read(provider.future)`, then `container.dispose()` and assert cleanup via `ref.onDispose`. ([Riverpod][1])
* *Providers depending on other providers?*
  Override the leaf dependencies and test the composed behavior (no special API). ([Riverpod][11])
* *Streams?*
  Use a `StreamController` in fakes, `container.listen` to capture states, and `pump` as needed.

**Widget Testing**

* *ConsumerWidget/ConsumerStatefulWidget?*
  Wrap in `ProviderScope(overrides: [...])`; assert `.when` branches. ([Riverpod][1])
* *Goldens?*
  Use **Alchemist** (CI‑friendly) or **golden\_toolkit** with font loading. ([GitHub][3])

**Integration Testing**

* *Structure tests with real services?*
  Place under `integration_test/`, use **integration\_test** binding and run on the desktop target. Keep platform channel code under `macos/Runner`. ([Flutter Docs][2])

**Code generation**

* *When/how to generate?*
  Run `dart run build_runner build -d` before tests/CI. Freezed & Riverpod codegen both depend on it. ([Riverpod][9])

**Error handling**

* *Result\<T, Failure> ⇄ AsyncValue<T>?*
  Convert at provider boundaries with `AsyncValue.guard` + `result.fold`. ([Dart packages][4], [Code With Andrea][5])

---

## 13) Extras (nice to have)

* **AsyncValue custom matchers** (above) to standardize expectations.
* **ProviderObserver** to capture logs/states during complex flows (attach at test container). ([Riverpod][1])
* **Accessibility** in tests: `expectLater(tester, meetsGuideline(...))`, semantics finders. ([Flutter Docs][12], [Flutter API Docs][18])

---

## 14) Commands you’ll actually run

```bash
# 1) Generate once
dart run build_runner build -d

# 2) Unit + widget
flutter test --coverage

# 3) Integration (desktop macOS)
flutter test integration_test -d macos

# 4) Update goldens
flutter test --update-goldens
```

---

### References

* Riverpod Testing & What’s New 3.0 (test helpers, WidgetTester.container) — official docs. ([Riverpod][1])
* Provider overrides & concepts. ([Riverpod][11])
* Automatic retry & disabling for tests. ([Riverpod][22])
* Code generation for @riverpod.
* AsyncValue API and idioms. ([Dart packages][23])
* `AsyncValue.guard` tip. ([Code With Andrea][5])
* Freezed docs.
* integration\_test (desktop/web). ([Flutter Docs][2])
* Platform channel (macOS location & shape). ([Flutter Docs][8])
* Goldens: golden\_toolkit & Alchemist. ([GitHub][3])
* Mocking: mocktail and mockito. ([Dart packages][16])
* Coverage reporting actions. ([GitHub][19])
* Riverpod lints + enabling. ([Riverpod][6])

---

### Drop‑in checklist for your codebase

* [ ] Add `freezed_annotation`, `riverpod_annotation`, `result_dart`; dev‑deps: `build_runner`, `freezed`, `riverpod_generator`, `custom_lint`, `riverpod_lint`.
* [ ] Create small service interfaces; providers only watch these.
* [ ] Convert `Result<T, Failure>` to `AsyncValue<T>` with `AsyncValue.guard`.
* [ ] Unit tests: `ProviderContainer(overrides: [...])`, `addTearDown(dispose)`.
* [ ] Widget tests: `ProviderScope(overrides: [...])` + assert `.when`.
* [ ] Integration\_test: run on macOS with real platform channel.
* [ ] Goldens: adopt **Alchemist** if you need multi‑OS CI.
* [ ] CI: `dart run build_runner build -d` before tests; upload coverage.
* [ ] Consider Riverpod 3.0 helpers when you upgrade; disable retry in tests.

This gives you **idiomatic, scalable, and maintainable** tests for Riverpod 2.x today, with a clear upgrade path to 3.0 ergonomics when you’re ready.

[1]: https://riverpod.dev/docs/how_to/testing "Testing your providers | Riverpod"
[2]: https://docs.flutter.dev/testing/integration-tests "Check app functionality with an integration test | Flutter"
[3]: https://github.com/Betterment/alchemist?utm_source=chatgpt.com "Betterment/alchemist: A Flutter tool that makes golden ..."
[4]: https://pub.dev/documentation/result_dart/latest/result_dart/ResultDart-class.html?utm_source=chatgpt.com "ResultDart class - result_dart library - Dart API"
[5]: https://codewithandrea.com/tips/async-value-guard-try-catch/?utm_source=chatgpt.com "Use AsyncValue.guard rather than try/catch inside your ..."
[6]: https://riverpod.dev/docs/introduction/getting_started?utm_source=chatgpt.com "Getting started"
[7]: https://pub.dev/packages/riverpod_lint?utm_source=chatgpt.com "riverpod_lint | Dart package"
[8]: https://docs.flutter.dev/platform-integration/platform-channels "Platform-specific code | Flutter"
[9]: https://riverpod.dev/docs/concepts/about_code_generation?utm_source=chatgpt.com "About code generation"
[10]: https://github.com/rrousselGit/freezed?utm_source=chatgpt.com "rrousselGit/freezed: Code generation for immutable ..."
[11]: https://riverpod.dev/docs/concepts2/overrides "Provider overrides | Riverpod"
[12]: https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility?utm_source=chatgpt.com "Accessibility"
[13]: https://api.flutter.dev/flutter/flutter_test/CommonFinders/bySemanticsIdentifier.html?utm_source=chatgpt.com "bySemanticsIdentifier method - CommonFinders class"
[14]: https://pub.dev/documentation/alchemist/latest/alchemist/goldenTest.html?utm_source=chatgpt.com "goldenTest function - alchemist library - Dart API"
[15]: https://docs.flutter.dev/testing?utm_source=chatgpt.com "Testing & debugging"
[16]: https://pub.dev/packages/mocktail?utm_source=chatgpt.com "mocktail | Dart package"
[17]: https://medium.com/flutter-community/build-sign-and-deliver-flutter-macos-desktop-applications-on-github-actions-5d9b69b0469c?utm_source=chatgpt.com "Build, Sign and Deliver Flutter MacOS Desktop ..."
[18]: https://api.flutter.dev/flutter/flutter_test/CommonFinders/bySemanticsLabel.html?utm_source=chatgpt.com "bySemanticsLabel method - CommonFinders class"
[19]: https://github.com/zgosalvez/github-actions-report-lcov?utm_source=chatgpt.com "zgosalvez/github-actions-report-lcov"
[20]: https://codewithandrea.com/articles/flutter-test-coverage/?utm_source=chatgpt.com "How to Generate and Analyze a Flutter Test Coverage ..."
[21]: https://pub.dev/packages/test?utm_source=chatgpt.com "test | Dart package"
[22]: https://riverpod.dev/docs/concepts2/retry "Automatic retry | Riverpod"
[23]: https://pub.dev/documentation/riverpod/latest/riverpod/AsyncValue-class.html?utm_source=chatgpt.com "AsyncValue class - riverpod library - Dart API"
