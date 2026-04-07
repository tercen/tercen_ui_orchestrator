/// Focus context received from other windows via EventBus.
///
/// Tells the chat what the user is currently looking at in the platform,
/// so the LLM can provide context-aware assistance.
class FocusContext {
  final String sourceWindow;
  final String nodeId;
  final String nodeType;
  final String nodeName;
  final Map<String, String> additionalContext;

  const FocusContext({
    required this.sourceWindow,
    required this.nodeId,
    required this.nodeType,
    required this.nodeName,
    this.additionalContext = const {},
  });

  String get displayLabel => '$nodeName ($sourceWindow)';
}
