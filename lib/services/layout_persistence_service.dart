import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:sdui/sdui.dart';

/// Auto-saves and auto-loads window layouts per Tercen project.
///
/// Listens to [WindowManager] changes and debounces saves. On project switch,
/// flushes the current layout and loads the new project's layout.
class LayoutPersistenceService {
  final WindowManager windowManager;
  final EventBus eventBus;

  /// Resolves the current username for file ownership.
  final String Function() getUsername;

  /// Resolves the current project ID (selected or default).
  final String? Function() getProjectId;

  Timer? _debounceTimer;
  String? _lastSavedProjectId;
  bool _saving = false;

  static const _fileName = 'layout.sdui.json';

  LayoutPersistenceService({
    required this.windowManager,
    required this.eventBus,
    required this.getUsername,
    required this.getProjectId,
  });

  void dispose() {
    _debounceTimer?.cancel();
  }

  /// Save the current layout now. Called from the "Save Layout" header button.
  Future<void> save() async {
    _debounceTimer?.cancel();
    await _doSave();
  }

  /// Save the current layout to the active project.
  Future<void> _doSave() async {
    final factory = tercen.ServiceFactory.CURRENT;
    if (factory == null) return;
    if (_saving) return;
    if (windowManager.windows.isEmpty) return;

    final projectId = getProjectId();
    if (projectId == null || projectId.isEmpty) return;

    _saving = true;
    try {
      final layoutJson = windowManager.toLayoutJson();
      layoutJson['version'] = 1;
      layoutJson['name'] = _fileName;
      layoutJson['savedAt'] = DateTime.now().toUtc().toIso8601String();

      final bytes = utf8.encode(
          const JsonEncoder.withIndent('  ').convert(layoutJson));

      // Check if file already exists in the project to update it
      final existingFileId = await _findLayoutFile(factory, projectId);

      final file = sci.FileDocument()
        ..name = _fileName
        ..projectId = projectId
        ..description = 'Auto-saved SDUI layout'
        ..acl.owner = getUsername();

      if (existingFileId != null) {
        file.id = existingFileId;
      }

      await factory.fileService.upload(
        file,
        Stream.value(bytes),
      );

      _lastSavedProjectId = projectId;
      debugPrint('[layout.auto] Saved to project $projectId '
          '(${windowManager.windows.length} windows, ${bytes.length} bytes)');
    } catch (e, st) {
      debugPrint('[layout.auto] Save failed: $e');
      ErrorReporter.instance.report(e,
          stackTrace: st,
          source: 'layout.auto',
          context: 'auto-saving layout');
    } finally {
      _saving = false;
    }
  }

  /// Load layout for a project. Call when project selection changes.
  Future<void> loadForProject(String projectId) async {
    // Flush current layout to old project first
    if (_lastSavedProjectId != null && _lastSavedProjectId != projectId) {
      await save();
    }

    final factory = tercen.ServiceFactory.CURRENT;
    if (factory == null) return;

    try {
      final fileId = await _findLayoutFile(factory, projectId);
      if (fileId == null) {
        debugPrint('[layout.auto] No saved layout for project $projectId');
        return;
      }

      final content =
          await utf8.decodeStream(factory.fileService.download(fileId));
      final layoutJson = jsonDecode(content) as Map<String, dynamic>;
      windowManager.loadLayout(layoutJson);
      _lastSavedProjectId = projectId;
      debugPrint('[layout.auto] Loaded layout from project $projectId');
    } catch (e, st) {
      debugPrint('[layout.auto] Load failed: $e');
      ErrorReporter.instance.report(e,
          stackTrace: st,
          source: 'layout.auto',
          context: 'loading layout from project $projectId');
    }
  }

  /// Find the layout.sdui.json file in a project, if it exists.
  Future<String?> _findLayoutFile(
      tercen.ServiceFactory factory, String projectId) async {
    try {
      final key = [projectId, '', _fileName];
      final docs =
          await factory.projectDocumentService.findProjectObjectsByFolderAndName(
        startKey: key,
        endKey: key,
        limit: 1,
        useFactory: true,
      );
      if (docs.isNotEmpty) return docs.first.id;
    } catch (e) {
      debugPrint('[layout.auto] Could not search files in project: $e');
    }
    return null;
  }
}
