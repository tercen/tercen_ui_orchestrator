# Tercen Flutter Skills

Build Tercen Flutter web widgets in 3 phases. Each phase uses a skill that dispatches by widget kind.

## Widget Kinds

| Kind | Layout | Use case |
| ---- | ------ | -------- |
| **Panel** | Two-panel: left controls + main content | Visualization, interactive data display, write-back |
| **Runner** | Three-panel: status + header + content | Workflow managers with run history and execution |
| **Window** | Feature window embedded in UI orchestrator | LLM interaction context, in-app tools |

Skeletons for each kind live in `skeletons/{kind}/`.

## Quick Start

1. Run `/setup-project widget_name` to create a new project from a skeleton
2. Add beginning materials (screenshots, data, docs) to the project
3. Run `/run-phase 1` to write the functional spec
4. Run `/run-phase 2` to build the mock widget
5. Run `/run-phase 3` to integrate with Tercen

## Phases

| Phase | What happens | Skill | Input | Output |
| ----- | ------------ | ----- | ----- | ------ |
| 1 | Write functional spec | `phase-1-functional-spec` | User requirements, screenshots, existing code | Functional spec markdown document |
| 2 | Build mock widget | `phase-2-mock-build` | Functional spec + `skeletons/{kind}/` | Running Flutter widget with mock data |
| 3 | Connect to Tercen | `phase-3-tercen-integration` | Working mock widget + taskId/projectId | Deployed widget in Tercen |

Each skill dispatches internally by widget kind — no separate skill variants needed.

## Project Structure

```text
tercen-flutter-skills/
├── skeletons/
│   ├── panel/           # Panel widget skeleton (two-panel layout)
│   ├── runner/          # Runner widget skeleton (three-panel layout)
│   └── window/          # Window widget skeleton (feature window)
├── _references/
│   ├── global-rules.md  # Shared rules for all widget kinds
│   ├── panel-design.md  # Panel design constraints
│   ├── runner-design.md # Runner design constraints
│   └── window-design.md # Window design constraints
├── .claude/
│   ├── skills/          # Phase skills (dispatch by kind)
│   └── agents/          # Agent definitions (spec-writer, mock-builder, reviewer, integrator)
└── _feedback/           # Post-build feedback for skill improvement
```

## Rules

- **One skill per session.** Do not load multiple skills.
- **Phase 1 output bridges to Phase 2.** The functional spec markdown document.
- **Phase 2 output bridges to Phase 3.** The working mock widget.
- **Do not modify the skeleton structure.** Copy it, rename it, replace placeholders. Do not restructure the shell, panels, or theme system.
- **Skills are read-only during builds.** Claude must never modify skill files while building a widget.

## What's in the Skeletons

### Panel Skeleton

- App shell with conditional top bar
- Left panel with collapse, resize, sections, header/footer
- Light/dark theme with Tercen brand colours
- Provider state management with wiring examples
- GetIt dependency injection with mock/real switching
- INFO section with GitHub link
- Deployment files (operator.json, index.html, .gitignore)

### Runner Skeleton

- Three-panel layout: Status Panel (left) + Header Panel (top-right) + Content Panel (main-right)
- Status Panel with 5 sections: ACTIONS, STATUS, CURRENT RUN, HISTORY, INFO
- Header Panel with two-zone layout (Actions | Theme/Exit)
- Content Panel with Input and Display modes
- Running overlay with AbsorbPointer + dimming
- AppStateProvider state machine (Running/Waiting)
- StatusIndicator with 6 states

### Window Skeleton

- Feature window shell with toolbar and body area
- Event bus for communication with UI orchestrator
- Minimal chrome for embedding context

Run any skeleton: `cd skeletons/{kind} && flutter run -d chrome`

## Feedback Process

1. **During a build**: If Claude encounters a skill gap, it notes it in `_issues/session-log.md`
2. **After the build**: Copy feedback into this repo's `_feedback/` directory
3. **Dedicated session**: Open a session in this repo and say "review feedback and update skills"

## Style Guide

The Tercen style guide is baked into the skeletons. Do not clone or read it during builds. It is maintained separately at <https://github.com/tercen/tercen-style>.
