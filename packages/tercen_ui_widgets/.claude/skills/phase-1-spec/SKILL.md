---
name: phase-1-spec
description: Write a functional specification for a new Tercen window/header widget. Use when starting a new widget, converting an existing one, or when the user asks for a spec, requirements, or functional design. Produces a complete spec document with no code.
argument-hint: "[widget name or description]"
disable-model-invocation: true
---

**READ-ONLY. Do NOT modify. Log gaps to `_issues/session-log.md` and continue.**

Produce a functional spec document. Do NOT write any code.

Shared patterns: `_references/global-rules.md`.

## Widget Kind

Window/header widgets only. Kind is always **window**.

| Kind | Template File |
|------|--------------|
| window | `template-window.md` |

Load `template-window.md` from this skill directory and follow its constraints, spec template, discovery process, and checklist.

## Output Rules

- Describe WHAT, never HOW.
- No Dart/pseudo-code, no implementation approach.
- No pixel values, spacing tokens, or colour codes (exception: domain-specific like chart series colours).
- No Flutter widgets, Provider, GetIt, or framework references.
- Mock data: describe WHAT data is needed and WHERE it comes from, not how to load it.

## Question Efficiency

- 3-4 questions per round, not all at once.
- Skip questions already answered by provided material.
- Proactively identify constraint violations in existing code/UI and propose fixes.
- Consolidate related questions.
