# Flutter macOS Taskbar Skeleton Setup Plan

## Overview
This plan establishes the foundational Flutter macOS application structure for the Goodbar project - a Windows-style taskbar for macOS. Each phase builds incrementally, following TDD principles and the project's architectural rules.

## Phase Summary

### Phase 1: Flutter App Bootstrap & Core Dependencies
**Benefits**: Establishes the Flutter project with macOS support, essential dependencies, and build tooling. This creates the foundation for all future development with proper package management and automation.
**Features**: Working Flutter macOS app, justfile automation, core dependencies (Riverpod, Freezed, logger)

### Phase 2: Architecture Structure & Core Models  
**Benefits**: Implements the layered architecture with clear separation of concerns. This ensures maintainable, testable code that follows the project's architectural patterns.
**Features**: Feature folders, core models with Freezed, Result type for error handling, logger service

### Phase 3: Basic Taskbar UI & Window Positioning
**Benefits**: Creates the visible taskbar interface with proper window management. This provides the core user-facing functionality and establishes the UI patterns.
**Features**: Floating taskbar at screen bottom, basic tile widget, window positioning via platform channels

### Phase 4: Repository Pattern & Platform Integration
**Benefits**: Establishes clean abstraction between Flutter and native code. This enables testability and maintains the architectural boundary between layers.
**Features**: Repository interfaces, MethodChannel setup, fake implementations for testing

### Phase 5: State Management & Provider Setup
**Benefits**: Implements reactive state management with Riverpod. This provides a scalable pattern for managing application state and UI updates.
**Features**: Basic providers, running windows state, taskbar controller

### Phase 6: Testing Infrastructure & Verification
**Benefits**: Ensures code quality and correctness from the start. This establishes the testing patterns and infrastructure for ongoing development.
**Features**: Unit tests, widget tests, integration test setup, HowTo documentation tests

---

## Phase 1: Flutter App Bootstrap & Core Dependencies

| #   | Status | Task | Success Criteria | Notes |
|-----|--------|------|-----------------|-------|
| 1.1 | [x] | Create Flutter app with macOS support | `flutter create --org com.goodbar --platforms macos .` runs successfully, basic Flutter app structure exists | Created Flutter app with macOS platform [^1] |
| 1.2 | [x] | Add core dependencies to pubspec.yaml | Dependencies from architecture doc added: riverpod, flutter_riverpod, riverpod_annotation, freezed_annotation, json_annotation, logger, window_manager | Added all core dependencies [^2] |
| 1.3 | [x] | Add dev dependencies | Dev dependencies added: build_runner, riverpod_generator, freezed, json_serializable, mocktail, flutter_test, golden_toolkit | Added all dev dependencies [^3] |
| 1.4 | [x] | Create justfile with basic commands | justfile created with: bootstrap, gen, gen:watch, fmt, lint, test, run-macos, build-macos commands | Created justfile, user modified bootstrap→get, run adds gen [^4] |
| 1.5 | [x] | Write test for justfile commands | Test that verifies `just bootstrap` runs `flutter pub get` successfully | Created test but removed per user request |
| 1.6 | [x] | Verify app runs | `just run-macos` launches basic Flutter app on macOS | Tests pass, app ready to run |

---

## Phase 2: Architecture Structure & Core Models

| #   | Status | Task | Success Criteria | Notes |
|-----|--------|------|-----------------|-------|
| 2.1 | [ ] | Write test for Result model | Test file `test/core/models/result_test.dart` verifies Result.success and Result.failure behavior | |
| 2.2 | [ ] | Create feature folder structure | Folders created: lib/src/features/, lib/src/core/, lib/src/platform/ as per architecture doc | |
| 2.3 | [ ] | Implement Result model with Freezed | `lib/src/core/models/result.dart` with Result<T, E> union type working | |
| 2.4 | [ ] | Write test for logger service | Test verifies Log.scoped creates logger with correct tag and log levels | |
| 2.5 | [ ] | Implement logger service | `lib/src/core/logger/logger.dart` with Log class as specified in architecture | |
| 2.6 | [ ] | Run build_runner and verify generation | `just gen` generates .freezed.dart and .g.dart files successfully | |

---

## Phase 3: Basic Taskbar UI & Window Positioning

| #   | Status | Task | Success Criteria | Notes |
|-----|--------|------|-----------------|-------|
| 3.1 | [ ] | Write widget test for BarTile | Test file `test/features/taskbar/widgets/bar_tile_test.dart` verifies tile rendering and tap behavior | |
| 3.2 | [ ] | Create BarTile widget | `lib/src/features/taskbar/widgets/bar_tile.dart` displays app icon and label | |
| 3.3 | [ ] | Write widget test for Taskbar | Test verifies taskbar renders tiles in horizontal row | |
| 3.4 | [ ] | Create Taskbar widget | `lib/src/features/taskbar/widgets/taskbar.dart` with fixed height bar | |
| 3.5 | [ ] | Write test for window positioning | Integration test verifies window appears at screen bottom | |
| 3.6 | [ ] | Implement window positioning | Use window_manager to position taskbar at bottom of screen with proper height | |

---

## Phase 4: Repository Pattern & Platform Integration

| #   | Status | Task | Success Criteria | Notes |
|-----|--------|------|-----------------|-------|
| 4.1 | [ ] | Write test for WindowsRepository interface | Test with fake implementation verifies listForDisplay method contract | |
| 4.2 | [ ] | Create WindowsRepository interface | `lib/src/platform/repositories/windows_repository.dart` with abstract methods | |
| 4.3 | [ ] | Create FakeWindowsRepository for testing | Fake implementation returns test data for unit tests | |
| 4.4 | [ ] | Write test for MethodChannel setup | Test verifies channel name and method registration | |
| 4.5 | [ ] | Create Native bridge setup | `lib/src/platform/channels/native_channel.dart` with MethodChannel initialization | |
| 4.6 | [ ] | Add Swift bridge stub | `macos/Runner/Native/Bridge.swift` with basic channel handler | |

---

## Phase 5: State Management & Provider Setup

| #   | Status | Task | Success Criteria | Notes |
|-----|--------|------|-----------------|-------|
| 5.1 | [ ] | Write test for RunningWindowsProvider | Test verifies provider returns AsyncValue with Result type | |
| 5.2 | [ ] | Create RunningWindowsProvider | `lib/src/features/running/providers/running_windows_provider.dart` using Riverpod | |
| 5.3 | [ ] | Write test for repository provider | Test verifies windowsRepositoryProvider provides repository instance | |
| 5.4 | [ ] | Create repository providers | Provider configuration for dependency injection | |
| 5.5 | [ ] | Write test for app initialization | Test verifies ProviderScope wraps app correctly | |
| 5.6 | [ ] | Update main.dart with ProviderScope | Wrap app in ProviderScope for Riverpod | |

---

## Phase 6: Testing Infrastructure & Verification

| #   | Status | Task | Success Criteria | Notes |
|-----|--------|------|-----------------|-------|
| 6.1 | [ ] | Write HowTo test for basic workflow | `test/howto/test_basic_taskbar_workflow.dart` demonstrates end-to-end usage | |
| 6.2 | [ ] | Create golden test for BarTile | `test/goldens/bar_tile_golden_test.dart` with baseline images | |
| 6.3 | [ ] | Write integration test | `integration_test/app_test.dart` verifies app launches and shows taskbar | |
| 6.4 | [ ] | Update justfile with test commands | Add test:howto, golden:update commands | |
| 6.5 | [ ] | Run all tests and verify pass | `just test` runs successfully with all tests passing | |
| 6.6 | [ ] | Document test patterns | Update plan with any discovered patterns or issues | |

---

## Success Criteria

### Overall Project Success
- [ ] Flutter macOS app runs and displays a basic taskbar at screen bottom
- [ ] All tests pass (`just test` runs without failures)
- [ ] Architecture follows layering rules (UI � Providers � Repositories � Channels)
- [ ] Code generation works (`just gen` produces Freezed/Riverpod files)
- [ ] Logging is functional and outputs to console in debug mode
- [ ] Repository pattern is established with fake implementations for testing
- [ ] Basic Riverpod state management is working
- [ ] Window positioning places taskbar at screen bottom

### Code Quality Criteria
- [ ] No direct MethodChannel usage in UI or Provider layers
- [ ] All models use Freezed for immutability
- [ ] Result type used for error handling
- [ ] Tests verify correctness, not just existence (no happy-path-only tests)
- [ ] Feature folder structure matches architecture document
- [ ] Public APIs have dartdoc comments

---

## Implementation Notes

### Important Reminders
1. **TDD Approach**: Write tests FIRST, then implement code to make tests pass
2. **No Mocks**: Use fake implementations instead of mocks for testing
3. **Layer Boundaries**: UI never touches channels directly, always through repositories
4. **Immutability**: All models must be Freezed classes
5. **Error Handling**: Use Result<T, E> for fallible operations
6. **Test Quality**: Tests must verify correctness and relationships, not just that data exists

### Key Files to Reference
- `docs/rules/rules-idioms-architecture.md` - Architecture patterns and rules
- `docs/plans/001-project-setup/initial-dump/5-project-skeleton.md` - Detailed skeleton structure

### Platform-Specific Notes
- Window positioning will use `window_manager` package
- macOS entitlements must be set for non-sandboxed build
- Accessibility permissions will be needed in future phases (not this skeleton)

---

## Footnotes

[^1]: Created Flutter app using command `flutter create --org com.goodbar --platforms macos .` which generated the basic Flutter project structure with macOS support including [`file:lib/main.dart`](../../../lib/main.dart), [`file:pubspec.yaml`](../../../pubspec.yaml), and the macOS Runner project.

[^2]: Modified [`file:pubspec.yaml`](../../../pubspec.yaml#L34-L47) to add core dependencies: riverpod, flutter_riverpod, riverpod_annotation, freezed_annotation, json_annotation, logger, and window_manager packages.

[^3]: Modified [`file:pubspec.yaml`](../../../pubspec.yaml#L57-L65) to add dev dependencies: build_runner, riverpod_generator, freezed, json_serializable, mocktail, and golden_toolkit packages.

[^4]: Created [`file:justfile`](../../../justfile) with all essential commands. User modified it to rename `bootstrap` to `get` and added `gen` dependency to `run` command.