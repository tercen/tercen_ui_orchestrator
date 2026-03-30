import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdui/sdui.dart';

import 'package:tercen_ui_orchestrator/sdui/validator/schema_generator.dart';

void main() {
  test('generate SDUI component schema', () {
    final registry = WidgetRegistry();
    registerBuiltinWidgets(registry);

    // Also load catalog templates.
    final catalogFile = File('../tercen_ui_widgets/catalog.json');
    if (catalogFile.existsSync()) {
      final catalogJson =
          jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
      registry.loadCatalog(catalogJson);
    }

    final generator = SduiSchemaGenerator(registry);
    final json = generator.toJson();

    // Write to file.
    final outputFile = File('../sdui-components.schema.json');
    outputFile.writeAsStringSync(json);

    // Verify structure.
    final schema = jsonDecode(json) as Map<String, dynamic>;
    final components = schema['components'] as Map<String, dynamic>;

    // ignore: avoid_print
    print('Components: ${components.length}');
    // ignore: avoid_print
    print('Tier 1: ${components.values.where((c) => (c as Map)['tier'] == 1).length}');
    // ignore: avoid_print
    print('Tier 2: ${components.values.where((c) => (c as Map)['tier'] == 2).length}');
    // ignore: avoid_print
    print('With provides: ${components.values.where((c) => (c as Map).containsKey('provides')).length}');
    // ignore: avoid_print
    print('With emits: ${components.values.where((c) => (c as Map).containsKey('emits')).length}');

    expect(components.length, greaterThan(40));
    expect(schema['tokens'], isNotNull);
    expect(schema['bindings'], isNotNull);
  });
}
