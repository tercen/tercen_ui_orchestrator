import 'dart:ui';

/// Identity properties that the window exposes to the Frame.
///
/// The Frame reads these to populate the tab: type icon colour, label text.
/// When [label] changes, WindowStateProvider publishes a `contentChanged`
/// intent on the `window.intent` EventBus channel.
class WindowIdentity {
  /// Immutable type identifier (e.g. 'dataViewer', 'chat', 'workflow').
  final String typeId;

  /// Immutable type colour from the Tercen logo palette.
  /// Used for the tab's coloured square icon.
  final Color typeColor;

  /// Human-readable label. May be updated by content
  /// (e.g. "Data" -> "raw_kinase_data.csv").
  String label;

  WindowIdentity({
    required this.typeId,
    required this.typeColor,
    required this.label,
  });
}
