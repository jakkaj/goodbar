# Service Layer Review 1 — Findings and Action Plan

This document summarizes the current implementation against our service-layer plan and rules, outlines concrete issues, and provides an actionable, testable fix plan we can execute step-by-step.

Scope covers: logging wrapper and DI, service providers, display service/pods, models, macOS coordinate conversion, tests, and docs/tooling.

## Summary of Findings

1) Logger wrapper (AppLogger)
- Surface API uses positional error/stack parameters while `package:logger` (2.6.x) exposes named args. This creates an inconsistent API for consumers and complicates propagation of error and stack traces through DI.
- Tagging uses `PrefixPrinter` with only `debug:` prefix, so only `debug` messages receive the tag. Info/warn/error/fatal lines are missing the tag consistently.
- Release-only file logging is present, but there is no rotation/retention strategy. Printing `time:` manually is redundant when printers already include timestamps.

2) DI wiring for services
- `screenServiceProvider` and other service providers are missing. UI demo constructs `MacOSScreenService` directly, bypassing provider-based DI and making overrides in tests harder.

3) Pods usage
- There is no `displaysPod`. The demo widget reads from the service directly rather than from a pod, breaking the intended flow: UI → Pods → Services → Platform.

4) Contract drift vs docs
- `Display` model currently uses custom `Rectangle`/`Point` types and a `String` id. Our service-layer doc recommends a small, portable DTO and suggests either `Rect` (with a JSON converter) or a minimal geometry type; also, `id` as `int` maps better to `CGDirectDisplayID` on macOS. A `name` field is also expected for display labeling.

5) macOS coordinate conversion
- The Swift bridge converts Y using only the primary display’s height, which yields wrong coordinates for stacked/negative layouts. It should compute the virtual desktop union (minX, maxY) across all screens and convert using that baseline for both `frame` and `visibleFrame`.

6) Repo/docs drift and small inconsistencies
- README says `just run-macos` but `justfile` provides `run`. Either rename/add alias or update docs.
- Folder layout differs slightly from rules; this is acceptable if we standardize and document it.

## Recommended Approach (High-Level)

- Logger: make `AppLogger` a thin façade over `Logger` with named parameters, consistent tagging via a small `TaggedPrinter`, and release-only file output (optional rotation using `AdvancedFileOutput`). Keep the providers as-is for DI and update tests to assert tag presence and level behavior.
- DI: add `screenServiceProvider` in a new `bootstrap/service_providers.dart`, inject the tagged logger from `loggerProvider('ScreenService')` and return `MacOSScreenService` on macOS (fake elsewhere or by override in tests).
- Pods: add a `displaysPod` `FutureProvider<List<Display>>` that logs, calls the service, maps `Result.success` to data and throws `StateError` for failures.
- Models: choose Option A (recommended): switch to `Rect` with a `JsonConverter`, use `int id`, add `name`, `uuid?`, `scale`, `frame`, `visibleFrame`. If we prefer minimal churn, keep `Rectangle` but add `name` and migrate `id` → `int`.
- Swift: fix coordinate conversion to use virtual union (minX, maxY) and return the enriched fields.
- UI demo: refactor to consume `displaysPod` rather than constructing services directly.
- Docs/tooling: align README and `justfile` commands; note log file location.

## Detailed Action Plan (Tasks & Success Criteria)

### Phase A — Logger corrections & tests

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| A.1 | [ ] | Align `AppLogger` API to named args | `AppLogger.d/i/w/e/f/wtf` accept named `{error, stackTrace, time}` and forward to `Logger` without compile errors | Update surface API to match `logger` 2.6.x [^f1] |
| A.2 | [ ] | Correct tagging for all levels | All levels include `[$tag]` prefix (verified by captured output test) | Replace partial `PrefixPrinter` usage with a `TaggedPrinter` wrapper [^f1] |
| A.3 | [ ] | Release-only file logging with rotation | In debug/tests only console; in release/macOS, writes under `~/Library/Logs/goodbar/` with rotation; add a basic retention config | Use `AdvancedFileOutput` (optional but recommended) [^f1] |
| A.4 | [ ] | Logger tests | Tests assert: tagged prefix present; `f()` logs; named args pass through; no exceptions thrown | Use a memory/capturing output to assert content [^t1] |

### Phase B — Service providers (DI) & tests

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| B.1 | [ ] | Add `screenServiceProvider` | `Provider<ScreenService>` returns `MacOSScreenService` on macOS and is override-friendly for tests | New file with logger injection via `loggerProvider('ScreenService')` [^f2] |
| B.2 | [ ] | Provider tests | Override `screenServiceProvider` with fake; verify tagged logger injection pattern via `loggerRootProvider` override | See example in service-layer doc [^t2] |

### Phase C — Displays pod & UI integration

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| C.1 | [ ] | Add `displaysPod` | `FutureProvider<List<Display>>` maps `Result.success` to data and throws `StateError` on failure; logs appropriately | Matches pattern in `docs/rules/service-layer.md` [^f3] |
| C.2 | [ ] | Pod tests | With fake service override, verify 1/2/3+ displays; verify failure converts to `AsyncError` | Use `ProviderContainer` and overrides [^t3] |
| C.3 | [ ] | Demo widget uses pod | Replace direct service construction with `ConsumerWidget` reading `displaysPod` | Remove tight coupling in `test_display_detection.dart` [^f4] |

### Phase D — Model alignment (Option A recommended)

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| D.1 | [ ] | Add `RectConverter` | `Rect` (frame/visibleFrame) serializes/deserializes; tests round-trip | New converter in geometry file [^f5] |
| D.2 | [ ] | Update `Display` model | Fields: `int id`, `String? uuid`, `String name`, `bool isPrimary`, `double scale`, `Rect frame`, `Rect visibleFrame`; tests updated | Freezed + JSON; run codegen [^f6] |
| D.3 | [ ] | Update fakes/services | Fake and macOS impl map new fields; tests pass | Minimal surface change in fake; mapper updates in macOS impl [^f7] |

### Phase E — macOS coordinate conversion and payload

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| E.1 | [ ] | Fix Y conversion using virtual union | For stacked/negative layouts, converted frames are correct; manual verification across arrangements | Compute `minX` and `maxY` over all screens; convert `frame` and `visibleFrame` [^f8] |
| E.2 | [ ] | Enrich payload | Include `id` (Int), `uuid?`, `name`, `scale`, `frame`, `visibleFrame` | Map `NSScreenNumber`, `CGDisplayCreateUUIDFromDisplayID`, `localizedName`, `backingScaleFactor` [^f8] |
| E.3 | [ ] | Dart mapper | `MacOSScreenService` maps new payload to `Display` correctly; tests updated | Error handling remains explicit with `Result` [^f7] |

### Phase F — Docs & tooling

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| F.1 | [ ] | README command fix | `just run` matches README or alias `run-macos` exists | Update either README or `justfile` [^f9] |
| F.2 | [ ] | Document small structure choice | Decide to keep current services folder vs. align to docs; document the decision | Minor doc note under rules or plan [^f10] |

## Risks, Pitfalls, Mitigations

- Logger API drift: If `logger` version changes, re-check method signatures for `f()`/named args. Keep a small shim to call `wtf()` if `f()` is unavailable.
- Tagging consistency: Ensure prefix applies to all levels (custom `TaggedPrinter`), not just debug.
- Coordinate correctness: Never base Y on the primary height; always compute union (minX, maxY). Validate with a stacked monitor layout.
- Model churn: If migrating to `Rect`, update all tests and mappers in one PR to avoid inconsistent state. If churn is too high right now, adopt the “keep `Rectangle`” fallback but still fix ID type and add `name`.
- Tests on CI: Keep native/hardware-dependent tests skipped or gated by env vars; rely on fakes + provider overrides for the bulk.

## Open Decisions (confirm before implementation)

- Display model direction: adopt `Rect` + converter (recommended) vs. keep `Rectangle` for now and add `name`/`int id`.
- Enable log rotation now (`AdvancedFileOutput`) vs. keep simple file output and revisit later.
- Folder layout: retain current `lib/src/services/screen/*` organization or align strictly to `core/services` + `core/services_impl` as per docs.

## References (internal)

- Rules & architecture: `docs/rules/rules-idioms-architecture.md`
- Service-layer spec: `docs/rules/service-layer.md`
- Existing plan: `docs/plans/001-project-setup/2-service-layer.md`

## Footnotes (targets to modify)

[^f1]: Update [`file:lib/src/core/logging/app_logger.dart`](../../../lib/src/core/logging/app_logger.dart) — named parameter surface API, `TaggedPrinter` usage for tags, release-only file output (optional rotation).

[^t1]: Logger tests in [`file:test/core/logging/app_logger_test.dart`](../../../test/core/logging/app_logger_test.dart) — capture output and assert tag prefix and `f()` logging paths.

[^f2]: Add service provider in [`file:lib/src/bootstrap/service_providers.dart`](../../../lib/src/bootstrap/service_providers.dart) — inject `loggerProvider('ScreenService')`, return `MacOSScreenService` on macOS, override-friendly.

[^t2]: Provider tests in [`file:test/bootstrap/logger_providers_test.dart`](../../../test/bootstrap/logger_providers_test.dart) and new service provider tests under `test/bootstrap/`.

[^f3]: Add displays pod in [`file:lib/src/features/displays/pods/displays_pod.dart`](../../../lib/src/features/displays/pods/displays_pod.dart) — logs, maps `Result`, throws `StateError` on failure.

[^t3]: Pod tests in a new file, e.g., [`file:test/features/displays/displays_pod_test.dart`](../../../test/features/displays/displays_pod_test.dart) — provider overrides with fake service.

[^f4]: Refactor demo to consume pod in [`file:lib/src/test_display_detection.dart`](../../../lib/src/test_display_detection.dart) — convert to `ConsumerWidget`/`WidgetRef`.

[^f5]: Add `RectConverter` in [`file:lib/src/core/models/geometry.dart`](../../../lib/src/core/models/geometry.dart) or a dedicated converter file — tests should round-trip.

[^f6]: Update `Display` model in [`file:lib/src/core/models/display.dart`](../../../lib/src/core/models/display.dart) — `int id`, `String? uuid`, `String name`, `double scale`, `Rect frame`, `Rect visibleFrame`.

[^f7]: Update macOS service mapper in [`file:lib/src/services/screen/macos_screen_service.dart`](../../../lib/src/services/screen/macos_screen_service.dart) and fake in [`file:lib/src/services/screen/fake_screen_service.dart`](../../../lib/src/services/screen/fake_screen_service.dart).

[^f8]: Fix coordinate conversion and enrich payload in [`file:macos/Runner/ScreenService.swift`](../../../macos/Runner/ScreenService.swift) — compute `minX` and `maxY`, convert both `frame` and `visibleFrame`, include `uuid` and `name`.

[^f9]: Align commands in [`file:README.md`](../../../README.md) and/or [`file:justfile`](../../../justfile) — ensure `just run` and/or `run-macos` alias.

[^f10]: Document folder layout decision in rules or a short note within this plan; align future changes accordingly.

