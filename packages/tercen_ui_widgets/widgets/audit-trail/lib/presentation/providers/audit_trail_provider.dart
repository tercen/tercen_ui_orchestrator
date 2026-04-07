import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../di/service_locator.dart';
import '../../domain/models/audit_event.dart';
import '../../domain/models/audit_scope.dart';
import '../../domain/models/content_state.dart';
import '../../domain/models/window_identity.dart';
import '../../domain/services/audit_data_service.dart';
import '../../domain/services/event_bus.dart';
import '../../domain/services/event_payload.dart';
import '../../domain/services/window_channels.dart';

/// Definition of a table column with its key, label, and default visibility.
class ColumnDef {
  final String key;
  final String label;
  final bool defaultVisible;
  /// Default pixel width for the column.
  final double defaultWidth;
  /// Whether this column holds date values (uses date-range filter).
  final bool isDate;

  const ColumnDef({
    required this.key,
    required this.label,
    this.defaultVisible = false,
    this.defaultWidth = 120,
    this.isDate = false,
  });
}

/// Central state provider for the Audit Trail window.
///
/// Manages: scope, events, selection, filters, search, sort, pagination.
class AuditTrailProvider extends ChangeNotifier {
  final AuditDataService _dataService = serviceLocator<AuditDataService>();
  final EventBus _eventBus = serviceLocator<EventBus>();

  final WindowIdentity identity;
  final String windowId;

  // -- Column definitions (order = display order) --
  static const List<ColumnDef> allColumns = [
    ColumnDef(key: 'date', label: 'Date', defaultVisible: true, defaultWidth: 130, isDate: true),
    ColumnDef(key: 'type', label: 'Type', defaultVisible: true, defaultWidth: 84),
    ColumnDef(key: 'user', label: 'User', defaultVisible: true, defaultWidth: 110),
    ColumnDef(key: 'action', label: 'Action', defaultVisible: true, defaultWidth: 160),
    ColumnDef(key: 'target', label: 'Target', defaultVisible: true, defaultWidth: 140),
    ColumnDef(key: 'team', label: 'Team', defaultVisible: true, defaultWidth: 110),
    ColumnDef(key: 'project', label: 'Project', defaultVisible: true, defaultWidth: 140),
    ColumnDef(key: 'objectKind', label: 'Object Kind', defaultWidth: 100),
    ColumnDef(key: 'targetId', label: 'Target ID', defaultWidth: 180),
    ColumnDef(key: 'source', label: 'Source', defaultWidth: 70),
    ColumnDef(key: 'public', label: 'Public', defaultWidth: 60),
    ColumnDef(key: 'createdDate', label: 'Created', defaultWidth: 130, isDate: true),
    ColumnDef(key: 'runDate', label: 'Run Date', defaultWidth: 130, isDate: true),
    ColumnDef(key: 'duration', label: 'Duration', defaultWidth: 80),
    ColumnDef(key: 'state', label: 'State', defaultWidth: 90),
    ColumnDef(key: 'error', label: 'Error', defaultWidth: 200),
    ColumnDef(key: 'recordId', label: 'Record ID', defaultWidth: 180),
  ];

  // -- Content state --
  ContentState _contentState = ContentState.loading;
  ContentState get contentState => _contentState;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // -- Scopes --
  List<AuditScope> _availableScopes = [];
  List<AuditScope> get availableScopes => _availableScopes;
  AuditScope? _currentScope;
  AuditScope? get currentScope => _currentScope;

  // -- Events --
  List<AuditEvent> _allEvents = [];
  List<AuditEvent> get filteredEvents => _applyFilters();
  bool _hasMore = false;
  bool get hasMore => _hasMore;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  // -- Selection --
  AuditEvent? _selectedEvent;
  AuditEvent? get selectedEvent => _selectedEvent;
  final Set<String> _multiSelectedIds = {};
  Set<String> get multiSelectedIds => Set.unmodifiable(_multiSelectedIds);
  int get multiSelectedCount => _multiSelectedIds.length;
  String? _lastClickedId; // for shift+click range selection

  // -- Column visibility & widths --
  late final Set<String> _visibleColumns = {
    for (final c in allColumns)
      if (c.defaultVisible) c.key,
  };
  Set<String> get visibleColumns => Set.unmodifiable(_visibleColumns);
  List<ColumnDef> get visibleColumnDefs =>
      allColumns.where((c) => _visibleColumns.contains(c.key)).toList();

  /// Current pixel widths per column key (resizable by dragging).
  late final Map<String, double> _columnWidths = {
    for (final c in allColumns) c.key: c.defaultWidth,
  };
  Map<String, double> get columnWidths => Map.unmodifiable(_columnWidths);

  double getColumnWidth(String key) => _columnWidths[key] ?? 100;

  void setColumnWidth(String key, double width) {
    _columnWidths[key] = width.clamp(40, 600);
    notifyListeners();
  }

  /// Measure max content width per column and auto-fit widths.
  void _autoFitColumnWidths() {
    const textStyle = TextStyle(
      fontFamily: 'Fira Sans',
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    const headerStyle = TextStyle(
      fontFamily: 'Fira Sans',
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    const padding = 28.0; // cell padding + filter icon + resize handle

    for (final col in allColumns) {
      // Measure header label
      double maxW = _measureText(col.label, headerStyle) + padding;

      // Measure all event values (sample up to 100 for performance)
      final events = _allEvents.length > 100
          ? _allEvents.sublist(0, 100)
          : _allEvents;
      for (final e in events) {
        final value = _getColumnValue(e, col.key);
        if (value.isNotEmpty) {
          final w = _measureText(value, textStyle) + padding;
          if (w > maxW) maxW = w;
        }
      }

      _columnWidths[col.key] = maxW.clamp(50, 400);
    }
  }

  double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  // -- Date range filters --
  final Map<String, DateTimeRange> _dateRangeFilters = {};
  Map<String, DateTimeRange> get dateRangeFilters =>
      Map.unmodifiable(_dateRangeFilters);

  void setDateRangeFilter(String column, DateTimeRange range) {
    _dateRangeFilters[column] = range;
    notifyListeners();
  }

  void clearDateRangeFilter(String column) {
    _dateRangeFilters.remove(column);
    notifyListeners();
  }

  bool isDateRangeFilterActive(String column) =>
      _dateRangeFilters.containsKey(column);

  // -- Filters --
  final Set<String> _enabledTypes = {
    'create', 'update', 'delete', 'run', 'complete', 'fail', 'cancel',
  };
  Set<String> get enabledTypes => Set.unmodifiable(_enabledTypes);
  static const Set<String> allEventTypes = {
    'create', 'update', 'delete', 'run', 'complete', 'fail', 'cancel',
  };

  // Column header filters: column name -> set of checked values
  final Map<String, Set<String>> _columnFilters = {};
  Map<String, Set<String>> get columnFilters =>
      Map.unmodifiable(_columnFilters);

  // -- Search --
  String _searchText = '';
  String get searchText => _searchText;

  // -- Sort --
  bool _newestFirst = true;
  bool get newestFirst => _newestFirst;

  StreamSubscription<EventPayload>? _commandSubscription;

  AuditTrailProvider({
    required this.identity,
    required this.windowId,
  }) {
    _commandSubscription = _eventBus
        .subscribe(WindowChannels.commandChannel(windowId))
        .listen(_handleCommand);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _availableScopes = await _dataService.getAvailableScopes();
      if (_availableScopes.isNotEmpty) {
        _currentScope = _availableScopes.first; // Default: Project scope
        await _loadEvents();
      } else {
        _contentState = ContentState.empty;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _contentState = ContentState.error;
      notifyListeners();
    }
  }

  void _handleCommand(EventPayload payload) {
    switch (payload.type) {
      // Set scope: { scopeType: "project"|"team"|"user", scopeId: "..." }
      case 'openAuditTrail':
        final scopeType = payload.data['scopeType'] as String?;
        final scopeId = payload.data['scopeId'] as String?;
        if (scopeType != null && scopeId != null) {
          final scope = _availableScopes.firstWhere(
            (s) => s.scopeType.name == scopeType && s.scopeId == scopeId,
            orElse: () => _availableScopes.first,
          );
          setScope(scope);
        }
        break;

      // Column filter: { column: "project", values: ["Name1", "Name2"] }
      case 'setAuditFilter':
        final column = payload.data['column'] as String?;
        final values = payload.data['values'] as List<dynamic>?;
        if (column != null && values != null) {
          setColumnFilter(column, values.cast<String>().toSet());
        }
        break;

      // Clear column filter: { column: "project" }
      case 'clearAuditFilter':
        final column = payload.data['column'] as String?;
        if (column != null) {
          clearColumnFilter(column);
        }
        break;

      // Date range: { column: "date", from: "2026-03-01T00:00:00Z", to: "2026-03-15T23:59:59Z" }
      case 'setAuditDateRange':
        final column = payload.data['column'] as String?;
        final fromStr = payload.data['from'] as String?;
        final toStr = payload.data['to'] as String?;
        if (column != null && fromStr != null && toStr != null) {
          final from = DateTime.tryParse(fromStr);
          final to = DateTime.tryParse(toStr);
          if (from != null && to != null) {
            setDateRangeFilter(column, DateTimeRange(start: from, end: to));
          }
        }
        break;

      // Clear date range: { column: "date" }
      case 'clearAuditDateRange':
        final column = payload.data['column'] as String?;
        if (column != null) {
          clearDateRangeFilter(column);
        }
        break;

      // Column visibility: { visible: ["date", "type", "user", "action"] }
      case 'setAuditColumns':
        final visible = payload.data['visible'] as List<dynamic>?;
        if (visible != null) {
          final desired = visible.cast<String>().toSet();
          for (final col in allColumns) {
            final isVisible = _visibleColumns.contains(col.key);
            final shouldBeVisible = desired.contains(col.key);
            if (isVisible != shouldBeVisible) {
              toggleColumnVisibility(col.key);
            }
          }
        }
        break;

      // Search text: { query: "some text" }
      case 'setAuditSearch':
        final query = payload.data['query'] as String?;
        if (query != null) {
          setSearchText(query);
        }
        break;

      // Sort: { newestFirst: true|false }
      case 'setAuditSort':
        final newest = payload.data['newestFirst'] as bool?;
        if (newest != null && newest != _newestFirst) {
          toggleSort();
        }
        break;
    }
  }

  // -- Scope --

  Future<void> setScope(AuditScope scope) async {
    _currentScope = scope;
    _resetFilters();
    await _loadEvents();
  }

  void _resetFilters() {
    _enabledTypes.clear();
    _enabledTypes.addAll(allEventTypes);
    _columnFilters.clear();
    _dateRangeFilters.clear();
    _searchText = '';
    _selectedEvent = null;
    _multiSelectedIds.clear();
    _lastClickedId = null;
  }

  // -- Data loading --

  Future<void> _loadEvents() async {
    if (_currentScope == null) return;

    _contentState = ContentState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _dataService.fetchEvents(
        scope: _currentScope!,
        offset: 0,
      );
      _allEvents = result.events;
      _hasMore = result.hasMore;

      if (_allEvents.isEmpty) {
        _contentState = ContentState.empty;
      } else {
        _contentState = ContentState.active;
        _autoFitColumnWidths();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _contentState = ContentState.error;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _currentScope == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _dataService.fetchEvents(
        scope: _currentScope!,
        offset: _allEvents.length,
      );
      _allEvents.addAll(result.events);
      _hasMore = result.hasMore;
    } catch (e) {
      debugPrint('Error loading more events: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> retry() async {
    await _loadEvents();
  }

  // -- Filtering pipeline --

  List<AuditEvent> _applyFilters() {
    var events = List<AuditEvent>.from(_allEvents);

    // 1. Type filter
    events = events.where((e) => _enabledTypes.contains(e.eventType)).toList();

    // 2. Column header filters
    for (final entry in _columnFilters.entries) {
      final column = entry.key;
      final allowedValues = entry.value;
      if (allowedValues.isEmpty) continue;

      events = events.where((e) {
        final value = _getColumnValue(e, column);
        return allowedValues.contains(value);
      }).toList();
    }

    // 3. Date range filters
    for (final entry in _dateRangeFilters.entries) {
      final column = entry.key;
      final range = entry.value;
      events = events.where((e) {
        final dateStr = _getColumnValue(e, column);
        if (dateStr.isEmpty) return false;
        final date = DateTime.tryParse(dateStr);
        if (date == null) return false;
        return !date.isBefore(range.start) &&
            date.isBefore(range.end.add(const Duration(days: 1)));
      }).toList();
    }

    // 4. Text search
    if (_searchText.isNotEmpty) {
      events = events.where((e) => e.matchesSearch(_searchText)).toList();
    }

    // 4. Sort
    if (_newestFirst) {
      events.sort((a, b) => b.displayDate.compareTo(a.displayDate));
    } else {
      events.sort((a, b) => a.displayDate.compareTo(b.displayDate));
    }

    return events;
  }

  String _getColumnValue(AuditEvent event, String column) {
    switch (column) {
      case 'date':
        return event.displayDate.toIso8601String();
      case 'type':
        return event.eventType;
      case 'user':
        return event.userId;
      case 'action':
        return event.actionSummary;
      case 'target':
        return event.targetName;
      case 'team':
        return event.teamId;
      case 'project':
        return event.projectName;
      case 'objectKind':
        return event.objectKind;
      case 'targetId':
        return event.targetId;
      case 'source':
        return event.source.name;
      case 'public':
        return event.isPublic ? 'Yes' : 'No';
      case 'createdDate':
        return event.details['createdDate'] ?? '';
      case 'runDate':
        return event.details['runDate'] ?? '';
      case 'duration':
        return event.details['duration'] ?? '';
      case 'state':
        return event.details['state'] ?? '';
      case 'error':
        return event.details['error'] ?? '';
      case 'recordId':
        return event.id;
      default:
        return '';
    }
  }

  /// Get unique values for a column from currently visible events
  /// (after other filters are applied, but excluding this column's filter).
  Set<String> getColumnValues(String column) {
    var events = List<AuditEvent>.from(_allEvents);

    // Apply type filter
    events = events.where((e) => _enabledTypes.contains(e.eventType)).toList();

    // Apply other column filters (not the requested column)
    for (final entry in _columnFilters.entries) {
      if (entry.key == column) continue;
      final allowedValues = entry.value;
      if (allowedValues.isEmpty) continue;
      events = events.where((e) {
        return allowedValues.contains(_getColumnValue(e, entry.key));
      }).toList();
    }

    // Apply search
    if (_searchText.isNotEmpty) {
      events = events.where((e) => e.matchesSearch(_searchText)).toList();
    }

    return events.map((e) => _getColumnValue(e, column)).toSet();
  }

  bool isColumnFilterActive(String column) {
    if (!_columnFilters.containsKey(column)) return false;
    final all = getColumnValues(column);
    return _columnFilters[column]!.length < all.length;
  }

  void setColumnFilter(String column, Set<String> values) {
    _columnFilters[column] = values;
    notifyListeners();
  }

  void clearColumnFilter(String column) {
    _columnFilters.remove(column);
    notifyListeners();
  }

  // -- Type filter --

  void toggleEventType(String type) {
    if (_enabledTypes.contains(type)) {
      _enabledTypes.remove(type);
    } else {
      _enabledTypes.add(type);
    }
    notifyListeners();
  }

  void setAllEventTypes(bool enabled) {
    if (enabled) {
      _enabledTypes.addAll(allEventTypes);
    } else {
      _enabledTypes.clear();
    }
    notifyListeners();
  }

  // -- Column visibility --

  /// Public accessor for column display values (used by EventList rows).
  String getColumnDisplayValue(AuditEvent event, String column) =>
      _getColumnValue(event, column);

  bool isColumnVisible(String key) => _visibleColumns.contains(key);

  void toggleColumnVisibility(String key) {
    if (_visibleColumns.contains(key)) {
      _visibleColumns.remove(key);
    } else {
      _visibleColumns.add(key);
    }
    notifyListeners();
  }

  // -- Search --

  void setSearchText(String text) {
    _searchText = text;
    notifyListeners();
  }

  // -- Sort --

  void toggleSort() {
    _newestFirst = !_newestFirst;
    notifyListeners();
  }

  // -- Selection --

  void selectEvent(AuditEvent event) {
    _selectedEvent = event;
    _lastClickedId = event.id;
    notifyListeners();
    _publishFocusChanged(event);
  }

  void toggleMultiSelect(AuditEvent event) {
    if (_multiSelectedIds.contains(event.id)) {
      _multiSelectedIds.remove(event.id);
    } else {
      _multiSelectedIds.add(event.id);
    }
    _lastClickedId = event.id;
    notifyListeners();
  }

  void shiftSelect(AuditEvent event) {
    final events = filteredEvents;
    final clickedIndex = events.indexWhere((e) => e.id == event.id);
    final lastIndex = _lastClickedId != null
        ? events.indexWhere((e) => e.id == _lastClickedId)
        : -1;

    if (lastIndex == -1 || clickedIndex == -1) {
      toggleMultiSelect(event);
      return;
    }

    final start = lastIndex < clickedIndex ? lastIndex : clickedIndex;
    final end = lastIndex < clickedIndex ? clickedIndex : lastIndex;

    for (var i = start; i <= end; i++) {
      _multiSelectedIds.add(events[i].id);
    }
    notifyListeners();
  }

  void selectAll() {
    final events = filteredEvents;
    _multiSelectedIds.clear();
    for (final e in events) {
      _multiSelectedIds.add(e.id);
    }
    notifyListeners();
  }

  void clearMultiSelection() {
    _multiSelectedIds.clear();
    notifyListeners();
  }

  bool isMultiSelected(String eventId) => _multiSelectedIds.contains(eventId);

  /// Move selection up/down in the filtered list.
  void moveSelection(int delta) {
    final events = filteredEvents;
    if (events.isEmpty) return;

    if (_selectedEvent == null) {
      selectEvent(events.first);
      return;
    }

    final currentIndex =
        events.indexWhere((e) => e.id == _selectedEvent!.id);
    if (currentIndex == -1) {
      selectEvent(events.first);
      return;
    }

    final newIndex = (currentIndex + delta).clamp(0, events.length - 1);
    selectEvent(events[newIndex]);
  }

  // -- Navigation --

  void navigateToTarget(AuditEvent event) {
    final String eventType;
    final Map<String, dynamic> data;

    switch (event.objectKind) {
      case 'Project':
        eventType = 'openProject';
        data = {'projectId': event.targetId};
        break;
      case 'Workflow':
        eventType = 'openWorkflow';
        data = {
          'workflowId': event.targetId,
          'projectId': event.projectId,
        };
        break;
      case 'Task':
        eventType = 'navigateToStep';
        data = {
          'stepId': event.targetId,
          'workflowId': event.details['workflowId'] ?? '',
        };
        break;
      default:
        eventType = 'openDocument';
        data = {
          'documentId': event.targetId,
          'documentKind': event.objectKind,
          'projectId': event.projectId,
        };
        break;
    }

    // Mock: log to console
    debugPrint('[EventBus] $eventType: $data');
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: eventType,
        sourceWidgetId: windowId,
        data: {'windowId': windowId, ...data},
      ),
    );
  }

  // -- Send to Chat --

  void sendToChat() {
    if (_multiSelectedIds.isEmpty) return;

    final selectedEvents = _allEvents
        .where((e) => _multiSelectedIds.contains(e.id))
        .toList();

    debugPrint(
        '[EventBus] sendAuditContext: ${selectedEvents.length} events');

    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: 'sendAuditContext',
        sourceWidgetId: windowId,
        data: {
          'windowId': windowId,
          'events': selectedEvents.map((e) => e.toMap()).toList(),
          'scope': _currentScope?.toMap(),
          'timestamp': DateTime.now().toIso8601String(),
          'totalFilteredCount': filteredEvents.length,
        },
      ),
    );
  }

  // -- CSV Export --

  String exportCsv() {
    // If rows are checkbox-selected, export only those; otherwise all filtered.
    final allFiltered = filteredEvents;
    final events = _multiSelectedIds.isNotEmpty
        ? allFiltered.where((e) => _multiSelectedIds.contains(e.id)).toList()
        : allFiltered;
    final cols = visibleColumnDefs;
    final buffer = StringBuffer();

    // Header — only visible columns
    buffer.writeln(cols.map((c) => '"${c.label}"').join(','));

    // Rows — only visible columns
    for (final e in events) {
      final row = cols.map((c) {
        final v = _getColumnValue(e, c.key);
        return '"${v.replaceAll('"', '""')}"';
      }).join(',');
      buffer.writeln(row);
    }

    final csv = buffer.toString();
    debugPrint('[Export] CSV generated: ${events.length} rows, ${cols.length} columns');
    return csv;
  }

  String get exportFilename {
    final scope = _currentScope;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    if (scope == null) return 'audit-trail-$date.csv';
    return 'audit-trail-${scope.scopeType.name}-${scope.scopeId}-$date.csv';
  }

  // -- EventBus helpers --

  void _publishFocusChanged(AuditEvent event) {
    debugPrint(
        '[EventBus] focusChanged: scope=${_currentScope?.scopeLabel}, '
        'event=${event.id}');
    _eventBus.publish(
      WindowChannels.windowIntent,
      EventPayload(
        type: 'focusChanged',
        sourceWidgetId: windowId,
        data: {
          'windowId': windowId,
          'scope': _currentScope?.scopeLabel ?? '',
          'selectedEventId': event.id,
        },
      ),
    );
  }

  // -- Keyboard handling --

  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      moveSelection(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedEvent != null) {
        navigateToTarget(_selectedEvent!);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchText.isNotEmpty) {
        setSearchText('');
      } else {
        clearMultiSelection();
      }
      return KeyEventResult.handled;
    }
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyA) {
      selectAll();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _commandSubscription?.cancel();
    super.dispose();
  }
}
