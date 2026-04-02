import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sdui/sdui.dart';

import 'chat_backend.dart';
import 'layout_dispatch.dart';

/// Chat backend that creates Tercen agent operator tasks and
/// streams results back via the event service.
///
/// Event contract (from agent main.ts → Tercen GenericEvent):
///
///   agent_text         {text: string}
///   agent_tool_use     {name: string, input: object}
///   agent_tool_result  {name: string, result: string}
///                      — name contains 'render_widget' → result is LayoutOp JSON
///   agent_result       {result, cost, turns, sessionId?, sessionData?}
///   agent_error        {errors: string[]}
///
/// Layout op delivery:
///   render_widget tool → PostToolUse hook → agent_tool_result event
///   → this class parses result as JSON → dispatches to EventBus
class AgentClient extends ChatBackend {
  final sci.ServiceFactory factory;
  final EventBus eventBus;
  final String agentOperatorId;
  final String anthropicApiKey;
  final String modelName;
  final int maxTurns;
  final String? projectId;
  final String? userId;

  /// Callback to collect current UI state snapshot.
  final Map<String, dynamic> Function()? uiStateCollector;

  StreamSubscription? _eventSub;
  String? _currentTaskId;
  bool _processing = false;

  final _chatMessages = StreamController<Map<String, dynamic>>.broadcast();

  /// Session state for conversation continuity.
  String? _sessionId;
  String? _sessionData;

  AgentClient({
    required this.factory,
    required this.eventBus,
    required this.agentOperatorId,
    required this.anthropicApiKey,
    this.modelName = 'claude-3-haiku-20240307',
    this.maxTurns = 12,
    this.projectId,
    this.userId,
    this.uiStateCollector,
  });

  @override
  Stream<Map<String, dynamic>> get chatMessages => _chatMessages.stream;

  @override
  bool get isConnected => true;

  @override
  bool get isProcessing => _processing;

  @override
  void sendChat(String message) {
    if (_processing) return;
    _processing = true;
    notifyListeners();
    _startAgentTask(message);
  }

  // -------------------------------------------------------------------------
  // Task creation
  // -------------------------------------------------------------------------

  Future<void> _startAgentTask(String message) async {
    try {
      final envPairs = <sci.Pair>[
        _pair('prompt', message),
        _pair('ANTHROPIC_API_KEY', anthropicApiKey),
        _pair('model', modelName),
        _pair('maxTurns', '$maxTurns'),
      ];

      if (uiStateCollector != null) {
        final uiState = uiStateCollector!();
        if (uiState.isNotEmpty) {
          envPairs.add(_pair('uiState', jsonEncode(uiState)));
        }
      }

      if (_sessionId != null && _sessionId!.isNotEmpty) {
        envPairs.add(_pair('sessionId', _sessionId!));
      }
      if (_sessionData != null && _sessionData!.isNotEmpty) {
        envPairs.add(_pair('sessionData', _sessionData!));
      }

      final task = sci.RunComputationTask();
      if (projectId != null && projectId!.isNotEmpty) {
        task.projectId = projectId!;
      }
      if (userId != null && userId!.isNotEmpty) {
        task.owner = userId!;
      }

      task.query.operatorSettings
        ..namespace = DateTime.now().millisecondsSinceEpoch.toString()
        ..operatorRef.operatorId = agentOperatorId
        ..operatorRef.operatorKind = 'DockerOperator'
        ..environment.addAll(envPairs);

      debugPrint('[agent] Creating task (${envPairs.length} props'
          '${_sessionId != null ? ", session=$_sessionId" : ""})');

      final created = await factory.taskService.create(task) as sci.RunComputationTask;
      _currentTaskId = created.id;
      debugPrint('[agent] Task ${created.id} on channel ${created.channelId}');

      _eventSub?.cancel();
      _eventSub = factory.eventService.channel(created.channelId).listen(
        _onEvent,
        onError: (e, st) {
          debugPrint('[agent] Event stream error: $e');
          _emitChat('error', {'text': '$e'});
          _finish();
        },
        onDone: () {
          debugPrint('[agent] Event stream closed');
          _finish();
        },
      );

      await factory.taskService.runTask(created.id);
    } catch (e, st) {
      debugPrint('[agent] Failed to start task: $e\n$st');
      _emitChat('error', {'text': '$e'});
      _finish();
    }
  }

  // -------------------------------------------------------------------------
  // Event handling
  // -------------------------------------------------------------------------

  void _onEvent(sci.Event event) {
    if (event is sci.TaskEvent &&
        _currentTaskId != null &&
        event.taskId.isNotEmpty &&
        event.taskId != _currentTaskId) {
      return; // Stale event from previous task on shared channel.
    }

    if (event is sci.GenericEvent) {
      _handleAgentEvent(event.type, event.content);
    } else if (event is sci.TaskStateEvent) {
      final state = event.state;
      debugPrint('[agent] Task state: ${state.kind}');
      if (state is sci.FailedState) {
        final reason = state.reason.isNotEmpty ? state.reason : state.error;
        _emitChat('error', {'text': 'Task failed: $reason'});
        _finish();
      } else if (state.kind == 'DoneState') {
        _finish();
      }
    } else if (event is sci.TaskLogEvent) {
      debugPrint('[agent] Log: ${event.message}');
    }
  }

  void _handleAgentEvent(String type, String content) {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[agent] Failed to parse event content ($type): $e');
      return;
    }

    switch (type) {
      case 'agent_text':
        final text = payload['text'] as String? ?? '';
        _emitChat('text_delta', {'text': text});

      case 'agent_tool_use':
        final name = payload['name'] as String? ?? '';
        _emitChat('tool_start', {'toolName': name, 'toolId': name});

      case 'agent_tool_result':
        _handleToolResult(payload);

      case 'agent_result':
        _handleResult(payload);

      case 'agent_error':
        final errors = payload['errors'] as List? ?? [];
        _emitChat('error', {'text': errors.join(', ')});
        _finish();

      default:
        debugPrint('[agent] Unknown event type: $type');
    }
  }

  /// Handle agent_tool_result — the ONLY path for layout ops.
  ///
  /// Contract: if name contains 'render_widget', result is a JSON
  /// string of a LayoutOp {op, id, title, size, align, content}.
  void _handleToolResult(Map<String, dynamic> payload) {
    final name = payload['name'] as String? ?? '';
    final result = payload['result'] as String? ?? '';

    debugPrint('[agent] tool_result: $name (${result.length} chars)');

    if (name.contains('render_widget') && result.isNotEmpty) {
      debugPrint('[agent] render_widget → dispatching layout op');
      final dispatched = dispatchLayoutOp(result, eventBus);
      if (!dispatched) {
        debugPrint('[agent] render_widget result was NOT a valid layout op:');
        debugPrint('[agent]   ${result.substring(0, result.length.clamp(0, 500))}');
      }
    }

    _emitChat('tool_end', {'toolId': name, 'isError': false});
  }

  /// Handle agent_result — end of agent turn.
  void _handleResult(Map<String, dynamic> payload) {
    // Store session state for next turn.
    final sid = payload['sessionId'] as String?;
    final sdata = payload['sessionData'] as String?;
    if (sid != null && sid.isNotEmpty) _sessionId = sid;
    if (sdata != null && sdata.isNotEmpty) _sessionData = sdata;

    final cost = payload['cost'];
    final turns = payload['turns'];
    debugPrint('[agent] Done — cost=\$$cost turns=$turns'
        '${_sessionId != null ? " session=$_sessionId" : ""}');

    // Final message marker for chat UI.
    _emitChat('assistant_message', {'text': ''});
    _finish();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  void _emitChat(String type, Map<String, dynamic> extra) {
    _chatMessages.add({'type': type, ...extra});
  }

  void _finish() {
    _eventSub?.cancel();
    _eventSub = null;
    _currentTaskId = null;
    _processing = false;
    _chatMessages.add({'type': 'done'});
    notifyListeners();
  }

  static sci.Pair _pair(String key, String value) {
    return sci.Pair()
      ..key = key
      ..value = value;
  }

  @override
  void resetSession() {
    _sessionId = null;
    _sessionData = null;
    debugPrint('[agent] Session reset');
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _chatMessages.close();
    super.dispose();
  }
}
