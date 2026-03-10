import '../event_bus/event_bus.dart';
import 'template_resolver.dart';

/// Shared context available to all SDUI widget builders.
/// Provided via InheritedWidget (SduiScope) in the widget tree.
class SduiRenderContext {
  final EventBus eventBus;
  final TemplateResolver templateResolver;

  const SduiRenderContext({
    required this.eventBus,
    required this.templateResolver,
  });
}
