import 'package:flutter/widgets.dart';

import 'event_bus/event_bus.dart';
import 'registry/builtin_widgets.dart';
import 'registry/widget_registry.dart';
import 'renderer/sdui_render_context.dart';
import 'renderer/template_resolver.dart';
import 'window/window_manager.dart';

/// Top-level SDUI context: owns the EventBus, WidgetRegistry, and WindowManager.
/// Created once at app startup. Passed down via InheritedWidget.
class SduiContext {
  final EventBus eventBus;
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;
  final WindowManager windowManager;

  SduiContext._({
    required this.eventBus,
    required this.registry,
    required this.renderContext,
    required this.windowManager,
  });

  factory SduiContext.create() {
    final eventBus = EventBus();
    final registry = WidgetRegistry();
    final templateResolver = TemplateResolver();
    final renderContext = SduiRenderContext(
      eventBus: eventBus,
      templateResolver: templateResolver,
    );

    registerBuiltinWidgets(registry);

    final windowManager = WindowManager(
      eventBus: eventBus,
      registry: registry,
      renderContext: renderContext,
    );

    return SduiContext._(
      eventBus: eventBus,
      registry: registry,
      renderContext: renderContext,
      windowManager: windowManager,
    );
  }

  void dispose() {
    windowManager.dispose();
    eventBus.dispose();
  }
}

/// InheritedWidget to provide SduiContext down the tree.
class SduiScope extends InheritedWidget {
  final SduiContext sduiContext;

  const SduiScope({
    super.key,
    required this.sduiContext,
    required super.child,
  });

  static SduiContext of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SduiScope>();
    assert(scope != null, 'SduiScope not found in widget tree');
    return scope!.sduiContext;
  }

  @override
  bool updateShouldNotify(SduiScope oldWidget) =>
      sduiContext != oldWidget.sduiContext;
}
