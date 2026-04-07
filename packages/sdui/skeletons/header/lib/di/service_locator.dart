import 'package:get_it/get_it.dart';

import '../domain/services/event_bus.dart';
import '../domain/services/header_data_service.dart';
import '../implementations/services/mock_event_bus.dart';
import '../implementations/services/mock_header_data_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// Register services. Called once from main().
void setupServiceLocator({bool useMocks = true}) {
  if (serviceLocator.isRegistered<EventBus>()) return;

  if (useMocks) {
    serviceLocator.registerLazySingleton<EventBus>(
      () => MockEventBus(),
    );
    serviceLocator.registerLazySingleton<HeaderDataService>(
      () => MockHeaderDataService(),
    );
  }
}
