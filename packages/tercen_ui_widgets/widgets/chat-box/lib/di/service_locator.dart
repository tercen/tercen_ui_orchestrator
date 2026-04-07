import 'package:get_it/get_it.dart';
import '../domain/services/chat_service.dart';
import '../domain/services/data_service.dart';
import '../domain/services/event_bus.dart';
import '../implementations/services/mock_chat_service.dart';
import '../implementations/services/mock_data_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// Register services. Called once from main().
///
/// [eventBus] — In production the orchestrator provides its EventBus instance.
/// In mock/standalone mode a local EventBus is created automatically.
///
/// Mock mode: registers MockChatService + MockDataService + local EventBus.
/// Real mode: registers Tercen context + real services.
///
/// Phase 3 adds:
///   import 'package:sci_tercen_client/sci_client_service_factory.dart';
///   setupServiceLocator(useMocks: false, factory: factory, taskId: taskId);
void setupServiceLocator({
  bool useMocks = true,
  EventBus? eventBus,
  // Phase 3: uncomment to accept factory + taskId
  // ServiceFactory? factory,
  // String? taskId,
}) {
  // EventBus — use provided instance or create a local one.
  if (!serviceLocator.isRegistered<EventBus>()) {
    serviceLocator.registerSingleton<EventBus>(eventBus ?? EventBus());
  }

  if (serviceLocator.isRegistered<DataService>()) return;

  if (useMocks) {
    serviceLocator.registerLazySingleton<DataService>(
      () => MockDataService(),
    );
    serviceLocator.registerLazySingleton<ChatService>(
      () => MockChatService(),
    );
  }
  // Phase 3: add else branch for real Tercen integration
}
