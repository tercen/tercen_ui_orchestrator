import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'domain/models/window_identity.dart';
import 'presentation/providers/audit_trail_provider.dart';
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
    // final taskId = Uri.base.queryParameters['taskId'];
    // if (taskId == null || taskId.isEmpty) {
    //   runApp(_buildErrorApp('Missing taskId parameter'));
    //   return;
    // }
    // try {
    //   final factory = await createServiceFactoryForWebApp();
    //   setupServiceLocator(useMocks: false, factory: factory, taskId: taskId);
    // } catch (e) {
    //   print('Tercen init failed: $e -- falling back to mocks');
    //   setupServiceLocator(useMocks: true);
    // }
    setupServiceLocator(useMocks: true);
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(AuditTrailApp(prefs: prefs));
}

class AuditTrailApp extends StatelessWidget {
  final SharedPreferences prefs;

  const AuditTrailApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    // Window 7 identity: Audit Trail, Teal #0D9488
    final identity = WindowIdentity(
      typeId: 'auditTrail',
      typeColor: const Color(0xFF0D9488),
      label: 'Audit Trail',
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(
          create: (_) => AuditTrailProvider(
            identity: identity,
            windowId: 'audit-trail-dev-01',
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Audit Trail',
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
