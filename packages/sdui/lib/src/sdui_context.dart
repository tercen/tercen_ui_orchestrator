import 'package:flutter/widgets.dart';

import 'contracts/contract_bus.dart';
import 'contracts/contract_registry.dart';
import 'event_bus/event_bus.dart';
import 'intent/intent_router.dart';
import 'registry/builtin_widgets.dart';
import 'registry/widget_registry.dart';
import 'renderer/sdui_render_context.dart';
import 'renderer/template_resolver.dart';
import 'theme/sdui_theme.dart';
import 'window/window_manager.dart';

/// Top-level SDUI context: owns the EventBus, WidgetRegistry, WindowManager,
/// and IntentRouter. Created once at app startup. Passed down via InheritedWidget.
class SduiContext {
  final EventBus eventBus;
  final WidgetRegistry registry;
  final SduiRenderContext renderContext;
  final WindowManager windowManager;
  final IntentRouter intentRouter;
  final ContractRegistry? contractRegistry;

  SduiContext._({
    required this.eventBus,
    required this.registry,
    required this.renderContext,
    required this.windowManager,
    required this.intentRouter,
    this.contractRegistry,
  });

  /// Convenience accessor for the contract bus (if configured).
  ContractBus? get contractBus => renderContext.contractBus;

  factory SduiContext.create({
    SduiTheme? theme,
    ContractRegistry? contractRegistry,
  }) {
    final eventBus = EventBus();
    final registry = WidgetRegistry();
    final templateResolver = TemplateResolver();

    ContractBus? contractBus;
    if (contractRegistry != null) {
      contractBus = ContractBus(eventBus: eventBus, registry: contractRegistry);
    }

    final renderContext = SduiRenderContext(
      eventBus: eventBus,
      templateResolver: templateResolver,
      theme: theme ?? const SduiTheme.light(),
      contractBus: contractBus,
    );

    registerBuiltinWidgets(registry);

    final windowManager = WindowManager(
      eventBus: eventBus,
      registry: registry,
      renderContext: renderContext,
    );

    final intentRouter = IntentRouter(
      eventBus: eventBus,
      registry: registry,
    )..start();

    return SduiContext._(
      eventBus: eventBus,
      registry: registry,
      renderContext: renderContext,
      windowManager: windowManager,
      intentRouter: intentRouter,
      contractRegistry: contractRegistry,
    );
  }

  void dispose() {
    intentRouter.dispose();
    windowManager.dispose();
    renderContext.contractBus?.dispose();
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
