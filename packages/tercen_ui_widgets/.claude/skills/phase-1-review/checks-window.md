# Phase 1 Review — Window Widget Checks

**READ-ONLY. Do NOT modify this file.**

These checks apply to **window** kind widgets. They are run in addition to the shared checks defined in `SKILL.md`.

Reference template: `.claude/skills/phase-1-functional-spec/template-window.md`

---

## Check Group W: Window-Specific Checks

### W1: Identity table complete

The spec must include an Identity table (Section 2.2) with all four properties:

| Property | Check |
|----------|-------|
| Type ID | Must be a specific string value (e.g., `dataViewer`, `chat`) — not generic |
| Type Colour | Must be a hex value from the window type colour table |
| Initial Label | Must be specified |
| Label Updates | Must state when/how the label changes, or "Does not update" |

### W2: Toolbar actions fully specified

Every toolbar action in Section 2.3 must have all columns filled:

- Position (number or `trailing`)
- Control name
- Type (`icon-only`, `icon+label`, `search`, `dropdown`)
- Tooltip text
- Enabled condition
- Action (what happens on click)

### W3: All four body states addressed

Section 2.4 must address all four states: Loading, Empty, Active, Error.

- Each state must describe what triggers it and what the user sees
- If a state is intentionally unused, it must say "Not applicable" with a justification
- Active state must describe content layout and user interactions

### W4: EventBus communication with explicit channel names

Section 2.5 must define:

- **Outbound intents** — each with explicit channel name (e.g., `window.intent`, or a custom channel), intent type, payload, and trigger condition
- **Inbound subscriptions** — each with explicit channel name, event type, and what the window does in response
- Standard intents (`close`, `maximize`, `restore`, `contentChanged`) are inherited from the skeleton — the spec only needs to list `openResource` and custom channels

### W5: Data source defined

Section 1.4 must list what data the window fetches, from what service/method or EventBus channel.

### W6: Mock data specified

Section 3 must describe:

- What mock data is needed (structure, volume, edge cases)
- How mock data maps to the data sources in Section 1.4
- What mock EventBus behaviour is needed for standalone development

### W7: Out of scope lists Frame concerns

The spec's Out of Scope (Section 1.3) must explicitly exclude Frame concerns: tab rendering, panel layout, theme toggle, window creation, tab drag/reorder.

### W8: Window type from colour table

The spec header must state a Window Type and Type Colour that match the colour assignment table in the template.

---

## Report Sections

Include these checks in the conformance report (in addition to shared groups from SKILL.md):

```
### W: Window-Specific Checks
- W1: [PASS/FAIL] -- Identity table complete [detail if FAIL]
- W2: [PASS/FAIL] -- Toolbar actions fully specified [detail if FAIL]
- W3: [PASS/FAIL] -- All four body states addressed [detail if FAIL]
- W4: [PASS/FAIL] -- EventBus with explicit channel names [detail if FAIL]
- W5: [PASS/FAIL] -- Data source defined [detail if FAIL]
- W6: [PASS/FAIL] -- Mock data specified [detail if FAIL]
- W7: [PASS/FAIL] -- Out of scope lists Frame concerns [detail if FAIL]
- W8: [PASS/FAIL] -- Window type from colour table [detail if FAIL]
```
