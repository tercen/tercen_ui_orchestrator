import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'domain/models/window_identity.dart';
import 'presentation/providers/chat_provider.dart';
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

  runApp(ChatBoxApp(prefs: prefs));
}

class ChatBoxApp extends StatelessWidget {
  final SharedPreferences prefs;

  const ChatBoxApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    // Window 2: Chat -- yellow square from the Tercen logo palette
    final identity = WindowIdentity(
      typeId: 'chat',
      typeColor: const Color(0xFFEAB308), // yellow
      label: 'Chat',
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            identity: identity,
            windowId: 'chat-dev-01',
          ),
        ),
        ChangeNotifierProxyProvider<ChatProvider, WindowStateProvider>(
          create: (context) => context.read<ChatProvider>(),
          update: (_, chatProvider, __) => chatProvider,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Chat Box',
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
