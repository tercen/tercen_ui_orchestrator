import 'package:flutter/material.dart';
import '../constants/window_constants.dart';

/// 8x8px coloured square used as the window type icon in tabs.
///
/// Each window type is assigned a colour from the Tercen logo palette.
/// This widget renders the square with a 2px border-radius.
class TabTypeIcon extends StatelessWidget {
  final Color color;
  final double size;

  const TabTypeIcon({
    super.key,
    required this.color,
    this.size = WindowConstants.tabIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(WindowConstants.tabIconRadius),
      ),
    );
  }
}
