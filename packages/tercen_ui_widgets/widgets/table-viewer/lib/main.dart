import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'domain/models/window_identity.dart';
import 'presentation/providers/data_table_provider.dart';
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
    // Also add these imports at the top of the file:
    //   import 'package:sci_tercen_client/sci_service_factory_web.dart';
    //   import 'package:sci_tercen_context/sci_tercen_context.dart';
    //
    // final taskId = Uri.base.queryParameters['taskId'];
    // if (taskId == null || taskId.isEmpty) {
    //   runApp(_buildErrorApp('Missing taskId parameter'));
    //   return;
    // }
    //
    // try {
    //   final factory = await createServiceFactoryForWebApp();
    //   setupServiceLocator(useMocks: false, factory: factory, taskId: taskId);
    // } catch (e) {
    //   print('Tercen init failed: $e — falling back to mocks');
    //   setupServiceLocator(useMocks: true);
    // }

    setupServiceLocator(useMocks: true);
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(DataTableApp(prefs: prefs));
}

class DataTableApp extends StatelessWidget {
  final SharedPreferences prefs;

  const DataTableApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    // Configure window identity
    final identity = WindowIdentity(
      typeId: 'dataTable',
      typeColor: const Color(0xFFF59E0B), // warning/data yellow
      label: 'Data',
    );

    final dataTableProvider = DataTableProvider(
      identity: identity,
      windowId: 'data-table-dev-01',
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider<DataTableProvider>.value(
            value: dataTableProvider),
        ChangeNotifierProvider<WindowStateProvider>.value(
            value: dataTableProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Data Table',
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
