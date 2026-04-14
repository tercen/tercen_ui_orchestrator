/// Bridge mixin for WindowStateProvider compatibility.
///
/// WindowStateProvider (DO-NOT-MODIFY) calls _dataService.loadData()
/// expecting Future<Map<String, dynamic>>. DataTableProvider overrides
/// loadData() so this bridge is never called at runtime, but it must
/// exist for compilation.
mixin LegacyDataBridge {
  Future<Map<String, dynamic>> loadData() async => {};
}
