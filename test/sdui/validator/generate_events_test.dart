import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdui/sdui.dart';

import 'package:tercen_ui_orchestrator/sdui/validator/event_spec_generator.dart';

void main() {
  test('generate event spec from catalog', () {
    final registry = WidgetRegistry();
    registerBuiltinWidgets(registry);

    Map<String, dynamic>? catalogJson;
    final catalogFile = File('../tercen_ui_widgets/catalog.json');
    if (catalogFile.existsSync()) {
      catalogJson =
          jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
      registry.loadCatalog(catalogJson);
    }

    final generator = EventSpecGenerator(registry, catalogJson: catalogJson);
    final json = generator.toJson();

    final outputFile = File('../sdui-events.json');
    outputFile.writeAsStringSync(json);

    final spec = jsonDecode(json) as Map<String, dynamic>;
    final channels = spec['channels'] as Map<String, dynamic>;
    final intents = spec['intents'] as Map<String, dynamic>;
    final patterns = spec['patterns'] as Map<String, dynamic>;

    // ignore: avoid_print
    print('Channels: ${channels.length}');
    // ignore: avoid_print
    print('Intents: ${intents.length}');
    // ignore: avoid_print
    print('Patterns: ${patterns.length}');
    // ignore: avoid_print
    print('');
    for (final entry in channels.entries) {
      final ch = entry.value as Map<String, dynamic>;
      final pub = (ch['publishers'] as List?)?.length ?? 0;
      final sub = (ch['subscribers'] as List?)?.length ?? 0;
      final keys = (ch['payloadKeys'] as List?)?.join(', ') ?? '';
      // ignore: avoid_print
      print('  ${entry.key}: $pub pub, $sub sub — keys: [$keys]');
    }
    // ignore: avoid_print
    print('');
    for (final entry in intents.entries) {
      final intent = entry.value as Map<String, dynamic>;
      // ignore: avoid_print
      print('  intent ${entry.key} → ${intent['handler']}');
    }

    expect(channels.length, greaterThan(5));
    expect(intents.length, greaterThan(5));
  });
}
