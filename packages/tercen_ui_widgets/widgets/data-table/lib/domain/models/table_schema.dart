/// Definition of a single column in a table.
class TableColumnDef {
  final String name;

  /// Type string: string, double, int32, uint64, uint16.
  final String type;

  const TableColumnDef({required this.name, required this.type});
}

/// Discriminator for the source of a table schema.
enum TableKind { tableSchema, computedTableSchema, cubeQueryTableSchema }

/// Describes the structure of a table: its columns, row count, and origin.
class TableSchema {
  final String id;
  final String name;
  final TableKind kind;
  final int nRows;
  final List<TableColumnDef> columns;

  const TableSchema({
    required this.id,
    required this.name,
    required this.kind,
    required this.nRows,
    required this.columns,
  });
}
