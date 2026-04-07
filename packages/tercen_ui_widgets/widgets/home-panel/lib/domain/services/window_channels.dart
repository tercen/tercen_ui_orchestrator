/// Channel names for window <-> frame communication via EventBus.
class WindowChannels {
  WindowChannels._();

  // -- Outbound (window -> frame) --
  static const String windowIntent = 'window.intent';

  // -- Inbound (frame -> window) --
  static const String _commandSuffix = 'command';
  static const String themeChanged = 'system.theme.changed';

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
