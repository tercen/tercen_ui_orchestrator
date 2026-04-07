import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A CustomPainter that generates a GitHub-style geometric identicon
/// from an identity string. The pattern is deterministic: same input
/// always produces the same visual output.
class IdenticonPainter extends CustomPainter {
  final String identityString;

  IdenticonPainter({required this.identityString});

  @override
  void paint(Canvas canvas, Size size) {
    final bytes = _hashString(identityString);

    // Derive foreground colour from hash bytes (NOT brand palette).
    final fgColor = Color.fromARGB(
      255,
      bytes[0],
      bytes[1],
      bytes[2],
    );

    // Ensure sufficient contrast: if colour is too light, darken it.
    final hsl = HSLColor.fromColor(fgColor);
    final adjustedColor = hsl.lightness > 0.7
        ? hsl.withLightness(0.5).toColor()
        : fgColor;

    final bgPaint = Paint()..color = Colors.white;
    final fgPaint = Paint()..color = adjustedColor;

    // Fill background white.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 5x5 grid, mirrored left-right (so columns 0-2 determine pattern,
    // column 3 mirrors column 1, column 4 mirrors column 0).
    final cellW = size.width / 5;
    final cellH = size.height / 5;

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 3; col++) {
        // Use one byte per cell from the hash. We have 16 bytes,
        // and need 15 cells (3 cols x 5 rows).
        final byteIndex = (row * 3 + col) % bytes.length;
        final filled = bytes[byteIndex] & 1 == 1;

        if (filled) {
          // Draw the cell.
          canvas.drawRect(
            Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH),
            fgPaint,
          );

          // Mirror: column 0 -> 4, column 1 -> 3, column 2 stays (center).
          if (col < 2) {
            final mirrorCol = 4 - col;
            canvas.drawRect(
              Rect.fromLTWH(mirrorCol * cellW, row * cellH, cellW, cellH),
              fgPaint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant IdenticonPainter oldDelegate) {
    return oldDelegate.identityString != identityString;
  }

  /// Simple deterministic hash: UTF-8 encode then fold into 16 bytes.
  /// Not cryptographic -- just needs to produce stable, varied output.
  static Uint8List _hashString(String input) {
    final encoded = utf8.encode(input);
    final result = Uint8List(16);

    // Initialize with a seed pattern.
    for (int i = 0; i < 16; i++) {
      result[i] = (i * 37 + 59) & 0xFF;
    }

    // Mix in each byte of the input.
    for (int i = 0; i < encoded.length; i++) {
      final idx = i % 16;
      result[idx] = ((result[idx] ^ encoded[i]) * 31 + 17) & 0xFF;
    }

    // Additional mixing passes for better distribution.
    for (int pass = 0; pass < 3; pass++) {
      for (int i = 0; i < 16; i++) {
        result[i] = ((result[i] ^ result[(i + 1) % 16]) * 37 + 53) & 0xFF;
      }
    }

    return result;
  }
}
