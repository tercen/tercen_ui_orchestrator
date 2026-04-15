import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:markdown/markdown.dart' as md;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../contracts/event_contracts.dart';
import '../error_reporter.dart';
import '../event_bus/event_bus.dart';
import '../event_bus/event_payload.dart';
import '../renderer/json_path_resolver.dart';
import '../renderer/sdui_render_context.dart';
import '../schema/prop_converter.dart';
import '../schema/sdui_node.dart';
import '../state/state_manager.dart';
import '../theme/sdui_theme.dart';
import 'widget_metadata.dart';
import 'widget_registry.dart';

/// Register all behavior widgets (DataSource, ForEach, Action, Conditional,
/// Sort, Filter, PromptRequired, Accordion).
void registerBehaviorWidgets(WidgetRegistry registry) {
  registry.registerScope('DataSource', _buildDataSource,
      metadata: const WidgetMetadata(
        type: 'DataSource',
        description: 'Fetches data from a service. When children exist, provides scope: '
            '{{data}}, {{loading}} (bool), {{error}} (bool), {{errorMessage}} (string), '
            '{{ready}} (bool = !loading && !error). Without children, shows a spinner/error. '
            'Use "refreshOn" to refetch when an EventBus event arrives — the event payload '
            'fields are merged into child scope, so {{...}} bindings in args resolve to '
            'the new values.',
        props: {
          'service': PropSpec(type: 'string', required: true),
          'method': PropSpec(type: 'string', required: true),
          'args': PropSpec(type: 'list'),
          'refreshOn': PropSpec(type: 'string',
              description: 'EventBus channel to listen on. When an event arrives, '
                  'payload fields are merged into scope and data is refetched.'),
          'searchChannel': PropSpec(type: 'string',
              description: 'EventBus channel to listen for search queries. '
                  'When a query arrives, calls searchService/searchMethod and filters results.'),
          'searchService': PropSpec(type: 'string',
              description: 'Service name for search calls (required if searchChannel is set)'),
          'searchMethod': PropSpec(type: 'string',
              description: 'Method name for search calls (required if searchChannel is set)'),
          'searchArgs': PropSpec(type: 'list',
              description: 'Arguments for search service call'),
          'searchResultFilter': PropSpec(type: 'object',
              description: 'Exact-match filter applied to search results: {field: value} pairs. '
                  'Only results where every field equals its value are included.'),
          'children': PropSpec(type: 'object',
              description: 'Tree child-loading config: {service, method, args}. '
                  'Args may contain {{parent.xxx}} bindings resolved against the parent node. '
                  'When present, DataSource becomes tree-aware and exposes _depth, _expanded, '
                  '_hasChildren, _loading metadata on each item.'),
          'expandChannel': PropSpec(type: 'string',
              description: 'EventBus channel for expand/collapse toggles. '
                  'Event payload must include nodeId.'),
          'nodeId': PropSpec(type: 'string', defaultValue: 'id',
              description: 'Field name used as node identity for tree operations.'),
          'rootNodes': PropSpec(type: 'list',
              description: 'Static root nodes prepended before fetched data. '
                  'Useful for virtual entries like "My Projects". '
                  'Supports template bindings (e.g., {{context.userId}}).'),
          'consumes': PropSpec(type: 'list',
              description: 'Contract-based refresh channels. Lists EventBus channels this '
                  'DataSource depends on. When any listed channel fires, data is refetched.'),
        },
      ));

  registry.registerScope('ForEach', _buildForEach,
      metadata: const WidgetMetadata(
        type: 'ForEach',
        description: 'Iterates a list, provides {{item}} and {{_index}} to children. '
            'Optional limit/offset for pagination (support template expressions). '
            'When inside a component with a StateManager, selected items are automatically '
            'highlighted with primaryContainer background.',
        props: {
          'items': PropSpec(type: 'list', required: true,
              description: 'Template like {{data}} resolving to a List'),
          'limit': PropSpec(type: 'int', defaultValue: 0,
              description: 'Max items to render (0 = unlimited). Supports {{state}} expressions.'),
          'offset': PropSpec(type: 'int', defaultValue: 0,
              description: 'Items to skip. Supports {{state}} expressions.'),
          'filterChannel': PropSpec(type: 'string',
              description: 'EventBus channel to listen for filter queries. '
                  'Filters items by matching query against string field values.'),
          'limitChannel': PropSpec(type: 'string',
              description: 'EventBus channel to listen for dynamic limit changes (e.g. page size). '
                  'Expects payload {value: int}.'),
          'filterFields': PropSpec(type: 'list',
              description: 'List of field names to match against (e.g. ["name","description"]). '
                  'If omitted, matches against all string values.'),
          'where': PropSpec(type: 'map',
              description: 'Exact-match filter: {field: value} pairs. '
                  'Only items where every field equals its value are included.'),
          'whereNot': PropSpec(type: 'map',
              description: 'Exact-match exclusion filter: {field: value} pairs. '
                  'Items where ALL fields match are excluded.'),
          'emptyText': PropSpec(type: 'string',
              description: 'Text shown when the filtered list is empty. '
                  'If omitted, shows "No data" (or "No matches" during text filter).'),
        },
      ));

  registry.register('Action', _buildAction,
      metadata: const WidgetMetadata(
        type: 'Action',
        description: 'Wraps children in a gesture detector that publishes to EventBus. '
            'Optional hoverColor highlights the child on mouse hover. '
            'If payload contains intent:"openUrl", children are auto-styled with link color. '
            'When inside a component with a StateManager, the action is delegated to the '
            'StateManager (which may update selection state) before publishing to EventBus.',
        props: {
          'gesture': PropSpec(type: 'string', defaultValue: 'onTap',
              values: ['onTap', 'onDoubleTap', 'onLongPress', 'onSecondaryTap']),
          'channel': PropSpec(type: 'string', required: true),
          'payload': PropSpec(type: 'object',
              description: 'Data published with the event. If payload.intent is "openUrl", '
                  'children get automatic link color styling.'),
          'hoverColor': PropSpec(type: 'string',
              description: 'Background color on hover (semantic token or hex)'),
        },
      ));

  // ReactTo removed — selection handled by StateManager + ForEach.
  // Toggle/match behavior is a StateManager operation.

  registry.registerScope('Conditional', _buildConditional,
      metadata: const WidgetMetadata(
        type: 'Conditional',
        description: 'Shows or hides children based on a boolean prop. '
            'Set negate:true to invert the condition (show when visible is false). '
            'Accepts bool true, string "true", or non-zero number as truthy values.',
        props: {
          'visible': PropSpec(type: 'bool', required: true,
              description: 'Condition to evaluate. Truthy: bool true, string "true", non-zero number.'),
          'negate': PropSpec(type: 'bool', defaultValue: false,
              description: 'Invert the visible condition'),
          'minWidth': PropSpec(type: 'number',
              description: 'Minimum available width (px) to show children. '
                  'When parent is narrower, children are hidden. '
                  'Uses LayoutBuilder for responsive visibility.'),
        },
      ));

  registry.registerScope('PromptRequired', _buildPromptRequired,
      metadata: const WidgetMetadata(
        type: 'PromptRequired',
        description: 'Prompts the user for missing required values before rendering children. '
            'Each entry in "fields" is {name, label, default, values?}. Resolved values are exposed in scope. '
            'If all values are already in scope/context, renders children immediately (no prompt).',
        props: {
          'fields': PropSpec(type: 'list', required: true,
              description: 'List of field objects: {name: string, label: string, default: string, '
                  'values?: List<string>}. If "values" is a non-empty list, renders a dropdown '
                  'instead of a text field.'),
        },
      ));

  // StateHolder removed — replaced by StateManager (per-widget, outside tree).

  registry.registerScope('Sort', _buildSort,
      metadata: const WidgetMetadata(
        type: 'Sort',
        description: 'Sorts a list by a key, exposes {{sorted}} to children. '
            'The key supports dot-notation JSON paths (e.g. "user.name").',
        props: {
          'items': PropSpec(type: 'list', required: true),
          'key': PropSpec(type: 'string', required: true,
              description: 'Field name or dot-notation path (e.g. "name" or "user.age")'),
          'direction': PropSpec(type: 'string', defaultValue: 'asc',
              values: ['asc', 'desc']),
        },
      ));

  registry.registerScope('Filter', _buildFilter,
      metadata: const WidgetMetadata(
        type: 'Filter',
        description: 'Filters a list by case-insensitive substring match, exposes {{filtered}} to children. '
            'The field supports dot-notation JSON paths (e.g. "user.name").',
        props: {
          'items': PropSpec(type: 'list', required: true),
          'field': PropSpec(type: 'string', required: true,
              description: 'Field name or dot-notation path to match against'),
          'contains': PropSpec(type: 'string', required: true,
              description: 'Substring to match (case-insensitive)'),
        },
      ));

  // Interaction removed — replaced by StateManager.

  registry.registerScope('EventScope', _buildEventScope,
      metadata: const WidgetMetadata(
        type: 'EventScope',
        description: 'Subscribes to an EventBus channel and exposes the last event payload '
            'in scope. Children can read {{selection.nodeType}}, {{selection.nodeId}}, etc. '
            'Optionally uses sticky replay to capture events published before mount.',
        props: {
          'channel': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to subscribe to'),
          'scopeKey': PropSpec(type: 'string', required: true,
              description: 'Key name to expose in scope (e.g., "selection")'),
          'replay': PropSpec(type: 'bool', defaultValue: false,
              description: 'Use sticky replay to get last event if missed'),
          'defaultPayload': PropSpec(type: 'object',
              description: 'Default scope values before any event arrives'),
        },
      ));

  registry.registerScope('AutoEmit', _buildAutoEmit,
      metadata: const WidgetMetadata(
        type: 'AutoEmit',
        description: 'Emits an EventBus event once on mount, then renders children. '
            'Use to trigger navigation or initialization after data loads.',
        props: {
          'channel': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to publish to'),
          'payload': PropSpec(type: 'object',
              description: 'Data to publish with the event'),
          'delayMs': PropSpec(type: 'int', defaultValue: 0,
              description: 'Delay in milliseconds before emitting (useful for '
                  'waiting for nested DataSources to load)'),
        },
      ));

  registry.registerScope('Collapsible', _buildCollapsible,
      metadata: const WidgetMetadata(
        type: 'Collapsible',
        description: 'Shows or hides children based on expand/collapse state. '
            'Listens to a toggleChannel for events with {nodeId}. '
            'When the nodeId matches this instance, toggles visibility. '
            'Also listens to expandChannel — expands (without toggle) when nodeId matches. '
            'Exposes {{expanded}} (bool) to children.',
        props: {
          'nodeId': PropSpec(type: 'string', required: true,
              description: 'Unique ID for this collapsible instance'),
          'toggleChannel': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to listen for toggle events'),
          'expandChannel': PropSpec(type: 'string',
              description: 'EventBus channel to listen for expand-only events. '
                  'When nodeId matches, sets expanded=true (never collapses).'),
          'defaultExpanded': PropSpec(type: 'bool', defaultValue: false,
              description: 'Whether initially expanded'),
        },
      ));

  registry.registerScope('Accordion', _buildAccordion,
      metadata: const WidgetMetadata(
        type: 'Accordion',
        description: 'Single-expand accordion list using Material ExpansionTile '
            'with FontAwesome chevron icons and theme tokens. Iterates '
            'over items, rendering two template children per item: '
            'first child = header row (title), second child = body '
            'content. Only one panel can be open at a time. '
            'Exposes {{item}}, {{index}}, {{expanded}} (bool), and '
            '{{activePanelId}} (string) to children.',
        props: {
          'items': PropSpec(type: 'list', required: true,
              description: 'List of data items to iterate over'),
          'itemVariable': PropSpec(type: 'string', defaultValue: 'item',
              description: 'Variable name for each item in scope'),
          'panelIdKey': PropSpec(type: 'string', required: true,
              description: 'Key in each item that provides the unique panel ID'),
          'expandChannel': PropSpec(type: 'string',
              description: 'EventBus channel to publish when a panel expands. '
                  'Payload: {panelId: <id>}'),
          'collapseChannel': PropSpec(type: 'string',
              description: 'EventBus channel to publish when a panel collapses. '
                  'Payload: {panelId: <id>}'),
        },
      ));

  registry.registerScope('DataGrid', _buildDataGrid,
      metadata: const WidgetMetadata(
        type: 'DataGrid',
        description: 'Unified data grid with two column modes. '
            'flex mode: columns share available width (good for known column sets). '
            'scroll mode: columns have computed pixel widths with horizontal scrolling '
            '(good for dynamic/unknown column sets). Supports sorting, filtering, '
            'search (filter or highlight), inline cell editing, row selection, '
            'CSV export, and optional frozen row-number column.',
        props: {
          'items': PropSpec(type: 'list', required: true,
              description: 'Row-major data: [{key: value, ...}, ...]'),
          'columns': PropSpec(type: 'list',
              description: 'Column defs: [{key, label, type?, flex?, width?, visible?, color?, '
                  'isChip?, isDate?, isLink?, colorTokenField?}]. '
                  'If omitted, auto-generated from first row keys.'),
          'columnMode': PropSpec(type: 'string', defaultValue: 'flex',
              description: '"flex" (divide available width) or "scroll" (computed widths, horizontal scroll)'),
          'columnMinWidth': PropSpec(type: 'double', defaultValue: 140,
              description: 'Minimum column width in scroll mode'),
          'columnMaxWidth': PropSpec(type: 'double', defaultValue: 400,
              description: 'Maximum column width in scroll mode'),
          'showRowNumbers': PropSpec(type: 'bool', defaultValue: false,
              description: 'Show frozen row-number column on the left'),
          'selectionMode': PropSpec(type: 'string', defaultValue: 'multi',
              description: '"none", "single", or "multi"'),
          'onSelectionChanged': PropSpec(type: 'string',
              description: 'EventBus channel for selection changes'),
          'onRowTap': PropSpec(type: 'string',
              description: 'EventBus channel for row tap'),
          'columnsChannel': PropSpec(type: 'string',
              description: 'EventBus channel to receive column visibility updates ({selected: [keys]})'),
          'sortable': PropSpec(type: 'bool', defaultValue: false,
              description: 'Enable click-to-sort on any column header (cycle: none→asc→desc→none). '
                  'Numeric/date types sort appropriately.'),
          'sortChannel': PropSpec(type: 'string',
              description: 'EventBus channel for sort state. In flex mode, also listens for external sort toggle.'),
          'editable': PropSpec(type: 'bool', defaultValue: false,
              description: 'Enable inline cell editing (double-click to edit). Publishes to editChannel.'),
          'editChannel': PropSpec(type: 'string',
              description: 'EventBus channel for cell edit events {row, column, newValue}'),
          'searchMode': PropSpec(type: 'string', defaultValue: 'filter',
              description: '"filter" (hide non-matching rows) or "highlight" (tint matching cells)'),
          'searchChannel': PropSpec(type: 'string',
              description: 'EventBus channel to receive search queries'),
          'scrollToRow': PropSpec(type: 'int',
              description: 'Row index to scroll to and briefly highlight'),
          'exportChannel': PropSpec(type: 'string',
              description: 'EventBus channel to trigger CSV export'),
          'refreshChannel': PropSpec(type: 'string',
              description: 'EventBus channel to trigger data re-query'),
        },
      ));

  registry.registerScope('ServiceCall', _buildServiceCall,
      metadata: const WidgetMetadata(
        type: 'ServiceCall',
        description: 'Event-triggered service mutation. Does nothing on mount (unlike DataSource). '
            'When triggerOn event arrives, re-resolves args and calls serviceCaller. '
            'Publishes "<id>.completed" on success. Exposes {{saving}}, {{saved}}, {{saveError}} to children.',
        props: {
          'service': PropSpec(type: 'string', required: true,
              description: 'Service name (e.g., "fileService")'),
          'method': PropSpec(type: 'string', required: true,
              description: 'Method name (e.g., "updateContent")'),
          'triggerOn': PropSpec(type: 'string', required: true,
              description: 'EventBus channel to listen for — triggers the service call'),
          'args': PropSpec(type: 'list',
              description: 'Arguments for the service call, may contain template expressions re-resolved at trigger time'),
          'watchChannels': PropSpec(type: 'map',
              description: 'Map of scopeKey → channel. Subscribes to each channel and keeps latest payload under scopeKey for arg resolution at trigger time.'),
          'refreshChannel': PropSpec(type: 'string',
              description: 'Optional EventBus channel to publish after a successful call (in addition to "<id>.completed"). '
                  'Use this to trigger a DataSource refresh after a mutation.'),
        },
      ));

  registry.registerScope('PrintTrigger', _buildPrintTrigger,
      metadata: const WidgetMetadata(
        type: 'PrintTrigger',
        description: 'Listens for a trigger event and opens the browser print dialog with '
            'markdown content converted to styled HTML. Uses watchChannels to track '
            'live content. Renders children as passthrough.',
        props: {
          'triggerOn': PropSpec(type: 'string', required: true,
              description: 'EventBus channel that triggers print'),
          'title': PropSpec(type: 'string',
              description: 'Document title for the print page'),
          'watchChannels': PropSpec(type: 'map',
              description: 'Map of scopeKey → channel. Tracks latest content for printing.'),
        },
      ));

}


// ---------------------------------------------------------------------------
// ServiceCall — event-triggered service mutation
// ---------------------------------------------------------------------------

Widget _buildServiceCall(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _ServiceCallWidget(
    key: ValueKey('sc-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _ServiceCallWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _ServiceCallWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_ServiceCallWidget> createState() => _ServiceCallWidgetState();
}

class _ServiceCallWidgetState extends State<_ServiceCallWidget> {
  bool _saving = false;
  bool _saved = false;
  String? _saveError;
  StreamSubscription? _triggerSub;
  final List<StreamSubscription> _watchSubs = [];

  /// Accumulated payloads from watched channels, keyed by scopeKey.
  final Map<String, dynamic> _watchScope = {};

  @override
  void initState() {
    super.initState();
    _subscribeTrigger();
    _subscribeWatchChannels();
  }

  void _subscribeTrigger() {
    final channel =
        PropConverter.to<String>(widget.node.props['triggerOn']);
    if (channel == null || channel.isEmpty) return;
    _triggerSub =
        widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted || _saving) return;
      _executeSave(Map<String, dynamic>.from(event.data));
    });
  }

  void _subscribeWatchChannels() {
    final watch = widget.node.props['watchChannels'];
    if (watch is! Map) return;
    for (final entry in watch.entries) {
      final scopeKey = entry.key.toString();
      final channel = entry.value.toString();
      _watchSubs.add(
        widget.context.eventBus.subscribe(channel).listen((event) {
          if (!mounted) return;
          _watchScope[scopeKey] = Map<String, dynamic>.from(event.data);
        }),
      );
    }
  }

  List<dynamic> _resolveArgs(Map<String, dynamic> triggerPayload) {
    final rawArgs = widget.node.props['_rawArgs'] as List?;
    final resolver = widget.context.templateResolver;
    final parentScope =
        widget.node.props['_parentScope'] as Map<String, dynamic>? ?? {};
    final mergedScope = <String, dynamic>{
      ...parentScope,
      ..._watchScope,
      ...triggerPayload,
    };
    if (rawArgs != null) {
      return rawArgs
          .map((a) => resolver.resolveValue(a, mergedScope))
          .toList();
    }
    return (widget.node.props['args'] as List<dynamic>?) ?? const [];
  }

  void _executeSave(Map<String, dynamic> triggerPayload) {
    final caller = widget.context.serviceCaller;
    if (caller == null) return;

    final service = widget.node.props['service'] as String;
    final method = widget.node.props['method'] as String;
    final args = _resolveArgs(triggerPayload);

    setState(() {
      _saving = true;
      _saved = false;
      _saveError = null;
    });

    caller(service, method, args).then((result) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
        _saveError = null;
      });
      widget.context.eventBus.publish(
        '${widget.node.id}.completed',
        EventPayload(
          type: 'service.completed',
          sourceWidgetId: widget.node.id,
          data: {'result': result},
        ),
      );
      // Publish to refreshChannel if specified (triggers DataSource refresh).
      final refreshChannel = widget.node.props['refreshChannel'] as String?;
      if (refreshChannel != null && refreshChannel.isNotEmpty) {
        widget.context.eventBus.publish(
          refreshChannel,
          EventPayload(
            type: 'service.refresh',
            sourceWidgetId: widget.node.id,
            data: {'result': result},
          ),
        );
      }
      // Reset saved indicator after 2 seconds.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }).catchError((Object e, StackTrace st) {
      ErrorReporter.instance.report(
        e,
        stackTrace: st,
        source: 'sdui.ServiceCall',
        context: '$service.$method',
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = '$service.$method: $e';
        });
      }
    });
  }

  @override
  void dispose() {
    _triggerSub?.cancel();
    for (final sub in _watchSubs) {
      sub.cancel();
    }
    _watchSubs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = <String, dynamic>{
      'saving': _saving,
      'saved': _saved,
      'saveError': _saveError,
    };

    final children = widget.node.children;
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) {
      return widget.childRenderer(children.first, scope);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.map((c) => widget.childRenderer(c, scope)).toList(),
    );
  }
}


// ---------------------------------------------------------------------------
// PrintTrigger — opens browser print dialog with markdown content
// ---------------------------------------------------------------------------

Widget _buildPrintTrigger(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _PrintTriggerWidget(
    key: ValueKey('print-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _PrintTriggerWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _PrintTriggerWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_PrintTriggerWidget> createState() => _PrintTriggerWidgetState();
}

class _PrintTriggerWidgetState extends State<_PrintTriggerWidget> {
  StreamSubscription? _triggerSub;
  final List<StreamSubscription> _watchSubs = [];
  final Map<String, dynamic> _watchScope = {};

  @override
  void initState() {
    super.initState();
    _subscribeTrigger();
    _subscribeWatchChannels();
  }

  void _subscribeTrigger() {
    final channel =
        PropConverter.to<String>(widget.node.props['triggerOn']);
    if (channel == null || channel.isEmpty) return;
    _triggerSub =
        widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      _print();
    });
  }

  void _subscribeWatchChannels() {
    final watch = widget.node.props['watchChannels'];
    if (watch is! Map) return;
    for (final entry in watch.entries) {
      final scopeKey = entry.key.toString();
      final channel = entry.value.toString();
      _watchSubs.add(
        widget.context.eventBus.subscribe(channel).listen((event) {
          if (!mounted) return;
          _watchScope[scopeKey] = Map<String, dynamic>.from(event.data);
        }),
      );
    }
  }

  void _print() {
    // Resolve content from watchScope or parentScope.
    final parentScope =
        widget.node.props['_parentScope'] as Map<String, dynamic>? ?? {};
    final mergedScope = <String, dynamic>{
      ...parentScope,
      ..._watchScope,
    };

    debugPrint('[PrintTrigger] parentScope keys: ${parentScope.keys.toList()}');
    debugPrint('[PrintTrigger] watchScope keys: ${_watchScope.keys.toList()}');

    // Try to get content: watchScope draft > parentScope draft > data.content.
    String content = '';

    // 1. Latest edit from watchChannels
    final watchDraft = _watchScope['draft'];
    if (watchDraft is Map && watchDraft['value'] is String) {
      content = watchDraft['value'] as String;
    }

    // 2. Fallback: draft from parent scope (EventScope defaultPayload)
    if (content.isEmpty) {
      final draft = parentScope['draft'];
      if (draft is Map && draft['value'] is String) {
        content = draft['value'] as String;
      }
    }

    // 3. Fallback: raw data.content from DataSource
    if (content.isEmpty) {
      final data = parentScope['data'];
      if (data is Map && data['content'] is String) {
        content = data['content'] as String;
      }
    }

    debugPrint('[PrintTrigger] content length: ${content.length}');

    final title = PropConverter.to<String>(widget.node.props['title']) ?? 'Document';

    if (content.isEmpty) {
      debugPrint('[PrintTrigger] No content to print');
      return;
    }

    // Convert markdown to HTML.
    final htmlBody = md.markdownToHtml(
      content,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    // Open print window with styled HTML.
    final fullHtml = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>$title</title>
<style>
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-size: 14px;
    line-height: 1.6;
    color: #111827;
    max-width: 800px;
    margin: 0 auto;
    padding: 24px;
  }
  h1 { font-size: 24px; font-weight: 700; margin: 24px 0 12px; }
  h2 { font-size: 20px; font-weight: 600; margin: 20px 0 10px; }
  h3 { font-size: 16px; font-weight: 600; margin: 16px 0 8px; }
  p { margin: 8px 0; }
  code {
    font-family: monospace;
    font-size: 13px;
    background: #f1f5f9;
    padding: 2px 4px;
    border-radius: 3px;
  }
  pre {
    background: #f1f5f9;
    padding: 12px;
    border-radius: 6px;
    overflow-x: auto;
  }
  pre code { background: none; padding: 0; }
  blockquote {
    border-left: 3px solid #1e40af;
    margin: 8px 0;
    padding: 4px 0 4px 16px;
    color: #374151;
  }
  table { border-collapse: collapse; margin: 8px 0; }
  th, td { border: 1px solid #d1d5db; padding: 6px 12px; }
  th { font-weight: 600; }
  hr { border: none; border-top: 1px solid #d1d5db; margin: 16px 0; }
  a { color: #1e40af; }
  img { max-width: 100%; }
  ul, ol { padding-left: 24px; }
  @media print { body { padding: 0; } }
</style>
</head>
<body>$htmlBody</body>
</html>
''';

    // Use Blob URL — works reliably for large content and avoids data URI limits.
    final blob = html.Blob([fullHtml], 'text/html');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    final printWindow = html.window.open(blobUrl, '_blank');
    // Wait for content to load, then trigger print dialog.
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        (printWindow as dynamic).print();
      } catch (_) {
        debugPrint('[PrintTrigger] Could not auto-trigger print()');
      }
      // Clean up blob URL after a delay.
      Future.delayed(const Duration(seconds: 5), () {
        html.Url.revokeObjectUrl(blobUrl);
      });
    });
  }

  @override
  void dispose() {
    _triggerSub?.cancel();
    for (final sub in _watchSubs) {
      sub.cancel();
    }
    _watchSubs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.node.children;
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) {
      return widget.childRenderer(children.first, const {});
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.map((c) => widget.childRenderer(c, const {})).toList(),
    );
  }
}


// ---------------------------------------------------------------------------
// DataGrid v2 — with column filtering, date range filter, restyled headers
// ---------------------------------------------------------------------------

Widget _buildDataGrid(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _DataGridWidget(
    key: ValueKey('dg-${node.id}'),
    node: node,
    context: ctx,
  );
}

class _DataGridWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;

  const _DataGridWidget({
    super.key,
    required this.node,
    required this.context,
  });

  @override
  State<_DataGridWidget> createState() => _DataGridWidgetState();
}

class _DataGridWidgetState extends State<_DataGridWidget> {
  final Set<int> _selectedIndices = {};
  Set<String>? _visibleColumns;
  bool _sortDescending = true;
  StreamSubscription? _columnsSub;
  StreamSubscription? _sortSub;
  StreamSubscription? _exportSub;
  StreamSubscription? _searchSub;

  // Filter state
  final Map<String, Set<String>> _valueFilters = {};
  final Map<String, List<String>> _dateFilters = {};
  String _searchQuery = '';
  OverlayEntry? _filterOverlay;

  // --- Scroll mode state ---
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _rowNumVerticalScroll = ScrollController();
  final ScrollController _headerHScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();

  // --- Type-aware sort state (for sortable mode) ---
  String? _sortColumn;
  String _sortDirection = 'none'; // 'none', 'asc', 'desc'

  // --- Inline editing state ---
  int? _editingRow;
  String? _editingCol;
  late TextEditingController _editController;
  final Map<String, String> _edits = {};

  // --- Scroll-to-row highlight ---
  int? _highlightedRow;

  String get _columnMode =>
      PropConverter.to<String>(widget.node.props['columnMode']) ?? 'flex';

  bool get _showRowNumbers =>
      PropConverter.to<bool>(widget.node.props['showRowNumbers']) ?? false;

  bool get _sortable =>
      PropConverter.to<bool>(widget.node.props['sortable']) ?? false;

  bool get _editable =>
      PropConverter.to<bool>(widget.node.props['editable']) ?? false;

  String get _searchMode =>
      PropConverter.to<String>(widget.node.props['searchMode']) ?? 'filter';

  List<Map<String, dynamic>> get _columns {
    final raw = widget.node.props['columns'];
    final explicit = (raw is List ? raw : <dynamic>[])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (explicit.isNotEmpty) return explicit;
    debugPrint('[DataGrid] _columns: columns prop is ${raw.runtimeType}: ${raw is String ? raw : "(not a string)"}');
    // Auto-generate from first row's keys
    final items = _rawItems;
    if (items.isEmpty) return [];
    final first = items.first;
    if (first is! Map) return [];
    return (first as Map).keys.map((k) => <String, dynamic>{
      'key': k.toString(),
      'label': k.toString(),
      'visible': true,
    }).toList();
  }

  List<dynamic> get _rawItems {
    final raw = widget.node.props['items'];
    if (raw is List) return raw;
    debugPrint('[DataGrid] _rawItems: items prop is ${raw.runtimeType}: ${raw is String ? raw : "(not a string)"}');
    return [];
  }

  /// Filtered + sorted items.
  List<dynamic> get _items {
    var items = _rawItems;
    if (items.isEmpty) return items;

    // Apply value filters (AND across columns)
    for (final entry in _valueFilters.entries) {
      final key = entry.key;
      final allowed = entry.value;
      items = items.where((item) {
        if (item is! Map) return false;
        final val = (item[key] ?? '').toString();
        return allowed.contains(val);
      }).toList();
    }

    // Search filter mode: hide non-matching rows
    if (_searchQuery.isNotEmpty && _searchMode == 'filter') {
      items = items.where((item) {
        if (item is! Map) return false;
        return (item as Map).values.any((v) =>
            (v ?? '').toString().toLowerCase().contains(_searchQuery));
      }).toList();
    }

    // Type-aware sort (sortable mode) takes precedence over legacy date sort
    if (_sortable && _sortColumn != null && _sortDirection != 'none') {
      return _applySortable(items);
    }

    // Legacy date sort (flex mode / AuditTrail compatibility)
    final sorted = List<dynamic>.from(items);
    sorted.sort((a, b) {
      final aDate = _getDateString(a);
      final bDate = _getDateString(b);
      return _sortDescending ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
    return sorted;
  }

  String _getDateString(dynamic item) {
    if (item is! Map) return '';
    return (item['sortDate'] ?? item['displayDate'] ?? item['timestamp'] ?? '').toString();
  }

  String get _selectionMode =>
      PropConverter.to<String>(widget.node.props['selectionMode']) ?? 'multi';

  bool get _showCheckbox => _selectionMode != 'none';

  List<Map<String, dynamic>> get _visibleColumnDefs {
    final cols = _columns;
    if (_visibleColumns != null) {
      return cols.where((c) {
        final key = PropConverter.to<String>(c['key']) ?? '';
        return _visibleColumns!.contains(key);
      }).toList();
    }
    return cols.where((c) {
      return PropConverter.to<bool>(c['visible']) != false;
    }).toList();
  }

  bool _isFilterActive(String key) {
    if (_valueFilters.containsKey(key)) {
      // Active if not all values are selected
      final allValues = _getUniqueValues(key, excludeSelf: false);
      return _valueFilters[key]!.length < allValues.length;
    }
    return _dateFilters.containsKey(key);
  }

  /// Get unique values for a column, optionally excluding the column's own filter.
  Set<String> _getUniqueValues(String columnKey, {bool excludeSelf = true}) {
    var items = _rawItems;

    // Apply other filters (not this column's)
    for (final entry in _valueFilters.entries) {
      if (excludeSelf && entry.key == columnKey) continue;
      items = items.where((item) {
        if (item is! Map) return false;
        final val = (item[entry.key] ?? '').toString();
        return entry.value.contains(val);
      }).toList();
    }
    // Date filters are server-side — no client-side date filtering of unique values

    final values = <String>{};
    for (final item in items) {
      if (item is Map) {
        final val = (item[columnKey] ?? '').toString();
        if (val.isNotEmpty) values.add(val);
      }
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    // Sync horizontal scroll between header and body in scroll mode
    _bodyHScroll.addListener(() {
      if (_headerHScroll.hasClients &&
          _headerHScroll.offset != _bodyHScroll.offset) {
        _headerHScroll.jumpTo(_bodyHScroll.offset);
      }
    });
    // Sync vertical scroll between row numbers and data
    _verticalScroll.addListener(() {
      if (_rowNumVerticalScroll.hasClients &&
          _rowNumVerticalScroll.offset != _verticalScroll.offset) {
        _rowNumVerticalScroll.jumpTo(_verticalScroll.offset);
      }
    });
    _subscribeColumns();
    _subscribeSort();
    _subscribeExport();
    _subscribeSearch();
    _applyDefaultDateFilter();
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  static String _formatMmmDate(DateTime dt) =>
      '${dt.year}-${_months[dt.month - 1]}-${dt.day.toString().padLeft(2, '0')}';

  static String _formatSortDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void _applyDefaultDateFilter() {
    final cols = _columns;
    for (final col in cols) {
      if (PropConverter.to<bool>(col['isDate']) == true) {
        final key = PropConverter.to<String>(col['key']) ?? '';
        if (key.isNotEmpty) {
          final now = DateTime.now();
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          _dateFilters[key] = [
            '${_formatSortDate(sevenDaysAgo)} 00:00',
            '${_formatSortDate(now)} 23:59',
          ];
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _columnsSub?.cancel();
    _sortSub?.cancel();
    _exportSub?.cancel();
    _searchSub?.cancel();
    _verticalScroll.dispose();
    _rowNumVerticalScroll.dispose();
    _headerHScroll.dispose();
    _bodyHScroll.dispose();
    _editController.dispose();
    _dismissFilter();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DataGridWidget old) {
    super.didUpdateWidget(old);
    final scrollToRow = PropConverter.to<int>(widget.node.props['scrollToRow']);
    if (scrollToRow != null && scrollToRow != _highlightedRow) {
      _scrollToRow(scrollToRow);
    }
  }

  void _scrollToRow(int row) {
    final t = widget.context.theme;
    final rowHeight = t.controlHeight.md;
    final offset = row * rowHeight;
    if (_verticalScroll.hasClients) {
      _verticalScroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    setState(() => _highlightedRow = row);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightedRow = null);
    });
  }

  // --- Type-aware sort ---

  void _toggleColumnSort(String colKey) {
    setState(() {
      if (_sortColumn != colKey) {
        _sortColumn = colKey;
        _sortDirection = 'asc';
      } else {
        _sortDirection = switch (_sortDirection) {
          'asc' => 'desc',
          'desc' => 'none',
          _ => 'asc',
        };
        if (_sortDirection == 'none') _sortColumn = null;
      }
    });
    final sortChannel = PropConverter.to<String>(widget.node.props['sortChannel']);
    if (sortChannel != null && sortChannel.isNotEmpty) {
      widget.context.eventBus.publish(
        '$sortChannel.state',
        EventPayload(type: 'sort.state', sourceWidgetId: widget.node.id, data: {
          'column': _sortColumn,
          'direction': _sortDirection,
        }),
      );
    }
  }

  List<dynamic> _applySortable(List<dynamic> items) {
    if (_sortColumn == null || _sortDirection == 'none') return items;
    // Find column type
    final colDef = _columns.firstWhere(
      (c) => PropConverter.to<String>(c['key']) == _sortColumn,
      orElse: () => <String, dynamic>{},
    );
    final colType = PropConverter.to<String>(colDef['type']) ?? '';
    final isDate = PropConverter.to<bool>(colDef['isDate']) == true;
    final isNumeric = const {'double', 'int32', 'float64', 'int', 'number'}.contains(colType);

    final sorted = List<dynamic>.from(items);
    sorted.sort((a, b) {
      if (a is! Map || b is! Map) return 0;
      final va = (a[_sortColumn] ?? '').toString();
      final vb = (b[_sortColumn] ?? '').toString();
      int cmp;
      if (isNumeric) {
        final da = double.tryParse(va) ?? 0;
        final db = double.tryParse(vb) ?? 0;
        cmp = da.compareTo(db);
      } else if (isDate) {
        cmp = va.compareTo(vb);
      } else {
        cmp = va.toLowerCase().compareTo(vb.toLowerCase());
      }
      return _sortDirection == 'desc' ? -cmp : cmp;
    });
    return sorted;
  }

  // --- Inline editing ---

  void _startEdit(int row, String col, String currentValue) {
    setState(() {
      _editingRow = row;
      _editingCol = col;
      _editController.text = currentValue;
    });
  }

  void _commitEdit() {
    if (_editingRow == null || _editingCol == null) return;
    final key = '$_editingRow:$_editingCol';
    final newValue = _editController.text;
    final editChannel = PropConverter.to<String>(widget.node.props['editChannel']);
    final row = _editingRow;
    final col = _editingCol;
    setState(() {
      _edits[key] = newValue;
      _editingRow = null;
      _editingCol = null;
    });
    if (editChannel != null && editChannel.isNotEmpty) {
      widget.context.eventBus.publish(
        editChannel,
        EventPayload(type: 'cell.edited', sourceWidgetId: widget.node.id,
          data: {'row': row, 'column': col, 'newValue': newValue}),
      );
    }
  }

  void _subscribeColumns() {
    final channel = PropConverter.to<String>(widget.node.props['columnsChannel']);
    if (channel == null || channel.isEmpty) return;
    _columnsSub = widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      final selected = event.data['selected'];
      if (selected is List) {
        setState(() {
          _visibleColumns = selected.map((e) => e.toString()).toSet();
        });
      }
    });
  }

  void _subscribeSort() {
    final channel = PropConverter.to<String>(widget.node.props['sortChannel']);
    if (channel == null || channel.isEmpty) return;
    _sortSub = widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      setState(() {
        _sortDescending = !_sortDescending;
        _selectedIndices.clear();
      });
      widget.context.eventBus.publish(
        '$channel.state',
        EventPayload(type: 'sort.state', sourceWidgetId: widget.node.id, data: {
          'direction': _sortDescending ? 'desc' : 'asc',
          'tooltip': _sortDescending ? 'Sort: Newest first' : 'Sort: Oldest first',
          'icon': _sortDescending ? 'sort' : 'sort_asc',
        }),
      );
    });
  }

  void _subscribeExport() {
    final channel = PropConverter.to<String>(widget.node.props['exportChannel']);
    if (channel == null || channel.isEmpty) return;
    _exportSub = widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      _exportCsv();
    });
  }

  void _subscribeSearch() {
    final channel = PropConverter.to<String>(widget.node.props['searchChannel']);
    if (channel == null || channel.isEmpty) return;
    _searchSub = widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      final query = (event.data['value'] as String?) ?? '';
      setState(() => _searchQuery = query.toLowerCase());
    });
  }

  void _exportCsv() {
    final items = _items;
    final visCols = _visibleColumnDefs;
    if (visCols.isEmpty || items.isEmpty) return;

    List<dynamic> exportRows;
    if (_selectedIndices.isNotEmpty) {
      exportRows = _selectedIndices
          .where((i) => i < items.length)
          .map((i) => items[i])
          .toList();
    } else {
      exportRows = items;
    }

    final buf = StringBuffer();
    buf.writeln(visCols.map((c) => _csvEscape(PropConverter.to<String>(c['label']) ?? '')).join(','));
    for (final row in exportRows) {
      final cells = visCols.map((c) {
        final key = PropConverter.to<String>(c['key']) ?? '';
        final val = row is Map ? (row[key] ?? '').toString() : '';
        return _csvEscape(val);
      });
      buf.writeln(cells.join(','));
    }

    final csvContent = buf.toString();
    final blob = html.Blob([csvContent], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'data_export.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _toggleRow(int index) {
    if (_selectionMode == 'none') return;
    setState(() {
      if (_selectionMode == 'single') {
        _selectedIndices.contains(index) ? _selectedIndices.clear() : (_selectedIndices..clear()).add(index);
      } else {
        _selectedIndices.contains(index) ? _selectedIndices.remove(index) : _selectedIndices.add(index);
      }
    });
    _publishSelection();
  }

  void _toggleAll() {
    if (_selectionMode != 'multi') return;
    setState(() {
      _selectedIndices.length == _items.length
          ? _selectedIndices.clear()
          : _selectedIndices.addAll(List.generate(_items.length, (i) => i));
    });
    _publishSelection();
  }

  void _publishSelection() {
    final channel = PropConverter.to<String>(widget.node.props['onSelectionChanged']);
    if (channel == null || channel.isEmpty) return;
    final items = _items;
    final selectedItems = _selectedIndices.where((i) => i < items.length).map((i) => items[i]).toList();
    widget.context.eventBus.publish(channel,
      EventPayload(type: 'selection.changed', sourceWidgetId: widget.node.id,
        data: {'selected': selectedItems, 'indices': _selectedIndices.toList()}));
  }

  void _onRowTap(int index, dynamic item) {
    final channel = PropConverter.to<String>(widget.node.props['onRowTap']);
    if (channel != null && channel.isNotEmpty && item is Map) {
      widget.context.eventBus.publish(channel,
        EventPayload(type: 'row.tap', sourceWidgetId: widget.node.id,
          data: Map<String, dynamic>.from(item as Map)));
    }
  }

  // --- Filter popups ---

  void _dismissFilter() {
    _filterOverlay?.remove();
    _filterOverlay = null;
  }

  void _showValueFilter(String columnKey, String label, RenderBox headerBox) {
    _dismissFilter();
    final offset = headerBox.localToGlobal(Offset.zero);
    final t = widget.context.theme;
    final uniqueValues = _getUniqueValues(columnKey).toList()..sort();
    final currentFilter = _valueFilters[columnKey];
    // Start with all selected if no filter, otherwise use current
    var checked = currentFilter != null ? Set<String>.from(currentFilter) : Set<String>.from(uniqueValues);

    _filterOverlay = OverlayEntry(builder: (context) {
      return _ValueFilterOverlay(
        offset: offset,
        headerHeight: headerBox.size.height,
        theme: t,
        label: label,
        uniqueValues: uniqueValues,
        checked: checked,
        onChanged: (newChecked) {
          checked = newChecked;
          setState(() {
            if (newChecked.length == uniqueValues.length) {
              _valueFilters.remove(columnKey); // all selected = no filter
            } else {
              _valueFilters[columnKey] = newChecked;
            }
            _selectedIndices.clear();
          });
        },
        onDismiss: _dismissFilter,
      );
    });
    Overlay.of(context).insert(_filterOverlay!);
  }

  void _showDateFilter(String columnKey, String label, RenderBox headerBox) {
    _dismissFilter();
    final offset = headerBox.localToGlobal(Offset.zero);
    final t = widget.context.theme;
    final existing = _dateFilters[columnKey];

    _filterOverlay = OverlayEntry(builder: (context) {
      return _DateFilterOverlay(
        offset: offset,
        headerHeight: headerBox.size.height,
        theme: t,
        label: label,
        initialFrom: existing != null && existing.isNotEmpty ? existing[0] : '',
        initialTo: existing != null && existing.length > 1 ? existing[1] : '',
        onApply: (from, to) {
          debugPrint('[DataGrid] DATE APPLY: from="$from" to="$to"');
          // 1. Close the popup first
          _dismissFilter();
          // 2. Store the date filter (for icon state + reopening)
          if (from.isEmpty && to.isEmpty) {
            _dateFilters.remove(columnKey);
          } else {
            _dateFilters[columnKey] = [from, to];
          }
          _selectedIndices.clear();
          debugPrint('[DataGrid] dateFilters stored: $_dateFilters');
          // 3. Trigger server re-query
          _publishDateRefresh(from, to);
          debugPrint('[DataGrid] refresh published');
        },
        onClear: () {
          _dismissFilter();
          _dateFilters.remove(columnKey);
          _selectedIndices.clear();
          _publishDateRefresh('', '');
        },
        onDismiss: _dismissFilter,
      );
    });
    Overlay.of(context).insert(_filterOverlay!);
  }

  /// Publish a refresh event to the DataSource with new date range args.
  /// This triggers a server re-query so data outside the current window can be fetched.
  void _publishDateRefresh(String from, String to) {
    final channel = PropConverter.to<String>(widget.node.props['refreshChannel']);
    debugPrint('[DataGrid] _publishDateRefresh: channel=$channel from=$from to=$to');
    if (channel == null || channel.isEmpty) {
      debugPrint('[DataGrid] WARNING: no refreshChannel configured!');
      return;
    }

    // Convert YYYY-MM-DD HH:mm to ISO 8601 for server query
    String startDate = '';
    String endDate = '';
    if (from.isNotEmpty) {
      final datePart = from.length >= 10 ? from.substring(0, 10) : from;
      startDate = '${datePart}T00:00:00.000Z';
    }
    if (to.isNotEmpty) {
      final datePart = to.length >= 10 ? to.substring(0, 10) : to;
      endDate = '${datePart}T23:59:59.999Z';
    }

    widget.context.eventBus.publish(
      channel,
      EventPayload(type: 'refresh', sourceWidgetId: widget.node.id, data: {
        'startDate': startDate,
        'endDate': endDate,
      }),
    );
  }

  /// Compute proportional flex weights based on content width (flex mode).
  Map<String, int> _computeFlexWeights(List<Map<String, dynamic>> visCols, List<dynamic> items) {
    final weights = <String, int>{};
    for (final col in visCols) {
      final key = PropConverter.to<String>(col['key']) ?? '';
      final label = PropConverter.to<String>(col['label']) ?? '';
      final isChip = PropConverter.to<bool>(col['isChip']) == true;
      var maxLen = label.length;
      if (isChip) { maxLen = (maxLen * 0.8).ceil().clamp(4, 10); }
      final sampleCount = items.length < 50 ? items.length : 50;
      for (var i = 0; i < sampleCount; i++) {
        final item = items[i];
        if (item is Map) {
          final val = (item[key] ?? '').toString();
          if (val.length > maxLen) maxLen = val.length;
        }
      }
      final minFlex = label.length + 2;
      weights[key] = maxLen.clamp(minFlex, 40);
    }
    return weights;
  }

  /// Compute pixel widths for scroll mode. Uses explicit width if set,
  /// otherwise samples content to determine width.
  Map<String, double> _computePixelWidths(List<Map<String, dynamic>> visCols, List<dynamic> items) {
    final colMinWidth = PropConverter.to<double>(widget.node.props['columnMinWidth']) ?? 140.0;
    final colMaxWidth = PropConverter.to<double>(widget.node.props['columnMaxWidth']) ?? 400.0;
    const charWidth = 8.0; // approximate monospace-ish character width

    final widths = <String, double>{};
    for (final col in visCols) {
      final key = PropConverter.to<String>(col['key']) ?? '';
      final label = PropConverter.to<String>(col['label']) ?? '';
      // Explicit width override
      final explicit = PropConverter.to<double>(col['width']);
      if (explicit != null) {
        widths[key] = explicit;
        continue;
      }
      var maxLen = label.length;
      final sampleCount = items.length < 50 ? items.length : 50;
      for (var i = 0; i < sampleCount; i++) {
        final item = items[i];
        if (item is Map) {
          final val = (item[key] ?? '').toString();
          if (val.length > maxLen) maxLen = val.length;
        }
      }
      // Convert char count to pixels, add padding for cell margins
      final computed = (maxLen * charWidth) + 32; // 32px for cell padding
      widths[key] = computed.clamp(colMinWidth, colMaxWidth);
    }
    return widths;
  }

  bool _isNumericType(String type) =>
      const {'double', 'int32', 'float64', 'int', 'number'}.contains(type);

  @override
  Widget build(BuildContext context) {
    final t = widget.context.theme;
    final items = _items;
    final visCols = _visibleColumnDefs;

    if (visCols.isEmpty) {
      return Center(child: Text('No columns visible',
          style: TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: t.colors.onSurfaceMuted)));
    }

    if (_columnMode == 'scroll') {
      return _buildScrollMode(t, items, visCols);
    }
    return _buildFlexMode(t, items, visCols);
  }

  // ===== FLEX MODE (original DataGrid layout) =====

  Widget _buildFlexMode(SduiTheme t, List<dynamic> items, List<Map<String, dynamic>> visCols) {
    final flexWeights = _computeFlexWeights(visCols, items);
    final checkboxColWidth = t.controlHeight.md + t.spacing.xs;
    final minWidth = (visCols.length * 50.0 + (_showCheckbox ? checkboxColWidth : 0)).clamp(300, 600);

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < minWidth) {
        return Center(child: Padding(
          padding: EdgeInsets.all(t.spacing.md),
          child: Text('Widen the pane to view the data',
            style: TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: t.colors.onSurfaceMuted),
            textAlign: TextAlign.center),
        ));
      }

      return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Container(
          height: t.controlHeight.md,
          color: t.colors.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_showCheckbox)
                Container(
                  width: checkboxColWidth,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: t.colors.outlineVariant, width: t.lineWeight.subtle)),
                  ),
                  child: Checkbox(
                    value: items.isNotEmpty && _selectedIndices.length == items.length
                        ? true : (_selectedIndices.isNotEmpty ? null : false),
                    tristate: true,
                    onChanged: (_) => _toggleAll(),
                    activeColor: t.colors.primary,
                  ),
                ),
              ...visCols.map((col) {
                final key = PropConverter.to<String>(col['key']) ?? '';
                final flex = flexWeights[key] ?? PropConverter.to<int>(col['flex']) ?? 1;
                final label = PropConverter.to<String>(col['label']) ?? '';
                final isDate = PropConverter.to<bool>(col['isDate']) == true;
                final active = _isFilterActive(key);
                final headerKey = GlobalKey();

                return Expanded(
                  flex: flex,
                  child: _buildFlexHeaderCell(t, key, label, isDate, active, headerKey),
                );
              }),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: t.colors.outline),
        // Data rows
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('No data',
                  style: TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: t.colors.onSurfaceMuted)))
              : ListView.builder(
                  itemCount: items.length,
                  itemExtent: t.controlHeight.md,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedIndices.contains(index);
                    final rowMap = item is Map ? item as Map : <String, dynamic>{};
                    return _DataGridRow(
                      index: index, item: rowMap, columns: visCols,
                      flexWeights: flexWeights,
                      isSelected: isSelected, showCheckbox: _showCheckbox,
                      searchQuery: _searchQuery,
                      theme: t, onToggle: () => _toggleRow(index),
                      onTap: () { _toggleRow(index); _onRowTap(index, item); },
                    );
                  },
                ),
        ),
      ],
    );
    }); // LayoutBuilder
  }

  Widget _buildFlexHeaderCell(SduiTheme t, String key, String label,
      bool isDate, bool active, GlobalKey headerKey) {
    return Container(
      key: headerKey,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: t.colors.outlineVariant, width: t.lineWeight.subtle)),
      ),
      child: InkWell(
        onTap: () {
          if (_sortable) {
            _toggleColumnSort(key);
            return;
          }
          final box = headerKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          if (isDate) {
            _showDateFilter(key, label, box);
          } else {
            _showValueFilter(key, label, box);
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                  style: t.textStyles.labelSmall.toTextStyle(color: t.colors.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_sortable && _sortColumn == key)
                Padding(
                  padding: EdgeInsets.only(left: t.spacing.xs),
                  child: Icon(
                    _sortDirection == 'asc'
                        ? FontAwesomeIcons.arrowUpShortWide
                        : FontAwesomeIcons.arrowDownWideShort,
                    size: 12.0,
                    color: t.colors.primary,
                  ),
                )
              else if (!_sortable)
                Container(
                  width: t.iconSize.sm, height: t.iconSize.sm,
                  decoration: active ? BoxDecoration(
                    border: Border.all(color: t.colors.primary, width: t.lineWeight.subtle),
                    borderRadius: BorderRadius.circular(t.radius.sm),
                    color: t.colors.primary.withAlpha(t.opacity.subtle),
                  ) : null,
                  child: Icon(FontAwesomeIcons.filter,
                    size: t.iconSize.sm - 7,
                    color: active ? t.colors.primary : t.colors.onSurfaceMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== SCROLL MODE (horizontal scrolling, computed column widths) =====

  Widget _buildScrollMode(SduiTheme t, List<dynamic> items, List<Map<String, dynamic>> visCols) {
    final pixelWidths = _computePixelWidths(visCols, items);
    final rowNumWidth = _showRowNumbers ? 56.0 : 0.0;
    final tableWidth = visCols.fold<double>(0, (sum, col) {
      final key = PropConverter.to<String>(col['key']) ?? '';
      return sum + (pixelWidths[key] ?? 140.0);
    });

    final headerStyle = t.textStyles.resolve('labelSmall')?.toTextStyle(
          color: t.colors.onSurfaceVariant,
        ) ??
        TextStyle(fontSize: t.textStyles.labelSmall.fontSize,
            color: t.colors.onSurfaceVariant, fontWeight: FontWeight.w600);
    final typeStyle = TextStyle(fontSize: t.textStyles.micro.fontSize, color: t.colors.onSurfaceMuted);
    final cellStyle = t.textStyles.resolve('bodySmall')?.toTextStyle(
          color: t.colors.onSurface,
        ) ??
        TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: t.colors.onSurface);
    final rowNumStyle = TextStyle(fontSize: t.textStyles.micro.fontSize, color: t.colors.onSurfaceMuted);

    final rowHeight = t.controlHeight.md;
    final searchHighlight = t.colors.warningContainer.withAlpha(160);
    final gotoHighlight = t.colors.warningContainer.withAlpha(200);
    final editHighlight = t.colors.primaryContainer.withAlpha(100);

    return LayoutBuilder(builder: (context, constraints) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Header row ---
          Container(
            height: t.controlHeight.md + 8, // extra for type subtitle
            color: t.colors.surfaceContainerHigh,
            child: Row(
              children: [
                if (_showRowNumbers)
                  Container(
                    width: rowNumWidth,
                    padding: EdgeInsets.symmetric(horizontal: t.spacing.xs, vertical: t.spacing.xs),
                    child: Text('#', style: headerStyle),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _headerHScroll,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: tableWidth,
                      child: Row(
                        children: visCols.map((col) {
                          final key = PropConverter.to<String>(col['key']) ?? '';
                          final label = PropConverter.to<String>(col['label']) ?? key;
                          final colType = PropConverter.to<String>(col['type']) ?? '';
                          final w = pixelWidths[key] ?? 140.0;
                          return SizedBox(
                            width: w,
                            child: InkWell(
                              onTap: _sortable ? () => _toggleColumnSort(key) : null,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: t.spacing.xs, vertical: t.spacing.xs),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(label, style: headerStyle, overflow: TextOverflow.ellipsis),
                                          if (colType.isNotEmpty)
                                            Text(colType, style: typeStyle),
                                        ],
                                      ),
                                    ),
                                    if (_sortable && _sortColumn == key)
                                      Icon(
                                        _sortDirection == 'asc'
                                            ? FontAwesomeIcons.arrowUpShortWide
                                            : FontAwesomeIcons.arrowDownWideShort,
                                        size: 12.0,
                                        color: t.colors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: t.colors.outlineVariant),
          // --- Data rows ---
          Expanded(
            child: items.isEmpty
                ? Center(child: Text('No data',
                    style: TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: t.colors.onSurfaceMuted)))
                : Row(
                    children: [
                      // Frozen row-number column
                      if (_showRowNumbers)
                        SizedBox(
                          width: rowNumWidth,
                          child: ListView.builder(
                            controller: _rowNumVerticalScroll,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            itemExtent: rowHeight,
                            itemBuilder: (_, index) {
                              return Container(
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.symmetric(horizontal: t.spacing.xs),
                                decoration: BoxDecoration(
                                  color: _highlightedRow == index
                                      ? gotoHighlight
                                      : index.isEven ? t.colors.surface : t.colors.surfaceContainerLow,
                                  border: Border(bottom: BorderSide(
                                    color: t.colors.outlineVariant,
                                    width: t.dataTable.rowSeparatorWidth,
                                  )),
                                ),
                                child: Text('${index + 1}', style: rowNumStyle),
                              );
                            },
                          ),
                        ),
                      // Scrollable data area
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _bodyHScroll,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            // Height comes from Expanded parent — this is the key
                            // layout fix vs the broken old DataTable/TabbedDataTable
                            child: ListView.builder(
                              controller: _verticalScroll,
                              itemCount: items.length,
                              itemExtent: rowHeight,
                              itemBuilder: (_, index) {
                                final item = items[index];
                                final rowMap = item is Map ? item as Map : {};
                                final isHighlighted = _highlightedRow == index;
                                final isSelected = _selectedIndices.contains(index);

                                return GestureDetector(
                                  onTap: () { _toggleRow(index); _onRowTap(index, item); },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? t.colors.primaryContainer
                                          : isHighlighted
                                              ? gotoHighlight
                                              : index.isEven ? t.colors.surface : t.colors.surfaceContainerLow,
                                      border: Border(bottom: BorderSide(
                                        color: t.colors.outlineVariant,
                                        width: t.dataTable.rowSeparatorWidth,
                                      )),
                                    ),
                                    child: Row(
                                      children: visCols.map((col) {
                                        final key = PropConverter.to<String>(col['key']) ?? '';
                                        final colType = PropConverter.to<String>(col['type']) ?? '';
                                        final w = pixelWidths[key] ?? 140.0;
                                        final isNumeric = _isNumericType(colType);
                                        final rawValue = (rowMap[key] ?? '').toString();
                                        final editKey = '$index:$key';
                                        final displayValue = _edits.containsKey(editKey) ? _edits[editKey]! : rawValue;
                                        final isEditing = _editingRow == index && _editingCol == key;

                                        // Cell highlight for search highlight mode
                                        Color? cellBg;
                                        if (_edits.containsKey(editKey)) cellBg = editHighlight;
                                        if (_searchMode == 'highlight' && _searchQuery.isNotEmpty &&
                                            displayValue.toLowerCase().contains(_searchQuery)) {
                                          cellBg = searchHighlight;
                                        }

                                        return SizedBox(
                                          width: w,
                                          child: isEditing
                                              ? _buildEditCell(t, cellStyle)
                                              : GestureDetector(
                                                  onDoubleTap: _editable
                                                      ? () => _startEdit(index, key, displayValue)
                                                      : null,
                                                  child: Container(
                                                    color: cellBg,
                                                    alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                                                    padding: EdgeInsets.symmetric(horizontal: t.spacing.xs),
                                                    child: Text(
                                                      displayValue,
                                                      style: cellStyle,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          // Footer: row count
          if (items.length > 0)
            Container(
              color: t.colors.surfaceContainerHigh,
              padding: EdgeInsets.symmetric(vertical: t.spacing.xs, horizontal: t.spacing.sm),
              child: Text(
                '${items.length} row${items.length == 1 ? '' : 's'}',
                style: typeStyle,
              ),
            ),
        ],
      );
    });
  }

  Widget _buildEditCell(SduiTheme t, TextStyle cellStyle) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.xs),
      child: TextField(
        controller: _editController,
        autofocus: true,
        style: cellStyle,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
              horizontal: t.spacing.xs, vertical: t.spacing.xs),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.radius.sm),
            borderSide: BorderSide(color: t.colors.primary, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.radius.sm),
            borderSide: BorderSide(color: t.colors.primary, width: 2),
          ),
        ),
        onSubmitted: (_) => _commitEdit(),
        onTapOutside: (_) => _commitEdit(),
      ),
    );
  }
}

// --- Value Filter Overlay ---

class _ValueFilterOverlay extends StatefulWidget {
  final Offset offset;
  final double headerHeight;
  final SduiTheme theme;
  final String label;
  final List<String> uniqueValues;
  final Set<String> checked;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onDismiss;

  const _ValueFilterOverlay({
    required this.offset, required this.headerHeight, required this.theme,
    required this.label, required this.uniqueValues, required this.checked,
    required this.onChanged, required this.onDismiss,
  });

  @override
  State<_ValueFilterOverlay> createState() => _ValueFilterOverlayState();
}

class _ValueFilterOverlayState extends State<_ValueFilterOverlay> {
  late Set<String> _checked;

  @override
  void initState() {
    super.initState();
    _checked = Set.from(widget.checked);
  }

  void _toggle(String value) {
    setState(() {
      _checked.contains(value) ? _checked.remove(value) : _checked.add(value);
    });
    widget.onChanged(Set.from(_checked));
  }

  void _toggleAll() {
    setState(() {
      _checked.length == widget.uniqueValues.length ? _checked.clear() : _checked.addAll(widget.uniqueValues);
    });
    widget.onChanged(Set.from(_checked));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final allSelected = _checked.length == widget.uniqueValues.length;
    final someSelected = _checked.isNotEmpty && !allSelected;

    return Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onDismiss, child: const SizedBox.expand())),
      Positioned(
        left: widget.offset.dx,
        top: widget.offset.dy + widget.headerHeight + 1,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(t.radius.md),
          color: t.colors.surface,
          child: Container(
            width: 220,
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              border: Border.all(color: t.colors.outlineVariant, width: t.lineWeight.subtle),
              borderRadius: BorderRadius.circular(t.radius.md),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: _toggleAll,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.spacing.sm, vertical: t.spacing.xs),
                  child: Row(children: [
                    SizedBox(width: 20, height: 20, child: Checkbox(
                      value: allSelected ? true : (someSelected ? null : false),
                      tristate: true, onChanged: (_) => _toggleAll(), activeColor: t.colors.primary)),
                    SizedBox(width: t.spacing.sm),
                    Text(allSelected ? 'Deselect All' : 'Select All',
                      style: t.textStyles.labelSmall.toTextStyle(color: t.colors.primary).copyWith(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              Divider(height: 1, color: t.colors.outlineVariant),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
                  child: Column(mainAxisSize: MainAxisSize.min, children: widget.uniqueValues.map((value) {
                    final checked = _checked.contains(value);
                    return InkWell(
                      onTap: () => _toggle(value),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: t.spacing.sm, vertical: t.spacing.xs / 2),
                        child: Row(children: [
                          SizedBox(width: 20, height: 20, child: Checkbox(
                            value: checked, onChanged: (_) => _toggle(value), activeColor: t.colors.primary)),
                          SizedBox(width: t.spacing.sm),
                          Expanded(child: Text(value,
                            style: t.textStyles.bodySmall.toTextStyle(color: t.colors.onSurface),
                            overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    );
                  }).toList()),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// --- Date Range Filter Overlay ---

class _DateFilterOverlay extends StatefulWidget {
  final Offset offset;
  final double headerHeight;
  final SduiTheme theme;
  final String label;
  final String initialFrom;
  final String initialTo;
  final void Function(String from, String to) onApply;
  final VoidCallback onClear;
  final VoidCallback onDismiss;

  const _DateFilterOverlay({
    required this.offset, required this.headerHeight, required this.theme,
    required this.label, required this.initialFrom, required this.initialTo,
    required this.onApply, required this.onClear, required this.onDismiss,
  });

  @override
  State<_DateFilterOverlay> createState() => _DateFilterOverlayState();
}

class _DateFilterOverlayState extends State<_DateFilterOverlay> {
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  late TextEditingController _fromCtrl;
  late TextEditingController _toCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: _sortToMmm(_extractDate(widget.initialFrom)));
    _toCtrl = TextEditingController(text: _sortToMmm(_extractDate(widget.initialTo)));
  }

  String _extractDate(String dt) {
    if (dt.length >= 10) return dt.substring(0, 10);
    return dt;
  }

  /// Convert YYYY-MM-DD to YYYY-MMM-DD for display
  String _sortToMmm(String date) {
    final re = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
    final m = re.firstMatch(date);
    if (m == null) return date;
    final month = int.tryParse(m.group(2)!) ?? 1;
    return '${m.group(1)}-${_months[month.clamp(1, 12) - 1]}-${m.group(3)}';
  }

  /// Convert YYYY-MMM-DD to YYYY-MM-DD for sorting/filtering
  String? _mmmToSort(String date) {
    final re = RegExp(r'^(\d{4})-([A-Za-z]{3})-(\d{2})$');
    final m = re.firstMatch(date);
    if (m == null) return null;
    final monthIdx = _months.indexWhere((mon) => mon.toLowerCase() == m.group(2)!.toLowerCase());
    if (monthIdx < 0) return null;
    return '${m.group(1)}-${(monthIdx + 1).toString().padLeft(2, '0')}-${m.group(3)}';
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _doApply() {
    final fromMmm = _fromCtrl.text.trim();
    final toMmm = _toCtrl.text.trim();

    if (fromMmm.isEmpty && toMmm.isEmpty) {
      widget.onClear();
      return;
    }

    final fromSort = fromMmm.isNotEmpty ? _mmmToSort(fromMmm) : '';
    final toSort = toMmm.isNotEmpty ? _mmmToSort(toMmm) : '';

    if ((fromMmm.isNotEmpty && fromSort == null) || (toMmm.isNotEmpty && toSort == null)) {
      setState(() => _error = 'Use format YYYY-MMM-DD (e.g. 2026-Mar-26)');
      return;
    }

    final fromFull = fromSort != null && fromSort.isNotEmpty ? '$fromSort 00:00' : '';
    final toFull = toSort != null && toSort.isNotEmpty ? '$toSort 23:59' : '';

    if (fromFull.isNotEmpty && toFull.isNotEmpty && toFull.compareTo(fromFull) < 0) {
      setState(() => _error = 'From must be before To');
      return;
    }

    setState(() => _error = null);
    widget.onApply(fromFull, toFull);
    // onApply handles dismissal — don't call onDismiss again
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onDismiss, child: const SizedBox.expand())),
      Positioned(
        left: widget.offset.dx,
        top: widget.offset.dy + widget.headerHeight + 1,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(t.radius.md),
          color: t.colors.surface,
          child: Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border.all(color: t.colors.outlineVariant, width: t.lineWeight.subtle),
              borderRadius: BorderRadius.circular(t.radius.md),
            ),
            padding: EdgeInsets.all(t.spacing.sm),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Filter: ${widget.label}',
                style: t.textStyles.labelSmall.toTextStyle(color: t.colors.onSurface).copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: t.spacing.sm),
              Text('From', style: t.textStyles.labelSmall.toTextStyle(color: t.colors.onSurfaceMuted)),
              SizedBox(height: t.spacing.xs),
              SizedBox(height: t.controlHeight.sm, child: TextField(
                controller: _fromCtrl,
                style: TextStyle(fontSize: t.textStyles.bodySmall.fontSize),
                decoration: InputDecoration(
                  hintText: 'YYYY-MMM-DD',
                  hintStyle: TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: t.colors.onSurfaceMuted),
                  contentPadding: EdgeInsets.symmetric(horizontal: t.spacing.sm, vertical: t.spacing.xs),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radius.sm)),
                  isDense: true),
              )),
              SizedBox(height: t.spacing.sm),
              Text('To', style: t.textStyles.labelSmall.toTextStyle(color: t.colors.onSurfaceMuted)),
              SizedBox(height: t.spacing.xs),
              SizedBox(height: t.controlHeight.sm, child: TextField(
                controller: _toCtrl,
                style: TextStyle(fontSize: t.textStyles.bodySmall.fontSize),
                decoration: InputDecoration(
                  hintText: 'YYYY-MMM-DD',
                  hintStyle: TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: t.colors.onSurfaceMuted),
                  contentPadding: EdgeInsets.symmetric(horizontal: t.spacing.sm, vertical: t.spacing.xs),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radius.sm)),
                  isDense: true),
              )),
              if (_error != null) ...[
                SizedBox(height: t.spacing.xs),
                Text(_error!, style: TextStyle(fontSize: t.textStyles.labelSmall.fontSize, color: t.colors.error)),
              ],
              SizedBox(height: t.spacing.sm),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                InkWell(
                  onTap: widget.onClear,
                  child: Text('Clear', style: t.textStyles.labelSmall.toTextStyle(color: t.colors.link)
                      .copyWith(decoration: TextDecoration.underline)),
                ),
                ElevatedButton(
                  onPressed: _doApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.colors.primary,
                    foregroundColor: t.colors.onPrimary,
                    padding: EdgeInsets.symmetric(horizontal: t.spacing.md, vertical: t.spacing.xs),
                    minimumSize: Size(0, t.controlHeight.sm),
                    textStyle: TextStyle(fontSize: t.textStyles.labelSmall.fontSize),
                  ),
                  child: const Text('Apply'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// --- Data Grid Row ---

class _DataGridRow extends StatelessWidget {
  final int index;
  final Map item;
  final List<Map<String, dynamic>> columns;
  final Map<String, int> flexWeights;
  final bool isSelected;
  final bool showCheckbox;
  final String searchQuery;
  final SduiTheme theme;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _DataGridRow({
    required this.index, required this.item, required this.columns,
    required this.flexWeights,
    required this.isSelected, required this.showCheckbox,
    this.searchQuery = '',
    required this.theme, required this.onToggle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bg = isSelected ? t.colors.primaryContainer : Colors.transparent;

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        hoverColor: t.colors.primary.withAlpha(t.opacity.subtle),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showCheckbox)
              Container(
                width: t.controlHeight.md + t.spacing.xs,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: t.colors.outlineVariant, width: t.lineWeight.subtle)),
                ),
                child: Checkbox(
                  value: isSelected, onChanged: (_) => onToggle(), activeColor: t.colors.primary,
                ),
              ),
            ...columns.map((col) {
              final key = PropConverter.to<String>(col['key']) ?? '';
              final flex = flexWeights[key] ?? PropConverter.to<int>(col['flex']) ?? 1;
              final isChip = PropConverter.to<bool>(col['isChip']) == true;
              final isLink = PropConverter.to<bool>(col['isLink']) == true;
              final colorField = PropConverter.to<String>(col['colorTokenField']);
              final cellColor = PropConverter.to<String>(col['color']);

              final value = _resolveField(item, key);

              Widget cellContent;
              if (isChip) {
                final tokenField = colorField ?? 'colorToken';
                final token = _resolveField(item, tokenField);
                cellContent = Align(alignment: Alignment.centerLeft,
                  child: _MiniChip(label: value, colorToken: token, theme: t));
              } else {
                final color = isLink ? t.colors.link
                    : cellColor == 'onSurfaceMuted' ? t.colors.onSurfaceMuted
                    : t.colors.onSurface;
                cellContent = _buildHighlightedText(value, color, t);
              }

              return Expanded(
                flex: flex,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: t.spacing.xs),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: t.colors.outlineVariant, width: t.lineWeight.subtle)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: cellContent,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String value, Color color, SduiTheme t) {
    if (searchQuery.isEmpty || !value.toLowerCase().contains(searchQuery)) {
      return Text(value,
        style: TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: color),
        maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    // Build spans with highlight
    final lowerVal = value.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (start < value.length) {
      final idx = lowerVal.indexOf(searchQuery, start);
      if (idx < 0) {
        spans.add(TextSpan(text: value.substring(start)));
        break;
      }
      if (idx > start) spans.add(TextSpan(text: value.substring(start, idx)));
      spans.add(TextSpan(
        text: value.substring(idx, idx + searchQuery.length),
        style: TextStyle(backgroundColor: t.colors.warning.withAlpha(80)),
      ));
      start = idx + searchQuery.length;
    }
    return RichText(
      maxLines: 1, overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(fontSize: t.textStyles.bodySmall.fontSize, color: color),
        children: spans));
  }

  String _resolveField(Map item, String key) {
    final val = item[key];
    if (val == null) return '';
    final str = val is String ? val : val.toString();
    // Show empty/null fields as dash for cleaner display
    return str.isEmpty ? '' : str;
  }
}

/// Compact colored chip for DataGrid type columns.
class _MiniChip extends StatelessWidget {
  final String label;
  final String colorToken;
  final SduiTheme theme;

  const _MiniChip({required this.label, required this.colorToken, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final color = _tokenToColor(colorToken, t);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.sm - 2, vertical: t.spacing.xs / 2),
      decoration: BoxDecoration(
        color: color.withAlpha(t.opacity.subtle),
        borderRadius: BorderRadius.circular(t.radius.sm),
      ),
      child: Text(label,
        style: TextStyle(fontSize: t.textStyles.labelSmall.fontSize, color: color, fontWeight: FontWeight.w600),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Color _tokenToColor(String token, SduiTheme t) {
    return switch (token) {
      'success' => t.colors.success,
      'error' => t.colors.error,
      'warning' => t.colors.warning,
      'info' => t.colors.info,
      'primary' => t.colors.primary,
      'secondary' => t.colors.secondary,
      _ => t.colors.onSurfaceMuted,
    };
  }
}


// ---------------------------------------------------------------------------
// DataSource
// ---------------------------------------------------------------------------

Widget _buildDataSource(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _DataSourceWidget(
    key: ValueKey('ds-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _DataSourceWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _DataSourceWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_DataSourceWidget> createState() => _DataSourceWidgetState();
}

class _DataSourceWidgetState extends State<_DataSourceWidget> {
  bool _loading = false;
  String? _errorMessage;
  dynamic _data;
  dynamic _defaultData; // Original data before search replaced it
  StreamSubscription? _refreshSub;
  StreamSubscription? _searchSub;
  StreamSubscription? _contractSub;
  Map<String, dynamic> _eventScope = {};

  // --- Tree state (active only when children config is present) ---
  //
  // All tree state is keyed by _nodeId (UUID), NOT the model's id field.
  // Each node gets a UUID stamped as `_nodeId` when it enters the system
  // (root fetch or child fetch). This allows the same model to appear at
  // multiple positions in the tree without collisions.
  dynamic _rootData; // Unflattened root data (before tree metadata injection)
  final Set<String> _expandedNodes = {};
  final Map<String, List<Map<String, dynamic>>> _childrenCache = {};
  final Set<String> _loadingNodes = {};
  StreamSubscription? _expandSub;

  static final _rng = Random();

  /// Generate a v4-style UUID without external dependencies.
  static String _uuid() {
    const hex = '0123456789abcdef';
    String b(int n) => List.generate(n, (_) => hex[_rng.nextInt(16)]).join();
    return '${b(8)}-${b(4)}-4${b(3)}-${hex[8 + _rng.nextInt(4)]}${b(3)}-${b(12)}';
  }

  /// Stamp every item in [items] with a `_nodeId` UUID (if not already set).
  static void _stampUuids(List<Map<String, dynamic>> items) {
    for (final item in items) {
      item['_nodeId'] ??= _uuid();
    }
  }

  String? get _refreshChannel =>
      PropConverter.to<String>(widget.node.props['refreshOn']);

  String? get _searchChannel =>
      PropConverter.to<String>(widget.node.props['searchChannel']);

  /// Raw (unresolved) args templates, preserved by the renderer via _rawArgs prop.
  List<dynamic>? get _rawArgs => widget.node.props['_rawArgs'] as List?;

  /// Tree config — when non-null, DataSource is tree-aware.
  Map<String, dynamic>? get _childrenConfig =>
      widget.node.props['children'] as Map<String, dynamic>?;

  bool get _isTree => _childrenConfig != null;

  String get _nodeIdField =>
      PropConverter.to<String>(widget.node.props['nodeId']) ?? 'id';

  String? get _expandChannel =>
      PropConverter.to<String>(widget.node.props['expandChannel']);

  /// Inline consumes declaration for contract-based refresh.
  ConsumesDecl? get _consumesDecl {
    final raw = widget.node.props['consumes'] as Map<String, dynamic>?;
    if (raw == null) return null;
    return ConsumesDecl.fromJson(raw);
  }

  @override
  void initState() {
    super.initState();
    _subscribeRefresh();
    _subscribeSearch();
    _subscribeContract();
    _subscribeExpand();
    _fetchData();
  }

  @override
  void didUpdateWidget(_DataSourceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldChannel = PropConverter.to<String>(oldWidget.node.props['refreshOn']);
    if (oldChannel != _refreshChannel) {
      _refreshSub?.cancel();
      _subscribeRefresh();
    }
    final oldSearchChannel = PropConverter.to<String>(oldWidget.node.props['searchChannel']);
    if (oldSearchChannel != _searchChannel) {
      _searchSub?.cancel();
      _subscribeSearch();
    }
    final oldExpandChannel = PropConverter.to<String>(oldWidget.node.props['expandChannel']);
    if (oldExpandChannel != _expandChannel) {
      _expandSub?.cancel();
      _subscribeExpand();
    }
    final oldProps = oldWidget.node.props;
    final newProps = widget.node.props;
    if (oldProps['service'] != newProps['service'] ||
        oldProps['method'] != newProps['method'] ||
        oldProps['args']?.toString() != newProps['args']?.toString()) {
      _fetchData();
    }
  }

  Timer? _searchDebounce;

  @override
  void dispose() {
    _expandSub?.cancel();
    _refreshSub?.cancel();
    _searchSub?.cancel();
    _contractSub?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _subscribeRefresh() {
    final channel = _refreshChannel;
    if (channel == null || channel.isEmpty) return;
    _refreshSub = widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      _eventScope = Map<String, dynamic>.from(event.data);
      _fetchData();
    });
  }

  void _subscribeExpand() {
    final channel = _expandChannel;
    if (channel == null || channel.isEmpty || !_isTree) {
      debugPrint('[DataSource.tree] _subscribeExpand skipped: '
          'channel=$channel isTree=$_isTree childrenConfig=$_childrenConfig');
      return;
    }
    debugPrint('[DataSource.tree] subscribing to expandChannel=$channel');
    _expandSub = widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      final nodeId = event.data['_nodeId']?.toString();
      debugPrint('[DataSource.tree] expand event: _nodeId=$nodeId');
      if (nodeId == null || nodeId.isEmpty) return;
      _toggleNode(nodeId);
    });
  }

  void _subscribeSearch() {
    final channel = _searchChannel;
    if (channel == null || channel.isEmpty) return;
    _searchSub = widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      final query = (event.data['query'] as String?) ?? '';
      if (query.isEmpty) {
        _searchDebounce?.cancel();
        if (_defaultData != null) {
          setState(() => _data = _defaultData);
        }
      } else {
        // Debounce: wait 300ms after last keystroke before calling API
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 300), () {
          if (mounted) _fetchSearchResults(query);
        });
      }
    });
  }

  void _subscribeContract() {
    final decl = _consumesDecl;
    final bus = widget.context.contractBus;
    if (decl == null || bus == null) return;
    _contractSub = bus.subscribe(decl).listen((mapped) {
      if (!mounted) return;
      _eventScope = mapped;
      _fetchData();
    });
  }

  void _fetchSearchResults(String query) {
    final caller = widget.context.serviceCaller;
    if (caller == null) return;

    final props = widget.node.props;
    final searchService = PropConverter.to<String>(props['searchService']);
    final searchMethod = PropConverter.to<String>(props['searchMethod']);
    if (searchService == null || searchMethod == null) return;

    final searchArgs = (props['searchArgs'] as List<dynamic>?) ?? const [];
    final args = [query, ...searchArgs];

    final resultFilter = props['searchResultFilter'] is Map
        ? Map<String, dynamic>.from(props['searchResultFilter'] as Map)
        : <String, dynamic>{};

    _defaultData ??= _data;

    // Don't set _loading = true — keep current data visible during search.

    caller(searchService, searchMethod, args).then((result) {
      if (!mounted) return;
      dynamic filtered = result;
      if (resultFilter.isNotEmpty && result is List) {
        filtered = result.where((item) {
          if (item is! Map) return false;
          return resultFilter.entries.every((e) => item[e.key] == e.value);
        }).toList();
      }
      setState(() {
        _data = filtered;
        _errorMessage = null;
      });
    }).catchError((Object e, StackTrace st) {
      ErrorReporter.instance.report(e,
        stackTrace: st,
        source: 'sdui.DataSource.search',
        context: '$searchService.$searchMethod("$query")',
      );
    });
  }

  /// Resolve args using the event scope. If we have raw args (unresolved
  /// templates), re-resolve them with the event payload. Otherwise use the
  /// already-resolved props.
  List<dynamic> _resolveArgs() {
    final rawArgs = _rawArgs;
    if (rawArgs != null && _eventScope.isNotEmpty) {
      // Re-resolve raw arg templates using the original parent scope
      // (which has {{props.scopeId}} etc.) merged with the event scope
      // (which has {{startDate}}, {{endDate}} etc.).
      final resolver = widget.context.templateResolver;
      final parentScope = widget.node.props['_parentScope'] as Map<String, dynamic>? ?? {};
      final mergedScope = <String, dynamic>{
        ...parentScope,
        ..._eventScope,
      };
      return rawArgs
          .map((a) => resolver.resolveValue(a, mergedScope))
          .toList();
    }
    // Fall back to already-resolved props
    return (widget.node.props['args'] as List<dynamic>?) ?? const [];
  }

  void _fetchData() {
    final caller = widget.context.serviceCaller;
    if (caller == null) return;

    final props = widget.node.props;
    final service = props['service'] as String;
    final method = props['method'] as String;
    final args = _resolveArgs();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    caller(service, method, args).then((result) {
      if (mounted) {
        setState(() {
          if (_isTree) {
            _rootData = result;
            // Stamp each root node with a UUID.
            if (result is List) {
              final typed = result
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              _stampUuids(typed);
              _rootData = typed;
            }
            debugPrint('[DataSource.tree] root data fetched: '
                '${result is List ? result.length : result.runtimeType} items');
            _rebuildFlatList();
          } else {
            _data = result;
            _defaultData = result;
          }
          _loading = false;
          _errorMessage = null;
        });
      }
    }).catchError((Object e, StackTrace st) {
      final errorMsg = '$service.$method: $e';
      ErrorReporter.instance.report(
        e,
        stackTrace: st,
        source: 'sdui.DataSource',
        context: '$service.$method(${args.map((a) => a is String ? '"$a"' : a).join(', ')})',
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = errorMsg;
        });
      }
    });
  }

  // -------------------------------------------------------------------------
  // Tree operations
  // -------------------------------------------------------------------------

  void _toggleNode(String nodeId) {
    final wasExpanded = _expandedNodes.contains(nodeId);
    debugPrint('[DataSource.tree] toggleNode=$nodeId wasExpanded=$wasExpanded');
    setState(() {
      if (wasExpanded) {
        _expandedNodes.remove(nodeId);
        _collapseDescendants(nodeId);
      } else {
        _expandedNodes.add(nodeId);
      }
      _rebuildFlatList();
    });

    // Lazy-fetch children on first expand
    if (!wasExpanded && !_childrenCache.containsKey(nodeId)) {
      debugPrint('[DataSource.tree] fetching children for $nodeId');
      _fetchChildren(nodeId);
    }
  }

  void _collapseDescendants(String parentNodeId) {
    final children = _childrenCache[parentNodeId];
    if (children == null) return;
    for (final child in children) {
      final childNodeId = child['_nodeId'] as String?;
      if (childNodeId != null && _expandedNodes.remove(childNodeId)) {
        _collapseDescendants(childNodeId);
      }
    }
  }

  void _fetchChildren(String nodeId) {
    final caller = widget.context.serviceCaller;
    final config = _childrenConfig;
    if (caller == null || config == null) return;

    final service = config['service'] as String?;
    final method = config['method'] as String?;
    if (service == null || method == null) return;

    final rawArgs = (config['args'] as List<dynamic>?) ?? const [];

    // Find the parent node to resolve {{parent.xxx}} bindings
    final parentNode = _findNodeById(nodeId);
    if (parentNode == null) return;

    final resolvedArgs = _resolveParentArgs(rawArgs, parentNode);
    debugPrint('[DataSource.tree] fetchChildren: $service.$method($resolvedArgs)');

    setState(() {
      _loadingNodes.add(nodeId);
      _rebuildFlatList();
    });

    caller(service, method, resolvedArgs).then((result) {
      if (!mounted) return;
      final children = (result is List)
          ? result.map((e) => e is Map
              ? Map<String, dynamic>.from(e)
              : <String, dynamic>{}).toList()
          : <Map<String, dynamic>>[];
      _stampUuids(children);
      setState(() {
        _childrenCache[nodeId] = children;
        _loadingNodes.remove(nodeId);
        _rebuildFlatList();
      });
    }).catchError((Object e, StackTrace st) {
      ErrorReporter.instance.report(e,
        stackTrace: st,
        source: 'sdui.DataSource.children',
        context: '$service.$method for node $nodeId',
      );
      if (mounted) {
        setState(() {
          _loadingNodes.remove(nodeId);
          _childrenCache[nodeId] = []; // Mark as explored (empty)
          _rebuildFlatList();
        });
      }
    });
  }

  /// Resolve {{parent.xxx}} bindings in children config args.
  List<dynamic> _resolveParentArgs(
      List<dynamic> rawArgs, Map<String, dynamic> parent) {
    final pattern = RegExp(r'\{\{parent\.(\w+(?:\.\w+)*)\}\}');
    dynamic resolve(dynamic arg) {
      if (arg is String) {
        return arg.replaceAllMapped(pattern, (m) {
          final path = m.group(1)!;
          dynamic value = parent;
          for (final segment in path.split('.')) {
            if (value is Map) {
              value = value[segment];
            } else {
              return '';
            }
          }
          return value?.toString() ?? '';
        });
      }
      if (arg is List) return arg.map(resolve).toList();
      return arg;
    }
    return rawArgs.map(resolve).toList();
  }

  /// Find a node by its UUID (`_nodeId`) across root data and all cached children.
  Map<String, dynamic>? _findNodeById(String nodeId) {
    if (_rootData is List) {
      for (final item in _rootData) {
        if (item is Map && item['_nodeId']?.toString() == nodeId) {
          return Map<String, dynamic>.from(item);
        }
      }
    }
    for (final children in _childrenCache.values) {
      for (final child in children) {
        if (child['_nodeId']?.toString() == nodeId) return child;
      }
    }
    return null;
  }

  /// Rebuild `_data` as a flat list with tree metadata from `_rootData`.
  void _rebuildFlatList() {
    if (!_isTree || _rootData is! List) {
      debugPrint('[DataSource.tree] rebuildFlatList skipped: isTree=$_isTree rootData=${_rootData?.runtimeType}');
      return;
    }
    final flat = <Map<String, dynamic>>[];

    // Prepend static root nodes (e.g., virtual "My Projects" entry).
    final rootNodes = widget.node.props['rootNodes'];
    if (rootNodes is List) {
      for (final rn in rootNodes) {
        if (rn is! Map) continue;
        final m = Map<String, dynamic>.from(rn);
        m['_nodeId'] ??= _uuid();
        _addNodeToFlatList(m, 0, flat);
      }
    }

    for (final root in _rootData as List) {
      if (root is! Map) continue;
      _addNodeToFlatList(Map<String, dynamic>.from(root), 0, flat);
    }
    _data = flat;
    _defaultData = flat;
    debugPrint('[DataSource.tree] rebuilt flat list: ${flat.length} items, '
        'expanded=${_expandedNodes.toList()}, cached=${_childrenCache.keys.toList()}');
  }

  void _addNodeToFlatList(
      Map<String, dynamic> node, int depth, List<Map<String, dynamic>> flat) {
    final nodeId = node['_nodeId'] as String? ?? '';

    final isExpanded = _expandedNodes.contains(nodeId);
    final isLoading = _loadingNodes.contains(nodeId);
    final cachedChildren = _childrenCache[nodeId];
    // Assume has children until fetch proves otherwise
    final hasChildren = cachedChildren != null
        ? cachedChildren.isNotEmpty
        : true;

    flat.add({
      ...node,
      '_depth': depth,
      '_expanded': isExpanded,
      '_hasChildren': hasChildren,
      '_loading': isLoading,
      '_indent': widget.context.theme.spacing.xs + (depth * (widget.context.theme.spacing.md + widget.context.theme.spacing.xs)),
      '_chevronIcon': isExpanded ? 'expand_more' : 'chevron_right',
    });

    if (isExpanded && cachedChildren != null) {
      for (final child in cachedChildren) {
        _addNodeToFlatList(child, depth + 1, flat);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caller = widget.context.serviceCaller;
    if (caller == null) {
      ErrorReporter.instance.report(
        'serviceCaller is null — not authenticated',
        source: 'sdui.DataSource',
        context: '${widget.node.props['service']}.${widget.node.props['method']}',
        severity: ErrorSeverity.warning,
      );
      return _placeholder('Not authenticated');
    }

    final hasChildren = widget.node.children.isNotEmpty;

    if (hasChildren) {
      // Expose state variables to children via scope.
      // Event payload fields from refreshOn are also merged so that
      // downstream bindings (e.g., {{fileId}}) resolve to event values.
      return _renderChildren({
        ..._eventScope,
        'data': _data,
        'loading': _loading,
        'error': _errorMessage != null,
        'errorMessage': _errorMessage ?? '',
        'ready': !_loading && _errorMessage == null,
      });
    }

    // No children: backwards-compatible spinner/error
    if (_loading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(widget.context.theme.spacing.md),
          child: SizedBox(
            width: widget.context.theme.window.spinnerSize * 0.7, height: widget.context.theme.window.spinnerSize * 0.7,
            child: CircularProgressIndicator(
              strokeWidth: widget.context.theme.lineWeight.emphasis,
              color: widget.context.theme.colors.primary,
            ),
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      return _error(_errorMessage!);
    }
    return _placeholder('No data');
  }

  Widget _renderChildren(Map<String, dynamic> scope) {
    final children = widget.node.children;
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) {
      return widget.childRenderer(children.first, scope);
    }
    // Stack children so they overlap. This supports the common pattern of
    // mutually-exclusive Conditionals (loading/error/ready) where only one
    // is visible at a time. Hidden Conditionals render SizedBox.shrink().
    // Using Stack instead of Column avoids unbounded-height issues when
    // the visible child is a scrollable (e.g., ListView).
    return Stack(
      fit: StackFit.loose,
      children: children.map((c) => widget.childRenderer(c, scope)).toList(),
    );
  }

  Widget _error(String message) {
    final theme = widget.context.theme;
    return Container(
      padding: EdgeInsets.all(theme.spacing.sm + theme.spacing.xs),
      decoration: BoxDecoration(
        color: theme.colors.error.withAlpha(theme.opacity.subtle),
        border: Border.all(color: theme.colors.error.withAlpha(theme.opacity.light)),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Text(
        'Data error: $message',
        style: TextStyle(color: theme.colors.error.withAlpha(theme.opacity.strong), fontSize: theme.textStyles.bodySmall.fontSize),
      ),
    );
  }

  Widget _placeholder(String message) {
    final theme = widget.context.theme;
    return Container(
      padding: EdgeInsets.all(theme.spacing.sm + theme.spacing.xs),
      decoration: BoxDecoration(
        color: theme.colors.onSurfaceMuted.withAlpha(theme.opacity.subtle),
        border: Border.all(color: theme.colors.onSurfaceMuted.withAlpha(theme.opacity.light)),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Text(
        message,
        style: TextStyle(color: theme.colors.onSurfaceMuted.withAlpha(theme.opacity.strong), fontSize: theme.textStyles.bodySmall.fontSize),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ForEach
// ---------------------------------------------------------------------------

Widget _buildForEach(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  final filterChannel = PropConverter.to<String>(node.props['filterChannel']);
  final limitChannel = PropConverter.to<String>(node.props['limitChannel']);

  // If a filterChannel or limitChannel is set, use the stateful version.
  if ((filterChannel != null && filterChannel.isNotEmpty) ||
      (limitChannel != null && limitChannel.isNotEmpty)) {
    return _FilterableForEach(
      key: ValueKey('ffe-${node.id}'),
      node: node,
      ctx: ctx,
      childRenderer: childRenderer,
      filterChannel: filterChannel ?? '',
      limitChannel: limitChannel ?? '',
    );
  }

  // Use _ForEachWidget so it has a BuildContext to read StateManagerScope.
  return _ForEachWidget(
    key: ValueKey('fe-${node.id}'),
    node: node,
    ctx: ctx,
    childRenderer: childRenderer,
  );
}

/// StatelessWidget wrapper for ForEach. Has a BuildContext so it can read
/// StateManagerScope for selection state. Renders items synchronously
/// via _renderForEach.
class _ForEachWidget extends StatelessWidget {
  final SduiNode node;
  final SduiRenderContext ctx;
  final SduiChildRenderer childRenderer;

  const _ForEachWidget({
    super.key,
    required this.node,
    required this.ctx,
    required this.childRenderer,
  });

  @override
  Widget build(BuildContext context) {
    // Read StateManager from the widget tree — persists beyond the SDUI render pass.
    final manager = StateManagerScope.maybeOf(context);
    // Temporarily set on render context so _renderForEach can access it.
    final previous = ctx.stateManager;
    ctx.stateManager = manager;
    final result = _renderForEach(node, ctx, childRenderer, '');
    ctx.stateManager = previous;
    return result;
  }
}

/// Derive a stable key for a list item. Prefers 'id', then 'name', then index.
String _itemKey(Map<String, dynamic> item, int index) {
  // Tree nodes have a UUID — always unique.
  final nodeId = item['_nodeId'];
  if (nodeId != null && '$nodeId'.isNotEmpty) return 'item-$nodeId';
  final id = item['id'];
  if (id != null && '$id'.isNotEmpty) return 'item-$id';
  final name = item['name'];
  if (name != null && '$name'.isNotEmpty) return 'item-$name-$index';
  return 'item-$index';
}

/// Pure rendering logic for ForEach — shared by stateless and stateful paths.
Widget _renderForEach(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer,
    String filterQuery) {
  final items = node.props['items'];

  if (items == null) return const SizedBox.shrink();

  if (items is! List) {
    ErrorReporter.instance.report(
      'ForEach "items" prop is not a List (got ${items.runtimeType})',
      source: 'sdui.ForEach',
      context: 'id: ${node.id}',
    );
    final theme = ctx.theme;
    return Container(
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        color: theme.colors.error.withAlpha(theme.opacity.subtle),
        border: Border.all(color: theme.colors.error.withAlpha(theme.opacity.light)),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: Text(
        'ForEach: items is not a List (${items.runtimeType})',
        style: TextStyle(color: theme.colors.error.withAlpha(theme.opacity.strong), fontSize: theme.textStyles.bodySmall.fontSize),
      ),
    );
  }

  if (items.isEmpty) {
    final emptyText = PropConverter.to<String>(node.props['emptyText']);
    if (emptyText != null && emptyText.isEmpty) return const SizedBox.shrink();
    final msg = emptyText ?? 'Empty';
    return Padding(
      padding: EdgeInsets.all(ctx.theme.spacing.md),
      child: Text(msg, style: TextStyle(color: ctx.theme.colors.onSurfaceMuted, fontSize: ctx.theme.textStyles.bodySmall.fontSize)),
    );
  }

  final rawLimit = node.props['limit'];
  final limit = (rawLimit is int ? rawLimit : int.tryParse('$rawLimit')) ?? 0;
  final rawOffset = node.props['offset'];
  final offset = (rawOffset is int ? rawOffset : int.tryParse('$rawOffset')) ?? 0;

  // Filter fields (optional — if omitted, match all string values)
  final rawFilterFields = node.props['filterFields'];
  final filterFields = rawFilterFields is List
      ? rawFilterFields.cast<String>()
      : <String>[];

  var workingItems = items.skip(offset).toList();

  // Apply exact-match `where` filter (e.g. {"kind": "WebAppOperator"}).
  final whereFilter = node.props['where'];
  if (whereFilter is Map && whereFilter.isNotEmpty) {
    workingItems = workingItems.where((item) {
      if (item is! Map) return false;
      return whereFilter.entries.every((e) =>
          item[e.key]?.toString() == e.value?.toString());
    }).toList();
  }

  // Apply exact-match `whereNot` exclusion filter (e.g. {"kind": "FolderDocument"}).
  final whereNotFilter = node.props['whereNot'];
  if (whereNotFilter is Map && whereNotFilter.isNotEmpty) {
    workingItems = workingItems.where((item) {
      if (item is! Map) return false;
      return !whereNotFilter.entries.every((e) =>
          item[e.key]?.toString() == e.value?.toString());
    }).toList();
  }

  // Apply client-side text filter if a query is active.
  if (filterQuery.isNotEmpty) {
    workingItems = workingItems.where((item) {
      if (item is! Map) return false;
      final fields = filterFields.isNotEmpty
          ? filterFields
          : item.keys.whereType<String>();
      return fields.any((key) {
        final val = item[key];
        if (val is String) return val.toLowerCase().contains(filterQuery);
        if (val is Map && val['kind'] == 'Date' && val['value'] is String) {
          return (val['value'] as String).toLowerCase().contains(filterQuery);
        }
        return val?.toString().toLowerCase().contains(filterQuery) ?? false;
      });
    }).toList();
  }

  final paginatedItems = workingItems
      .take(limit > 0 ? limit : workingItems.length)
      .toList();

  if (paginatedItems.isEmpty) {
    final emptyText = PropConverter.to<String>(node.props['emptyText']);
    if (emptyText != null) {
      if (emptyText.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.all(ctx.theme.spacing.md),
        child: Text(emptyText, style: TextStyle(color: ctx.theme.colors.onSurfaceMuted, fontSize: ctx.theme.textStyles.bodySmall.fontSize)),
      );
    }
    final msg = filterQuery.isNotEmpty ? 'No matches' : 'Empty';
    return Padding(
      padding: EdgeInsets.all(ctx.theme.spacing.md),
      child: Text(msg, style: TextStyle(color: ctx.theme.colors.onSurfaceMuted, fontSize: ctx.theme.textStyles.bodySmall.fontSize)),
    );
  }

  final manager = ctx.stateManager;

  // Build a keyed widget per item so Flutter can diff by identity.
  Widget buildItem(int i) {
    final item = paginatedItems[i];
    final itemMap =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final scope = <String, dynamic>{'item': itemMap, '_index': offset + i};

    // Check selection inline — no per-item listeners.
    final selected = manager != null && manager.isSelected(itemMap);

    final children = <Widget>[];
    for (final childNode in node.children) {
      final indexedNode = _suffixNodeIds(childNode, '__$i');
      children.add(childRenderer(indexedNode, scope));
    }

    Widget result = children.length == 1 ? children.first : Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    if (selected) {
      result = DecoratedBox(
        decoration: BoxDecoration(
          color: ctx.theme.colors.primaryContainer,
          borderRadius: BorderRadius.circular(ctx.theme.radius.sm),
        ),
        child: result,
      );
    }
    return KeyedSubtree(
      key: ValueKey(_itemKey(itemMap, offset + i)),
      child: result,
    );
  }

  // For small lists, use Column; for larger lists, use ListView.builder
  // to avoid rendering off-screen items.
  if (paginatedItems.length <= 20) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(paginatedItems.length, buildItem),
    );
  }

  return ListView.builder(
    shrinkWrap: true,
    itemCount: paginatedItems.length,
    itemBuilder: (_, i) => buildItem(i),
  );
}

/// Stateful ForEach that subscribes to a filter channel for client-side filtering.
/// One-directional: only receives filter queries, never publishes back.
class _FilterableForEach extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext ctx;
  final SduiChildRenderer childRenderer;
  final String filterChannel;
  final String limitChannel;

  const _FilterableForEach({
    super.key,
    required this.node,
    required this.ctx,
    required this.childRenderer,
    required this.filterChannel,
    this.limitChannel = '',
  });

  @override
  State<_FilterableForEach> createState() => _FilterableForEachState();
}

class _FilterableForEachState extends State<_FilterableForEach> {
  String _filterQuery = '';
  int? _dynamicLimit;
  StreamSubscription<EventPayload>? _filterSub;
  StreamSubscription<EventPayload>? _limitSub;

  @override
  void initState() {
    super.initState();
    if (widget.filterChannel.isNotEmpty) {
      _filterSub = widget.ctx.eventBus
          .subscribe(widget.filterChannel)
          .listen(_onFilter);
    }
    if (widget.limitChannel.isNotEmpty) {
      _limitSub = widget.ctx.eventBus
          .subscribe(widget.limitChannel)
          .listen(_onLimit);
    }
  }

  @override
  void dispose() {
    _filterSub?.cancel();
    _limitSub?.cancel();
    super.dispose();
  }

  void _onFilter(EventPayload event) {
    final query = (event.data['query'] as String?) ??
        (event.data['value'] as String?) ?? '';
    if (query != _filterQuery && mounted) {
      setState(() => _filterQuery = query);
    }
  }

  void _onLimit(EventPayload event) {
    final value = PropConverter.to<int>(event.data['value']);
    if (value != null && value != _dynamicLimit && mounted) {
      setState(() => _dynamicLimit = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Override the node's limit prop with dynamic limit if set
    final node = _dynamicLimit != null
        ? widget.node.copyWith(props: {...widget.node.props, 'limit': _dynamicLimit})
        : widget.node;
    return _renderForEach(
        node, widget.ctx, widget.childRenderer, _filterQuery);
  }
}

/// Recursively appends a suffix to all node IDs in the subtree.
SduiNode _suffixNodeIds(SduiNode node, String suffix) {
  return node.copyWith(
    id: '${node.id}$suffix',
    children: node.children.map((c) => _suffixNodeIds(c, suffix)).toList(),
  );
}

// ---------------------------------------------------------------------------
// Action
// ---------------------------------------------------------------------------

Widget _buildAction(
    SduiNode node, List<Widget> children, SduiRenderContext ctx) {
  final gesture = PropConverter.to<String>(node.props['gesture']) ?? 'onTap';
  final channel = PropConverter.to<String>(node.props['channel']) ?? '';
  final payload =
      node.props['payload'] is Map
          ? Map<String, dynamic>.from(node.props['payload'] as Map)
          : <String, dynamic>{};
  final hoverColorStr = PropConverter.to<String>(node.props['hoverColor']);

  final isLink = payload['intent'] == 'openUrl';

  var child = children.length == 1
      ? children.first
      : Column(mainAxisSize: MainAxisSize.min, children: children);

  // Automatically style link actions with the theme's link color.
  if (isLink) {
    final linkColor = ctx.theme.colors.link;
    child = DefaultTextStyle.merge(
      style: TextStyle(color: linkColor),
      child: IconTheme(
        data: IconThemeData(color: linkColor, size: 12),
        child: child,
      ),
    );
  }

  return _ActionWidget(
    key: ValueKey('action-${node.id}'),
    nodeId: node.id,
    gesture: gesture,
    channel: channel,
    payload: payload,
    hoverColor: _resolveActionColor(hoverColorStr, ctx),
    eventBus: ctx.eventBus,
    child: child,
  );
}

/// Action widget that reads StateManager from context.
/// If a StateManager exists, delegates to it. Otherwise publishes directly to EventBus.
class _ActionWidget extends StatelessWidget {
  final String nodeId;
  final String gesture;
  final String channel;
  final Map<String, dynamic> payload;
  final Color? hoverColor;
  final EventBus eventBus;
  final Widget child;

  const _ActionWidget({
    super.key,
    required this.nodeId,
    required this.gesture,
    required this.channel,
    required this.payload,
    this.hoverColor,
    required this.eventBus,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    void handler() {
      try {
        // Handle openUrl intent directly — open in new browser tab.
        if (payload['intent'] == 'openUrl') {
          final url = payload['url']?.toString() ?? '';
          if (url.isNotEmpty) {
            html.window.open(url, '_blank');
            return;
          }
        }

        // Use findAncestorWidgetOfExactType — does NOT register as dependency.
        // Action only needs the manager at tap time, not during build.
        final scope = context.findAncestorWidgetOfExactType<StateManagerScope>();
        final manager = scope?.notifier;
        if (manager != null) {
          // StateManager handles state update + EventBus publishing.
          manager.onAction(channel, payload);
        } else {
          // No StateManager — publish directly to EventBus.
          eventBus.publish(
            channel,
            EventPayload(
              type: gesture,
              sourceWidgetId: nodeId,
              data: {...payload, '_channel': channel},
            ),
          );
        }
      } catch (e, st) {
        ErrorReporter.instance.report(e,
          stackTrace: st,
          source: 'sdui.Action',
          context: '$nodeId gesture=$gesture channel=$channel',
        );
      }
    }

    final gestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: gesture == 'onTap' ? handler : null,
      onDoubleTap: gesture == 'onDoubleTap' ? handler : null,
      onLongPress: gesture == 'onLongPress' ? handler : null,
      onSecondaryTap: gesture == 'onSecondaryTap' ? handler : null,
      child: child,
    );

    if (hoverColor == null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: gestureDetector,
      );
    }

    return _ActionHover(
      key: ValueKey('hover-$nodeId'),
      hoverColor: hoverColor!,
      child: gestureDetector,
    );
  }
}

/// Resolves a color string (hex or semantic token) for Action widgets.
Color? _resolveActionColor(String? value, SduiRenderContext ctx) {
  if (value == null || value.isEmpty) return null;
  // Hex color (#RRGGBB or #AARRGGBB)
  if (value.startsWith('#')) {
    final h = value.substring(1);
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    if (h.length == 8) return Color(int.parse(h, radix: 16));
  }
  // Named Material colors
  final named = switch (value) {
    'red' => Colors.red,
    'blue' => Colors.blue,
    'green' => Colors.green,
    'orange' => Colors.orange,
    'purple' => Colors.purple,
    'white' => Colors.white,
    'black' => Colors.black,
    'grey' || 'gray' => Colors.grey,
    _ => null,
  };
  if (named != null) return named;
  // Semantic theme token
  return ctx.theme.colors.resolve(value);
}

class _ActionHover extends StatefulWidget {
  final Color hoverColor;
  final Widget child;

  const _ActionHover({
    super.key,
    required this.hoverColor,
    required this.child,
  });

  @override
  State<_ActionHover> createState() => _ActionHoverState();
}

class _ActionHoverState extends State<_ActionHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: ColoredBox(
        color: _hovered ? widget.hoverColor : Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PromptRequired
// ---------------------------------------------------------------------------

Widget _buildPromptRequired(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _PromptRequiredWidget(
    key: ValueKey('pr-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _PromptRequiredWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _PromptRequiredWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_PromptRequiredWidget> createState() => _PromptRequiredState();
}

class _PromptRequiredState extends State<_PromptRequiredWidget> {
  Map<String, String>? _resolvedValues;

  List<Map<String, dynamic>> get _fields {
    final raw = widget.node.props['fields'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _tryAutoResolve();
  }

  void _tryAutoResolve() {
    final resolver = widget.context.templateResolver;
    final resolved = <String, String>{};
    bool allResolved = true;

    for (final field in _fields) {
      final name = field['name'] as String? ?? '';
      if (name.isEmpty) continue;

      // Check if already in context/scope
      final existing = resolver.get(name);
      if (existing != null && existing.toString().isNotEmpty) {
        resolved[name] = existing.toString();
      } else {
        allResolved = false;
      }
    }

    if (allResolved) {
      _resolvedValues = resolved;
    }
  }

  void _showPrompt() {
    final controllers = <String, TextEditingController>{};
    final dropdownValues = <String, String>{};
    for (final field in _fields) {
      final name = field['name'] as String? ?? '';
      final defaultVal = field['default']?.toString() ?? '';
      final existing = widget.context.templateResolver.get(name);
      final initial = existing?.toString() ?? defaultVal;
      controllers[name] = TextEditingController(text: initial);
      dropdownValues[name] = initial;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = widget.context.theme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Required values',
                  style: TextStyle(fontSize: theme.textStyles.bodyMedium.fontSize, color: theme.colors.onSurface)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: _fields.map((field) {
                  final name = field['name'] as String? ?? '';
                  final label = field['label'] as String? ?? name;
                  final values = field['values'];

                  // If the field has a 'values' list, render a dropdown
                  if (values is List && values.isNotEmpty) {
                    final options = values.map((v) => v.toString()).toList();
                    return Padding(
                      padding: EdgeInsets.only(bottom: theme.spacing.sm),
                      child: DropdownButtonFormField<String>(
                        initialValue: options.contains(dropdownValues[name])
                            ? dropdownValues[name]
                            : options.first,
                        decoration: InputDecoration(
                          labelText: label,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        style: TextStyle(fontSize: theme.textStyles.bodySmall.fontSize, color: theme.colors.onSurface),
                        items: options
                            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => dropdownValues[name] = v);
                          }
                        },
                      ),
                    );
                  }

                  // Default: text field
                  return Padding(
                    padding: EdgeInsets.only(bottom: theme.spacing.sm),
                    child: TextField(
                      controller: controllers[name],
                      decoration: InputDecoration(
                        labelText: label,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      style: TextStyle(fontSize: theme.textStyles.bodySmall.fontSize, color: theme.colors.onSurface),
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final result = <String, String>{};
                    for (final field in _fields) {
                      final name = field['name'] as String? ?? '';
                      final values = field['values'];
                      if (values is List && values.isNotEmpty) {
                        result[name] = dropdownValues[name] ?? '';
                      } else {
                        result[name] = controllers[name]?.text ?? '';
                      }
                    }
                    Navigator.of(ctx).pop(result);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    ).then((values) {
      if (values is Map<String, String>) {
        setState(() {
          _resolvedValues = values;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedValues != null) {
      // All values resolved — render children with them in scope
      final scope = <String, dynamic>{..._resolvedValues!};
      final children = widget.node.children;
      if (children.isEmpty) return const SizedBox.shrink();
      if (children.length == 1) {
        return widget.childRenderer(children.first, scope);
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children:
            children.map((c) => widget.childRenderer(c, scope)).toList(),
      );
    }

    // Show prompt button
    final theme = widget.context.theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FontAwesomeIcons.gear, size: theme.window.bodyStateIconSize, color: theme.colors.onSurfaceMuted),
          SizedBox(height: theme.spacing.sm),
          Text('Configuration required',
              style: TextStyle(
                  color: theme.colors.onSurfaceVariant, fontSize: theme.textStyles.bodyMedium.fontSize)),
          SizedBox(height: theme.spacing.sm + theme.spacing.xs),
          ElevatedButton.icon(
            onPressed: _showPrompt,
            icon: const Icon(FontAwesomeIcons.pen, size: 16),
            label: const Text('Configure'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conditional
// ---------------------------------------------------------------------------

Widget _buildConditional(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  final visible = node.props['visible'];
  final negate = node.props['negate'] == true || node.props['negate'] == 'true';
  var show = visible == true ||
      visible == 'true' ||
      (visible is num && visible != 0) ||
      (visible is List && visible.isNotEmpty) ||
      (visible is Map && visible.isNotEmpty) ||
      (visible is String && visible.isNotEmpty && visible != 'false');
  if (negate) show = !show;

  if (!show) return const SizedBox.shrink();

  final children = node.children;
  if (children.isEmpty) return const SizedBox.shrink();

  Widget result;
  if (children.length == 1) {
    result = childRenderer(children.first, const {});
  } else {
    result = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.map((c) => childRenderer(c, const {})).toList(),
    );
  }

  // Responsive visibility: hide when parent is narrower than minWidth.
  final minWidth = PropConverter.to<double>(node.props['minWidth']);
  if (minWidth != null) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minWidth) return const SizedBox.shrink();
        return result;
      },
    );
  }

  return result;
}

// ---------------------------------------------------------------------------
// Sort
// ---------------------------------------------------------------------------

Widget _buildSort(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  final items = node.props['items'];
  if (items == null || items is! List) return const SizedBox.shrink();

  final key = PropConverter.to<String>(node.props['key']) ?? '';
  final direction = PropConverter.to<String>(node.props['direction']) ?? 'asc';

  final sorted = List<dynamic>.from(items);
  sorted.sort((a, b) {
    final va = resolveJsonPath(a, key);
    final vb = resolveJsonPath(b, key);
    if (va == null && vb == null) return 0;
    if (va == null) return 1;
    if (vb == null) return -1;
    if (va is Comparable && vb is Comparable) {
      return Comparable.compare(va, vb);
    }
    return va.toString().compareTo(vb.toString());
  });
  if (direction == 'desc') {
    final reversed = sorted.reversed.toList();
    sorted
      ..clear()
      ..addAll(reversed);
  }

  final scope = <String, dynamic>{'sorted': sorted};
  final children = node.children;
  if (children.isEmpty) return const SizedBox.shrink();
  if (children.length == 1) return childRenderer(children.first, scope);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children.map((c) => childRenderer(c, scope)).toList(),
  );
}

// ---------------------------------------------------------------------------
// Filter
// ---------------------------------------------------------------------------

Widget _buildFilter(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  final items = node.props['items'];
  if (items == null || items is! List) return const SizedBox.shrink();

  final field = PropConverter.to<String>(node.props['field']) ?? '';
  final contains = PropConverter.to<String>(node.props['contains']) ?? '';

  final List<dynamic> filtered;
  if (contains.isEmpty) {
    filtered = items;
  } else {
    final lowerContains = contains.toLowerCase();
    filtered = items.where((item) {
      final value = resolveJsonPath(item, field);
      if (value == null) return false;
      return value.toString().toLowerCase().contains(lowerContains);
    }).toList();
  }

  final scope = <String, dynamic>{'filtered': filtered};
  final children = node.children;
  if (children.isEmpty) return const SizedBox.shrink();
  if (children.length == 1) return childRenderer(children.first, scope);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children.map((c) => childRenderer(c, scope)).toList(),
  );
}

// ---------------------------------------------------------------------------
// EventScope
// ---------------------------------------------------------------------------

Widget _buildEventScope(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _EventScopeWidget(
    key: ValueKey('es-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _EventScopeWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _EventScopeWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_EventScopeWidget> createState() => _EventScopeWidgetState();
}

class _EventScopeWidgetState extends State<_EventScopeWidget> {
  StreamSubscription? _sub;
  late Map<String, dynamic> _lastPayload;

  String get _channel =>
      PropConverter.to<String>(widget.node.props['channel']) ?? '';
  String get _scopeKey =>
      PropConverter.to<String>(widget.node.props['scopeKey']) ?? 'event';
  bool get _replay =>
      PropConverter.to<bool>(widget.node.props['replay']) ?? false;

  @override
  void initState() {
    super.initState();
    final defaultPayload = widget.node.props['defaultPayload'];
    _lastPayload = defaultPayload is Map
        ? Map<String, dynamic>.from(defaultPayload)
        : {};
    _subscribe();
  }

  @override
  void didUpdateWidget(_EventScopeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldChannel = PropConverter.to<String>(oldWidget.node.props['channel']);
    if (oldChannel != _channel) {
      _sub?.cancel();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    final channel = _channel;
    if (channel.isEmpty) return;
    final stream = _replay
        ? widget.context.eventBus.subscribeWithReplay(channel)
        : widget.context.eventBus.subscribe(channel);
    _sub = stream.listen((event) {
      if (!mounted) return;
      final newPayload = Map<String, dynamic>.from(event.data);
      // Only rebuild if payload actually changed (prevent infinite loops).
      if (_payloadEquals(newPayload, _lastPayload)) return;
      setState(() {
        _lastPayload = newPayload;
      });
    });
  }

  bool _payloadEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key]?.toString() != b[key]?.toString()) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scope = <String, dynamic>{_scopeKey: _lastPayload};
    final children = widget.node.children;
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) {
      return widget.childRenderer(children.first, scope);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          children.map((c) => widget.childRenderer(c, scope)).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// AutoEmit
// ---------------------------------------------------------------------------

Widget _buildAutoEmit(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _AutoEmitWidget(
    key: ValueKey('ae-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _AutoEmitWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _AutoEmitWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_AutoEmitWidget> createState() => _AutoEmitWidgetState();
}

class _AutoEmitWidgetState extends State<_AutoEmitWidget> {
  bool _emitted = false;

  @override
  void initState() {
    super.initState();
    // Emit after the first frame (+ optional delay) so child widgets subscribe first.
    final delayMs =
        PropConverter.to<int>(widget.node.props['delayMs']) ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _emitted) return;
      _emitted = true;
      void emit() {
        if (!mounted) return;
        final channel =
            PropConverter.to<String>(widget.node.props['channel']) ?? '';
        if (channel.isEmpty) return;
        final payload = widget.node.props['payload'] is Map
            ? Map<String, dynamic>.from(widget.node.props['payload'] as Map)
            : <String, dynamic>{};
        widget.context.eventBus.publishSticky(
          channel,
          EventPayload(
            type: 'autoEmit',
            sourceWidgetId: widget.node.id,
            data: {...payload, '_channel': channel},
          ),
        );
      }
      if (delayMs > 0) {
        Future.delayed(Duration(milliseconds: delayMs), emit);
      } else {
        emit();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.node.children;
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) {
      return widget.childRenderer(children.first, const {});
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          children.map((c) => widget.childRenderer(c, const {})).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsible
// ---------------------------------------------------------------------------

Widget _buildCollapsible(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _CollapsibleWidget(
    key: ValueKey('coll-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _CollapsibleWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _CollapsibleWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_CollapsibleWidget> createState() => _CollapsibleWidgetState();
}

class _CollapsibleWidgetState extends State<_CollapsibleWidget> {
  late bool _expanded;
  StreamSubscription? _toggleSub;
  StreamSubscription? _expandSub;

  String get _nodeId =>
      PropConverter.to<String>(widget.node.props['nodeId']) ?? '';

  String get _toggleChannel =>
      PropConverter.to<String>(widget.node.props['toggleChannel']) ?? '';

  String get _expandChannel =>
      PropConverter.to<String>(widget.node.props['expandChannel']) ?? '';

  @override
  void initState() {
    super.initState();
    _expanded =
        PropConverter.to<bool>(widget.node.props['defaultExpanded']) ?? false;
    _subscribeToggle();
    _subscribeExpand();
  }

  @override
  void didUpdateWidget(_CollapsibleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldToggle =
        PropConverter.to<String>(oldWidget.node.props['toggleChannel']);
    if (oldToggle != _toggleChannel) {
      _toggleSub?.cancel();
      _subscribeToggle();
    }
    final oldExpand =
        PropConverter.to<String>(oldWidget.node.props['expandChannel']);
    if (oldExpand != _expandChannel) {
      _expandSub?.cancel();
      _subscribeExpand();
    }
  }

  @override
  void dispose() {
    _toggleSub?.cancel();
    _expandSub?.cancel();
    super.dispose();
  }

  void _subscribeToggle() {
    final channel = _toggleChannel;
    if (channel.isEmpty) return;
    _toggleSub = widget.context.eventBus.subscribe(channel).listen((event) {
      if (!mounted) return;
      final eventNodeId = event.data['nodeId']?.toString() ?? '';
      if (eventNodeId == _nodeId) {
        setState(() => _expanded = !_expanded);
      }
    });
  }

  void _subscribeExpand() {
    final channel = _expandChannel;
    if (channel.isEmpty) return;
    // Use subscribeWithReplay so Collapsibles created after the AutoEmit
    // event still receive it (e.g., project Collapsibles inside a team
    // that was just expanded).
    _expandSub = widget.context.eventBus.subscribeWithReplay(channel).listen((event) {
      if (!mounted) return;
      final eventNodeId = event.data['nodeId']?.toString() ?? '';
      if (eventNodeId == _nodeId && !_expanded) {
        setState(() => _expanded = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = <String, dynamic>{'expanded': _expanded};
    final children = widget.node.children;

    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) {
      return widget.childRenderer(children.first, scope);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          children.map((c) => widget.childRenderer(c, scope)).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Accordion  (wraps Material ExpansionTile with single-expand management)
// ---------------------------------------------------------------------------

Widget _buildAccordion(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _AccordionWidget(
    key: ValueKey('accordion-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _AccordionWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _AccordionWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_AccordionWidget> createState() => _AccordionWidgetState();
}

class _AccordionWidgetState extends State<_AccordionWidget> {
  String? _activePanelId;

  List<dynamic> get _items {
    final raw = widget.node.props['items'];
    if (raw is List) return raw;
    return const [];
  }

  String get _itemVariable =>
      PropConverter.to<String>(widget.node.props['itemVariable']) ?? 'item';

  String get _panelIdKey =>
      PropConverter.to<String>(widget.node.props['panelIdKey']) ?? 'id';

  String get _expandChannel =>
      PropConverter.to<String>(widget.node.props['expandChannel']) ?? '';

  String get _collapseChannel =>
      PropConverter.to<String>(widget.node.props['collapseChannel']) ?? '';

  String _panelIdFor(dynamic item) {
    if (item is Map) return item[_panelIdKey]?.toString() ?? '';
    return '';
  }

  void _onPanelExpansionChanged(String panelId, bool expanded) {
    if (expanded) {
      // A panel is opening — close the previous one (single-expand)
      final previousId = _activePanelId;
      if (previousId != null && previousId != panelId) {
        final channel = _collapseChannel;
        if (channel.isNotEmpty) {
          widget.context.eventBus.publish(channel,
              EventPayload(type: 'panel.collapsed',
                  sourceWidgetId: widget.node.id,
                  data: {'panelId': previousId}));
        }
      }
      final channel = _expandChannel;
      if (channel.isNotEmpty) {
        widget.context.eventBus.publish(channel,
            EventPayload(type: 'panel.expanded',
                sourceWidgetId: widget.node.id,
                data: {'panelId': panelId}));
      }
      setState(() => _activePanelId = panelId);
    } else {
      // Panel is closing
      final channel = _collapseChannel;
      if (channel.isNotEmpty) {
        widget.context.eventBus.publish(channel,
            EventPayload(type: 'panel.collapsed',
                sourceWidgetId: widget.node.id,
                data: {'panelId': panelId}));
      }
      if (_activePanelId == panelId) {
        setState(() => _activePanelId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final templateChildren = widget.node.children;

    // Need at least one child as template (header). Second child is body.
    if (templateChildren.isEmpty || items.isEmpty) {
      return const SizedBox.shrink();
    }

    final headerTemplate = templateChildren[0];
    final bodyTemplate =
        templateChildren.length > 1 ? templateChildren[1] : null;

    final theme = widget.context.theme;

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: theme.lineWeight.subtle,
        thickness: theme.lineWeight.subtle,
        color: theme.colors.outlineVariant,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        final panelId = _panelIdFor(item);
        final isExpanded = _activePanelId == panelId;

        final scope = <String, dynamic>{
          _itemVariable: item,
          'index': i,
          'expanded': isExpanded,
          'activePanelId': _activePanelId ?? '',
        };

        return _AccordionTile(
          key: ValueKey('accordion-tile-$panelId'),
          panelId: panelId,
          isExpanded: isExpanded,
          theme: theme,
          onExpansionChanged: (expanded) =>
              _onPanelExpansionChanged(panelId, expanded),
          header: widget.childRenderer(headerTemplate, scope),
          body: bodyTemplate != null
              ? widget.childRenderer(bodyTemplate,
                  {...scope, 'expanded': true})
              : null,
        );
      },
    );
  }
}

/// Individual accordion tile wrapping Material [ExpansionTile] with
/// FontAwesome chevron icon, theme tokens for all visual values,
/// and controller-driven collapse for single-expand enforcement.
class _AccordionTile extends StatefulWidget {
  final String panelId;
  final bool isExpanded;
  final SduiTheme theme;
  final ValueChanged<bool> onExpansionChanged;
  final Widget header;
  final Widget? body;

  const _AccordionTile({
    super.key,
    required this.panelId,
    required this.isExpanded,
    required this.theme,
    required this.onExpansionChanged,
    required this.header,
    this.body,
  });

  @override
  State<_AccordionTile> createState() => _AccordionTileState();
}

class _AccordionTileState extends State<_AccordionTile> {
  late final ExpansibleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExpansibleController();
  }

  @override
  void didUpdateWidget(_AccordionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Single-expand enforcement: collapse if parent says we're no longer active
    if (oldWidget.isExpanded && !widget.isExpanded) {
      try { _controller.collapse(); } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return ExpansionTile(
      controller: _controller,
      initiallyExpanded: widget.isExpanded,
      onExpansionChanged: widget.onExpansionChanged,
      maintainState: true,
      // FontAwesome chevron — replaces Material's default icon
      trailing: AnimatedRotation(
        turns: widget.isExpanded ? 0.25 : 0.0,
        duration: theme.animation.medium,
        curve: theme.animation.curve,
        child: FaIcon(
          FontAwesomeIcons.chevronRight,
          size: theme.iconSize.sm,
          color: theme.colors.onSurfaceVariant,
        ),
      ),
      showTrailingIcon: false,
      // Theme-aware styling
      tilePadding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.xs,
      ),
      childrenPadding: EdgeInsets.only(
        left: theme.spacing.md,
        right: theme.spacing.md,
        bottom: theme.spacing.sm,
      ),
      backgroundColor: theme.colors.surface,
      collapsedBackgroundColor: theme.colors.surface,
      shape: Border(
        bottom: BorderSide(
          color: theme.colors.outlineVariant,
          width: theme.lineWeight.subtle,
        ),
      ),
      collapsedShape: Border(
        bottom: BorderSide(
          color: theme.colors.outlineVariant,
          width: theme.lineWeight.subtle,
        ),
      ),
      title: widget.header,
      children: [
        if (widget.body != null) widget.body!,
      ],
    );
  }
}
