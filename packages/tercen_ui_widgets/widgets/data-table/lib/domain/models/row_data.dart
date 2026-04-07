/// A page of row data fetched from a table.
class RowDataPage {
  /// Zero-based offset of the first row in this page.
  final int offset;

  /// Maximum number of rows requested.
  final int limit;

  /// The row data. Each map key is a column name.
  final List<Map<String, dynamic>> rows;

  const RowDataPage({
    required this.offset,
    required this.limit,
    required this.rows,
  });
}
