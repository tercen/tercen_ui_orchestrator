import 'package:get_it/get_it.dart';
import '../domain/services/home_data_service.dart';
import '../domain/services/event_bus.dart';
import '../implementations/services/mock_home_data_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// Register services. Called once from main().
void setupServiceLocator({
  bool useMocks = true,
  EventBus? eventBus,
}) {
  // EventBus
  if (!serviceLocator.isRegistered<EventBus>()) {
    serviceLocator.registerSingleton<EventBus>(eventBus ?? EventBus());
  }

  if (serviceLocator.isRegistered<HomeDataService>()) return;

  if (useMocks) {
    serviceLocator.registerLazySingleton<HomeDataService>(
      () => MockHomeDataService(),
    );
  }
  // Phase 3: add else branch for real Tercen integration
}
