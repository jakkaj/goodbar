# Service Layer Review 1 — Findings and Action Plan (Updated)

This document summarizes the current implementation against our service-layer plan and rules, outlines concrete issues, and provides an actionable, testable fix plan we can execute step-by-step.

Scope covers: logging wrapper and DI, service providers, display service/pods, models, macOS coordinate conversion, tests, and docs/tooling.

## Summary of Findings

1) Logger wrapper (AppLogger)
- Tagging: `tag()` uses `PrefixPrinter` with only the `debug:` prefix, so only `debug` lines are tagged; `info/warn/error/fatal` lack the `[$tag]` prefix. Needs a printer that tags all levels [^1].
- API shape: Methods currently accept positional `(message, [error, stack])` and forward as named to `package:logger`. This is acceptable; alignment to named args on our surface API is optional. Keep as-is unless we see confusion in call sites [^1].
- File logging: Release-only file output is present; rotation/retention not implemented. Optional enhancement.

2) DI wiring for services — Implemented
- `screenServiceProvider` exists and injects a tagged logger; fakes can override in tests [^2].

3) Pods usage — Implemented
- `displaysProvider` exists as an `AsyncNotifier` (good choice for manual refresh) and uses the `ScreenService` contract. UI (`DisplaysScreen`) consumes the provider, not the service directly [^3].

4) Contract alignment vs docs
- `Display` model uses `Rectangle/Point` (Freezed) and `id: String`. This is fine and portable; the docs’ `Rect`/`int id` suggestion can be adapted. Consider adding `name` later if the platform can provide it [^4][^5].

5) macOS coordinate conversion — Needs fix
- Swift converts Y using the primary display height, which is incorrect for non-trivial layouts. Should compute the virtual desktop union and convert using `virtualMaxY` for both `frame` and `visibleFrame` [^6][^7].

6) Repo/docs drift
- README says `just run-macos` but `justfile` provides `run`. Add an alias or update README [^8].

## Recommended Approach (High-Level)

- Logger: keep current API; fix tagging to apply to all levels (replace `PrefixPrinter` usage with a simple all-level prefixing printer). Optional: add rotation later. Update/extend tests to assert tag presence across levels.
- DI: keep `screenServiceProvider` and continue overriding with `FakeScreenService` in tests.
- Pods: keep `AsyncNotifier`-based `displaysProvider` for refresh capability; add provider tests that exercise success/failure paths via overrides.
- Models: keep `Rectangle` (portable), keep `id: String` (future-proofs UUIDs); consider adding optional `name` later if feasible on macOS.
- Swift: fix coordinate conversion using virtual desktop union and, if available, enrich payload with `uuid`/`name`.
- Docs/tooling: align README and `justfile` commands; document log file location.

## Detailed Action Plan (Tasks & Success Criteria)

### Phase A — Logger corrections & tests

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| A.1 | [ ] | Tagging applies to all levels | All levels include `[$tag]` prefix (verified by captured output test) | Replace current `PrefixPrinter(debug: ...)` with an all-level prefixing printer [^1] |
| A.2 | [ ] | Keep current API shape | Keep `(message, [error, stack])`; ensure forwarding to `Logger` named args stays correct | No call-site churn; verify with tests [^1] |
| A.3 | [ ] | Logger tests | Assert tag prefix across levels; `f()` works; error/stack captured; no throws | Use a capturing output in tests [^1] |
| A.4 | [ ] | Optional: file rotation | Add retention/rotation in release; document log path in README | Nice-to-have; non-blocking |

### Phase B — Service providers (DI) & tests

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| B.1 | [x] | `screenServiceProvider` implemented | Provider returns `MacOSScreenService` and supports overrides in tests | Implemented in providers; injects tagged logger [^2] |
| B.2 | [ ] | Provider tests | Override `screenServiceProvider` with fake; verify override and tagging flow via `loggerRootProvider` | Based on current provider wiring [^2] |

### Phase C — Pods & UI integration

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| C.1 | [x] | Displays provider implemented | `displaysProvider` as `AsyncNotifier` returns `List<Display>` and handles failures | Refresh supported via notifier API [^3] |
| C.2 | [x] | UI consumes provider | Demo screen uses `ref.watch(displaysProvider)`; no direct service calls | AsyncValue states handled in UI [^3] |
| C.3 | [ ] | Provider tests | Override with `FakeScreenService`; test success (3 displays), failure, and `refresh()` | No mocks; provider overrides only |

### Phase D — Models & contract alignment

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| D.1 | [ ] | Confirm `id` semantics | Keep `String` id for future UUIDs; document mapping from native display ID | Avoid churn; ensure tests reflect this [^4] |
| D.2 | [ ] | Optional `name` field | Add `name` when obtainable from macOS; otherwise derive `"Display <id>"` | Requires Swift changes [^6][^7] |
| D.3 | [ ] | Tests for model shape | JSON round-trip, computed fields (menuBarHeight/dockHeight), equality | Extend existing tests as needed [^4][^5] |

### Phase E — macOS coordinate conversion

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| E.1 | [ ] | Compute virtual desktop union | Use union(minX, maxY) across all screens; convert y with `virtualMaxY - (y + height)` | Apply to both `frame` and `visibleFrame` [^6][^7] |
| E.2 | [ ] | Return enriched fields | Include `uuid` if available; optionally `name` | Keep id as stringified display number for now [^7] |
| E.3 | [ ] | Tests/validation | Manual validation on multi-display layouts (stacked, negative coordinates) | Verify menu bar/dock heights mapped correctly |

### Phase F — Docs/tooling alignment

| # | Status | Task | Success Criteria | Notes |
|---|--------|------|------------------|-------|
| F.1 | [ ] | Align README and `justfile` | Add `run-macos` alias or update README to `just run`; document log path | Developer experience consistency [^8] |

---

[^1]: Review and adjust tagging in [`method:lib/src/core/logging/app_logger.dart:AppLogger.tag`](../../../lib/src/core/logging/app_logger.dart) and verify all shorthands (`d/i/w/e/f`) forward error/stack correctly.

[^2]: `screenServiceProvider` implemented in [`file:lib/src/providers/services.dart`](../../../lib/src/providers/services.dart) and consumes [`provider:lib/src/bootstrap/logger_providers.dart:loggerProvider`](../../../lib/src/bootstrap/logger_providers.dart).

[^3]: Displays provider and UI in [`file:lib/src/providers/displays_provider.dart`](../../../lib/src/providers/displays_provider.dart) and [`file:lib/src/widgets/displays_screen.dart`](../../../lib/src/widgets/displays_screen.dart).

[^4]: Display model lives in [`file:lib/src/core/models/display.dart`](../../../lib/src/core/models/display.dart) with `id: String`, `bounds/workArea: Rectangle`, and computed properties.

[^5]: Geometry types are defined in [`file:lib/src/core/models/geometry.dart`](../../../lib/src/core/models/geometry.dart) (`Point`, `Rectangle`).

[^6]: Dart side mapping/parsing occurs in [`file:lib/src/services/screen/macos_screen_service.dart`](../../../lib/src/services/screen/macos_screen_service.dart).

[^7]: Platform implementation in [`method:macos/Runner/ScreenService.swift:displayToDictionary`](../../../macos/Runner/ScreenService.swift) currently uses primary height for Y conversion; update to virtual union and consider adding `uuid`/`name`.

[^8]: Align commands in [`file:README.md`](../../../README.md) and [`file:justfile`](../../../justfile) — ensure `just run` and/or `run-macos` alias exists and README matches.

