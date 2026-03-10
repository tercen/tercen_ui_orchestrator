import 'package:flutter/material.dart';

import 'window_state.dart';

/// Title bar and controls for a floating window.
class WindowChrome extends StatelessWidget {
  final WindowState state;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onFocus;
  final Widget child;

  const WindowChrome({
    super.key,
    required this.state,
    required this.onClose,
    required this.onMinimize,
    required this.onFocus,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(127),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTitleBar(),
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return GestureDetector(
      onTap: onFocus,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Color(0xFF383838),
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                state.title ?? state.content.type,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _chromeButton(Icons.remove, onMinimize),
            const SizedBox(width: 4),
            _chromeButton(Icons.close, onClose),
          ],
        ),
      ),
    );
  }

  Widget _chromeButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: Colors.white38),
      ),
    );
  }
}
