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

class SduiNode {
  final String type;
  final String id;
  final Map<String, dynamic> props;
  final List<SduiNode> children;
  final List<SduiAnnotation> annotations;

  const SduiNode({
    required this.type,
    required this.id,
    this.props = const {},
    this.children = const [],
    this.annotations = const [],
  });

  factory SduiNode.fromJson(Map<String, dynamic> json) {
    return SduiNode(
      type: json['type'] as String,
      id: json['id'] as String,
      props: Map<String, dynamic>.from(json['props'] as Map? ?? {}),
      children: (json['children'] as List<dynamic>?)
              ?.map((c) =>
                  SduiNode.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          [],
      annotations: (json['annotations'] as List<dynamic>?)
              ?.map((a) =>
                  SduiAnnotation.fromJson(Map<String, dynamic>.from(a as Map)))
              .toList() ??
          [],
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
      };

  SduiNode copyWith({
    String? type,
    String? id,
    Map<String, dynamic>? props,
    List<SduiNode>? children,
    List<SduiAnnotation>? annotations,
  }) {
    return SduiNode(
      type: type ?? this.type,
      id: id ?? this.id,
      props: props ?? this.props,
      children: children ?? this.children,
      annotations: annotations ?? this.annotations,
    );
  }
}
