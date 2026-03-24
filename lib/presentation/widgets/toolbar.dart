import 'package:flutter/material.dart';
import 'package:sdui/sdui.dart';
import 'package:tercen_ui_orchestrator/main.dart';

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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
              // Theme toggle
              Builder(
                builder: (context) {
                  final themeCtrl = ThemeController.of(context);
                  return IconButton(
                    icon: Icon(
                      themeCtrl.isDark ? Icons.light_mode : Icons.dark_mode,
                      size: 18,
                    ),
                    color: Theme.of(context).colorScheme.onSurface,
                    tooltip: themeCtrl.isDark ? 'Switch to light mode' : 'Switch to dark mode',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: themeCtrl.onToggle,
                  );
                },
              ),
              // Load Library button removed — catalog auto-loads on startup
              // from orchestrator.config.json widgetLibraryUrl
            ],
          ),
        );
      },
    );
  }

  Future<void> _openWidget(BuildContext context, String widgetType) async {
    final sdui = SduiScope.of(context);
    final meta = sdui.registry.getMetadata(widgetType);

    // Collect required props from the user
    final requiredProps = <String, PropSpec>{};
    if (meta != null) {
      for (final entry in meta.props.entries) {
        if (entry.value.required) {
          requiredProps[entry.key] = entry.value;
        }
      }
    }

    Map<String, dynamic> props = {};
    if (requiredProps.isNotEmpty && mounted) {
      final result = await _promptForProps(context, widgetType, requiredProps);
      if (result == null) return; // user cancelled
      props = result;
    }

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
        'props': props,
        'children': [],
      },
    };

    sdui.eventBus.publish(
      'system.layout.op',
      EventPayload(type: 'layout.op', data: layoutOp),
    );

    if (mounted) setState(() => _statusMessage = 'Opened $widgetType');
  }

  Future<Map<String, dynamic>?> _promptForProps(
    BuildContext context,
    String widgetType,
    Map<String, PropSpec> requiredProps,
  ) async {
    final controllers = <String, TextEditingController>{};
    for (final key in requiredProps.keys) {
      controllers[key] = TextEditingController();
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$widgetType — required props'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries.map((e) {
              final spec = requiredProps[e.key]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: e.key,
                    hintText: spec.description ?? spec.type,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final props = <String, dynamic>{};
              for (final e in controllers.entries) {
                final val = e.value.text.trim();
                if (val.isNotEmpty) props[e.key] = val;
              }
              Navigator.of(ctx).pop(props);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );

    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
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
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }
}
