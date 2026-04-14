# Phase 1 Conformance Report

**Spec:** `team-manager-spec.md`
**Widget Name:** Team Manager
**Widget Kind:** Window (Feature Window)
**Date:** 2026-04-14

## Summary

| Result | Count |
|--------|-------|
| PASS | 19 |
| FAIL | 1 |
| **Total** | **20** |

**Verdict: NON-CONFORMING**

---

## Results

### B: Header Metadata

- B1: PASS — Widget name in top-level heading
- B2: PASS — Version field present (`1.0.0`)
- B3: PASS — Status field present (`Draft`)
- B4: PASS — Last Updated field present (`2026-04-14`)
- B5: PASS — Reference field present (`Tercen API — teamService, userService (sci_tercen_client)`)
- B6: PASS — Widget kind explicitly stated (`Window (Feature Window)`)

### W: Window-Specific Checks

- W1: PASS — Identity table complete: Type ID (`teamManager`), Type Colour (`#FF0000`), Initial Label ("Team Manager"), Label Updates ("None — label is always 'Team Manager'") all present
- W2: PASS — All toolbar actions fully specified: Position, Control, Type, Tooltip, Enabled When, and Action columns present for all three actions (Create Team, Delete, Sort)
- W3: PASS — All four body states addressed: Loading (spinner on fetch), Empty (no collaborative teams, with icon + message + Create Team action), Active (master-detail accordion list, references §2.5), Error (server error message + Retry button)
- W4: PASS — EventBus communication defined with explicit channel names: outbound on `window.intent`, inbound on `window.{id}.command`; both tables complete
- W5: PASS — Data sources defined in §1.4 with service/method and SDUI template mapping table
- W6: PASS — Mock data section describes required data volume (3–5 teams), privilege coverage, member count range, edge case (single-member team), and mock EventBus behaviour (standard focus/blur only)
- W7: PASS — Out of scope explicitly names Frame concerns: "Tab management, layout, or theme control (Frame concerns)"
- W8: FAIL — Type Colour `#FF0000` (Red) and window type "Team Manager" do not appear in the window type colour assignment table

### No Implementation Detail

- PASS — No code
- PASS — No framework references
- PASS — No pixel values or spacing tokens
- PASS — No colour codes (Type Colour hex values in the identity table are a required structural declaration, not a styling instruction)
- PASS — No file paths or imports
- PASS — Mock data describes WHAT not HOW

---

## Failures Detail

### W8: Window type from colour table

**Location:** Spec header (`**Type Colour:** \`#FF0000\` (Red)`) and §2.2 Identity table  
**Expected:** The window type and its hex colour must both appear in the colour assignment table defined in `template-window.md`. The approved window types and their colours are:

| Window Type | Hex |
|---|---|
| Home | — (multi) |
| File Navigator | `#FFBF00` |
| Chat | `#00FFFF` |
| Workflow | `#9333EA` |
| Document | `#FF8200` |
| Data Viewer | `#0099FF` |
| Visualization | `#66FF7F` |
| Audit Trail | `#0D9488` |

**Found:** Window Type "Team Manager" with Type Colour `#FF0000` (Red). Neither the type name nor the hex value appears in the table. `#FF0000` is not assigned to any window type.

**Required action:** Either (a) map Team Manager to an existing window type from the table (the most appropriate fit given its administrative nature would need agreement — no obvious match exists), or (b) extend the colour assignment table with a new approved entry for Team Manager before this spec can be marked conforming. This requires a decision outside the spec itself.
