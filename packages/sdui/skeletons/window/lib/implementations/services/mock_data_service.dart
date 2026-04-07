import '../../domain/services/data_service.dart';

/// Mock implementation that returns placeholder data.
/// Replace with real mock data for your window type.
class MockDataService implements DataService {
  @override
  Future<Map<String, dynamic>> loadData() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return {
      'itemCount': 42,
      'status': 'Mock data loaded',
      'items': ['Alpha', 'Beta', 'Gamma', 'Delta'],
    };
  }
}
