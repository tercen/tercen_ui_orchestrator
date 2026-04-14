import '../models/table_schema.dart';
import '../models/row_data.dart';
import '../models/search_match.dart';
import 'legacy_data_bridge.dart';

/// Abstract data service for the data table.
/// Phase 2: Mock implementation returns generated tabular data.
/// Phase 3: Real implementation queries Tercen API.
abstract class DataService with LegacyDataBridge {
  /// Fetch the schema (columns, row count, kind) for a table.
  Future<TableSchema> getSchema(String tableId);

  /// Fetch a page of row data with optional sorting.
  Future<RowDataPage> getRows(
    String tableId,
    int offset,
    int limit, {
    String? sortColumn,
    bool ascending = true,
  });

  /// Search all cells for [query] and return matching coordinates.
  Future<List<SearchMatch>> search(String tableId, String query);

  /// Save annotation edits. Returns the new annotation table ID.
  Future<String> saveAnnotations(
    String sourceTableId,
    String projectId,
    Map<String, Map<String, dynamic>> edits,
  );

  /// Export the table as CSV bytes.
  Future<List<int>> exportCsv(String tableId);
}
