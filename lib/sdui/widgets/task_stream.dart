import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';
import 'dart:html' as html;

/// Metadata for the TaskStream scope builder.
const taskStreamMetadata = WidgetMetadata(
  type: 'TaskStream',
  description: 'Bridges the TaskMonitorService into SDUI scope. '
      'Exposes {{tasks}}, {{runningTasks}}, {{recentTasks}}, '
      '{{activeCount}}, {{hasRunning}}, {{hasRecent}}, {{hasTasks}}. '
      'Listens on cancelChannel for cancel actions.',
  props: {
    'cancelChannel': PropSpec(
      type: 'string',
      defaultValue: 'task.cancel',
      description: 'EventBus channel for task cancel requests.',
    ),
    'exportChannel': PropSpec(
      type: 'string',
      description: 'EventBus channel for CSV export requests.',
    ),
  },
);

/// Scope builder for the TaskStream widget.
Widget buildTaskStream(
    SduiNode node, SduiRenderContext ctx, SduiChildRenderer childRenderer) {
  return _TaskStreamWidget(
    key: ValueKey('taskstream-${node.id}'),
    node: node,
    context: ctx,
    childRenderer: childRenderer,
  );
}

class _TaskStreamWidget extends StatefulWidget {
  final SduiNode node;
  final SduiRenderContext context;
  final SduiChildRenderer childRenderer;

  const _TaskStreamWidget({
    super.key,
    required this.node,
    required this.context,
    required this.childRenderer,
  });

  @override
  State<_TaskStreamWidget> createState() => _TaskStreamWidgetState();
}

class _TaskStreamWidgetState extends State<_TaskStreamWidget> {
  List<Map<String, dynamic>> _allTasks = [];
  StreamSubscription<List<Map<String, dynamic>>>? _taskSub;
  StreamSubscription? _cancelSub;
  StreamSubscription? _exportSub;
  Timer? _elapsedTimer;

  String get _cancelChannel =>
      PropConverter.to<String>(widget.node.props['cancelChannel']) ??
      'task.cancel';

  @override
  void initState() {
    super.initState();
    final provider = widget.context.taskStreamProvider;
    if (provider == null) {
      debugPrint('[TaskStream] taskStreamProvider is null');
      return;
    }
    _taskSub = provider.tasks.listen((tasks) {
      if (!mounted) return;
      setState(() => _allTasks = tasks);
      _manageTimer();
    });
    _cancelSub = widget.context.eventBus.subscribe(_cancelChannel).listen((event) {
      final taskId = event.data['taskId'] as String?;
      if (taskId != null && taskId.isNotEmpty) {
        widget.context.taskStreamProvider?.cancel(taskId);
      }
    });
    final exportChannel = PropConverter.to<String>(widget.node.props['exportChannel']);
    if (exportChannel != null && exportChannel.isNotEmpty) {
      _exportSub = widget.context.eventBus.subscribe(exportChannel).listen((event) {
        if (mounted) _exportCsv();
      });
    }
  }

  void _manageTimer() {
    final hasRunning = _allTasks.any((t) => t['isFinal'] != true);
    if (hasRunning && _elapsedTimer == null) {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!hasRunning && _elapsedTimer != null) {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _cancelSub?.cancel();
    _exportSub?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _exportCsv() {
    if (_allTasks.isEmpty) return;
    const columns = [
      'taskId', 'workflowName', 'projectName', 'stepName',
      'taskType', 'status', 'elapsed', 'startedAt', 'completedAt',
    ];
    final buf = StringBuffer();
    buf.writeln(columns.join(','));
    for (final task in _allTasks) {
      final cells = columns.map((col) => _csvEscape((task[col] ?? '').toString()));
      buf.writeln(cells.join(','));
    }
    final blob = html.Blob([buf.toString()], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'task_monitor_export.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final running = _allTasks.where((t) => t['isFinal'] != true).toList();
    final recent = _allTasks.where((t) => t['isFinal'] == true).toList();

    final scope = <String, dynamic>{
      'tasks': _allTasks,
      'runningTasks': running,
      'recentTasks': recent,
      'activeCount': running.length,
      'hasRunning': running.isNotEmpty,
      'hasRecent': recent.isNotEmpty,
      'hasTasks': _allTasks.isNotEmpty,
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
