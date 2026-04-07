/// Typed event contract system for SDUI inter-widget communication.
///
/// Instead of string-addressed pub/sub, widgets declare:
/// - **produces**: what event contracts they emit, with field mappings
/// - **consumes**: what event contracts they accept, with field requirements
///
/// The [ContractBus] resolves compatibility: if widget A produces a
/// "selection" contract and widget B consumes "selection", the bus maps
/// A's output fields to B's input fields automatically.
///
/// This replaces hard-coded channel names with structural type matching.
library;

/// A formal event contract — defines a semantic event type with typed fields.
///
/// Contracts are the vocabulary of inter-widget communication.
/// They are defined once (in the contract registry) and referenced by widgets.
class EventContract {
  /// Unique contract identifier (e.g., "selection", "navigation", "dataChanged").
  final String name;

  /// Human-readable description of what this event means.
  final String description;

  /// Typed fields this contract carries.
  /// Keys are field names, values are [ContractField] definitions.
  final Map<String, ContractField> fields;

  const EventContract({
    required this.name,
    required this.description,
    required this.fields,
  });

  factory EventContract.fromJson(Map<String, dynamic> json) {
    final fieldsJson = json['fields'] as Map<String, dynamic>? ?? {};
    return EventContract(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      fields: fieldsJson.map(
          (k, v) => MapEntry(k, ContractField.fromJson(v as Map<String, dynamic>))),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'fields': fields.map((k, v) => MapEntry(k, v.toJson())),
      };

  /// Check if a payload satisfies the required fields of this contract.
  bool satisfiedBy(Map<String, dynamic> payload) {
    for (final entry in fields.entries) {
      if (entry.value.required && !payload.containsKey(entry.key)) {
        return false;
      }
    }
    return true;
  }
}

/// A typed field within a contract.
class ContractField {
  final String type; // 'string', 'int', 'number', 'bool', 'object', 'list'
  final bool required;
  final String? description;
  final List<String>? enumValues; // for filtered matching

  const ContractField({
    required this.type,
    this.required = false,
    this.description,
    this.enumValues,
  });

  factory ContractField.fromJson(Map<String, dynamic> json) {
    return ContractField(
      type: json['type'] as String? ?? 'string',
      required: json['required'] as bool? ?? false,
      description: json['description'] as String?,
      enumValues: (json['enum'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (required) 'required': true,
        if (description != null) 'description': description,
        if (enumValues != null) 'enum': enumValues,
      };
}

/// Declares that a widget produces events matching a contract.
class ProducesDecl {
  /// The contract name this widget produces.
  final String contract;

  /// Maps contract field names to widget data expressions.
  /// e.g., {"id": "item.id", "name": "item.name"}
  final Map<String, String> mapping;

  const ProducesDecl({required this.contract, required this.mapping});

  factory ProducesDecl.fromJson(Map<String, dynamic> json) {
    return ProducesDecl(
      contract: json['contract'] as String,
      mapping: Map<String, String>.from(json['mapping'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {'contract': contract, 'mapping': mapping};
}

/// Declares that a widget consumes events matching a contract.
class ConsumesDecl {
  /// The contract name this widget consumes.
  final String contract;

  /// Maps widget input names to contract field names.
  /// e.g., {"resourceId": "id"} means "take the contract's 'id' field
  /// and deliver it as 'resourceId' to this widget".
  final Map<String, String> mapping;

  /// Optional filter: only match events where specific fields have these values.
  /// e.g., {"kind": ["FileDocument", "Schema"]} — only react to file/schema selections.
  final Map<String, List<String>>? filter;

  const ConsumesDecl({
    required this.contract,
    required this.mapping,
    this.filter,
  });

  factory ConsumesDecl.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>>? filter;
    final filterJson = json['filter'] as Map<String, dynamic>?;
    if (filterJson != null) {
      filter = filterJson.map((k, v) => MapEntry(
          k, v is List ? v.cast<String>() : [v.toString()]));
    }
    return ConsumesDecl(
      contract: json['contract'] as String,
      mapping: Map<String, String>.from(json['mapping'] as Map? ?? {}),
      filter: filter,
    );
  }

  Map<String, dynamic> toJson() => {
        'contract': contract,
        'mapping': mapping,
        if (filter != null) 'filter': filter,
      };
}
