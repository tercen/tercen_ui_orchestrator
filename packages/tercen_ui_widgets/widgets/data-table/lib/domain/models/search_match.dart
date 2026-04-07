/// Represents a single search hit at a specific cell coordinate.
class SearchMatch {
  /// Zero-based row index.
  final int row;

  /// Column name.
  final String column;

  const SearchMatch({required this.row, required this.column});
}
