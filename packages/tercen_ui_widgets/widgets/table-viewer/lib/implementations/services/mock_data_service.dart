import 'dart:convert';
import 'dart:math';

import '../../domain/models/row_data.dart';
import '../../domain/models/search_match.dart';
import '../../domain/models/table_schema.dart';
import '../../domain/services/data_service.dart';

/// Mock implementation that returns generated tabular data with realistic
/// latency simulation per the spec (Section 13.7).
class MockDataService extends DataService {
  final _random = Random();

  /// 10% chance of throwing on initial load for testing error state.
  bool _shouldFailInitialLoad = false;
  int _loadCount = 0;

  // Cached generated data per table ID.
  final Map<String, List<Map<String, dynamic>>> _tableData = {};

  // --- Table definitions ---

  static const _tables = {
    'mock-crabs': _TableDef(
      id: 'mock-crabs',
      name: 'crabs-long.csv',
      kind: TableKind.tableSchema,
      nRows: 1000,
    ),
    'mock-variables': _TableDef(
      id: 'mock-variables',
      name: 'Variables',
      kind: TableKind.computedTableSchema,
      nRows: 47,
    ),
    'mock-dose': _TableDef(
      id: 'mock-dose',
      name: 'Dose-Response',
      kind: TableKind.cubeQueryTableSchema,
      nRows: 180,
    ),
    'mock-umap': _TableDef(
      id: 'mock-umap',
      name: 'UMAP+Clusters',
      kind: TableKind.computedTableSchema,
      nRows: 4000,
    ),
  };

  static final _schemas = {
    'mock-crabs': TableSchema(
      id: 'mock-crabs',
      name: 'crabs-long.csv',
      kind: TableKind.tableSchema,
      nRows: 1000,
      columns: const [
        TableColumnDef(name: 'sp', type: 'string'),
        TableColumnDef(name: 'sex', type: 'string'),
        TableColumnDef(name: 'index', type: 'double'),
        TableColumnDef(name: 'observation', type: 'double'),
        TableColumnDef(name: 'variable', type: 'string'),
        TableColumnDef(name: 'measurement', type: 'double'),
      ],
    ),
    'mock-variables': TableSchema(
      id: 'mock-variables',
      name: 'Variables',
      kind: TableKind.computedTableSchema,
      nRows: 47,
      columns: const [
        TableColumnDef(name: 'channel_name', type: 'string'),
        TableColumnDef(name: 'channel_description', type: 'string'),
        TableColumnDef(name: 'channel_id', type: 'double'),
      ],
    ),
    'mock-dose': TableSchema(
      id: 'mock-dose',
      name: 'Dose-Response',
      kind: TableKind.cubeQueryTableSchema,
      nRows: 180,
      columns: const [
        TableColumnDef(name: 'Dose', type: 'double'),
        TableColumnDef(name: 'Group', type: 'string'),
        TableColumnDef(name: 'Response', type: 'double'),
      ],
    ),
    'mock-umap': TableSchema(
      id: 'mock-umap',
      name: 'UMAP+Clusters',
      kind: TableKind.computedTableSchema,
      nRows: 4000,
      columns: const [
        TableColumnDef(name: 'umap.umap.1', type: 'double'),
        TableColumnDef(name: 'umap.umap.2', type: 'double'),
        TableColumnDef(name: 'clust.cluster_id', type: 'string'),
      ],
    ),
  };

  // --- Delay helpers ---

  Future<void> _delay(int minMs, int maxMs) async {
    final ms = minMs + _random.nextInt(maxMs - minMs + 1);
    await Future.delayed(Duration(milliseconds: ms));
  }

  // --- Data generation ---

  List<Map<String, dynamic>> _generateData(String tableId) {
    if (_tableData.containsKey(tableId)) return _tableData[tableId]!;

    final def = _tables[tableId];
    if (def == null) return [];

    final rows = <Map<String, dynamic>>[];

    switch (tableId) {
      case 'mock-crabs':
        final species = ['B', 'O'];
        final sexes = ['M', 'F'];
        final variables = ['FL', 'RW', 'CL', 'CW', 'BD'];
        for (int i = 0; i < def.nRows; i++) {
          rows.add({
            'sp': species[_random.nextInt(2)],
            'sex': sexes[_random.nextInt(2)],
            'index': (i ~/ 5 + 1).toDouble(),
            'observation': (i % 50 + 1).toDouble(),
            'variable': variables[i % 5],
            'measurement':
                double.parse((8.0 + _random.nextDouble() * 12.0).toStringAsFixed(2)),
          });
        }
        break;

      case 'mock-variables':
        final channelNames = [
          'FSC-A', 'FSC-H', 'FSC-W', 'SSC-A', 'SSC-H', 'SSC-W',
          'FITC-A', 'PE-A', 'PE-Cy5-A', 'PE-Cy7-A', 'APC-A', 'APC-Cy7-A',
          'Pacific Blue-A', 'BV421-A', 'BV510-A', 'BV605-A', 'BV650-A',
          'BV711-A', 'BV786-A', 'BB515-A', 'BB700-A', 'BB790-A',
          'AF488-A', 'AF647-A', 'AF700-A', 'PerCP-Cy5.5-A',
          'CD3', 'CD4', 'CD8', 'CD14', 'CD16', 'CD19', 'CD20',
          'CD25', 'CD27', 'CD28', 'CD38', 'CD45', 'CD45RA', 'CD45RO',
          'CD56', 'CD57', 'CD127', 'HLA-DR', 'IgD', 'TCRgd', 'Time',
        ];
        final descriptions = [
          'Forward Scatter Area', 'Forward Scatter Height', 'Forward Scatter Width',
          'Side Scatter Area', 'Side Scatter Height', 'Side Scatter Width',
          'FITC fluorescence', 'PE fluorescence', 'PE-Cy5 fluorescence',
          'PE-Cy7 fluorescence', 'APC fluorescence', 'APC-Cy7 fluorescence',
          'Pacific Blue fluorescence', 'BV421 fluorescence', 'BV510 fluorescence',
          'BV605 fluorescence', 'BV650 fluorescence', 'BV711 fluorescence',
          'BV786 fluorescence', 'BB515 fluorescence', 'BB700 fluorescence',
          'BB790 fluorescence', 'AF488 fluorescence', 'AF647 fluorescence',
          'AF700 fluorescence', 'PerCP-Cy5.5 fluorescence',
          'T cell marker', 'T helper marker', 'Cytotoxic T marker',
          'Monocyte marker', 'NK cell marker', 'B cell marker', 'B cell marker',
          'IL-2 receptor alpha', 'Memory marker', 'Co-stimulatory molecule',
          'Activation marker', 'Leukocyte common antigen', 'Naive T cell marker',
          'Memory T cell marker', 'NK cell marker', 'Terminal differentiation',
          'IL-7 receptor', 'MHC class II', 'Immunoglobulin D',
          'Gamma delta T cell receptor', 'Acquisition time',
        ];
        for (int i = 0; i < def.nRows; i++) {
          rows.add({
            'channel_name': channelNames[i],
            'channel_description': descriptions[i],
            'channel_id': (i + 1).toDouble(),
          });
        }
        break;

      case 'mock-dose':
        final groups = ['P999', 'P100'];
        final doses = [0.001, 0.01, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 25.0, 50.0,
          100.0, 250.0, 500.0, 1000.0, 2500.0, 5000.0, 10000.0, 50000.0];
        for (int i = 0; i < def.nRows; i++) {
          final group = groups[i % 2];
          final doseIdx = (i ~/ 2) % doses.length;
          final baseDose = doses[doseIdx];
          final baseResponse = group == 'P999'
              ? 100.0 / (1.0 + (10.0 / baseDose))
              : 80.0 / (1.0 + (50.0 / baseDose));
          rows.add({
            'Dose': baseDose,
            'Group': group,
            'Response': double.parse(
                (baseResponse + (_random.nextDouble() - 0.5) * 10).toStringAsFixed(2)),
          });
        }
        break;

      case 'mock-umap':
        final clusters = List.generate(13, (i) => 'c${i.toString().padLeft(2, '0')}');
        for (int i = 0; i < def.nRows; i++) {
          final cluster = clusters[i % 13];
          final clusterIdx = i % 13;
          // Generate cluster-specific coordinates
          final cx = -10.0 + (clusterIdx % 4) * 7.0;
          final cy = -8.0 + (clusterIdx ~/ 4) * 6.0;
          rows.add({
            'umap.umap.1': double.parse(
                (cx + (_random.nextDouble() - 0.5) * 4.0).toStringAsFixed(4)),
            'umap.umap.2': double.parse(
                (cy + (_random.nextDouble() - 0.5) * 4.0).toStringAsFixed(4)),
            'clust.cluster_id': cluster,
          });
        }
        break;
    }

    _tableData[tableId] = rows;
    return rows;
  }

  // --- DataService implementation ---

  @override
  Future<TableSchema> getSchema(String tableId) async {
    _loadCount++;
    // 10% random error chance on initial loads
    if (_loadCount <= 4 && _random.nextDouble() < 0.10) {
      _shouldFailInitialLoad = true;
    }

    // Initial load latency: 800-1200ms
    await _delay(800, 1200);

    if (_shouldFailInitialLoad) {
      _shouldFailInitialLoad = false;
      throw Exception('Mock error: Failed to fetch table schema for $tableId. '
          'Network timeout after 5000ms.');
    }

    final schema = _schemas[tableId];
    if (schema == null) {
      throw Exception('Table not found: $tableId');
    }
    return schema;
  }

  @override
  Future<RowDataPage> getRows(
    String tableId,
    int offset,
    int limit, {
    String? sortColumn,
    bool ascending = true,
  }) async {
    // Page fetch: 200-400ms, Sort: 500-800ms
    if (sortColumn != null) {
      await _delay(500, 800);
    } else {
      await _delay(200, 400);
    }

    final allRows = _generateData(tableId);
    if (allRows.isEmpty) {
      return RowDataPage(offset: offset, limit: limit, rows: const []);
    }

    var sorted = List<Map<String, dynamic>>.from(allRows);

    if (sortColumn != null) {
      sorted.sort((a, b) {
        final va = a[sortColumn];
        final vb = b[sortColumn];
        if (va == null && vb == null) return 0;
        if (va == null) return ascending ? -1 : 1;
        if (vb == null) return ascending ? 1 : -1;

        int cmp;
        if (va is num && vb is num) {
          cmp = va.compareTo(vb);
        } else {
          cmp = va.toString().compareTo(vb.toString());
        }
        return ascending ? cmp : -cmp;
      });
    }

    final start = offset.clamp(0, sorted.length);
    final end = (offset + limit).clamp(0, sorted.length);
    final page = sorted.sublist(start, end);

    return RowDataPage(offset: offset, limit: limit, rows: page);
  }

  @override
  Future<List<SearchMatch>> search(String tableId, String query) async {
    // Search: 400-600ms
    await _delay(400, 600);

    if (query.isEmpty) return [];

    final allRows = _generateData(tableId);
    final schema = _schemas[tableId];
    if (schema == null) return [];

    final matches = <SearchMatch>[];
    final lowerQuery = query.toLowerCase();

    for (int r = 0; r < allRows.length; r++) {
      for (final col in schema.columns) {
        final val = allRows[r][col.name];
        if (val != null && val.toString().toLowerCase().contains(lowerQuery)) {
          matches.add(SearchMatch(row: r, column: col.name));
        }
      }
    }

    return matches;
  }

  @override
  Future<String> saveAnnotations(
    String sourceTableId,
    String projectId,
    Map<String, Map<String, dynamic>> edits,
  ) async {
    // Annotation save: 600-1000ms
    await _delay(600, 1000);

    // Apply edits to the in-memory data
    final allRows = _generateData(sourceTableId);
    for (final entry in edits.entries) {
      final rowIdx = int.tryParse(entry.key);
      if (rowIdx != null && rowIdx >= 0 && rowIdx < allRows.length) {
        for (final colEntry in entry.value.entries) {
          allRows[rowIdx][colEntry.key] = colEntry.value;
        }
      }
    }

    return 'annotation-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<List<int>> exportCsv(String tableId) async {
    // CSV download: 1000-2000ms
    await _delay(1000, 2000);

    final allRows = _generateData(tableId);
    final schema = _schemas[tableId];
    if (schema == null) return [];

    final buffer = StringBuffer();
    // Header
    buffer.writeln(schema.columns.map((c) => c.name).join(','));
    // Rows
    for (final row in allRows) {
      buffer.writeln(schema.columns.map((c) {
        final val = row[c.name];
        if (val is String && val.contains(',')) return '"$val"';
        return val?.toString() ?? '';
      }).join(','));
    }

    return utf8.encode(buffer.toString());
  }
}

/// Internal helper for table definitions.
class _TableDef {
  final String id;
  final String name;
  final TableKind kind;
  final int nRows;

  const _TableDef({
    required this.id,
    required this.name,
    required this.kind,
    required this.nRows,
  });
}
