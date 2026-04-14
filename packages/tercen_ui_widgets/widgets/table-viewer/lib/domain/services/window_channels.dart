/// Channel names for window <-> frame communication via EventBus.
///
/// Follows the orchestrator's `system.*` naming convention.
/// See: tercen_ui_orchestrator — system.layout.op, system.data.*, etc.
///
/// ## Outbound (window publishes)
///
/// Windows publish intents to these channels. The frame subscribes and acts.
///
/// | Channel                | EventPayload.type  | data                                    |
/// |------------------------|--------------------|-----------------------------------------|
/// | `window.intent`        | `close`            | `{windowId}`                            |
/// | `window.intent`        | `maximize`         | `{windowId}`                            |
/// | `window.intent`        | `restore`          | `{windowId}`                            |
/// | `window.intent`        | `contentChanged`   | `{windowId, label}`                     |
/// | `window.intent`        | `openResource`     | `{windowId, resourceType, resourceId}`  |
///
/// ## Inbound (frame publishes, window subscribes)
///
/// The frame sends commands to individual windows or broadcasts globally.
///
/// | Channel                      | EventPayload.type  | data              |
/// |------------------------------|--------------------|--------------------|
/// | `window.{id}.command`        | `focus`            | `{}`               |
/// | `window.{id}.command`        | `blur`             | `{}`               |
/// | `system.theme.changed`       | `themeChanged`     | `{mode}`           |
///
class WindowChannels {
  WindowChannels._();

  // -- Outbound (window -> frame) --

  /// Single channel for all window intents. Frame subscribes to this.
  static const String windowIntent = 'window.intent';

  // -- Inbound (frame -> window) --

  /// Per-window command channel. Frame publishes focus/blur here.
  /// Use [commandChannel] to build the full channel name.
  static const String _commandSuffix = 'command';

  /// Global theme broadcast channel.
  static const String themeChanged = 'system.theme.changed';

  /// Build the command channel for a specific window instance.
  /// Returns `window.{windowId}.command`.
  static String commandChannel(String windowId) =>
      'window.$windowId.$_commandSuffix';

  // -- EventPayload.type values --

  static const String typeClose = 'close';
  static const String typeMaximize = 'maximize';
  static const String typeRestore = 'restore';
  static const String typeContentChanged = 'contentChanged';
  static const String typeOpenResource = 'openResource';
  static const String typeFocus = 'focus';
  static const String typeBlur = 'blur';
  static const String typeThemeChanged = 'themeChanged';
}
