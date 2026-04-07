/// Channel names for data-table-specific EventBus communication.
///
/// These extend the base WindowChannels with data table events.
class DataTableChannels {
  DataTableChannels._();

  // -- Outbound (data table -> frame) --

  /// Table selection: user opened/loaded a table.
  static const String tableSelection = 'system.selection.table';

  /// Annotation saved: edits were committed to a new annotation table.
  static const String annotationSaved = 'system.data.annotationSaved';

  // -- Inbound (frame -> data table) --

  /// Table updated: external process modified the table data.
  static const String tableUpdated = 'system.data.tableUpdated';
}
