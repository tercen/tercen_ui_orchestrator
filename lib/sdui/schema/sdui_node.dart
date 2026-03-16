class SduiAnnotation {
  final String text;
  final String position;

  const SduiAnnotation({required this.text, this.position = 'top-right'});

  factory SduiAnnotation.fromJson(Map<String, dynamic> json) {
    return SduiAnnotation(
      text: json['text'] as String,
      position: json['position'] as String? ?? 'top-right',
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'position': position};
}

/// Describes an action triggered by a gesture (tap, double-tap, long-press).
///
/// The action publishes a payload to an EventBus channel. The channel determines
/// what happens — e.g., `system.selection.project` updates user context,
/// `system.layout.op` triggers a layout operation.
class SduiAction {
  final String channel;
  final Map<String, dynamic> payload;

  const SduiAction({required this.channel, this.payload = const {}});

  factory SduiAction.fromJson(Map<String, dynamic> json) {
    return SduiAction(
      channel: json['channel'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'channel': channel,
        if (payload.isNotEmpty) 'payload': payload,
      };
}

/// Describes a data source for a node: which service/method/args to call.
///
/// When present on a node:
///   - If the result is a list → children act as a template repeated per item,
///     with `{{item.field}}` bindings.
///   - If the result is a single object → `{{data.field}}` bindings resolve in
///     props and children.
/// Describes a reactive binding: subscribe to an EventBus channel and
/// override props when the event payload matches.
class SduiReaction {
  final String channel;
  final Map<String, dynamic> match;
  final Map<String, dynamic> props;

  const SduiReaction({
    required this.channel,
    this.match = const {},
    this.props = const {},
  });

  factory SduiReaction.fromJson(Map<String, dynamic> json) {
    return SduiReaction(
      channel: json['channel'] as String,
      match: Map<String, dynamic>.from(json['match'] as Map? ?? {}),
      props: Map<String, dynamic>.from(json['props'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'channel': channel,
        if (match.isNotEmpty) 'match': match,
        if (props.isNotEmpty) 'props': props,
      };
}

class SduiDataSource {
  final String service;
  final String method;
  final List<dynamic> args;

  const SduiDataSource({
    required this.service,
    required this.method,
    this.args = const [],
  });

  factory SduiDataSource.fromJson(Map<String, dynamic> json) {
    return SduiDataSource(
      service: json['service'] as String,
      method: json['method'] as String,
      args: (json['args'] as List<dynamic>?) ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'service': service,
        'method': method,
        if (args.isNotEmpty) 'args': args,
      };
}

class SduiNode {
  final String type;
  final String id;
  final Map<String, dynamic> props;
  final List<SduiNode> children;
  final List<SduiAnnotation> annotations;
  final SduiDataSource? dataSource;

  /// Gesture actions: keys are gesture types (onTap, onDoubleTap, onLongPress).
  /// Each action publishes its payload to the specified EventBus channel.
  final Map<String, SduiAction> actions;

  /// Reactive binding: subscribe to a channel and override props when matched.
  final SduiReaction? reactTo;

  const SduiNode({
    required this.type,
    required this.id,
    this.props = const {},
    this.children = const [],
    this.annotations = const [],
    this.dataSource,
    this.actions = const {},
    this.reactTo,
  });

  factory SduiNode.fromJson(Map<String, dynamic> json) {
    return SduiNode(
      type: json['type'] as String,
      id: json['id'] as String,
      props: Map<String, dynamic>.from(
        (json['props'] as Map<String, dynamic>?) ?? {},
      ),
      children: (json['children'] as List<dynamic>?)
              ?.map((c) => SduiNode.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      annotations: (json['annotations'] as List<dynamic>?)
              ?.map((a) => SduiAnnotation.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      dataSource: json['dataSource'] != null
          ? SduiDataSource.fromJson(json['dataSource'] as Map<String, dynamic>)
          : null,
      actions: (json['actions'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, SduiAction.fromJson(v as Map<String, dynamic>))) ??
          const {},
      reactTo: json['reactTo'] != null
          ? SduiReaction.fromJson(json['reactTo'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        if (props.isNotEmpty) 'props': props,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
        if (annotations.isNotEmpty)
          'annotations': annotations.map((a) => a.toJson()).toList(),
        if (dataSource != null) 'dataSource': dataSource!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (reactTo != null) 'reactTo': reactTo!.toJson(),
      };

  SduiNode copyWith({
    String? type,
    String? id,
    Map<String, dynamic>? props,
    List<SduiNode>? children,
    List<SduiAnnotation>? annotations,
    SduiDataSource? dataSource,
    Map<String, SduiAction>? actions,
    SduiReaction? reactTo,
  }) {
    return SduiNode(
      type: type ?? this.type,
      id: id ?? this.id,
      props: props ?? this.props,
      children: children ?? this.children,
      annotations: annotations ?? this.annotations,
      dataSource: dataSource ?? this.dataSource,
      actions: actions ?? this.actions,
      reactTo: reactTo ?? this.reactTo,
    );
  }
}
