import 'dart:async';

import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/focus_context.dart';
import '../../domain/models/window_identity.dart';
import '../../domain/services/chat_service.dart';
import '../../domain/services/event_payload.dart';
import '../../implementations/services/mock_data.dart';
import 'window_state_provider.dart';

/// Manages the chat window's state: sessions, messages, input, focus context.
///
/// Extends WindowStateProvider to satisfy the skeleton window_body.dart contract
/// while adding chat-specific state management.
class ChatProvider extends WindowStateProvider {
  final ChatService _chatService = serviceLocator<ChatService>();

  // -- Sessions --
  List<ChatSession> _sessions = [];
  List<ChatSession> get sessions => _sessions;

  ChatSession? _currentSession;
  ChatSession? get currentSession => _currentSession;

  // -- Messages (shortcut to current session) --
  List<ChatMessage> get messages => _currentSession?.messages ?? [];

  // -- Input state --
  final TextEditingController inputController = TextEditingController();
  bool _isSending = false;
  bool get isSending => _isSending;

  /// Whether a message can be sent right now.
  bool get canSend => inputController.text.trim().isNotEmpty && !_isSending;

  /// Send the current input text and clear the field.
  void sendFromInput() {
    final text = inputController.text;
    if (text.trim().isEmpty || _isSending) return;
    inputController.clear();
    sendMessage(text);
  }

  // -- Focus context --
  FocusContext? _focusContext;
  FocusContext? get focusContext => _focusContext;

  StreamSubscription<EventPayload>? _focusSubscription;

  ChatProvider({
    required WindowIdentity identity,
    required String windowId,
  }) : super(identity: identity, windowId: windowId) {
    // Listen for focusChanged events from other windows
    _focusSubscription = eventBusInstance
        .subscribe('focus.changed')
        .listen(_handleFocusChanged);

    // Set default mock focus context
    _focusContext = MockData.defaultFocusContext;

    // Notify listeners when input text changes (for canSend)
    inputController.addListener(() => notifyListeners());
  }

  /// Initialize: load sessions and set the first one as active.
  Future<void> initialize() async {
    contentStateValue = ContentState.loading;
    errorMessageValue = null;
    notifyListeners();

    try {
      _sessions = await _chatService.listSessions();

      if (_sessions.isNotEmpty) {
        _currentSession = _sessions.first;
      } else {
        // No existing sessions — create one automatically
        final session = await _chatService.createSession();
        _sessions.insert(0, session);
        _currentSession = session;
      }
      contentStateValue = ContentState.active;
    } catch (e) {
      errorMessageValue = e.toString();
      contentStateValue = ContentState.error;
    }
    notifyListeners();
  }

  /// Override loadData to delegate to initialize for skeleton compatibility.
  @override
  Future<void> loadData() async {
    await initialize();
  }

  // -- Inbound focus handling --

  void _handleFocusChanged(EventPayload payload) {
    final data = payload.data;
    _focusContext = FocusContext(
      sourceWindow: data['sourceWindow'] as String? ?? '',
      nodeId: data['nodeId'] as String? ?? '',
      nodeType: data['nodeType'] as String? ?? '',
      nodeName: data['nodeName'] as String? ?? '',
    );
    notifyListeners();
  }

  // -- Action intent helpers (spec section 12.1) --

  /// Emit a createStep intent -- LLM response containing a create-step action.
  void emitCreateStep({
    required String stepType,
    required String workflowId,
    Map<String, dynamic> configuration = const {},
  }) {
    publishIntent('createStep', {
      'stepType': stepType,
      'workflowId': workflowId,
      'configuration': configuration,
    });
  }

  /// Emit an openFile intent -- LLM response containing an open-file action.
  void emitOpenFile({
    required String fileId,
    required String projectId,
  }) {
    publishIntent('openFile', {
      'fileId': fileId,
      'projectId': projectId,
    });
  }

  /// Emit an openWorkflow intent -- LLM response containing an open-workflow action.
  void emitOpenWorkflow({required String workflowId}) {
    publishIntent('openWorkflow', {
      'workflowId': workflowId,
    });
  }

  /// Emit a navigateToStep intent -- LLM response directing attention to a step.
  void emitNavigateToStep({
    required String stepId,
    required String workflowId,
  }) {
    publishIntent('navigateToStep', {
      'stepId': stepId,
      'workflowId': workflowId,
    });
  }

  /// Emit a navigateTo intent -- LLM response directing attention to a file/project.
  void emitNavigateTo({required String nodeIdOrPath}) {
    publishIntent('navigateTo', {
      'nodeIdOrPath': nodeIdOrPath,
    });
  }

  /// Emit a refreshTree intent -- LLM response after file operations.
  void emitRefreshTree() {
    publishIntent('refreshTree');
  }

  /// Emit a workflowUpdated intent -- LLM response after workflow modifications.
  void emitWorkflowUpdated({required String workflowId}) {
    publishIntent('workflowUpdated', {
      'workflowId': workflowId,
    });
  }

  // -- Session management --

  /// Create a new empty session and switch to it.
  Future<void> createNewSession() async {
    try {
      final session = await _chatService.createSession();
      _sessions.insert(0, session);
      _currentSession = session;
      contentStateValue = ContentState.active;
      notifyListeners();
    } catch (e) {
      errorMessageValue = 'Failed to create session: $e';
      contentStateValue = ContentState.error;
      notifyListeners();
    }
  }

  /// Switch to an existing session by ID.
  Future<void> switchSession(String sessionId) async {
    if (_currentSession?.id == sessionId) return;

    try {
      final session = await _chatService.loadSession(sessionId);
      _currentSession = session;
      contentStateValue = ContentState.active;
      notifyListeners();
    } catch (e) {
      errorMessageValue = 'Failed to load session: $e';
      contentStateValue = ContentState.error;
      notifyListeners();
    }
  }

  // -- Messaging --

  /// Send a user message and wait for the assistant response.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending || _currentSession == null) return;

    final session = _currentSession!;

    // Create and add user message immediately
    final userMessage = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    session.messages.add(userMessage);

    // Auto-title from first user message
    if (session.messages.where((m) => m.role == MessageRole.user).length == 1) {
      final titleText = text.trim();
      session.title =
          titleText.length > 60 ? '${titleText.substring(0, 57)}...' : titleText;
    }

    session.lastMessageAt = DateTime.now();
    _isSending = true;
    contentStateValue = ContentState.active;
    notifyListeners();

    try {
      final response = await _chatService.sendMessage(
        sessionId: session.id,
        messageText: text.trim(),
        focusContext: _focusContext,
      );
      session.messages.add(response);
      session.lastMessageAt = response.timestamp;
    } catch (e) {
      // Add an inline error message from the assistant
      session.messages.add(ChatMessage(
        id: 'msg-err-${DateTime.now().millisecondsSinceEpoch}',
        role: MessageRole.assistant,
        content: 'Sorry, I encountered an error: $e',
        timestamp: DateTime.now(),
      ));
    }

    _isSending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _focusSubscription?.cancel();
    inputController.dispose();
    super.dispose();
  }
}
