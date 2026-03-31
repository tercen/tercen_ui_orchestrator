import 'dart:convert';

import 'event_contracts.dart';

/// Registry of all known event contracts.
///
/// This is the formal vocabulary of inter-widget communication.
/// Loaded from `sdui-contracts.json` or defined programmatically.
class ContractRegistry {
  final Map<String, EventContract> _contracts = {};

  /// All registered contracts.
  Iterable<EventContract> get contracts => _contracts.values;

  /// Get a contract by name. Returns null if not found.
  EventContract? get(String name) => _contracts[name];

  /// Register a contract.
  void register(EventContract contract) {
    _contracts[contract.name] = contract;
  }

  /// Load contracts from JSON.
  void loadFromJson(Map<String, dynamic> json) {
    final contractsJson = json['contracts'] as Map<String, dynamic>? ?? {};
    for (final entry in contractsJson.entries) {
      final contractJson = entry.value as Map<String, dynamic>;
      contractJson['name'] = entry.key;
      register(EventContract.fromJson(contractJson));
    }
  }

  /// Check if a producer and consumer are compatible.
  ///
  /// Compatible means:
  /// 1. They reference the same contract
  /// 2. The producer's mapping covers all fields the consumer requires
  /// 3. Filter conditions can be evaluated at runtime
  ContractMatch? matchProducerConsumer(
      ProducesDecl producer, ConsumesDecl consumer) {
    if (producer.contract != consumer.contract) return null;

    final contract = _contracts[producer.contract];
    if (contract == null) return null;

    // Check that the producer provides all fields the consumer maps from.
    final consumerNeeds = consumer.mapping.values.toSet(); // contract field names
    final producerProvides = producer.mapping.keys.toSet(); // contract field names

    if (!consumerNeeds.every((need) => producerProvides.contains(need))) {
      return null; // Producer doesn't provide what consumer needs.
    }

    // Build the field mapping: consumer input name → producer data expression.
    final fieldMapping = <String, String>{};
    for (final entry in consumer.mapping.entries) {
      final consumerInputName = entry.key; // what the consumer calls it
      final contractFieldName = entry.value; // the contract field name
      final producerExpr = producer.mapping[contractFieldName];
      if (producerExpr != null) {
        fieldMapping[consumerInputName] = producerExpr;
      }
    }

    return ContractMatch(
      contract: contract,
      fieldMapping: fieldMapping,
      filter: consumer.filter,
    );
  }

  /// Export the registry as JSON.
  Map<String, dynamic> toJson() {
    final contractsJson = <String, dynamic>{};
    for (final contract in _contracts.values) {
      contractsJson[contract.name] = {
        'description': contract.description,
        'fields': contract.fields.map((k, v) => MapEntry(k, v.toJson())),
      };
    }
    return {
      'title': 'SDUI Event Contracts',
      'description': 'Formal vocabulary of inter-widget communication. '
          'Widgets declare produces/consumes against these contracts.',
      'version': '1.0.0',
      'contracts': contractsJson,
    };
  }

  String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Result of matching a producer to a consumer.
class ContractMatch {
  /// The contract both sides reference.
  final EventContract contract;

  /// Maps consumer input names → producer data expressions.
  /// e.g., {"resourceId": "item.id"} — consumer gets "resourceId" from producer's "item.id".
  final Map<String, String> fieldMapping;

  /// Optional runtime filter from the consumer.
  final Map<String, List<String>>? filter;

  const ContractMatch({
    required this.contract,
    required this.fieldMapping,
    this.filter,
  });
}

/// The built-in contract definitions for the Tercen SDUI system.
ContractRegistry createDefaultRegistry() {
  final registry = ContractRegistry();

  registry.register(const EventContract(
    name: 'selection',
    description: 'User selected an entity (project, workflow, file, step, team member, etc.)',
    fields: {
      'id': ContractField(type: 'string', required: true, description: 'Entity ID'),
      'name': ContractField(type: 'string', description: 'Entity display name'),
      'kind': ContractField(type: 'string', description: 'Entity type/kind (e.g., Workflow, FileDocument)'),
      'parentId': ContractField(type: 'string', description: 'Parent entity ID (e.g., projectId)'),
    },
  ));

  registry.register(const EventContract(
    name: 'navigation',
    description: 'Request to open/navigate to a resource in a new or existing window',
    fields: {
      'resourceId': ContractField(type: 'string', required: true, description: 'Resource to open'),
      'resourceType': ContractField(type: 'string', description: 'Type of resource (maps to widget type or intent)'),
      'resourceName': ContractField(type: 'string', description: 'Display name for window title'),
      'parentId': ContractField(type: 'string', description: 'Parent context (e.g., projectId for a workflow)'),
    },
  ));

  registry.register(const EventContract(
    name: 'dataChanged',
    description: 'Underlying data was created, updated, or deleted — consumers should refresh',
    fields: {
      'entityId': ContractField(type: 'string', description: 'ID of changed entity'),
      'entityKind': ContractField(type: 'string', description: 'Type of changed entity'),
      'action': ContractField(type: 'string', required: true, description: 'What happened',
          enumValues: ['created', 'updated', 'deleted']),
    },
  ));

  registry.register(const EventContract(
    name: 'command',
    description: 'A user action/command (toggle theme, save layout, sign out, etc.)',
    fields: {
      'action': ContractField(type: 'string', required: true, description: 'Command name'),
      'value': ContractField(type: 'string', description: 'Optional command value'),
    },
  ));

  registry.register(const EventContract(
    name: 'notification',
    description: 'User-facing notification message',
    fields: {
      'severity': ContractField(type: 'string', required: true, description: 'Level',
          enumValues: ['info', 'success', 'warning', 'error']),
      'message': ContractField(type: 'string', required: true, description: 'Message text'),
    },
  ));

  registry.register(const EventContract(
    name: 'taskStatus',
    description: 'A background task changed state',
    fields: {
      'taskId': ContractField(type: 'string', required: true, description: 'Task ID'),
      'state': ContractField(type: 'string', required: true, description: 'New state',
          enumValues: ['running', 'done', 'failed', 'cancelled']),
      'progress': ContractField(type: 'number', description: '0.0-1.0 progress'),
    },
  ));

  registry.register(const EventContract(
    name: 'formSubmit',
    description: 'A form was submitted with field values',
    fields: {
      'formId': ContractField(type: 'string', description: 'Form identifier'),
      'values': ContractField(type: 'object', required: true, description: 'Field name→value map'),
    },
  ));

  registry.register(const EventContract(
    name: 'stateChange',
    description: 'Local widget state mutation',
    fields: {
      'op': ContractField(type: 'string', required: true, description: 'Mutation operation',
          enumValues: ['merge', 'increment', 'decrement', 'toggle', 'reset']),
      'key': ContractField(type: 'string', description: 'State key to mutate'),
      'values': ContractField(type: 'object', description: 'Values to merge'),
      'amount': ContractField(type: 'number', description: 'Amount for increment/decrement'),
    },
  ));

  return registry;
}
