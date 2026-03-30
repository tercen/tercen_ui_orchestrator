/// Severity of a validation finding.
enum ValidationSeverity { error, warning, info }

/// A single validation finding from the template validator.
class ValidationResult {
  final ValidationSeverity severity;
  final String message;

  /// Path to the node, e.g. "DataSource({{widgetId}}-ds) > ForEach({{widgetId}}-fe)"
  final String nodePath;

  /// Machine-readable rule identifier, e.g. "binding-scope/item-outside-foreach"
  final String ruleId;

  const ValidationResult({
    required this.severity,
    required this.message,
    required this.nodePath,
    required this.ruleId,
  });

  bool get isError => severity == ValidationSeverity.error;
  bool get isWarning => severity == ValidationSeverity.warning;

  @override
  String toString() => '[${severity.name}] $ruleId: $message ($nodePath)';
}
