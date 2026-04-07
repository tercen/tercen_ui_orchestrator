# Global Rules — All Widget Kinds

> Shared reference for all skills. Applies to all widget kinds (panel, runner, window) equally.

---

## Typography Scale

All widgets use `AppTextStyles` from the skeleton. No custom font sizes.

| Token | Size | Weight | Line Height | Use |
|-------|------|--------|-------------|-----|
| h1 | 24px | 600 | 1.25 | Page titles (rare) |
| h2 | 20px | 600 | 1.25 | Content Panel headings |
| h3 | 16px | 600 | 1.25 | Results section headings, sub-headings |
| bodyLarge | 14px | 400 | 1.5 | Large body content |
| body | 13px | 400 | 1.5 | Standard body, option text, table cells |
| bodySmall | 12px | 400 | 1.5 | Helper text, hints (muted colour) |
| label | 12px | 500 | 1.5 | Control labels, chart labels, table headers |
| labelSmall | 11px | 500 | 1.5 | Compact labels |
| sectionHeader | 11px | 600 | 1.25 | UPPERCASE section titles (0.5 letter spacing) |

---

## Line Weights — `AppLineWeights`

All `strokeWidth` values must use `AppLineWeights.*` constants. No hardcoded numbers.

**UI chrome:**

| Token | Weight | Use |
|-------|--------|-----|
| lineSubtle | 1.0px | Internal cell borders in dense data tables |
| lineStandard | 1.5px | Section dividers, panel borders, card borders |
| lineEmphasis | 2.0px | Focus states, active selection borders, progress bars |

**Visualization content:**

| Token | Weight | Use |
|-------|--------|-----|
| vizGrid | 1.0px | Background grid lines, minor tick marks |
| vizAxis | 2.0px | X and Y axis lines, major tick marks |
| vizData | 2.0px | Data series lines, vectors, connectors |
| vizHighlight | 3.0px | Selected/hovered data series, emphasis lines |

---

## 11 Control Types

All widget kinds draw from the same control vocabulary. Reference the skeleton's `controls_section.dart` for implementation patterns.

| Control Type | Key Widget | Sizing Notes |
|---|---|---|
| Text input | `TextField` with `onChanged` | Standard |
| Dropdown | `DropdownButton<String>` with `onChanged` | Standard |
| Checkbox | `Checkbox` inside `SizedBox(16x16)`, `visualDensity: compact` | Compact |
| Radio | `Radio<String>` inside `SizedBox(16x16)`, `visualDensity: compact` | Compact |
| Switch/toggle | `Switch` inside `FittedBox` inside `SizedBox(36x20)` | Compact |
| Slider | `Slider` with `onChanged` | Standard |
| Range slider | `RangeSlider` with `onChanged` | Standard |
| Number input | `TextField` with `keyboardType: number`, nullable parse | Standard |
| Searchable input | `Autocomplete<String>` | Standard |
| Segmented button | `SegmentedButton<String>` | Standard |
| Multi-select chips | `Wrap` + `FilterChip` | Variable |

---

## Control Styling Pattern

Every control follows this theme-aware pattern:

```dart
final isDark = context.watch<ThemeProvider>().isDarkMode;
final labelColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

Text('Label', style: AppTextStyles.label.copyWith(color: labelColor)),
const SizedBox(height: AppSpacing.xs),
// control widget here
const SizedBox(height: AppSpacing.controlSpacing),
```

---

## Wiring Golden Rule

Every control follows one-way data flow through the provider:

```
control.onChanged → provider.setXxx(value) → notifyListeners() → Consumer rebuilds
```

All state flows through providers. No direct widget-to-widget communication.

---

## Icon Library

All widgets use **FontAwesome 6** icons (`font_awesome_flutter` package). Do not use Material Icons for UI elements.

Icon colours must use theme palette tokens only — no custom hex values:

| Context | Light token | Dark token |
|---------|-------------|------------|
| Primary/navigation | `AppColors.primary` | `AppColorsDark.primary` |
| Documents/files | `AppColors.neutral700` | `AppColorsDark.neutral300` |
| Data/tables | `AppColors.warning` | `AppColorsDark.warning` |
| Workflows/pipelines | `AppColors.info` | `AppColorsDark.info` |
| Muted/secondary | `AppColors.neutral500` | `AppColorsDark.neutral400` |
| Default UI | `AppColors.neutral600` | `AppColorsDark.neutral400` |

---

## Text Overflow Convention

Any item name in a list, tree, or table must use:

```dart
Flexible(
  child: Text(
    name,
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  ),
),
```

Never allow text to wrap or overflow its container.

---

## Inline Indicator Convention

Status badges, chips, or icons displayed after an item name should:

- Use `Flexible` (not `Expanded`) on the name text so indicators flow inline
- Add `AppSpacing.sm` padding between the name and first indicator
- NOT be pushed to the right edge with a `Spacer`

---

## Theme Rules

- Left panel and top bar / header panel: fully theme-aware (light + dark)
- Graph/chart containers: always force white background with light-mode colours
- Main panel chrome (background, status text, legends): theme-aware
- Scientific visualizations: maximum contrast, white background always
