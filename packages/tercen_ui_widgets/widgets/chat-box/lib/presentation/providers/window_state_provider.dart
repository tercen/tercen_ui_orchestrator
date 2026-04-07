import 'dart:async';

import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/window_identity.dart';
import '../../domain/services/data_service.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/window_channels.dart';

/// Manages the window's content state and identity.
///
/// Publishes window intents to the EventBus so the frame can act on them.
/// Subscribes to the per-window command channel for focus/blur messages.
///
/// Extend this provider for your window type to add domain-specific state.
class WindowStateProvider extends ChangeNotifier {
  final DataService _dataService = serviceLocator<DataService>();
  final EventBus eventBusInstance = serviceLocator<EventBus>();

  /// The window's identity -- type, colour, label.
  final WindowIdentity identity;

  /// Unique instance id used for per-window command channels.
  final String windowId;

  /// Current body content state.
  ContentState _contentState = ContentState.empty;
  ContentState get contentState => _contentState;
  set contentStateValue(ContentState value) {
    _contentState = value;
    notifyListeners();
  }

  /// Data loaded from the service.
  List<ChatSession>? _data;
  List<ChatSession>? get data => _data;

  /// Error message when in error state.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  set errorMessageValue(String? value) {
    _errorMessage = value;
  }

  /// Whether this window currently has frame focus.
  bool _focused = false;
  bool get focused => _focused;
  set focusedValue(bool value) {
    _focused = value;
    notifyListeners();
  }

  StreamSubscription<EventPayload>? _commandSubscription;

  WindowStateProvider({
    required this.identity,
    required this.windowId,
  }) {
    _commandSubscription = eventBusInstance
        .subscribe(WindowChannels.commandChannel(windowId))
        .listen(_handleCommand);
  }

  // -- Inbound command handling --

  void _handleCommand(EventPayload payload) {
    switch (payload.type) {
      case WindowChannels.typeFocus:
        _focused = true;
        notifyListeners();
        break;
      case WindowChannels.typeBlur:
        _focused = false;
        notifyListeners();
        break;
    }
  }

  // -- Outbound intents --

  /// Publish an intent to the frame via the shared EventBus.
  void publishIntent(String type, [Map<String, dynamic> extra = const {}]) {
    eventBusInstance.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: type,
        sourceWidgetId: windowId,
        data: {'windowId': windowId, ...extra},
      ),
    );
  }

  /// Request the frame to close this window.
  void requestClose() => publishIntent(WindowChannels.typeClose);

  /// Request the frame to maximize this window.
  void requestMaximize() => publishIntent(WindowChannels.typeMaximize);

  /// Request the frame to restore this window from maximized.
  void requestRestore() => publishIntent(WindowChannels.typeRestore);

  /// Request the frame to open a resource in a new window.
  void requestOpenResource({
    required String resourceType,
    required String resourceId,
  }) {
    publishIntent(WindowChannels.typeOpenResource, {
      'resourceType': resourceType,
      'resourceId': resourceId,
    });
  }

  // -- State management --

  /// Transition to a content state.
  void setContentState(ContentState state) {
    _contentState = state;
    notifyListeners();
  }

  /// Update the window label and notify the frame.
  void updateLabel(String newLabel) {
    identity.label = newLabel;
    notifyListeners();
    publishIntent(WindowChannels.typeContentChanged, {'label': newLabel});
  }

  /// Load data from the service.
  /// Transitions: empty/error -> loading -> active/error.
  Future<void> loadData() async {
    _contentState = ContentState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _dataService.loadData();
      _contentState = ContentState.active;
    } catch (e) {
      _errorMessage = e.toString();
      _contentState = ContentState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    super.dispose();
  }
}
