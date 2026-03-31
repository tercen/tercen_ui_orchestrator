import 'archetypes.dart';
import 'skeleton_theme.dart';

/// Expands an archetype with slot values into a complete widget definition
/// (metadata + template JSON) ready for the catalog or on-the-fly rendering.
class ArchetypeExpander {
  /// Expand an archetype by name with the given slot values.
  ///
  /// Returns `{metadata: {...}, template: {...}}` — the same shape as a
  /// catalog widget entry.
  ///
  /// Throws if required slots are missing.
  Map<String, dynamic> expand({
    required String archetypeName,
    required String widgetType,
    required Map<String, dynamic> slotValues,
    String? description,
  }) {
    final archetype = archetypes[archetypeName];
    if (archetype == null) {
      throw ArgumentError('Unknown archetype: $archetypeName');
    }

    // Validate required slots.
    for (final entry in archetype.slots.entries) {
      if (entry.value.required && !slotValues.containsKey(entry.key)) {
        throw ArgumentError(
            'Missing required slot "${entry.key}" for archetype "$archetypeName"');
      }
    }

    // Merge defaults.
    final slots = <String, dynamic>{};
    for (final entry in archetype.slots.entries) {
      slots[entry.key] = slotValues[entry.key] ?? entry.value.defaultValue;
    }

    // Dispatch to the appropriate builder.
    return switch (archetypeName) {
      'data-list' => _buildDataList(widgetType, slots, description),
      'detail-view' => _buildDetailView(widgetType, slots, description),
      'dashboard-card' => _buildDashboardCard(widgetType, slots, description),
      'form' => _buildForm(widgetType, slots, description),
      'master-detail' => _buildMasterDetail(widgetType, slots, description),
      _ => throw ArgumentError('No builder for archetype: $archetypeName'),
    };
  }

  // ---------------------------------------------------------------------------
  // data-list
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildDataList(
      String widgetType, Map<String, dynamic> s, String? desc) {
    final tapPayloadFields = _listStr(s['tapPayloadFields'] ?? ['id', 'name']);

    // Build tap payload: {fieldName: "{{item.fieldName}}", ...}
    final tapPayload = <String, dynamic>{};
    for (final field in tapPayloadFields) {
      tapPayload[field] = '{{item.$field}}';
    }

    // ForEach row content.
    final rowChildren = <Map<String, dynamic>>[
      _icon('{{widgetId}}-icon', s['icon'] ?? 'description'),
      _sizedBox('{{widgetId}}-gap', width: SkeletonTheme.iconTextGap),
      _expanded('{{widgetId}}-primary', [
        _text('{{widgetId}}-primary-text', '{{item.${s['primaryField']}}}',
            role: SkeletonTheme.primary),
      ]),
    ];
    if (s['secondaryField'] != null) {
      rowChildren.add(_text('{{widgetId}}-secondary',
          '{{item.${s['secondaryField']}}}',
          role: SkeletonTheme.secondary));
    }

    // Build the ForEach item with Action + ReactTo.
    var itemContent = _padding('pad-{{item.id}}', SkeletonTheme.listItemPadding, [
      _row('row-{{item.id}}', rowChildren),
    ]);

    // Action for tap. (Selection highlighting handled by Interaction + ForEach.)
    itemContent = {
      'type': 'Action',
      'id': 'tap-{{item.id}}',
      'props': {
        'gesture': 'onTap',
        'channel': s['tapChannel'],
        'payload': tapPayload,
      },
      'children': [itemContent],
    };

    // Optional double-tap intent.
    if (s['doubleTapIntent'] != null) {
      final intentPayload = <String, dynamic>{'intent': s['doubleTapIntent']};
      final propsMap = s['doubleTapPropsMap'] as Map<String, dynamic>?;
      if (propsMap != null) {
        for (final entry in propsMap.entries) {
          intentPayload[entry.key] = '{{item.${entry.value}}}';
        }
      }
      itemContent = {
        'type': 'Action',
        'id': 'dbl-{{item.id}}',
        'props': {
          'gesture': 'onDoubleTap',
          'channel': 'system.intent',
          'payload': intentPayload,
        },
        'children': [itemContent],
      };
    }

    // DataSource + loading/error/ready conditionals.
    final dsProps = <String, dynamic>{
      'service': s['service'],
      'method': s['method'],
      'args': s['args'],
    };
    if (s['refreshOn'] != null) dsProps['refreshOn'] = s['refreshOn'];

    final dataSourceChildren = [
      _conditional('{{widgetId}}-loading', '{{loading}}', [
        _center('{{widgetId}}-spinner', [
          _loadingIndicator('{{widgetId}}-li', 'Loading...'),
        ]),
      ]),
      _conditional('{{widgetId}}-error', '{{error}}', [
        _center('{{widgetId}}-err-center', [
          _errorColumn('{{widgetId}}-err'),
        ]),
      ]),
      _conditional('{{widgetId}}-ready', '{{ready}}', [
        {
          'type': 'ListView',
          'id': '{{widgetId}}-lv',
          'props': {'padding': SkeletonTheme.listPadding},
          'children': [
            {
              'type': 'ForEach',
              'id': '{{widgetId}}-fe',
              'props': {'items': '{{data}}'},
              'children': [itemContent],
            },
          ],
        },
      ]),
    ];

    // Root structure — no Interaction wrapper. StateManager is created
    // by the renderer from metadata.state config.
    final root = <String, dynamic>{
      'type': 'Column',
      'id': '{{widgetId}}-root',
      'props': {'crossAxisAlignment': 'stretch'},
      'children': [
        _toolbar('{{widgetId}}', s['title'] ?? widgetType),
        _expanded('{{widgetId}}-body', [
          {
            'type': 'DataSource',
            'id': '{{widgetId}}-ds',
            'props': dsProps,
            'children': dataSourceChildren,
          },
        ]),
      ],
    };

    // Metadata.
    final metadata = <String, dynamic>{
      'type': widgetType,
      'tier': 2,
      'description': desc ?? archetype_description('data-list', s),
      'state': {
        'selection': {
          'channel': s['tapChannel'],
          'matchField': 'id',
          'payloadField': tapPayloadFields.first,
        },
        'publishTo': [s['tapChannel']],
      },
    };
    final emitted = <String>[s['tapChannel'] as String];
    if (s['doubleTapIntent'] != null) {
      emitted.add('system.intent');
    }
    metadata['emittedEvents'] = emitted;

    return {'metadata': metadata, 'template': root};
  }

  // ---------------------------------------------------------------------------
  // detail-view
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildDetailView(
      String widgetType, Map<String, dynamic> s, String? desc) {
    final fields = (s['fields'] as List?) ?? [];

    final fieldWidgets = <Map<String, dynamic>>[];
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i] as Map<String, dynamic>;
      final field = f['field'] as String;
      final label = f['label'] as String? ?? field;
      final role = SkeletonTheme.resolveRole(f['role'] as String?) ??
          SkeletonTheme.primary;

      fieldWidgets.add(_padding('{{widgetId}}-field-$i', SkeletonTheme.listItemPadding, [
        _row('{{widgetId}}-frow-$i', [
          _sizedBox('{{widgetId}}-flbl-box-$i', width: SkeletonTheme.fieldLabelWidth, children: [
            _text('{{widgetId}}-flbl-$i', label, role: SkeletonTheme.secondary),
          ]),
          _expanded('{{widgetId}}-fval-exp-$i', [
            _text('{{widgetId}}-fval-$i', '{{data.$field}}', role: role),
          ]),
        ]),
      ]));
    }

    var root = <String, dynamic>{
      'type': 'Column',
      'id': '{{widgetId}}-root',
      'props': {'crossAxisAlignment': 'stretch'},
      'children': [
        _toolbar('{{widgetId}}', s['title'] ?? widgetType),
        _expanded('{{widgetId}}-body', [
          {
            'type': 'DataSource',
            'id': '{{widgetId}}-ds',
            'props': {
              'service': s['service'],
              'method': s['method'],
              'args': s['args'],
            },
            'children': [
              _conditional('{{widgetId}}-loading', '{{loading}}', [
                _center('{{widgetId}}-spinner', [
                  _loadingIndicator('{{widgetId}}-li', 'Loading...'),
                ]),
              ]),
              _conditional('{{widgetId}}-error', '{{error}}', [
                _center('{{widgetId}}-err-center', [
                  _errorColumn('{{widgetId}}-err'),
                ]),
              ]),
              _conditional('{{widgetId}}-ready', '{{ready}}', [
                {
                  'type': 'ListView',
                  'id': '{{widgetId}}-fields',
                  'props': {'padding': SkeletonTheme.listItemPadding},
                  'children': fieldWidgets,
                },
              ]),
            ],
          },
        ]),
      ],
    };

    final promptFields = s['promptFields'] as List?;
    if (promptFields != null && promptFields.isNotEmpty) {
      root = {
        'type': 'PromptRequired',
        'id': '{{widgetId}}-prompt',
        'props': {'fields': promptFields},
        'children': [root],
      };
    }

    return {
      'metadata': {
        'type': widgetType,
        'tier': 2,
        'description': desc ?? 'Detail view for $widgetType',
      },
      'template': root,
    };
  }

  // ---------------------------------------------------------------------------
  // dashboard-card
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildDashboardCard(
      String widgetType, Map<String, dynamic> s, String? desc) {
    final tapPayload = <String, dynamic>{};
    for (final field in _listStr(s['tapPayloadFields'] ?? ['id', 'name'])) {
      tapPayload[field] = '{{item.$field}}';
    }

    var itemContent = _padding('{{widgetId}}-item-pad', SkeletonTheme.listItemPadding, [
      _row('{{widgetId}}-item-row', [
        _icon('{{widgetId}}-item-icon', s['cardIcon'], size: 14),
        _sizedBox('{{widgetId}}-item-gap', width: SkeletonTheme.iconTextGap),
        _expanded('{{widgetId}}-item-name-exp', [
          _text('{{widgetId}}-item-name', '{{item.${s['primaryField']}}}',
              role: SkeletonTheme.primary),
        ]),
        if (s['secondaryField'] != null)
          _text('{{widgetId}}-item-sub', '{{item.${s['secondaryField']}}}',
              role: SkeletonTheme.secondary),
      ]),
    ]);

    if (s['tapChannel'] != null) {
      itemContent = {
        'type': 'Action',
        'id': '{{widgetId}}-item-action',
        'props': {
          'gesture': 'onTap',
          'channel': s['tapChannel'],
          'payload': tapPayload,
        },
        'children': [itemContent],
      };
    }

    return {
      'metadata': {
        'type': widgetType,
        'tier': 2,
        'description': desc ?? 'Dashboard card: ${s['cardTitle']}',
      },
      'template': {
        'type': 'DashboardCard',
        'id': '{{widgetId}}-card',
        'props': {'title': s['cardTitle'], 'icon': s['cardIcon']},
        'children': [
          {
            'type': 'DataSource',
            'id': '{{widgetId}}-ds',
            'props': {
              'service': s['service'],
              'method': s['method'],
              'args': s['args'],
            },
            'children': [
              _conditional('{{widgetId}}-loading', '{{loading}}', [
                _center('{{widgetId}}-spinner', [
                  _loadingIndicator('{{widgetId}}-li', 'Loading...'),
                ]),
              ]),
              _conditional('{{widgetId}}-ready', '{{ready}}', [
                {
                  'type': 'Column',
                  'id': '{{widgetId}}-list',
                  'children': [
                    {
                      'type': 'ForEach',
                      'id': '{{widgetId}}-fe',
                      'props': {'items': '{{data}}'},
                      'children': [itemContent],
                    },
                  ],
                },
              ]),
            ],
          },
        ],
      },
    };
  }

  // ---------------------------------------------------------------------------
  // form
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildForm(
      String widgetType, Map<String, dynamic> s, String? desc) {
    final formFields = (s['formFields'] as List?) ?? [];

    final initialState = <String, dynamic>{};
    final fieldWidgets = <Map<String, dynamic>>[];

    for (var i = 0; i < formFields.length; i++) {
      final f = formFields[i] as Map<String, dynamic>;
      final name = f['name'] as String;
      final label = f['label'] as String? ?? name;
      final defaultVal = f['default']?.toString() ?? '';

      initialState[name] = defaultVal;

      fieldWidgets.add(_padding('{{widgetId}}-field-$i', SkeletonTheme.formFieldGap, [
        {
          'type': 'Column',
          'id': '{{widgetId}}-fcol-$i',
          'props': {'crossAxisAlignment': 'stretch'},
          'children': [
            _text('{{widgetId}}-flbl-$i', label, role: SkeletonTheme.secondary),
            _sizedBox('{{widgetId}}-fgap-$i', height: SkeletonTheme.smallGapHeight),
            {
              'type': 'TextField',
              'id': '{{widgetId}}-finput-$i',
              'props': {'hint': label},
            },
          ],
        },
      ]));
    }

    return {
      'metadata': {
        'type': widgetType,
        'tier': 2,
        'description': desc ?? 'Form widget',
        'emittedEvents': [s['submitChannel']],
      },
      'template': {
        'type': 'StateHolder',
        'id': '{{widgetId}}-state',
        'props': {'initialState': initialState},
        'children': [
          {
            'type': 'Column',
            'id': '{{widgetId}}-root',
            'props': {'crossAxisAlignment': 'stretch'},
            'children': [
              if (s['title'] != null) _toolbar('{{widgetId}}', s['title']),
              {
                'type': 'Padding',
                'id': '{{widgetId}}-form-pad',
                'props': {'padding': SkeletonTheme.formPadding},
                'children': [
                  {
                    'type': 'Column',
                    'id': '{{widgetId}}-fields',
                    'props': {'crossAxisAlignment': 'stretch'},
                    'children': [
                      ...fieldWidgets,
                      _sizedBox('{{widgetId}}-submit-gap', height: SkeletonTheme.submitGapHeight),
                      {
                        'type': 'ElevatedButton',
                        'id': '{{widgetId}}-submit',
                        'props': {
                          'text': s['submitLabel'] ?? 'Submit',
                          'channel': s['submitChannel'],
                        },
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    };
  }

  // ---------------------------------------------------------------------------
  // master-detail
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildMasterDetail(
      String widgetType, Map<String, dynamic> s, String? desc) {
    // This generates a single widget with two side-by-side data sources.
    // Master list on left, detail fields on right, linked by refreshOn.

    final selectionIdField = s['selectionIdField'] as String;
    final detailFields = (s['detailFields'] as List?) ?? [];

    final detailFieldWidgets = <Map<String, dynamic>>[];
    for (var i = 0; i < detailFields.length; i++) {
      final f = detailFields[i] as Map<String, dynamic>;
      final field = f['field'] as String;
      final label = f['label'] as String? ?? field;
      detailFieldWidgets.add(_padding('{{widgetId}}-df-$i', SkeletonTheme.listItemPadding, [
        _row('{{widgetId}}-drow-$i', [
          _sizedBox('{{widgetId}}-dlbl-box-$i', width: SkeletonTheme.fieldLabelWidth, children: [
            _text('{{widgetId}}-dlbl-$i', label, role: SkeletonTheme.secondary),
          ]),
          _expanded('{{widgetId}}-dval-exp-$i', [
            _text('{{widgetId}}-dval-$i', '{{data.$field}}', role: SkeletonTheme.primary),
          ]),
        ]),
      ]));
    }

    final root = <String, dynamic>{
      'type': 'Row',
      'id': '{{widgetId}}-root',
      'children': [
            // Master list
            _expanded('{{widgetId}}-master-exp', [
              {
                'type': 'Column',
                'id': '{{widgetId}}-master-col',
                'props': {'crossAxisAlignment': 'stretch'},
                'children': [
                  _toolbar('{{widgetId}}-master', s['title'] ?? 'Master'),
                  _expanded('{{widgetId}}-master-body', [
                    {
                      'type': 'DataSource',
                      'id': '{{widgetId}}-master-ds',
                      'props': {
                        'service': s['masterService'],
                        'method': s['masterMethod'],
                        'args': s['masterArgs'],
                      },
                      'children': [
                        _conditional('{{widgetId}}-master-loading', '{{loading}}', [
                          _center('{{widgetId}}-master-spinner', [
                            _loadingIndicator('{{widgetId}}-master-li', 'Loading...'),
                          ]),
                        ]),
                        _conditional('{{widgetId}}-master-ready', '{{ready}}', [
                          {
                            'type': 'ListView',
                            'id': '{{widgetId}}-master-lv',
                            'props': {'padding': SkeletonTheme.listPadding},
                            'children': [
                              {
                                'type': 'ForEach',
                                'id': '{{widgetId}}-master-fe',
                                'props': {'items': '{{data}}'},
                                'children': [
                                  {
                                    'type': 'Action',
                                    'id': 'tap-{{item.id}}',
                                    'props': {
                                      'gesture': 'onTap',
                                      'channel': s['selectionChannel'],
                                      'payload': {
                                        selectionIdField: '{{item.$selectionIdField}}',
                                        'name': '{{item.${s['masterPrimaryField']}}}',
                                      },
                                    },
                                    'children': [
                                      _padding('pad-{{item.id}}', SkeletonTheme.listItemPadding, [
                                        _row('row-{{item.id}}', [
                                          _icon('icon-{{item.id}}', s['masterIcon'] ?? 'description'),
                                          _sizedBox('gap-{{item.id}}', width: SkeletonTheme.iconTextGap),
                                          _expanded('exp-{{item.id}}', [
                                            _text('name-{{item.id}}',
                                                '{{item.${s['masterPrimaryField']}}}',
                                                role: SkeletonTheme.primary),
                                          ]),
                                        ]),
                                      ]),
                                    ],
                                  },
                                ],
                              },
                            ],
                          },
                        ]),
                      ],
                    },
                  ]),
                ],
              },
            ]),
            // Divider
            {'type': 'Divider', 'id': '{{widgetId}}-divider', 'props': {'height': 1, 'color': SkeletonTheme.dividerColor}},
            // Detail
            _expanded('{{widgetId}}-detail-exp', [
              {
                'type': 'DataSource',
                'id': '{{widgetId}}-detail-ds',
                'props': {
                  'service': s['detailService'],
                  'method': s['detailMethod'],
                  'args': ['{{$selectionIdField}}'],
                  'refreshOn': s['selectionChannel'],
                },
                'children': [
                  _conditional('{{widgetId}}-detail-loading', '{{loading}}', [
                    _center('{{widgetId}}-detail-spinner', [
                      _loadingIndicator('{{widgetId}}-detail-li', 'Loading...'),
                    ]),
                  ]),
                  _conditional('{{widgetId}}-detail-ready', '{{ready}}', [
                    {
                      'type': 'ListView',
                      'id': '{{widgetId}}-detail-fields',
                      'props': {'padding': SkeletonTheme.listItemPadding},
                      'children': detailFieldWidgets,
                    },
                  ]),
                ],
              },
            ]),
      ],
    };

    return {
      'metadata': {
        'type': widgetType,
        'tier': 2,
        'description': desc ?? 'Master-detail browser',
        'emittedEvents': [s['selectionChannel']],
        'state': {
          'selection': {
            'channel': s['selectionChannel'],
            'matchField': 'id',
            'payloadField': selectionIdField,
          },
          'publishTo': [s['selectionChannel']],
        },
      },
      'template': root,
    };
  }

  // ---------------------------------------------------------------------------
  // Shared widget helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _text(String id, String text,
      {TextRole? role, String? textStyle, String? color}) {
    // Explicit textStyle/color override role if provided.
    final r = role ?? SkeletonTheme.primary;
    return {
      'type': 'Text',
      'id': id,
      'props': {
        'text': text,
        'textStyle': textStyle ?? r.textStyle,
        'color': color ?? r.color,
      },
    };
  }

  Map<String, dynamic> _icon(String id, String icon,
      {int? size, String? color}) {
    return {
      'type': 'Icon',
      'id': id,
      'props': {
        'icon': icon,
        'size': size ?? SkeletonTheme.itemIconSize,
        'color': color ?? SkeletonTheme.itemIconColor,
      },
    };
  }

  Map<String, dynamic> _sizedBox(String id,
      {double? width, double? height, List<Map<String, dynamic>>? children}) {
    return {
      'type': 'SizedBox',
      'id': id,
      'props': {
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      },
      if (children != null) 'children': children,
    };
  }

  Map<String, dynamic> _row(String id, List<Map<String, dynamic>> children) {
    return {'type': 'Row', 'id': id, 'children': children};
  }

  Map<String, dynamic> _expanded(String id, List<Map<String, dynamic>> children) {
    return {'type': 'Expanded', 'id': id, 'children': children};
  }

  Map<String, dynamic> _center(String id, List<Map<String, dynamic>> children) {
    return {'type': 'Center', 'id': id, 'children': children};
  }

  Map<String, dynamic> _padding(
      String id, String padding, List<Map<String, dynamic>> children) {
    return {
      'type': 'Padding',
      'id': id,
      'props': {'padding': padding},
      'children': children,
    };
  }

  Map<String, dynamic> _conditional(
      String id, String visible, List<Map<String, dynamic>> children) {
    return {
      'type': 'Conditional',
      'id': id,
      'props': {'visible': visible},
      'children': children,
    };
  }

  Map<String, dynamic> _loadingIndicator(String id, String text) {
    return {
      'type': 'LoadingIndicator',
      'id': id,
      'props': {'variant': 'skeleton', 'text': text},
    };
  }

  Map<String, dynamic> _toolbar(String prefix, String title) {
    return {
      'type': 'Container',
      'id': '$prefix-toolbar',
      'props': {
        'color': SkeletonTheme.toolbarBg,
        'padding': SkeletonTheme.toolbarPadding,
      },
      'children': [
        {
          'type': 'Row',
          'id': '$prefix-toolbar-row',
          'props': {'mainAxisAlignment': 'spaceBetween'},
          'children': [
            _text('$prefix-title', title, role: SkeletonTheme.section),
          ],
        },
      ],
    };
  }

  Map<String, dynamic> _errorColumn(String prefix) {
    return {
      'type': 'Column',
      'id': '$prefix-col',
      'props': {'mainAxisAlignment': 'center'},
      'children': [
        _icon('$prefix-icon', 'error_outline',
            size: SkeletonTheme.errorIconSize, color: SkeletonTheme.errorColor),
        _sizedBox('$prefix-gap', height: SkeletonTheme.iconTextGap),
        _text('$prefix-text', '{{errorMessage}}',
            role: SkeletonTheme.primary, color: SkeletonTheme.errorColor),
      ],
    };
  }

  List<String> _listStr(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

String archetype_description(String archetype, Map<String, dynamic> slots) {
  final service = slots['service'] ?? '';
  final method = slots['method'] ?? '';
  return 'Auto-generated from $archetype archetype using $service.$method';
}
