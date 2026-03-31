import 'package:flutter_test/flutter_test.dart';
import 'package:sdui/sdui.dart';

import 'package:tercen_ui_orchestrator/sdui/contracts/contract_bus.dart';
import 'package:tercen_ui_orchestrator/sdui/contracts/contract_registry.dart';
import 'package:tercen_ui_orchestrator/sdui/contracts/event_contracts.dart';

void main() {
  late EventBus eventBus;
  late ContractRegistry registry;
  late ContractBus contractBus;

  setUp(() {
    eventBus = EventBus();
    registry = createDefaultRegistry();
    contractBus = ContractBus(eventBus: eventBus, registry: registry);
  });

  tearDown(() {
    contractBus.dispose();
    eventBus.dispose();
  });

  test('producer → consumer with field mapping', () async {
    // ProjectNavigator produces "selection" with {id, name, kind}
    // DocumentViewer consumes "selection" mapping {resourceId: id, fileName: name}

    final received = <Map<String, dynamic>>[];
    contractBus
        .subscribe(ConsumesDecl(
          contract: 'selection',
          mapping: {'resourceId': 'id', 'fileName': 'name'},
        ))
        .listen(received.add);

    // Simulate ProjectNavigator publishing a selection.
    contractBus.publish(
      contractName: 'selection',
      payload: {'id': 'file-001', 'name': 'Report.md', 'kind': 'FileDocument'},
      sourceWidgetId: 'project-nav-1',
    );

    await Future.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received[0]['resourceId'], 'file-001'); // mapped from 'id'
    expect(received[0]['fileName'], 'Report.md'); // mapped from 'name'
    expect(received[0]['kind'], 'FileDocument'); // passed through unmapped
  });

  test('filter: consumer only receives matching events', () async {
    final received = <Map<String, dynamic>>[];
    contractBus
        .subscribe(ConsumesDecl(
          contract: 'selection',
          mapping: {'fileId': 'id'},
          filter: {'kind': ['FileDocument', 'Schema']},
        ))
        .listen(received.add);

    // Publish a Workflow selection — should be filtered out.
    contractBus.publish(
      contractName: 'selection',
      payload: {'id': 'wf-001', 'name': 'Pipeline', 'kind': 'Workflow'},
    );

    // Publish a FileDocument selection — should pass.
    contractBus.publish(
      contractName: 'selection',
      payload: {'id': 'file-001', 'name': 'Data.csv', 'kind': 'FileDocument'},
    );

    await Future.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received[0]['fileId'], 'file-001');
  });

  test('multiple consumers on same contract', () async {
    final consumer1 = <Map<String, dynamic>>[];
    final consumer2 = <Map<String, dynamic>>[];

    contractBus
        .subscribe(ConsumesDecl(
          contract: 'selection',
          mapping: {'selectedId': 'id'},
        ))
        .listen(consumer1.add);

    contractBus
        .subscribe(ConsumesDecl(
          contract: 'selection',
          mapping: {'entityId': 'id', 'entityName': 'name'},
        ))
        .listen(consumer2.add);

    contractBus.publish(
      contractName: 'selection',
      payload: {'id': 'proj-001', 'name': 'My Project', 'kind': 'Project'},
    );

    await Future.delayed(Duration.zero);

    expect(consumer1, hasLength(1));
    expect(consumer1[0]['selectedId'], 'proj-001');

    expect(consumer2, hasLength(1));
    expect(consumer2[0]['entityId'], 'proj-001');
    expect(consumer2[0]['entityName'], 'My Project');
  });

  test('contract compatibility check', () {
    final producer = ProducesDecl(
      contract: 'selection',
      mapping: {'id': 'item.id', 'name': 'item.name', 'kind': 'item.kind'},
    );

    // Compatible consumer — needs id, which producer provides.
    final consumer1 = ConsumesDecl(
      contract: 'selection',
      mapping: {'resourceId': 'id'},
    );

    // Incompatible consumer — needs 'parentId', which producer doesn't map.
    final consumer2 = ConsumesDecl(
      contract: 'selection',
      mapping: {'parentProjectId': 'parentId'},
    );

    // Different contract — never compatible.
    final consumer3 = ConsumesDecl(
      contract: 'navigation',
      mapping: {'resourceId': 'id'},
    );

    expect(registry.matchProducerConsumer(producer, consumer1), isNotNull);
    expect(registry.matchProducerConsumer(producer, consumer2), isNull);
    expect(registry.matchProducerConsumer(producer, consumer3), isNull);
  });

  test('reject payload that does not satisfy contract', () async {
    final received = <Map<String, dynamic>>[];
    contractBus
        .subscribe(ConsumesDecl(
          contract: 'selection',
          mapping: {'entityId': 'id'},
        ))
        .listen(received.add);

    // Missing required field 'id' — should be rejected by publish.
    contractBus.publish(
      contractName: 'selection',
      payload: {'name': 'Orphan'}, // no 'id'!
    );

    await Future.delayed(Duration.zero);
    expect(received, isEmpty);
  });

  test('default registry has expected contracts', () {
    expect(registry.get('selection'), isNotNull);
    expect(registry.get('navigation'), isNotNull);
    expect(registry.get('dataChanged'), isNotNull);
    expect(registry.get('command'), isNotNull);
    expect(registry.get('notification'), isNotNull);
    expect(registry.get('taskStatus'), isNotNull);
    expect(registry.get('formSubmit'), isNotNull);
    expect(registry.get('stateChange'), isNotNull);

    // Selection contract has required 'id' field.
    final selection = registry.get('selection')!;
    expect(selection.fields['id']?.required, isTrue);
    expect(selection.fields['name']?.required, isFalse);
  });

  test('export registry as JSON and reload', () {
    final json = registry.toJson();
    expect(json['contracts'], isNotNull);

    final contracts = json['contracts'] as Map<String, dynamic>;
    expect(contracts.length, 8);
    expect(contracts['selection'], isNotNull);

    // Reload into fresh registry.
    final registry2 = ContractRegistry();
    registry2.loadFromJson(json);
    expect(registry2.get('selection')?.fields['id']?.required, isTrue);
  });
}
