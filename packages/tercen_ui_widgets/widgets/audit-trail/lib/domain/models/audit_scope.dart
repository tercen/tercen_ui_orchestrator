/// The scope used to query audit events.
class AuditScope {
  final ScopeType scopeType;
  final String scopeId;
  final String scopeLabel;

  const AuditScope({
    required this.scopeType,
    required this.scopeId,
    required this.scopeLabel,
  });

  Map<String, dynamic> toMap() => {
        'scopeType': scopeType.name,
        'scopeId': scopeId,
        'scopeLabel': scopeLabel,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditScope &&
          scopeType == other.scopeType &&
          scopeId == other.scopeId;

  @override
  int get hashCode => scopeType.hashCode ^ scopeId.hashCode;
}

enum ScopeType {
  user,
  team,
  project,
}
