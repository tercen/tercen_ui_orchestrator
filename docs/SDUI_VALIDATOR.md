# SDUI Template Validator

Validates widget templates for correctness against the SDUI spec.

## Quick Start

```bash
flutter test test/sdui/validator/validate_catalog_test.dart
```

This validates all widgets in `packages/tercen_ui_widgets/catalog.json` and prints a report.

## What It Checks

### 1. Structural
- Every node has `type` and `id`
- Type exists in the WidgetRegistry
- IDs are unique (static IDs only — `{{...}}` expressions are skipped)

### 2. Binding Scope
- `{{item}}` / `{{_index}}` only inside `ForEach`
- `{{data}}` / `{{loading}}` / `{{ready}}` / `{{error}}` only inside `DataSource`
- `{{state}}` only inside `StateHolder`
- `{{matched}}` only inside `ReactTo`
- `{{sorted}}` / `{{filtered}}` only inside `Sort` / `Filter`

### 3. Event Wiring
- `ReactTo` / `DataSource.refreshOn` subscribers have a matching publisher in the same template (warning if not — could be cross-widget)

### 4. Service Methods
- `DataSource` has `service` and `method` props
- Service name is a known Tercen service

### 5. Theming
- No raw hex colors (`#1E1E1E`) — use semantic tokens
- No raw `fontSize` — use `textStyle` with a token name
- Unknown color/textStyle token names flagged

### 6. ID Patterns
- IDs should use `{{widgetId}}` prefix to avoid collisions across instances
- IDs inside `ForEach` should include `{{item.X}}` for per-iteration uniqueness

### 7. Metadata Consistency
- Declared props used in template (and vice versa)
- `emittedEvents` match actual Action publishers
- Description not too short

## API Usage

```dart
import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/sdui/validator/template_validator.dart';

final registry = WidgetRegistry();
registerBuiltinWidgets(registry);
registry.loadCatalog(catalogJson);

final validator = TemplateValidator(registry: registry);

// Validate a single widget.
final results = validator.validate(metadata: meta, template: template);

// Validate an entire catalog.
final allResults = validator.validateCatalog(catalogJson);
```

## Severity Levels

- **error** — will cause runtime failure (wrong type, scope violation)
- **warning** — likely a bug (unused prop, raw hex color, missing publisher)
- **info** — style suggestion (numeric padding, ForEach ID pattern)

## Known False Positives

Widgets using orchestrator-provided scope builders (`ChatStream`, `TaskStream`) report scope errors for variables like `{{hasMessages}}`, `{{isThinking}}`, `{{runningTasks}}`. These are injected by compiled Dart widgets, not by behavior widgets in the template tree. The validator doesn't know about them.

## Files

```
lib/sdui/validator/
  template_validator.dart  — main validator (7 rule categories)
  validation_result.dart   — result types
  schema_generator.dart    — generates sdui-components.schema.json
  event_spec_generator.dart — generates sdui-events.json
test/sdui/validator/
  validate_catalog_test.dart — validates the real catalog
  generate_schema_test.dart  — generates component schema
  generate_events_test.dart  — generates event spec
```
