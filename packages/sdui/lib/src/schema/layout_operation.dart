import 'prop_converter.dart';
import 'sdui_node.dart';

sealed class LayoutOperation {
  const LayoutOperation();

  factory LayoutOperation.fromJson(Map<String, dynamic> json) {
    final op = json['op'] as String;
    return switch (op) {
      'addWindow' => AddWindow.fromJson(json),
      'removeWindow' => RemoveWindow.fromJson(json),
      'moveWindow' => MoveWindow.fromJson(json),
      'resizeWindow' => ResizeWindow.fromJson(json),
      'focusWindow' => FocusWindow.fromJson(json),
      'minimizeWindow' => MinimizeWindow.fromJson(json),
      'restoreWindow' => RestoreWindow.fromJson(json),
      'updateContent' => UpdateContent.fromJson(json),
      'addChild' => AddChild.fromJson(json),
      'removeChild' => RemoveChild.fromJson(json),
      'updateProps' => UpdateProps.fromJson(json),
      'addTab' => AddTab.fromJson(json),
      'removeTab' => RemoveTab.fromJson(json),
      'activateTab' => ActivateTab.fromJson(json),
      _ => throw ArgumentError('Unknown operation: $op'),
    };
  }

  static List<LayoutOperation> fromBatch(Map<String, dynamic> json) {
    final ops = json['ops'] as List<dynamic>;
    return ops
        .map((o) => LayoutOperation.fromJson(o as Map<String, dynamic>))
        .toList();
  }
}

// -- Window operations --

class AddWindow extends LayoutOperation {
  final String id;
  final SduiNode content;
  final String size;
  final String align;
  final String? title;

  /// Controls where the new window opens relative to the source widget.
  /// - `"newPane"` (default): creates a docked pane, auto-tiled
  /// - `"samePane"`: adds as a tab in the source widget's pane, activates it
  /// - `"beside"`: creates a docked pane beside the source
  /// - `"floating"`: creates a floating pane at explicit x/y/width/height
  final String placement;

  /// ID of the widget that triggered this operation. Used to resolve
  /// which pane to target for "samePane" and "beside" placements.
  final String? sourceWidgetId;

  /// Explicit pixel coordinates for "floating" placement (LLM use).
  /// When set, the pane is created as floating at these coordinates.
  final double? x;
  final double? y;
  final double? width;
  final double? height;

  const AddWindow({
    required this.id,
    required this.content,
    this.size = 'medium',
    this.align = 'center',
    this.title,
    this.placement = 'newPane',
    this.sourceWidgetId,
    this.x,
    this.y,
    this.width,
    this.height,
  });

  factory AddWindow.fromJson(Map<String, dynamic> json) => AddWindow(
        id: json['id'] as String,
        content: SduiNode.fromJson(Map<String, dynamic>.from(json['content'] as Map)),
        size: json['size'] as String? ?? 'medium',
        align: json['align'] as String? ?? 'center',
        title: json['title'] as String?,
        placement: json['placement'] as String? ?? 'newPane',
        sourceWidgetId: json['sourceWidgetId'] as String?,
        x: PropConverter.to<double>(json['x']),
        y: PropConverter.to<double>(json['y']),
        width: PropConverter.to<double>(json['width']),
        height: PropConverter.to<double>(json['height']),
      );
}

class RemoveWindow extends LayoutOperation {
  final String windowId;

  const RemoveWindow({required this.windowId});

  factory RemoveWindow.fromJson(Map<String, dynamic> json) =>
      RemoveWindow(windowId: json['windowId'] as String);
}

class MoveWindow extends LayoutOperation {
  final String windowId;
  final String? align;
  final double? x;
  final double? y;

  const MoveWindow({required this.windowId, this.align, this.x, this.y});

  factory MoveWindow.fromJson(Map<String, dynamic> json) => MoveWindow(
        windowId: json['windowId'] as String,
        align: json['align'] as String?,
        x: PropConverter.to<double>(json['x']),
        y: PropConverter.to<double>(json['y']),
      );
}

class ResizeWindow extends LayoutOperation {
  final String windowId;
  final String? size;
  final double? width;
  final double? height;

  const ResizeWindow({
    required this.windowId,
    this.size,
    this.width,
    this.height,
  });

  factory ResizeWindow.fromJson(Map<String, dynamic> json) => ResizeWindow(
        windowId: json['windowId'] as String,
        size: json['size'] as String?,
        width: PropConverter.to<double>(json['width']),
        height: PropConverter.to<double>(json['height']),
      );
}

class FocusWindow extends LayoutOperation {
  final String windowId;

  const FocusWindow({required this.windowId});

  factory FocusWindow.fromJson(Map<String, dynamic> json) =>
      FocusWindow(windowId: json['windowId'] as String);
}

class MinimizeWindow extends LayoutOperation {
  final String windowId;

  const MinimizeWindow({required this.windowId});

  factory MinimizeWindow.fromJson(Map<String, dynamic> json) =>
      MinimizeWindow(windowId: json['windowId'] as String);
}

class RestoreWindow extends LayoutOperation {
  final String windowId;

  const RestoreWindow({required this.windowId});

  factory RestoreWindow.fromJson(Map<String, dynamic> json) =>
      RestoreWindow(windowId: json['windowId'] as String);
}

// -- Content operations --

class UpdateContent extends LayoutOperation {
  final String windowId;
  final SduiNode content;

  const UpdateContent({required this.windowId, required this.content});

  factory UpdateContent.fromJson(Map<String, dynamic> json) => UpdateContent(
        windowId: json['windowId'] as String,
        content: SduiNode.fromJson(Map<String, dynamic>.from(json['content'] as Map)),
      );
}

class AddChild extends LayoutOperation {
  final String parentId;
  final SduiNode content;
  final int? index;

  const AddChild({required this.parentId, required this.content, this.index});

  factory AddChild.fromJson(Map<String, dynamic> json) => AddChild(
        parentId: json['parentId'] as String,
        content: SduiNode.fromJson(Map<String, dynamic>.from(json['content'] as Map)),
        index: PropConverter.to<int>(json['index']),
      );
}

class RemoveChild extends LayoutOperation {
  final String nodeId;

  const RemoveChild({required this.nodeId});

  factory RemoveChild.fromJson(Map<String, dynamic> json) =>
      RemoveChild(nodeId: json['nodeId'] as String);
}

class UpdateProps extends LayoutOperation {
  final String nodeId;
  final Map<String, dynamic> props;

  const UpdateProps({required this.nodeId, required this.props});

  factory UpdateProps.fromJson(Map<String, dynamic> json) => UpdateProps(
        nodeId: json['nodeId'] as String,
        props: Map<String, dynamic>.from(json['props'] as Map? ?? const {}),
      );
}

// -- Pane/tab operations --

/// Add a tab to an existing pane (identified by any windowId in that pane).
class AddTab extends LayoutOperation {
  final String paneId;
  final SduiNode content;
  final String? title;

  const AddTab({required this.paneId, required this.content, this.title});

  factory AddTab.fromJson(Map<String, dynamic> json) => AddTab(
        paneId: json['paneId'] as String,
        content: SduiNode.fromJson(
            Map<String, dynamic>.from(json['content'] as Map)),
        title: json['title'] as String?,
      );
}

/// Remove a tab from its pane. If it's the last tab, the pane is removed.
class RemoveTab extends LayoutOperation {
  final String windowId;

  const RemoveTab({required this.windowId});

  factory RemoveTab.fromJson(Map<String, dynamic> json) =>
      RemoveTab(windowId: json['windowId'] as String);
}

/// Switch the active tab in a pane.
class ActivateTab extends LayoutOperation {
  final String windowId;

  const ActivateTab({required this.windowId});

  factory ActivateTab.fromJson(Map<String, dynamic> json) =>
      ActivateTab(windowId: json['windowId'] as String);
}
