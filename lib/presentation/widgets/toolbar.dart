import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sci_http_client/http_browser_client.dart' as io_http;
import 'package:sci_http_client/http_client.dart' as http_api;
import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/main.dart';
import 'package:tercen_ui_orchestrator/services/orchestrator_client.dart';

/// Fixed toolbar at the top of the orchestrator layout.
///
/// - "Load Library" icon button: prompts for a GitHub repo URL, server fetches catalog.json
/// - One button per installed template widget: opens it in a floating window
class Toolbar extends StatefulWidget {
  const Toolbar({super.key});

  @override
  State<Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<Toolbar> {
  bool _loading = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final sdui = SduiScope.of(context);
    final registry = sdui.registry;

    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final templateWidgets = registry.catalog.where((m) => m.tier >= 2).toList();

        return Container(
          height: 42,
          color: const Color(0xFF2D2D2D),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // One button per template widget in the catalog
              ...templateWidgets.map((meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ToolbarButton(
                      icon: Icons.widgets_outlined,
                      label: meta.type,
                      onPressed: () => _openWidget(context, meta.type),
                    ),
                  )),
              const Spacer(),
              // Status message
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FadingStatus(
                    message: _statusMessage!,
                    onDone: () {
                      if (mounted) setState(() => _statusMessage = null);
                    },
                  ),
                ),
              // Load Library icon button
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                )
              else
                IconButton(
                  icon: const Icon(Icons.library_add_outlined, size: 18),
                  color: Colors.white70,
                  tooltip: 'Load Library',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _showLoadDialog(context),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLoadDialog(BuildContext context) async {
    final sdui = SduiScope.of(context);
    final client = OrchestratorClientScope.of(context);
    final controller = TextEditingController(
      text: 'https://github.com/tercen/test_widget_library',
    );

    final repo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Widget Library'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'GitHub repository URL',
            hintText: 'https://github.com/owner/repo',
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (!mounted || repo == null || repo.isEmpty) return;
    _loadFromGitHub(sdui, client, repo);
  }

  Future<void> _loadFromGitHub(SduiContext sdui, OrchestratorClient client, String repoUrl) async {

    setState(() {
      _loading = true;
      _statusMessage = 'Fetching catalog from GitHub...';
    });

    try {
      final httpUrl = client.baseUrl
          .replaceFirst('ws://', 'http://')
          .replaceFirst('wss://', 'https://');
      final url = '$httpUrl/api/widget-catalog/load';

      final httpClient = io_http.HttpBrowserClient();
      final response = await httpClient.post(
        url,
        headers: http_api.ContentTypeHeaderValue.getJsonHeader(),
        body: jsonEncode({'repo': repoUrl}),
      );

      final body = jsonDecode(response.body as String) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(body['error'] ?? 'Server error ${response.statusCode}');
      }

      // Now fetch the full catalog to load into the registry
      final catalogResponse = await httpClient.get('$httpUrl/api/widget-catalog');
      final catalog = jsonDecode(catalogResponse.body as String) as Map<String, dynamic>;
      final widgets = catalog['widgets'] as List<dynamic>? ?? [];

      sdui.registry.loadCatalog(catalog);

      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Loaded ${widgets.length} widget(s)';
        });
      }
    } catch (e, st) {
      ErrorReporter.instance.report(e,
        stackTrace: st,
        source: 'toolbar.loadCatalog',
        context: 'repo: $repoUrl',
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = 'Failed: $e';
        });
      }
    }
  }

  void _openWidget(BuildContext context, String widgetType) {
    final sdui = SduiScope.of(context);
    final windowId = 'win-${widgetType.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}';

    // Dispatch an addWindow layout op through the EventBus — same path Claude uses.
    final layoutOp = {
      'op': 'addWindow',
      'id': windowId,
      'size': 'medium',
      'align': 'center',
      'title': widgetType,
      'content': {
        'type': widgetType,
        'id': '$windowId-root',
        'props': {},
        'children': [],
      },
    };

    sdui.eventBus.publish(
      'system.layout.op',
      EventPayload(type: 'layout.op', data: layoutOp),
    );

    setState(() => _statusMessage = 'Opened $widgetType');
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Shows a status message that auto-fades after 3 seconds.
class _FadingStatus extends StatefulWidget {
  final String message;
  final VoidCallback onDone;

  const _FadingStatus({required this.message, required this.onDone});

  @override
  State<_FadingStatus> createState() => _FadingStatusState();
}

class _FadingStatusState extends State<_FadingStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _controller.forward().then((_) => widget.onDone());
      }
    });
  }

  @override
  void didUpdateWidget(_FadingStatus old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message) {
      _controller.reset();
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _controller.forward().then((_) => widget.onDone());
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        widget.message,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
