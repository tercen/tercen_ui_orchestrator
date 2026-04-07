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

    // Build the field mapping: consumer input name -> producer data expression.
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

  /// Maps consumer input names to producer data expressions.
  final Map<String, String> fieldMapping;

  /// Optional runtime filter from the consumer.
  final Map<String, List<String>>? filter;

  const ContractMatch({
    required this.contract,
    required this.fieldMapping,
    this.filter,
  });
}
