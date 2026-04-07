---
name: phase-2-review
description: Review a Phase 2 HTML mock for conformance against the functional spec and Tercen design system. Produces a PASS/FAIL report.
argument-hint: "[path to widget directory]"
disable-model-invocation: true
---

**READ-ONLY. Do NOT modify this file.**

## Inputs

1. **Widget directory** — Phase 2 output (contains `_mock/` and `_fixtures/`)
2. **Functional spec** — `widgets/{name}/{name}-spec.md`

Ask user if missing.

## Check Group A: Mock Files Exist

- **A1:** `_mock/wireframe.html` exists
- **A2:** `_mock/styled.html` exists
- **A3:** `_mock/gap-report.md` exists
- **A4:** `_fixtures/` directory exists with at least one JSON file

## Check Group B: Spec Coverage

- **B1:** Every spec feature has a corresponding element in styled mock
- **B2:** All 4 body states represented (loading, empty, active, error)
- **B3:** Toolbar controls match spec
- **B4:** Fixture data shapes match spec's data requirements

## Check Group C: Design System Compliance

- **C1:** No hex colour values in `styled.html` (must use CSS variables)
- **C2:** No raw pixel font sizes (must use text style CSS variables)
- **C3:** Spacing uses token CSS variables
- **C4:** Border radius uses token CSS variables
- **C5:** FontAwesome 6 Solid icons only

## Check Group D: Colour Approval

- **D1:** Approved colour names extracted from `../tercen-style/tokens.meta.json`
- **D2:** Every CSS variable colour reference uses an approved token
- **D3:** No unapproved colour tokens used

## Check Group E: Gap Report Quality

- **E1:** `gap-report.md` exists and non-empty
- **E2:** Every styled mock element accounted for in gap report
- **E3:** Gap categorisation uses the 5 defined categories
- **E4:** Each gap has a clear action item

## Conformance Report Format

Write to `_local/review-phase-2.md`:

```markdown
# Phase 2 Mock Review

**Widget:** [widget name]
**Spec:** [spec filename]
**Date:** [review date]

## Summary

| Result | Count |
|--------|-------|
| PASS | [n] |
| FAIL | [n] |
| **Total** | [n] |

**Verdict:** [PASS / FAIL]

PASS only if every check is PASS.

---

## Results

### A: Mock Files Exist
- A1: [PASS/FAIL] -- wireframe.html [detail if FAIL]
- A2: [PASS/FAIL] -- styled.html [detail if FAIL]
- A3: [PASS/FAIL] -- gap-report.md [detail if FAIL]
- A4: [PASS/FAIL] -- _fixtures/ directory [detail if FAIL]

### B: Spec Coverage
- B1: [PASS/FAIL] -- Feature coverage [detail if FAIL]
- B2: [PASS/FAIL] -- All 4 body states [detail if FAIL]
- B3: [PASS/FAIL] -- Toolbar controls [detail if FAIL]
- B4: [PASS/FAIL] -- Fixture data shapes [detail if FAIL]

### C: Design System Compliance
- C1: [PASS/FAIL] -- No hex colours [detail if FAIL]
- C2: [PASS/FAIL] -- No raw pixel font sizes [detail if FAIL]
- C3: [PASS/FAIL] -- Spacing tokens [detail if FAIL]
- C4: [PASS/FAIL] -- Border radius tokens [detail if FAIL]
- C5: [PASS/FAIL] -- FontAwesome 6 Solid only [detail if FAIL]

### D: Colour Approval
- D1: [PASS/FAIL] -- Approved colours extracted [detail if FAIL]
- D2: [PASS/FAIL] -- All colour refs approved [detail if FAIL]
- D3: [PASS/FAIL] -- No unapproved tokens [detail if FAIL]

### E: Gap Report Quality
- E1: [PASS/FAIL] -- gap-report.md exists and non-empty [detail if FAIL]
- E2: [PASS/FAIL] -- All elements accounted for [detail if FAIL]
- E3: [PASS/FAIL] -- Correct gap categories [detail if FAIL]
- E4: [PASS/FAIL] -- Action items for gaps [detail if FAIL]

---

## Failures Detail

[For each FAIL:]

### [Check ID]: [Check name]
**File:** [file path]
**Expected:** [what should be there]
**Found:** [what was found]
```

## Rules

- Report only. Never edit mock files.
- Read spec first. Cite file paths in failures.
- Only check what this skill defines.
- Every check is PASS or FAIL. No warnings.
