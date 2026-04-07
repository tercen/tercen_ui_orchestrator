/// Server-Driven UI framework.
///
/// Provides widget registry, SDUI renderer, EventBus, and window manager
/// for composing Flutter UIs from JSON schemas.
library sdui;

// Error reporting
export 'src/error_reporter.dart';

// Event Bus
export 'src/event_bus/event_bus.dart';
export 'src/event_bus/event_payload.dart';

// Schema
export 'src/schema/sdui_node.dart';
export 'src/schema/layout_operation.dart';
export 'src/schema/prop_converter.dart';

// Registry
export 'src/registry/widget_registry.dart';
export 'src/registry/widget_metadata.dart';
export 'src/registry/builtin_widgets.dart';

// Renderer
export 'src/renderer/sdui_render_context.dart';
export 'src/renderer/sdui_renderer.dart';
export 'src/renderer/template_resolver.dart';
export 'src/renderer/json_path_resolver.dart';
export 'src/renderer/error_boundary.dart';

// Intent routing
export 'src/intent/intent_router.dart';

// Window / Pane
export 'src/window/window_manager.dart';
export 'src/window/window_state.dart';
export 'src/window/window_chrome.dart';
export 'src/window/floating_window.dart';
export 'src/window/pane_state.dart';
export 'src/window/pane_chrome.dart';

// Theme
export 'src/theme/sdui_theme.dart';

// Overlays
export 'src/overlay/toast_overlay.dart';
export 'src/overlay/popup_overlay.dart';

// Contracts
export 'src/contracts/event_contracts.dart';
export 'src/contracts/contract_registry.dart';
export 'src/contracts/contract_bus.dart';

// State
export 'src/state/state_manager.dart';

// Context
export 'src/sdui_context.dart';
