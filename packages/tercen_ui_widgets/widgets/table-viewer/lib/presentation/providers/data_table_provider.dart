import 'dart:async';

import 'package:flutter/material.dart';
import '../../di/service_locator.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/row_data.dart';
import '../../domain/models/search_match.dart';
import '../../domain/models/table_schema.dart';
import '../../domain/models/window_identity.dart';
import '../../domain/services/data_service.dart';
import '../../domain/services/data_table_channels.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/window_channels.dart';
import 'window_state_provider.dart';

/// State management provider for the Data Table window.
///
/// Extends WindowStateProvider to be compatible with the skeleton's
/// WindowBody which watches WindowStateProvider for content state.
class DataTableProvider extends WindowStateProvider {
  final DataService _dtDataService = serviceLocator<DataService>();
  final EventBus _dtEventBus = serviceLocator<EventBus>();

  // -- Content state (overrides parent) --
  ContentState _contentState = ContentState.loading;
  @override
  ContentState get contentState => _contentState;

  String? _errorMessage;
  @override
  String? get errorMessage => _errorMessage;

  // -- Table identity --
  String _tableId = 'mock-crabs';
  String get tableId => _tableId;

  String _tableName = 'crabs-long.csv';
  String get tableName => _tableName;

  TableKind _tableKind = TableKind.tableSchema;
  TableKind get tableKind => _tableKind;

  // -- Schema --
  TableSchema? _schema;
  TableSchema? get schema => _schema;

  // -- Row data --
  RowDataPage? _loadedRows;
  RowDataPage? get loadedRows => _loadedRows;

  int _totalRows = 0;
  int get totalRows => _totalRows;

  // -- Sorting --
  String? _sortColumn;
  String? get sortColumn => _sortColumn;

  bool _sortAscending = true;
  bool get sortAscending => _sortAscending;

  bool _isSorting = false;
  bool get isSorting => _isSorting;

  // Track sort clicks for third-click removal
  int _sortClickCount = 0;

  // -- Search --
  String _searchText = '';
  String get searchText => _searchText;

  List<SearchMatch> _searchMatches = [];
  List<SearchMatch> get searchMatches => _searchMatches;

  int _currentMatchIndex = -1;
  int get currentMatchIndex => _currentMatchIndex;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  Timer? _searchDebounce;

  // -- Annotation mode --
  bool _annotationMode = false;
  bool get annotationMode => _annotationMode;

  /// Edits keyed by "rowIndex" -> { columnName -> newValue }.
  final Map<String, Map<String, dynamic>> _annotationEdits = {};
  Map<String, Map<String, dynamic>> get annotationEdits =>
      Map.unmodifiable(_annotationEdits);

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  // -- Download --
  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  // -- Go-to-row --
  int? _goToRowValue;
  int? get goToRowValue => _goToRowValue;

  // -- Loading page --
  bool _isLoadingPage = false;
  bool get isLoadingPage => _isLoadingPage;

  // -- Subscriptions --
  StreamSubscription<EventPayload>? _tableUpdatedSubscription;

  // -- Page size --
  static const int pageSize = 100;

  // -- Confirmation callback (set by the UI for showing dialogs) --
  Future<bool> Function(BuildContext context, String message)?
      confirmationCallback;

  DataTableProvider({
    required WindowIdentity identity,
    required String windowId,
  }) : super(identity: identity, windowId: windowId) {
    // Subscribe to external table updates
    _tableUpdatedSubscription = _dtEventBus
        .subscribe(DataTableChannels.tableUpdated)
        .listen(_handleTableUpdated);

    // Auto-load default table
    loadTable(_tableId, _tableName, _tableKind);
  }

  // -- Command handling (parent handles focus/blur via super) --

  void _handleTableUpdated(EventPayload payload) {
    final updatedId = payload.data['tableId'] as String?;
    if (updatedId == _tableId) {
      loadTable(_tableId, _tableName, _tableKind);
    }
  }

  // -- Override loadData for WindowBody error retry --

  @override
  Future<void> loadData() async {
    await loadTable(_tableId, _tableName, _tableKind);
  }

  // -- Intent publishing --

  void _publishTableIntent(String channel, String type,
      [Map<String, dynamic> extra = const {}]) {
    _dtEventBus.publish(
      channel,
      EventPayload(
        type: type,
        sourceWidgetId: windowId,
        data: {'windowId': windowId, ...extra},
      ),
    );
  }

  // -- Table loading --

  Future<void> loadTable(
      String tableId, String tableName, TableKind tableKind) async {
    _tableId = tableId;
    _tableName = tableName;
    _tableKind = tableKind;
    _contentState = ContentState.loading;
    _errorMessage = null;
    _schema = null;
    _loadedRows = null;
    _sortColumn = null;
    _sortAscending = true;
    _sortClickCount = 0;
    _searchText = '';
    _searchMatches = [];
    _currentMatchIndex = -1;
    _annotationMode = false;
    _annotationEdits.clear();
    notifyListeners();

    try {
      _schema = await _dtDataService.getSchema(tableId);
      _totalRows = _schema!.nRows;

      // Fetch first page
      _loadedRows = await _dtDataService.getRows(tableId, 0, pageSize);

      if (_loadedRows!.rows.isEmpty) {
        _contentState = ContentState.empty;
      } else {
        _contentState = ContentState.active;
      }

      // Update identity label
      identity.label = tableName;

      // Publish events
      _publishTableIntent(
          DataTableChannels.tableSelection, 'tableSelected', {
        'tableId': tableId,
        'tableName': tableName,
      });
      _publishTableIntent(WindowChannels.windowIntent,
          WindowChannels.typeContentChanged, {
        'label': tableName,
      });
    } catch (e) {
      _errorMessage = e.toString();
      _contentState = ContentState.error;
    }
    notifyListeners();
  }

  // -- Pagination --

  Future<void> loadPage(int offset, int limit) async {
    if (_isLoadingPage) return;
    _isLoadingPage = true;
    notifyListeners();

    try {
      _loadedRows = await _dtDataService.getRows(
        _tableId,
        offset,
        limit,
        sortColumn: _sortColumn,
        ascending: _sortAscending,
      );
    } catch (e) {
      // Silently fail page loads — keep existing data
    }
    _isLoadingPage = false;
    notifyListeners();
  }

  // -- Sorting --

  Future<void> sort(String columnName) async {
    if (_isSorting) return;

    if (_sortColumn == columnName) {
      _sortClickCount++;
      if (_sortClickCount >= 3) {
        // Third click: remove sort
        _sortColumn = null;
        _sortAscending = true;
        _sortClickCount = 0;
      } else {
        // Second click: reverse direction
        _sortAscending = !_sortAscending;
      }
    } else {
      // New column: first click ascending
      _sortColumn = columnName;
      _sortAscending = true;
      _sortClickCount = 1;
    }

    _isSorting = true;
    notifyListeners();

    try {
      _loadedRows = await _dtDataService.getRows(
        _tableId,
        0,
        pageSize,
        sortColumn: _sortColumn,
        ascending: _sortAscending,
      );
    } catch (e) {
      // Keep existing data on sort failure
    }
    _isSorting = false;
    notifyListeners();
  }

  // -- Search --

  void search(String query) {
    _searchText = query;
    _searchMatches = [];
    _currentMatchIndex = -1;
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _isSearching = false;
      notifyListeners();
      return;
    }

    // Debounce search
    _searchDebounce?.cancel();
    _isSearching = true;
    notifyListeners();

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        _searchMatches = await _dtDataService.search(_tableId, query);
        if (_searchMatches.isNotEmpty) {
          _currentMatchIndex = 0;
        } else {
          _currentMatchIndex = -1;
        }
      } catch (e) {
        _searchMatches = [];
        _currentMatchIndex = -1;
      }
      _isSearching = false;
      notifyListeners();
    });
  }

  void nextMatch() {
    if (_searchMatches.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    _ensureMatchVisible();
    notifyListeners();
  }

  void previousMatch() {
    if (_searchMatches.isEmpty) return;
    _currentMatchIndex =
        (_currentMatchIndex - 1 + _searchMatches.length) %
            _searchMatches.length;
    _ensureMatchVisible();
    notifyListeners();
  }

  void _ensureMatchVisible() {
    if (_currentMatchIndex >= 0 &&
        _currentMatchIndex < _searchMatches.length) {
      final match = _searchMatches[_currentMatchIndex];
      _goToRowValue = match.row;
    }
  }

  // -- Annotation mode --

  /// Toggle annotation mode. If there are pending edits, requests confirmation
  /// via [confirmationCallback] before exiting.
  Future<void> toggleAnnotationMode([BuildContext? context]) async {
    if (_annotationMode && _annotationEdits.isNotEmpty) {
      // Require confirmation to discard edits
      if (context != null && confirmationCallback != null) {
        final confirmed = await confirmationCallback!(
          context,
          'Discard ${editCount} unsaved changes?',
        );
        if (!confirmed) return;
      } else {
        return; // No context for dialog — block toggle
      }
      _annotationEdits.clear();
    }
    _annotationMode = !_annotationMode;
    if (!_annotationMode) {
      _annotationEdits.clear();
    }
    notifyListeners();
  }

  void editCell(int row, String column, dynamic value) {
    final key = row.toString();
    _annotationEdits.putIfAbsent(key, () => {});
    _annotationEdits[key]![column] = value;
    notifyListeners();
  }

  Future<void> saveAnnotations() async {
    if (_annotationEdits.isEmpty || _isSaving) return;

    _isSaving = true;
    notifyListeners();

    try {
      final annotationId = await _dtDataService.saveAnnotations(
        _tableId,
        'mock-project-01',
        Map.from(_annotationEdits),
      );

      _annotationEdits.clear();
      _annotationMode = false;

      _publishTableIntent(
          DataTableChannels.annotationSaved, 'annotationSaved', {
        'tableId': _tableId,
        'annotationId': annotationId,
      });

      // Reload to show saved data
      await loadPage(0, pageSize);
    } catch (e) {
      _errorMessage = 'Failed to save annotations: $e';
    }
    _isSaving = false;
    notifyListeners();
  }

  /// Discard annotations. If [context] is provided and there are edits,
  /// shows a confirmation dialog first.
  Future<void> discardAnnotations([BuildContext? context]) async {
    if (_annotationEdits.isNotEmpty && context != null &&
        confirmationCallback != null) {
      final confirmed = await confirmationCallback!(
        context,
        'Discard ${editCount} unsaved changes?',
      );
      if (!confirmed) return;
    }
    _annotationEdits.clear();
    _annotationMode = false;
    notifyListeners();
  }

  // -- CSV Export --

  Future<void> exportCsv() async {
    if (_isDownloading) return;

    _isDownloading = true;
    notifyListeners();

    try {
      await _dtDataService.exportCsv(_tableId);
    } catch (e) {
      _errorMessage = 'Export failed: $e';
    }
    _isDownloading = false;
    notifyListeners();
  }

  // -- Go-to-row --

  void goToRow(int rowNumber) {
    if (rowNumber < 0 || rowNumber >= _totalRows) return;
    _goToRowValue = rowNumber;
    notifyListeners();

    // Clear the go-to highlight after a delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_goToRowValue == rowNumber) {
        _goToRowValue = null;
        notifyListeners();
      }
    });
  }

  void clearGoToRow() {
    _goToRowValue = null;
    notifyListeners();
  }

  // -- Mock: Simulate Refresh --

  Future<void> simulateRefresh() async {
    _dtEventBus.publish(
      DataTableChannels.tableUpdated,
      EventPayload(
        type: 'tableUpdated',
        sourceWidgetId: 'external',
        data: {'tableId': _tableId},
      ),
    );
  }

  /// Get the edited value for a cell, if any.
  dynamic getEditedValue(int row, String column) {
    final key = row.toString();
    return _annotationEdits[key]?[column];
  }

  /// Check if a cell has been edited.
  bool isCellEdited(int row, String column) {
    final key = row.toString();
    return _annotationEdits[key]?.containsKey(column) ?? false;
  }

  /// Total number of individual cell edits.
  int get editCount {
    int count = 0;
    for (final rowEdits in _annotationEdits.values) {
      count += rowEdits.length;
    }
    return count;
  }

  /// Check if a cell matches the current search.
  bool isCellSearchMatch(int row, String column) {
    return _searchMatches.any((m) => m.row == row && m.column == column);
  }

  /// Check if a cell is the focused (current) search match.
  bool isCellCurrentMatch(int row, String column) {
    if (_currentMatchIndex < 0 ||
        _currentMatchIndex >= _searchMatches.length) {
      return false;
    }
    final m = _searchMatches[_currentMatchIndex];
    return m.row == row && m.column == column;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tableUpdatedSubscription?.cancel();
    super.dispose();
  }
}
