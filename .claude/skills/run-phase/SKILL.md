---
name: run-phase
description: Orchestrate a complete build-review-fix cycle for a given phase. Runs the appropriate skill, then the reviewer, and loops until the review passes or the user intervenes.
argument-hint: "[phase-number] [widget-name or path-to-spec]"
---

# Run Phase

Orchestrate the build-review-fix loop for one phase.

## Phase routing

| Phase | Build skill | Review skill | Notes |
|-------|-------------|-------------|-------|
| 1 | `phase-1-spec` | `phase-1-review` | Spec writing + conformance review |
| 3 | `phase-3-primitives` | — | Fill SDUI primitive gaps (no review phase) |
| 4 | `phase-4-catalog` | `phase-5-review` | Author catalog entry + conformance review |

Phases 2 and 3-reconcile are obsolete — the mock shell (`lib/mock/main_mock.dart`) replaces HTML mocks.

## Workflow

### Phase 1: Spec
1. Invoke `phase-1-spec` with $ARGUMENTS[1]
2. Invoke `phase-1-review` on the produced spec
3. FAIL -> fix issues, re-review. Loop until PASS.
4. PASS -> notify user

### Phase 3: Primitives
1. Read gap report: `packages/tercen_ui_widgets/widgets/{name}/_mock/sdui-gaps.md`
2. If no gaps, skip
3. Fill gaps per `phase-3-primitives` skill (create primitives in `packages/sdui/`, run `dart analyze`)
4. Present completed primitives for review

### Phase 4: Catalog
1. Invoke `phase-4-catalog` with spec at $ARGUMENTS[1]
2. Test in mock shell: `flutter run -t lib/mock/main_mock.dart -d web-server --web-port 12889 --dart-define=MOCK_WIDGET=WidgetName`
3. Invoke `phase-5-review` on the catalog entry
4. FAIL -> fix issues, re-test, re-review. Loop until PASS.
5. PASS -> validate catalog.json parses, notify user

## Rules

- Each phase must complete before the next begins
- Reviews are automatic — do not wait for user to request them
- After PASS, present report location
- Log issues encountered during the cycle
