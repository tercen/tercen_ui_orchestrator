class PropSpec {
  final String type;
  final bool required;
  final dynamic defaultValue;
  final List<String>? values;
  final String? description;

  const PropSpec({
    required this.type,
    this.required = false,
    this.defaultValue,
    this.values,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'required': required,
        if (defaultValue != null) 'default': defaultValue,
        if (values != null) 'values': values,
        if (description != null) 'description': description,
      };
}

class WidgetMetadata {
  final String type;
  final int tier; // 1 = Flutter primitive, 2 = Tercen domain
  final String description;
  final Map<String, PropSpec> props;
  final List<String> gestures;
  final List<String> emittedEvents;
  final List<String> acceptedActions;

  const WidgetMetadata({
    required this.type,
    this.tier = 1,
    this.description = '',
    this.props = const {},
    this.gestures = const [],
    this.emittedEvents = const [],
    this.acceptedActions = const [],
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'tier': tier,
        'description': description,
        'props': props.map((k, v) => MapEntry(k, v.toJson())),
        if (gestures.isNotEmpty) 'gestures': gestures,
        if (emittedEvents.isNotEmpty) 'emittedEvents': emittedEvents,
        if (acceptedActions.isNotEmpty) 'acceptedActions': acceptedActions,
      };
}
