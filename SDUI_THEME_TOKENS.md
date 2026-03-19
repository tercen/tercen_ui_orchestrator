# SDUI Theme Token Specification

This document defines the complete set of theme tokens used by the SDUI system. These tokens are the contract between the orchestrator (which provides values) and the SDUI widgets (which consume them).

---

## Design Principles

1. **Theme is data, not code.** Theme values are defined as configuration at the orchestrator level (e.g., a `theme.json` file or database record), not hardcoded in Dart.
2. **Widget libraries are theme-agnostic.** Widget templates never specify colors — they reference semantic tokens (`"primary"`, `"surface"`) and the orchestrator fills in the actual values.
3. **The AI server doesn't care about theme.** It composes widget trees without color props. The SDUI renderer applies theme defaults automatically.
4. **Layered responsibility:**
   - **sdui package** — defines `SduiTheme` structure, `fromJson()`, token resolution
   - **orchestrator** — owns the actual theme values (per deployment / per tenant)
   - **widget library** — never specifies colors, only uses semantic tokens if needed

---

## Token Categories

### 1. Color Tokens (17 tokens)

#### Surfaces — background colors at different levels

| Token | Purpose | Example Usage |
|---|---|---|
| `background` | Lowest-level background (scaffold, workspace) | Workspace panel, scaffold background |
| `surface` | Mid-level surfaces (cards, panels, containers) | Card widget, chat panel, data containers |
| `surfaceVariant` | Elevated surfaces (toolbars, headers, title bars) | Toolbar, window chrome, title bar |

#### Content — text and icon colors at 3 emphasis levels

| Token | Purpose | Example Usage |
|---|---|---|
| `onSurface` | High emphasis — primary text, active icons | Body text, icon default color, input text |
| `onSurfaceVariant` | Medium emphasis — secondary text, subtitles | Subtitle text, inactive icons, window title |
| `onSurfaceMuted` | Low emphasis — hints, placeholders, disabled | Hint text, placeholder text, disabled controls, captions |

#### Interactive — accent and action colors

| Token | Purpose | Example Usage |
|---|---|---|
| `primary` | Brand/accent color — links, active buttons, focus | Send button, active spinner, Placeholder accent, links |
| `onPrimary` | Text/icon on a primary-colored background | Button label on primary background |

#### Feedback — status indication colors

| Token | Purpose | Example Usage |
|---|---|---|
| `error` | Error text and icons | Error messages, error icon, disconnected indicator |
| `errorContainer` | Error background (subtle) | Error bar background, error box background |
| `warning` | Warning text and icons | Warning messages, unknown widget indicator |
| `warningContainer` | Warning background (subtle) | Warning box background |
| `success` | Success/positive states | Connected indicator, success messages |
| `info` | Informational states | Info-severity error bar entries |

#### Structural — borders and dividers

| Token | Purpose | Example Usage |
|---|---|---|
| `border` | Subtle outlines and window borders | Window chrome border, container outlines |
| `divider` | Horizontal/vertical separators | Shell screen dividers, section separators |

---

### 2. Typography Tokens (4 tokens)

Font sizes only — font family is inherited from the Material theme.

| Token | Default | Purpose |
|---|---|---|
| `bodySize` | 14 | Standard body text (Text widget default) |
| `captionSize` | 12 | Small text, labels, loading indicator text |
| `titleSize` | 16 | Section titles, card headers |
| `headingSize` | 20 | Page headings, large titles |

---

### 3. Spacing Tokens (5 tokens)

Consistent spacing scale used for padding, margins, and gaps.

| Token | Default | Purpose |
|---|---|---|
| `xs` | 4 | Tight spacing (icon padding, chrome buttons) |
| `sm` | 8 | Standard small spacing (grid gaps, list padding) |
| `md` | 12 | Medium spacing (content padding, section gaps) |
| `lg` | 16 | Large spacing (card padding, panel padding) |
| `xl` | 24 | Extra large spacing (page margins, major sections) |

---

### 4. Elevation Tokens (3 tokens)

Material elevation levels.

| Token | Default | Purpose |
|---|---|---|
| `none` | 0 | Flat surfaces |
| `low` | 1 | Subtle elevation (Card widget default) |
| `medium` | 4 | Prominent elevation (floating windows, dialogs) |

---

### 5. Radius Tokens (3 tokens)

Border radius scale.

| Token | Default | Purpose |
|---|---|---|
| `small` | 4 | Subtle rounding (error boxes, skeleton pulse) |
| `medium` | 8 | Standard rounding (cards, windows, input fields) |
| `large` | 12 | Prominent rounding (dialogs, large containers) |

---

## Widget-to-Token Mapping

Every SDUI widget maps to these tokens. This table shows what each widget uses by default (when no explicit color/size is specified in props).

| Widget | Tokens Used |
|---|---|
| **Text** | `onSurface` (color), `bodySize` (fontSize) |
| **Icon** | `onSurface` (color) |
| **Card** | `surface` (color), `low` (elevation) |
| **Container** | No default color (transparent) |
| **Placeholder** | `primary` (accent color) |
| **LoadingIndicator** | `primary` (spinner/bar), `onSurfaceVariant` (text), `onSurfaceMuted` (skeleton) |
| **Grid** | `sm` (spacing) |
| **Padding** | `sm` (default padding value) |
| **DataSource** (error) | `error`/`errorContainer` (error box), `primary` (spinner), `onSurfaceMuted` (placeholder) |
| **ForEach** (error) | `error`/`errorContainer` (error box), `onSurfaceMuted` ("No data" text) |
| **WindowChrome** | `surfaceVariant` (background, title bar), `border` (outline), `onSurfaceVariant` (title), `onSurfaceMuted` (buttons) |
| **Renderer** (error) | `error` (error box), `warning` (unknown widget box) |

---

## JSON Format

Theme values are provided as a JSON object. The orchestrator loads this from its configuration (file, database, or API).

```json
{
  "colors": {
    "primary": "#1976D2",
    "onPrimary": "#FFFFFF",
    "surface": "#FAFAFA",
    "surfaceVariant": "#EEEEEE",
    "background": "#F5F5F5",
    "onSurface": "#DD000000",
    "onSurfaceVariant": "#8A000000",
    "onSurfaceMuted": "#61000000",
    "border": "#1F000000",
    "divider": "#1F000000",
    "error": "#D32F2F",
    "errorContainer": "#FFEBEE",
    "onError": "#FFFFFF",
    "warning": "#F57C00",
    "warningContainer": "#FFF3E0",
    "success": "#388E3C",
    "info": "#1976D2"
  },
  "typography": {
    "bodySize": 14,
    "captionSize": 12,
    "titleSize": 16,
    "headingSize": 20
  },
  "spacing": {
    "xs": 4,
    "sm": 8,
    "md": 12,
    "lg": 16,
    "xl": 24
  },
  "elevation": {
    "none": 0,
    "low": 1,
    "medium": 4
  },
  "radius": {
    "small": 4,
    "medium": 8,
    "large": 12
  }
}
```

Color format: `#RRGGBB` for opaque colors, `#AARRGGBB` for colors with alpha.

---

## Presets

Two presets are built into the sdui package as fallbacks:

- **`SduiTheme.light()`** — standard light palette (light backgrounds, dark text, blue accents)
- **`SduiTheme.dark()`** — dark palette matching the original hardcoded look (dark backgrounds, light text, blue accents)

These are used when the orchestrator does not provide a custom theme configuration.

---

## Semantic Color Resolution in Widget Props

When a widget prop accepts a color value (e.g., `Text.color`, `Container.color`), the SDUI renderer resolves it in this order:

1. **Hex string** — `#RRGGBB` or `#AARRGGBB` (literal color)
2. **Named Material color** — `red`, `blue`, `green`, `orange`, `purple`, `white`, `black`, `grey`
3. **Semantic theme token** — `primary`, `surface`, `error`, `onSurface`, etc.
4. **null** — widget applies its theme default

In normal usage, widget templates should **not** specify colors at all. The renderer applies appropriate theme defaults. Explicit colors should only be used for rare cases where a specific literal color is needed regardless of theme.
