import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'domain/models/window_identity.dart';
import 'presentation/providers/home_panel_provider.dart';
import 'presentation/providers/theme_provider.dart';
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

  runApp(HomePanelApp(prefs: prefs));
}

class HomePanelApp extends StatelessWidget {
  final SharedPreferences prefs;

  const HomePanelApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    // Window 0 identity: Home, Multi (Tercen logo — no single hex colour).
    // Colors.transparent signals "multi" to the Frame tab renderer.
    final identity = WindowIdentity(
      typeId: 'homePanel',
      typeColor: Colors.transparent,
      label: 'Home',
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(
          create: (_) => HomePanelProvider(
            identity: identity,
            windowId: 'home-panel-dev-01',
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Home',
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
