import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdui/sdui.dart';

import 'package:tercen_ui_orchestrator/sdui/validator/template_validator.dart';
import 'package:tercen_ui_orchestrator/sdui/validator/validation_result.dart';

void main() {
  late WidgetRegistry registry;
  late Map<String, dynamic> catalogJson;

  setUpAll(() {
    final catalogFile = File('../tercen_ui_widgets/catalog.json');
    if (!catalogFile.existsSync()) {
      fail('catalog.json not found at ${catalogFile.path}');
    }
    catalogJson = jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;

    registry = WidgetRegistry();
    registerBuiltinWidgets(registry);
    registry.loadCatalog(catalogJson);
  });

  test('validate all catalog widgets and print report', () {
    final validator = TemplateValidator(registry: registry);
    final allResults = validator.validateCatalog(catalogJson);

    var totalErrors = 0;
    var totalWarnings = 0;
    var totalInfos = 0;

    for (final entry in allResults.entries) {
      final widgetName = entry.key;
      final results = entry.value;

      if (results.isEmpty) {
        // ignore: avoid_print
        print('  $widgetName: OK');
        continue;
      }

      final errors = results.where((r) => r.isError).length;
      final warnings = results.where((r) => r.isWarning).length;
      final infos = results.where((r) => !r.isError && !r.isWarning).length;
      totalErrors += errors;
      totalWarnings += warnings;
      totalInfos += infos;

      // ignore: avoid_print
      print('  $widgetName: $errors errors, $warnings warnings, $infos info');
      for (final r in results) {
        final icon = switch (r.severity) {
          ValidationSeverity.error => 'E',
          ValidationSeverity.warning => 'W',
          ValidationSeverity.info => 'I',
        };
        // ignore: avoid_print
        print('    [$icon] ${r.ruleId}: ${r.message}');
        // ignore: avoid_print
        print('        at ${r.nodePath}');
      }
    }

    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('Total: $totalErrors errors, $totalWarnings warnings, $totalInfos info');

    // The test passes regardless — this is a diagnostic report.
    // Uncomment the next line to fail on errors:
    // expect(totalErrors, 0);
  });
}
