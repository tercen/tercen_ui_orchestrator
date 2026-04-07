import 'package:flutter/material.dart';
import '../theme/app_line_weights.dart';

/// Dimension and styling constants for the Pane (tab container).
///
/// A Pane is the draggable frame that holds 1+ widget tabs.
/// It consists of a tab strip + content container. Nothing else.
/// Toolbars and body states are the widget's responsibility.
class PaneConstants {
  PaneConstants._();

  // ── Tab strip ──
  static const double tabStripHeight = 32.0; // tabHeight + 4px top padding
  static const double tabHeight = 28.0;
  static const double tabMaxWidth = 220.0;
  static const double tabMinWidth = 80.0;

  // ── Tab internal ──
  static const double tabIconSize = 8.0; // color square
  static const double tabIconRadius = 2.0; // color square corner radius
  static const double tabFontSize = 11.0;
  static const double tabButtonSize = 20.0; // close button
  static const double tabButtonIconSize = 11.0; // close icon
  static const double tabPaddingH = 8.0; // horizontal padding inside tab
  static const double tabGap = 4.0; // gap between icon/title/close

  // ── Tab font weights by state ──
  static const FontWeight tabWeightFocused = FontWeight.w700; // active tab, focused pane
  static const FontWeight tabWeightBlurred = FontWeight.w500; // active tab, blurred pane
  static const FontWeight tabWeightInactive = FontWeight.w400; // inactive tab

  // ── Tab accent (bottom border on active tab) ──
  static const double tabAccentWidth = AppLineWeights.lineEmphasis; // 2px

  // ── Pane frame ──
  static const double borderWidth = AppLineWeights.lineSubtle; // 1px
  static const double borderRadius = 0.0; // straight corners for clean stacking

  // ── Resize handle (floating panes only) ──
  static const double resizeHandleSize = 16.0;

  // ── Shadow (floating panes only) ──
  static const double shadowBlur = 12.0;
  static const double shadowOffsetY = 4.0;
}
