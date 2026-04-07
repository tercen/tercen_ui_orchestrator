import 'package:flutter/foundation.dart';

import '../../di/service_locator.dart';
import '../../domain/models/user_state.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/header_data_service.dart';

/// Manages header state: user identity, LLM status, dropdown visibility.
class HeaderStateProvider extends ChangeNotifier {
  final EventBus _eventBus = serviceLocator<EventBus>();
  final HeaderDataService _dataService = serviceLocator<HeaderDataService>();

  late UserState _userState;
  late bool _llmConnected;
  bool _dropdownOpen = false;

  HeaderStateProvider() {
    _userState = _dataService.getUserState();
    _llmConnected = _dataService.isLlmConnected();
  }

  // -- Getters --

  UserState get userState => _userState;
  bool get llmConnected => _llmConnected;
  bool get dropdownOpen => _dropdownOpen;

  // -- Dropdown --

  void toggleDropdown() {
    _dropdownOpen = !_dropdownOpen;
    notifyListeners();
  }

  void closeDropdown() {
    if (_dropdownOpen) {
      _dropdownOpen = false;
      notifyListeners();
    }
  }

  // -- Actions (each publishes to EventBus header.intent channel) --

  void navigateHome() {
    _eventBus.publish('header.intent', 'navigateHome', {});
    print('Navigate to Home requested');
  }

  void saveLayout() {
    _eventBus.publish('header.intent', 'saveLayout', {});
    print('Save layout requested');
    closeDropdown();
  }

  /// Toggle theme. In mock mode, also toggles ThemeProvider locally.
  /// The [onToggle] callback is used by the widget to toggle ThemeProvider.
  void toggleTheme({required bool isDark, VoidCallback? onToggle}) {
    final targetTheme = isDark ? 'light' : 'dark';
    _eventBus.publish('header.intent', 'toggleTheme', {'targetTheme': targetTheme});
    print('Toggle theme requested: target=$targetTheme');
    onToggle?.call();
    closeDropdown();
  }

  void openLlmSettings() {
    _eventBus.publish('header.intent', 'openLlmSettings', {});
    print('Open LLM settings requested');
    closeDropdown();
  }

  void openTaskManager() {
    _eventBus.publish('header.intent', 'openTaskManager', {});
    print('Open Task Manager requested');
    closeDropdown();
  }

  void openAdminPanel() {
    _eventBus.publish('header.intent', 'openAdminPanel', {});
    print('Open Admin Panel requested');
    closeDropdown();
  }

  void signOut() {
    _eventBus.publish('header.intent', 'signOut', {});
    print('Sign out requested');
    closeDropdown();
  }
}
