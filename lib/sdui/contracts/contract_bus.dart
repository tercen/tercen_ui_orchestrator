import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sdui/sdui.dart';

import 'contract_registry.dart';
import 'event_contracts.dart';

/// A typed event bus that routes events by contract compatibility,
/// not by channel name matching.
///
/// Sits on top of the existing [EventBus]. Widgets publish typed events
/// (contract + payload), consumers subscribe by contract. The bus resolves
/// field mappings and filter conditions automatically.
///
/// Backward compatible: the underlying EventBus still works for
/// string-addressed pub/sub. ContractBus adds a typed layer on top.
class ContractBus {
  final EventBus eventBus;
  final ContractRegistry registry;

  final _subscriptions = <_ContractSubscription>[];

  /// Internal channel used for contract-based events.
  static const _contractChannel = 'contract.event';

  StreamSubscription<EventPayload>? _busSub;

  ContractBus({required this.eventBus, required this.registry}) {
    _busSub = eventBus.subscribe(_contractChannel).listen(_onContractEvent);
  }

  /// Publish a typed event.
  ///
  /// The [contractName] identifies the event contract. The [payload] must
  /// satisfy the contract's required fields. The [sourceWidgetId] identifies
  /// the publisher.
  void publish({
    required String contractName,
    required Map<String, dynamic> payload,
    String? sourceWidgetId,
  }) {
    final contract = registry.get(contractName);
    if (contract == null) {
      debugPrint('[ContractBus] Unknown contract: $contractName');
      return;
    }

    if (!contract.satisfiedBy(payload)) {
      debugPrint('[ContractBus] Payload does not satisfy contract '
          '"$contractName" required fields');
      return;
    }

    eventBus.publish(
      _contractChannel,
      EventPayload(
        type: contractName,
        sourceWidgetId: sourceWidgetId,
        data: {
          '_contract': contractName,
          ...payload,
        },
      ),
    );
  }

  /// Subscribe to events matching a contract.
  ///
  /// The [consumes] declaration specifies the contract, field mapping,
  /// and optional filter. Returns a stream of mapped payloads — the
  /// consumer receives data with its own field names, not the producer's.
  Stream<Map<String, dynamic>> subscribe(ConsumesDecl consumes) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final sub = _ContractSubscription(
      consumes: consumes,
      controller: controller,
    );
    _subscriptions.add(sub);

    controller.onCancel = () {
      _subscriptions.remove(sub);
    };

    return controller.stream;
  }

  void _onContractEvent(EventPayload event) {
    final contractName = event.data['_contract'] as String?;
    if (contractName == null) return;

    for (final sub in _subscriptions) {
      if (sub.consumes.contract != contractName) continue;

      // Apply filter.
      if (!_matchesFilter(event.data, sub.consumes.filter)) continue;

      // Map fields: consumer input name → value from event payload.
      final mapped = <String, dynamic>{};
      for (final entry in sub.consumes.mapping.entries) {
        final consumerKey = entry.key;
        final contractField = entry.value;
        mapped[consumerKey] = event.data[contractField];
      }

      // Also pass through unmapped fields for flexibility.
      for (final entry in event.data.entries) {
        if (entry.key.startsWith('_')) continue; // skip internal fields
        mapped.putIfAbsent(entry.key, () => entry.value);
      }

      sub.controller.add(mapped);
    }
  }

  bool _matchesFilter(
      Map<String, dynamic> payload, Map<String, List<String>>? filter) {
    if (filter == null) return true;
    for (final entry in filter.entries) {
      final value = payload[entry.key]?.toString();
      if (value == null || !entry.value.contains(value)) return false;
    }
    return true;
  }

  /// Find all compatible consumers for a given producer declaration.
  ///
  /// Used by the AI/validator to check wiring before deploying.
  List<ContractMatch> findMatches(ProducesDecl producer) {
    final matches = <ContractMatch>[];
    for (final sub in _subscriptions) {
      final match = registry.matchProducerConsumer(producer, sub.consumes);
      if (match != null) matches.add(match);
    }
    return matches;
  }

  void dispose() {
    _busSub?.cancel();
    for (final sub in _subscriptions) {
      sub.controller.close();
    }
    _subscriptions.clear();
  }
}

class _ContractSubscription {
  final ConsumesDecl consumes;
  final StreamController<Map<String, dynamic>> controller;

  _ContractSubscription({required this.consumes, required this.controller});
}
