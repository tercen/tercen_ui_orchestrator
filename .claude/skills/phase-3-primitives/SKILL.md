---
name: phase-3-primitives
description: Fill SDUI primitive gaps identified in the Phase 2 gap report. Creates or extends primitives in the sdui package, updates tokens if needed.
argument-hint: "[path to gap-report.md]"
disable-model-invocation: true
---

**READ-ONLY. Do NOT modify. Log gaps to `_issues/session-log.md` and continue.**

## Input

Gap report at `packages/tercen_ui_widgets/widgets/{name}/_mock/gap-report.md`. If no gaps, skip to Phase 4.

## Gap Resolution by Category

### Primitive Gap (new primitive)
1. Read existing patterns in `packages/sdui/lib/src/registry/builtin_widgets.dart` and `behavior_widgets.dart`
2. Create builder: use `PropConverter.to<T>()` for props, `_resolveColor()` for colours, `ctx.theme` for tokens. Stateful: follow `_SduiCheckbox`/`_SduiSwitch` pattern. Publish to EventBus on interaction.
3. Register with `registry.register(name, builder, metadata: WidgetMetadata(...))`
4. Declare ALL handled props in `WidgetMetadata.props`
5. Run `cd packages/sdui && dart analyze lib/`

### Variant Gap (new variant of existing)
1. Locate existing builder
2. Add variant as prop option or new registered type
3. Update `WidgetMetadata.props`
4. Run `cd packages/sdui && dart analyze lib/`

### Prop Gap (missing prop)
1. Add prop handling to builder
2. Add to `WidgetMetadata.props`
3. Run `cd packages/sdui && dart analyze lib/`

### Style Gap (missing token)
1. Update `SduiTheme.dart`
2. Update `../tercen-style/tokens.meta.json` with approval flag
3. Regenerate: `cd packages/sdui && flutter test tool/run_export.dart`
4. Regenerate: `cd ../tercen-style && node scripts/generate-style-guide.js`

### Composition Question (achievable with existing)
1. Document composition pattern in `gap-report.md`
2. No code changes needed

## After All Gaps Filled

1. `cd packages/sdui && dart analyze lib/` — must pass with no errors
2. `cd packages/sdui && flutter test tool/run_export.dart > ../tercen-style/theme-export.json`
3. `cd ../tercen-style && node scripts/generate-style-guide.js`

## Checklist

- [ ] All primitive gaps created and registered
- [ ] All variant/prop gaps filled
- [ ] All style gaps resolved
- [ ] `dart analyze` passes on sdui package
- [ ] `theme-export.json` regenerated
- [ ] `style-guide.html` regenerated
- [ ] `gap-report.md` updated with resolutions
