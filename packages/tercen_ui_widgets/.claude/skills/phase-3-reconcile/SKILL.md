---
name: phase-3-reconcile
description: Reconcile an approved HTML mock against its functional spec. Produces a binding design-decisions document that overrides the spec for catalog integration. Run after Phase 2 mock approval, before Phase 4 catalog.
argument-hint: "[path to widget directory]"
disable-model-invocation: true
---

**READ-ONLY. Do NOT modify this file.**

## Purpose

During mock development (Phase 2), the design is refined through iteration — features are added, removed, or changed relative to the original functional spec. These refinements are **approved design decisions** that MUST survive into the real implementation.

This skill produces `_mock/design-decisions.md` — a binding document that the catalog-integrator (Phase 4) reads as **authoritative overrides** to the functional spec. Where a decision conflicts with the spec, the decision wins.

## Inputs

1. **Approved HTML mock** — `widgets/{name}/_mock/styled.html`
2. **Functional spec** — `widgets/{name}/{name}-spec.md`
3. **Mock data** — inline in styled.html or in `_fixtures/`

## Process

### Step 1 — Extract mock truth

Read the approved styled.html and document exactly what it implements:

- **Layout**: what structural elements exist and their arrangement
- **Toolbar**: which buttons, their variants (primary/secondary/ghost), enabled conditions
- **Tree/list/content**: node types, icon choices (solid vs regular), colours per type
- **Sort order**: how items are ordered within containers
- **Filter/search**: what filtering and search behaviour is implemented
- **Body states**: what each state (loading, empty, active, error) shows
- **EventBus events**: what events are emitted, their channels and payloads
- **Interactions**: click, double-click, hover, keyboard — what each does
- **Convenience bar elements**: what is dev-only vs what is widget

### Step 2 — Diff against spec

Compare every element from Step 1 against the functional spec. Categorise each difference:

| Category | Meaning |
|----------|---------|
| **Added** | Mock has a feature not in the spec |
| **Removed** | Spec describes a feature the mock deliberately omits |
| **Changed** | Both have the feature but details differ (colour, icon, behaviour, layout) |
| **Unchanged** | Spec and mock agree — no override needed |

### Step 3 — Write design-decisions.md

Output to `widgets/{name}/_mock/design-decisions.md`:

```markdown
# Design Decisions — {Widget Name}

**Generated:** {date}
**Mock:** _mock/styled.html
**Spec:** {name}-spec.md

## Authority

This document records approved design decisions from mock refinement.
Where a decision conflicts with the functional spec, **this document wins**.
The catalog-integrator (Phase 4) MUST read this document before the spec.

## Decisions

### {Category}: {Short title}

**Spec says:** {what the spec describes}
**Mock implements:** {what the approved mock actually does}
**Reason:** {why the change was made, if known}
**Binding:** YES — use mock version in catalog.json

---

(repeat for each difference)

## Unchanged from Spec

{List features where spec and mock agree — confirms these carry forward as-is}
```

### Step 4 — Update spec (optional)

If the differences are substantial (>5 decisions), update the functional spec inline:
- Add a `## Mock Refinements` section at the end of the spec
- List each override with a reference to design-decisions.md
- Do NOT delete original spec text — mark overridden sections with `[Overridden — see design-decisions.md]`

This keeps the spec readable as a single document while preserving the original intent.

## Output

- `widgets/{name}/_mock/design-decisions.md` — ALWAYS produced
- `widgets/{name}/{name}-spec.md` — updated only if >5 decisions

## Rules

- Read the mock as the source of truth. It was approved by the user.
- Do not add, remove, or change anything in the mock.
- Do not invent reasons for decisions — write "Reason: refined during mock iteration" if unknown.
- Every difference MUST be documented. Missing a difference means the spec version leaks into the real implementation.
- The catalog-integrator MUST read design-decisions.md. Add this to Step 2 of the catalog skill if not already there.
