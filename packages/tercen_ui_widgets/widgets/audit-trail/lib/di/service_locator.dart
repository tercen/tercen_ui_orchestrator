import 'package:get_it/get_it.dart';
import '../domain/services/audit_data_service.dart';
import '../domain/services/event_bus.dart';
import '../implementations/services/mock_audit_data_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// Register services. Called once from main().
///
/// Mock mode: registers MockAuditDataService + local EventBus.
/// Real mode: registers Tercen context + real data service.
void setupServiceLocator({
  bool useMocks = true,
  EventBus? eventBus,
}) {
  // EventBus
  if (!serviceLocator.isRegistered<EventBus>()) {
    serviceLocator.registerSingleton<EventBus>(eventBus ?? EventBus());
  }

  if (serviceLocator.isRegistered<AuditDataService>()) return;

  if (useMocks) {
    serviceLocator.registerLazySingleton<AuditDataService>(
      () => MockAuditDataService(),
    );
  }
  // Phase 3: add else branch for real Tercen integration
}
