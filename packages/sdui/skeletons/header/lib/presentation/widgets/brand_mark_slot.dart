import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/header_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../providers/header_state_provider.dart';
import '../providers/theme_provider.dart';

/// Brand mark slot on the left side of the header.
/// Phase 2 mock: renders a simple 4x4 coloured grid placeholder (App.svg stand-in).
class BrandMarkSlot extends StatelessWidget {
  const BrandMarkSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final headerProvider = context.read<HeaderStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Tooltip(
      message: 'Home',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => headerProvider.navigateHome(),
          child: SizedBox(
            height: HeaderConstants.brandMarkMaxHeight,
            child: _PlaceholderBrandMark(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

/// Temporary 4x4 coloured grid placeholder standing in for the brand mark.
class _PlaceholderBrandMark extends StatelessWidget {
  final bool isDark;

  const _PlaceholderBrandMark({required this.isDark});

  // Tercen-inspired 4x4 colour grid (from App.svg).
  static const List<Color> _gridColors = [
    Color(0xFF1E40AF), // Blue
    Color(0xFF059669), // Green
    Color(0xFFD97706), // Amber
    Color(0xFF7C3AED), // Purple
    Color(0xFFDC2626), // Red
    Color(0xFF0891B2), // Cyan
    Color(0xFF1E40AF), // Blue
    Color(0xFFD97706), // Amber
    Color(0xFF059669), // Green
    Color(0xFF7C3AED), // Purple
    Color(0xFFDC2626), // Red
    Color(0xFF0891B2), // Cyan
    Color(0xFF1E40AF), // Blue
    Color(0xFF059669), // Green
    Color(0xFFD97706), // Amber
    Color(0xFF7C3AED), // Purple
  ];

  @override
  Widget build(BuildContext context) {
    const gridSize = 24.0; // 24px square grid
    const cellSize = gridSize / 4;

    return SizedBox(
      width: gridSize,
      height: gridSize,
      child: CustomPaint(
        size: const Size.square(gridSize),
        painter: _GridPainter(colors: _gridColors, cellSize: cellSize),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final List<Color> colors;
  final double cellSize;

  _GridPainter({required this.colors, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 16; i++) {
      final row = i ~/ 4;
      final col = i % 4;
      paint.color = colors[i];
      canvas.drawRect(
        Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
