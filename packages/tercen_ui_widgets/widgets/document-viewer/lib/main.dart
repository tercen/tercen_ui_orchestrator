import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'domain/models/window_identity.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/document_provider.dart';
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

  runApp(DocumentEditorApp(prefs: prefs));
}

class DocumentEditorApp extends StatelessWidget {
  final SharedPreferences prefs;

  const DocumentEditorApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final identity = WindowIdentity(
      typeId: 'documentEditor',
      typeColor: const Color(0xFF6366F1), // indigo
      label: 'Document Editor',
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(
            create: (_) => DocumentProvider(
                  identity: identity,
                  windowId: 'doc-editor-dev-01',
                )),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Document Editor',
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
