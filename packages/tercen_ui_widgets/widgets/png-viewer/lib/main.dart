import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'domain/models/window_identity.dart';
import 'domain/services/event_bus.dart';
import 'domain/services/event_payload.dart';
import 'implementations/services/mock_data_service.dart';
import 'presentation/providers/png_viewer_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/window_state_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Mock/Real switching ---
  const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

  if (useMocks) {
    setupServiceLocator(useMocks: true);
  } else {
    // Phase 3: Uncomment to initialize Tercen context.
    setupServiceLocator(useMocks: true);
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(PngViewerApp(prefs: prefs));
}

class PngViewerApp extends StatelessWidget {
  final SharedPreferences prefs;

  const PngViewerApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final identity = WindowIdentity(
      typeId: 'visualization',
      typeColor: const Color(0xFF66FF7F),
      label: 'PNG Viewer',
    );

    const windowId = 'png-viewer-dev-01';

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider<WindowStateProvider>(
          create: (_) {
            final provider = PngViewerProvider(
              identity: identity,
              windowId: windowId,
            );
            // Fire simulated loadImage after a brief delay (mock behaviour).
            Future.delayed(const Duration(milliseconds: 600), () {
              final eventBus = serviceLocator<EventBus>();
              eventBus.publish(
                'visualization.$windowId.loadImage',
                EventPayload(
                  type: 'loadImage',
                  sourceWidgetId: 'mock-frame',
                  data: {
                    'resourceType': MockDataService.sampleResourceType,
                    'resourceId': MockDataService.sampleResourceId,
                  },
                ),
              );
            });
            return provider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'PNG Viewer',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
