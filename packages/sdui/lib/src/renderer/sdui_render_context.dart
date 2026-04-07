import 'dart:async';

import '../contracts/contract_bus.dart';
import '../event_bus/event_bus.dart';
import '../state/state_manager.dart';
import '../theme/sdui_theme.dart';
import 'template_resolver.dart';

/// Callback that executes a service call and returns the result.
/// The result is either a List<Map> (for list methods) or a Map (for single object).
typedef ServiceCaller = Future<dynamic> Function(
    String service, String method, List<dynamic> args);

/// Provider for the chat WebSocket stream. Returns access to the chat message
/// stream, a send function, and a connection status check.
typedef ChatStreamProvider = ({
  Stream<Map<String, dynamic>> messages,
  void Function(String text) send,
  bool Function() isConnected,
  void Function() resetSession,
});

/// Provider for the task monitor stream. Exposes a stream of task snapshots,
/// a cancel function, and a running-check.
typedef TaskStreamProvider = ({
  Stream<List<Map<String, dynamic>>> tasks,
  void Function(String taskId) cancel,
  bool Function() hasRunning,
});

/// Shared context available to all SDUI widget builders.
/// Provided via InheritedWidget (SduiScope) in the widget tree.
class SduiRenderContext {
  final EventBus eventBus;
  final TemplateResolver templateResolver;

  /// Active SDUI theme. Mutable so theme can be switched at runtime.
  SduiTheme theme;

  /// Optional service caller for data-driven widgets.
  /// Null until auth completes — widgets degrade gracefully.
  ServiceCaller? serviceCaller;

  /// Optional chat stream provider for the ChatStream behavior widget.
  /// Bridges the orchestrator's WebSocket chat into SDUI scope.
  ChatStreamProvider? chatStreamProvider;

  /// Optional task stream provider for the TaskStream scope builder.
  /// Bridges the orchestrator's TaskMonitorService into SDUI scope.
  TaskStreamProvider? taskStreamProvider;

  /// Current StateManager, set by _StateManagerHost during template re-render.
  /// Read by ForEach to check selection state per item.
  /// Not a listener — ForEach evaluates selection inline during its render pass.
  StateManager? stateManager;

  /// Optional contract bus for typed inter-widget communication.
  /// Null if the host app does not use contracts.
  ContractBus? contractBus;

  /// Base URL for resolving relative asset URLs in catalog widgets.
  /// Set when a catalog is loaded from a known origin (server or GitHub).
  String? catalogBaseUrl;

  SduiRenderContext({
    required this.eventBus,
    required this.templateResolver,
    required this.theme,
    this.serviceCaller,
    this.chatStreamProvider,
    this.taskStreamProvider,
    this.contractBus,
  });

  /// Set user context values accessible to templates via {{context.key}}.
  /// Call after auth with e.g. {'username': 'alice', 'userId': '123'}.
  void setUserContext(Map<String, dynamic> ctx) {
    for (final entry in ctx.entries) {
      templateResolver.set(entry.key, entry.value);
    }
  }
}
