---
name: setup-project
description: Set up a new Tercen window/header widget project. Creates the project directory structure and prepares for Phase 1 spec writing.
disable-model-invocation: true
argument-hint: "[widget-name]"
---

Set up a new Tercen window/header widget project called `$ARGUMENTS`.

## Steps

### 1. Determine paths
- **Widget name:** `$ARGUMENTS` (snake_case)
- **Target directory:** `widgets/${ARGUMENTS}/`

### 2. Validate name
Must be snake_case. Must not conflict with existing `widgets/` directory.

### 3. Ask for description
Ask user for a one-line description of the widget.

### 4. Create directories
- `widgets/${ARGUMENTS}/`
- `widgets/${ARGUMENTS}/_mock/`
- `widgets/${ARGUMENTS}/_fixtures/`
- `_issues/` (if not exists)
- `_local/` (if not exists)

### 5. Create spec placeholder
Create `widgets/${ARGUMENTS}/${ARGUMENTS}-spec.md`:
```markdown
# ${ARGUMENTS} — Functional Spec

**Kind:** window
**Status:** draft

## 1. Overview

[To be filled in during Phase 1]
```

### 6. Create session log (if needed)
If `_issues/session-log.md` does not exist, create:
```markdown
# Session Log — tercen_ui_widgets

Issues, workarounds, and insights captured during development.
Tags: [skill-gap] [sdk-issue] [workaround] [fixed] [pattern]
```

### 7. Prompt user

> Project `${ARGUMENTS}` is set up as a **window** widget. Before starting Phase 1:
> 1. Add beginning materials to `widgets/${ARGUMENTS}/` — screenshots, data files, existing code, documentation.
> 2. When ready, run `/run-phase 1` to start the functional spec.

## Do NOT
- Start building the widget
- Write any application code
- Run flutter commands
