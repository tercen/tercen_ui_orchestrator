---
name: phase-5-review
description: Phase 5 — Review a catalog.json integration for conformance against SDUI rules, data connections, and semantic token usage. Runs as a read-only reviewer agent that produces a PASS/FAIL conformance report. Use after Phase 4 catalog authoring is complete. Assumes Phase 2 conformance has already been verified.
argument-hint: "[path to catalog.json] [path to functional spec]"
disable-model-invocation: true
---

**READ-ONLY — do not modify this file.**

Window/header widgets only. Always dispatch to `checks-catalog.md`.

Load and follow `checks-catalog.md` in this skill directory. It has its own complete workflow, check groups, and report format.

## Inputs

- **catalog.json entry** — Phase 4 output
- **Functional spec** — Phase 1 output
- **HTML mock** — Phase 2 output (`_mock/`)

Ask user if missing.

## Workflow

1. Load `checks-catalog.md` from this skill directory
2. Follow its workflow, check groups, and report format exactly
3. Save report to `_local/review-5.md`

## Rules

1. Read spec first.
2. Report only. Never edit application files or catalog.json.
3. Only check what `checks-catalog.md` defines.
4. Cite file paths in failures. Do not re-check Phase 2 requirements.
