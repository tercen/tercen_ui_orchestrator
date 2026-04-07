---
name: phase-1-review
description: Review a Phase 1 functional spec for conformance. Determines widget kind, loads kind-specific checks, and produces a PASS/FAIL conformance report.
argument-hint: "[path to functional spec]"
disable-model-invocation: true
---

**READ-ONLY — do not modify this file.**

## Input

Spec path (markdown file). Ask user if not provided.

## Kind Detection

Read spec to determine widget kind. Look for `Widget Kind:` in header metadata, or infer:
- Two-panel (left + main) = **panel**
- Three-panel (status + header + content) = **runner**
- Standalone feature window = **window**

## Kind Dispatch

Load kind-specific checks from this skill directory:
- panel -> `checks-panel.md`
- runner -> `checks-runner.md`
- window -> `checks-window.md`

## Workflow

1. Read entire spec
2. Determine kind, load kind-specific checks
3. Run shared checks (Group B + No Implementation Detail) plus all kind-specific checks, recording PASS/FAIL
4. Produce Conformance Report (template below)
5. Save to `_local/phase-1-conformance-report.md` (ask user for path if unknown)

## Shared Check Group B: Header Metadata

| Check | Rule |
|-------|------|
| B1 | Top-level heading with widget name |
| B2 | `**Version:**` present |
| B3 | `**Status:**` present |
| B4 | `**Last Updated:**` with date |
| B5 | `**Reference:**` describing source material (if from scratch: "Original specification") |
| B6 | Widget kind explicitly stated (typically in 1.1 or 1.3) |

## Shared Check Group: No Implementation Detail

Spec must describe WHAT, never HOW. Scan entire document.

| Check | Rule | Exception |
|-------|------|-----------|
| No code | No Dart, pseudo-code, code-like syntax | ASCII layout diagrams OK |
| No framework references | No Flutter widgets, Provider, GetIt, ChangeNotifier, Consumer, context.watch, setState | — |
| No pixel values/spacing tokens | No "280px", "AppSpacing.md", CSS-like specs | Domain-specific user-facing sizes OK ("thumbnail 100x100") |
| No colour codes | No hex codes, RGB values, theme tokens | Domain-level descriptions OK ("red for upregulated") |
| No file paths/imports | No Dart file paths, imports, package names | — |
| Mock data WHAT not HOW | No loading mechanisms (rootBundle, loadString, CsvToListConverter) | — |

## Conformance Report Format

Use this exact wrapper format. Kind-specific checks file defines which groups appear in Results and Failures Detail. List every check — do not abbreviate.

```markdown
# Phase 1 Conformance Report

**Spec:** [spec filename]
**Widget Name:** [name from spec heading]
**Widget Kind:** [panel / runner / window]
**Date:** [review date]

## Summary

| Result | Count |
|--------|-------|
| PASS | [n] |
| FAIL | [n] |
| **Total** | [n] |

**Verdict:** [CONFORMING / NON-CONFORMING]

CONFORMING only if every check is PASS.

---

## Results

### B: Header Metadata
- B1: [PASS/FAIL] — Widget name in top-level heading [detail if FAIL]
- B2: [PASS/FAIL] — Version field [detail if FAIL]
- B3: [PASS/FAIL] — Status field [detail if FAIL]
- B4: [PASS/FAIL] — Last Updated field [detail if FAIL]
- B5: [PASS/FAIL] — Reference field [detail if FAIL]
- B6: [PASS/FAIL] — Widget kind identified [detail if FAIL]

[Kind-specific check groups from checks-panel.md / checks-runner.md / checks-window.md]

### No Implementation Detail
- [PASS/FAIL] — No code [detail if FAIL]
- [PASS/FAIL] — No framework references [detail if FAIL]
- [PASS/FAIL] — No pixel values or spacing tokens [detail if FAIL]
- [PASS/FAIL] — No colour codes [detail if FAIL]
- [PASS/FAIL] — No file paths or imports [detail if FAIL]
- [PASS/FAIL] — Mock data describes WHAT not HOW [detail if FAIL]

---

## Failures Detail

[For each FAIL:]

### [Check ID]: [Check name]
**Location:** [section number and heading]
**Expected:** [what should be there]
**Found:** [what was found, or "missing"]
```

## Rules

1. Report only. Never edit the spec. Cite section numbers and quote text in failures.
2. Only check what skills define. No opinions on domain accuracy or writing quality.
3. Judge content, not formatting. Correct info in non-standard markdown = PASS. Perfect formatting with empty content = FAIL.
4. All checks are binary PASS/FAIL. No warnings or partial credit.
5. Domain accuracy is out of scope. Structural and rule conformance only.
