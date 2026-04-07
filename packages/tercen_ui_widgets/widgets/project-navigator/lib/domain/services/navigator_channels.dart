/// Channel names for navigator-specific EventBus communication.
///
/// These extend the base WindowChannels with navigator-specific events.
class NavigatorChannels {
  NavigatorChannels._();

  // -- Outbound (navigator -> frame) --

  /// Focus changed: user selected a node in the tree.
  static const String focusChanged = 'navigator.focusChanged';

  /// Open viewer: user double-clicked a leaf node.
  static const String openViewer = 'navigator.openViewer';

  /// Open team widget: user clicked Team toolbar button.
  static const String openTeamWidget = 'navigator.openTeamWidget';

  /// Download file: user clicked Download toolbar button.
  static const String downloadFile = 'navigator.downloadFile';

  /// Content changed: upload completed, tree data modified.
  static const String contentChanged = 'navigator.contentChanged';

  // -- Inbound (frame -> navigator) --

  /// Navigate to a specific node in the tree.
  static const String navigateTo = 'navigator.navigateTo';

  /// Refresh the tree data.
  static const String refreshTree = 'navigator.refreshTree';
}
