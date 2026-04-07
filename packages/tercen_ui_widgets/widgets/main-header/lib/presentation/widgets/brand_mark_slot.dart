import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/constants/header_constants.dart';
import '../providers/header_state_provider.dart';
import '../providers/theme_provider.dart';

/// Brand mark slot on the left side of the header.
/// Renders the Tercen brand mark SVG with theme-aware wordmark fill.
class BrandMarkSlot extends StatefulWidget {
  const BrandMarkSlot({super.key});

  @override
  State<BrandMarkSlot> createState() => _BrandMarkSlotState();
}

class _BrandMarkSlotState extends State<BrandMarkSlot> {
  String? _svgRaw;

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  Future<void> _loadSvg() async {
    final raw = await rootBundle.loadString('assets/TercenID_Final_TM_C_no_tag.svg');
    if (mounted) {
      setState(() => _svgRaw = raw);
    }
  }

  /// For dark mode, inject fill="#FFFFFF" into <path> elements that have no
  /// explicit fill attribute. This targets the wordmark paths (ercen) while
  /// leaving the coloured <rect> blocks (which have explicit fills) unchanged.
  String _themedSvg(String raw, bool isDark) {
    if (!isDark) return raw;
    // Match <path that does NOT already contain a fill= attribute.
    // Insert fill="#FFFFFF" right after "<path".
    return raw.replaceAllMapped(
      RegExp(r'<path(?![^>]*fill=)'),
      (match) => '<path fill="#FFFFFF"',
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerProvider = context.read<HeaderStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Tooltip(
      message: 'Home',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            headerProvider.navigateHome();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Home: reload configuration')),
            );
          },
          child: SizedBox(
            height: HeaderConstants.brandMarkMaxHeight,
            child: _svgRaw == null
                ? const SizedBox.shrink()
                : SvgPicture.string(
                    _themedSvg(_svgRaw!, isDark),
                    height: HeaderConstants.brandMarkMaxHeight,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }
}
