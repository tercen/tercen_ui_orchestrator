import '../event_bus/event_bus.dart';
import 'template_resolver.dart';

/// Callback that executes a service call and returns the result.
/// The result is either a List<Map> (for list methods) or a Map (for single object).
typedef ServiceCaller = Future<dynamic> Function(
    String service, String method, List<dynamic> args);

/// Shared context available to all SDUI widget builders.
/// Provided via InheritedWidget (SduiScope) in the widget tree.
class SduiRenderContext {
  final EventBus eventBus;
  final TemplateResolver templateResolver;

  /// Optional service caller for data-driven widgets.
  /// Null until auth completes — widgets degrade gracefully.
  ServiceCaller? serviceCaller;

  SduiRenderContext({
    required this.eventBus,
    required this.templateResolver,
    this.serviceCaller,
  });
}
