import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sdui/sdui.dart';

import 'chat_backend.dart';
import 'layout_extractor.dart';

/// Chat backend that creates Tercen agent operator tasks and
/// streams results back via the event service.
///
/// Each [sendChat] call creates a new [RunComputationTask] with
/// the user's message as the `prompt` operator property, subscribes
/// to the task's event channel, and maps agent events to the chat
/// message format expected by ChatPanel.
///
/// Conversation continuity: the agent returns a sessionId and
/// base64-encoded session data after each turn. These are passed
/// back on subsequent tasks so the CLI can resume the conversation.
class AgentClient extends ChatBackend {
  final sci.ServiceFactory factory;
  final EventBus eventBus;
  final String agentOperatorId;
  final String systemPrompt;
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
  final StringBuffer _textAccumulator = StringBuffer();

  final _chatMessages = StreamController<Map<String, dynamic>>.broadcast();

  /// Session state for conversation continuity.
  String? _sessionId;
  String? _sessionData;

  AgentClient({
    required this.factory,
    required this.eventBus,
    required this.agentOperatorId,
    required this.anthropicApiKey,
    this.systemPrompt = '',
    this.modelName = 'claude-sonnet-4-6',
    this.maxTurns = 8,
    this.projectId,
    this.userId,
    this.uiStateCollector,
  });

  @override
  Stream<Map<String, dynamic>> get chatMessages => _chatMessages.stream;

  @override
  bool get isConnected => true; // Always "connected" — tasks are on-demand

  @override
  bool get isProcessing => _processing;

  @override
  void sendChat(String message) {
    if (_processing) return;
    _processing = true;
    _textAccumulator.clear();
    notifyListeners();
    _startAgentTask(message);
  }

  Future<void> _startAgentTask(String message) async {
    try {
      // Build operator properties
      final envPairs = <sci.Pair>[
        sci.Pair()
          ..key = 'prompt'
          ..value = message,
        sci.Pair()
          ..key = 'ANTHROPIC_API_KEY'
          ..value = anthropicApiKey,
        sci.Pair()
          ..key = 'model'
          ..value = modelName,
        sci.Pair()
          ..key = 'maxTurns'
          ..value = '$maxTurns',
      ];

      if (systemPrompt.isNotEmpty) {
        envPairs.add(sci.Pair()
          ..key = 'systemPrompt'
          ..value = systemPrompt);
      }

      // Collect and attach UI state snapshot
      if (uiStateCollector != null) {
        final uiState = uiStateCollector!();
        if (uiState.isNotEmpty) {
          envPairs.add(sci.Pair()
            ..key = 'uiState'
            ..value = jsonEncode(uiState));
        }
      }

      // Session continuity — pass previous session if available
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        envPairs.add(sci.Pair()
          ..key = 'sessionId'
          ..value = _sessionId!);
      }
      if (_sessionData != null && _sessionData!.isNotEmpty) {
        envPairs.add(sci.Pair()
          ..key = 'sessionData'
          ..value = _sessionData!);
      }

      // Build the task
      final task = sci.RunComputationTask();
      if (projectId != null && projectId!.isNotEmpty) {
        task.projectId = projectId!;
      }
      if (userId != null && userId!.isNotEmpty) {
        task.owner = userId!;
      }

      task.query.operatorSettings
        ..operatorRef.operatorId = agentOperatorId
        ..operatorRef.operatorKind = 'DockerOperator'
        ..environment.addAll(envPairs);

      debugPrint('[agent] Creating task with ${envPairs.length} properties'
          '${_sessionId != null ? " (resuming session $_sessionId)" : ""}');

      // Create task (assigns channelId)
      final created = await factory.taskService
          .create(task) as sci.RunComputationTask;
      _currentTaskId = created.id;
      debugPrint('[agent] Task created: id=${created.id}, '
          'channelId=${created.channelId}');

      // Subscribe to channel BEFORE starting the task
      _eventSub?.cancel();
      _eventSub = factory.eventService
          .channel(created.channelId)
          .listen(
        _onEvent,
        onError: (e, st) {
          debugPrint('[agent] Event stream error: $e');
          _chatMessages.add({'type': 'error', 'text': '$e'});
          _finish();
        },
        onDone: () {
          debugPrint('[agent] Event stream closed');
          _finish();
        },
      );

      // Start execution
      await factory.taskService.runTask(created.id);
      debugPrint('[agent] Task started');
    } catch (e, st) {
      debugPrint('[agent] Failed to start task: $e\n$st');
      _chatMessages.add({'type': 'error', 'text': '$e'});
      _finish();
    }
  }

  void _onEvent(sci.Event event) {
    // Ignore events from previous tasks on a shared channel.
    if (event is sci.TaskEvent &&
        _currentTaskId != null &&
        event.taskId.isNotEmpty &&
        event.taskId != _currentTaskId) {
      return;
    }

    if (event is sci.GenericEvent) {
      _handleAgentEvent(event.type, event.content);
    } else if (event is sci.TaskStateEvent) {
      final state = event.state;
      debugPrint('[agent] Task state: ${state.kind}');
      if (state is sci.FailedState) {
        final reason = state.reason.isNotEmpty ? state.reason : state.error;
        debugPrint('[agent] Task failed: $reason');
        _chatMessages.add({
          'type': 'error',
          'text': 'Task failed: $reason',
        });
        _finish();
      } else if (state.kind == 'DoneState') {
        _finish();
      }
    } else if (event is sci.TaskLogEvent) {
      debugPrint('[agent] Log: ${event.message}');
    }
  }

  void _handleAgentEvent(String type, String content) {
    try {
      final payload = jsonDecode(content) as Map<String, dynamic>;

      switch (type) {
        case 'agent_text':
          final text = payload['text'] as String? ?? '';
          _textAccumulator.write(text);
          _chatMessages.add({'type': 'text_delta', 'text': text});
          break;

        case 'agent_tool_use':
          final name = payload['name'] as String? ?? '';
          _chatMessages.add({
            'type': 'tool_start',
            'toolName': name,
            'toolId': name,
          });
          break;

        case 'agent_tool_result':
          final name = payload['name'] as String? ?? '';
          _chatMessages.add({
            'type': 'tool_end',
            'toolId': name,
            'isError': false,
          });
          break;

        case 'agent_result':
          final fullText = _textAccumulator.toString();
          // Extract and dispatch layout operations
          extractAndDispatchLayoutOps(fullText, eventBus);
          // Send cleaned text as final message
          final cleanText = stripJsonCodeBlocks(fullText);
          _chatMessages.add({
            'type': 'assistant_message',
            'text': cleanText,
          });

          // Store session state for next turn
          final sid = payload['sessionId'] as String?;
          final sdata = payload['sessionData'] as String?;
          if (sid != null && sid.isNotEmpty) {
            _sessionId = sid;
            debugPrint('[agent] Session ID: $_sessionId');
          }
          if (sdata != null && sdata.isNotEmpty) {
            _sessionData = sdata;
            debugPrint('[agent] Session data: ${sdata.length} chars');
          }

          final cost = payload['cost'];
          final turns = payload['turns'];
          debugPrint('[agent] Done — cost: \$$cost, turns: $turns');
          _finish();
          break;

        case 'agent_error':
          final errors = payload['errors'] as List? ?? [];
          _chatMessages.add({
            'type': 'error',
            'text': errors.join(', '),
          });
          _finish();
          break;

        default:
          debugPrint('[agent] Unknown event type: $type');
      }
    } catch (e) {
      debugPrint('[agent] Failed to parse event content: $e');
    }
  }

  void _finish() {
    _eventSub?.cancel();
    _eventSub = null;
    _currentTaskId = null;
    _processing = false;
    _chatMessages.add({'type': 'done'});
    notifyListeners();
  }

  @override
  void resetSession() {
    _sessionId = null;
    _sessionData = null;
    _textAccumulator.clear();
    debugPrint('[agent] Session reset');
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _chatMessages.close();
    super.dispose();
  }
}
