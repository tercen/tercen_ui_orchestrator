/// Built-in widget archetypes for AI-assisted generation.
///
/// Each archetype defines a common widget pattern with:
/// - A structural template with token bindings
/// - Named slots the AI fills in (data source, display fields, events)
/// - Standard loading/error/ready conditionals
///
/// The [ArchetypeExpander] takes an archetype + slot values and produces
/// a complete widget definition (metadata + template JSON).
library;

/// All available archetypes.
const archetypes = <String, Archetype>{
  'data-list': dataListArchetype,
  'detail-view': detailViewArchetype,
  'dashboard-card': dashboardCardArchetype,
  'form': formArchetype,
  'master-detail': masterDetailArchetype,
};

/// Describes a reusable widget pattern.
class Archetype {
  final String name;
  final String description;

  /// Slots the AI must fill in.
  final Map<String, SlotDef> slots;

  const Archetype({
    required this.name,
    required this.description,
    required this.slots,
  });
}

/// A named slot in an archetype.
class SlotDef {
  final String type; // 'string', 'object', 'list', 'bool'
  final String description;
  final bool required;
  final dynamic defaultValue;

  const SlotDef({
    required this.type,
    required this.description,
    this.required = false,
    this.defaultValue,
  });
}

// ---------------------------------------------------------------------------
// Archetype definitions
// ---------------------------------------------------------------------------

/// Scrollable list of items from a data source with selection highlighting.
/// Used by: ProjectNavigator, HomePanel project list, activity list.
const dataListArchetype = Archetype(
  name: 'data-list',
  description:
      'Scrollable list of items fetched from a data source. '
      'Supports selection highlighting, tap/double-tap actions, '
      'and PromptRequired for missing config values.',
  slots: {
    // Data source
    'service': SlotDef(type: 'string', description: 'Tercen service name', required: true),
    'method': SlotDef(type: 'string', description: 'Service method name', required: true),
    'args': SlotDef(type: 'list', description: 'Method arguments array', required: true),
    'refreshOn': SlotDef(type: 'string', description: 'EventBus channel to trigger refetch'),

    // Display fields
    'primaryField': SlotDef(type: 'string', description: 'Field name for primary text (e.g., "name")', required: true),
    'secondaryField': SlotDef(type: 'string', description: 'Field name for secondary text (e.g., "description")'),
    'tertiaryField': SlotDef(type: 'string', description: 'Field name for tertiary text (e.g., "lastModifiedDate.value")'),
    'icon': SlotDef(type: 'string', description: 'Material icon name', defaultValue: 'description'),

    // Interaction
    'tapChannel': SlotDef(type: 'string', description: 'EventBus channel for onTap', required: true),
    'tapPayloadFields': SlotDef(type: 'list', description: 'Item fields to include in tap payload (e.g., ["id", "name", "kind"])'),
    'doubleTapIntent': SlotDef(type: 'string', description: 'Intent name for onDoubleTap (e.g., "openWorkflow")'),
    'doubleTapPropsMap': SlotDef(type: 'object', description: 'Maps intent param names to item fields'),

    // Config
    'promptFields': SlotDef(type: 'list', description: 'PromptRequired fields [{name, label, default}]'),
    'title': SlotDef(type: 'string', description: 'Toolbar title text', defaultValue: 'Items'),
    'emptyText': SlotDef(type: 'string', description: 'Text when list is empty', defaultValue: 'No items'),
  },
);

/// Single-object detail view with labeled fields.
/// Used by: DocumentViewer, potential profile views.
const detailViewArchetype = Archetype(
  name: 'detail-view',
  description:
      'Displays a single object with labeled field rows. '
      'Fetches one object by ID via DataSource.',
  slots: {
    'service': SlotDef(type: 'string', description: 'Tercen service name', required: true),
    'method': SlotDef(type: 'string', description: 'Service method (usually "get")', required: true, defaultValue: 'get'),
    'args': SlotDef(type: 'list', description: 'Method arguments', required: true),
    'fields': SlotDef(
      type: 'list',
      description: 'Fields to display as [{field, label, textStyle?}]',
      required: true,
    ),
    'promptFields': SlotDef(type: 'list', description: 'PromptRequired fields'),
    'title': SlotDef(type: 'string', description: 'Header title', defaultValue: 'Details'),
  },
);

/// Dashboard summary card with a data count + list preview.
/// Used by: HomePanel project/apps/activity cards.
const dashboardCardArchetype = Archetype(
  name: 'dashboard-card',
  description:
      'A DashboardCard showing a summary count and a short list preview. '
      'Used in home panels and dashboards.',
  slots: {
    'service': SlotDef(type: 'string', description: 'Tercen service name', required: true),
    'method': SlotDef(type: 'string', description: 'Service method', required: true),
    'args': SlotDef(type: 'list', description: 'Method arguments', required: true),
    'cardTitle': SlotDef(type: 'string', description: 'Card header title', required: true),
    'cardIcon': SlotDef(type: 'string', description: 'Card header icon', required: true),
    'primaryField': SlotDef(type: 'string', description: 'Field for item name', required: true),
    'secondaryField': SlotDef(type: 'string', description: 'Field for item subtitle'),
    'tapChannel': SlotDef(type: 'string', description: 'Tap event channel'),
    'tapPayloadFields': SlotDef(type: 'list', description: 'Payload fields'),
    'maxItems': SlotDef(type: 'string', description: 'Max items to show', defaultValue: '5'),
  },
);

/// Form with input fields and a submit action.
const formArchetype = Archetype(
  name: 'form',
  description:
      'A form with labeled input fields and a submit button. '
      'Uses StateHolder to track field values, submits via Action.',
  slots: {
    'formFields': SlotDef(
      type: 'list',
      description: 'Fields as [{name, label, type?, default?}]',
      required: true,
    ),
    'submitChannel': SlotDef(type: 'string', description: 'EventBus channel for form submission', required: true),
    'submitLabel': SlotDef(type: 'string', description: 'Submit button text', defaultValue: 'Submit'),
    'title': SlotDef(type: 'string', description: 'Form title'),
  },
);

/// Two linked data sources — selection in one drives the other.
/// Used by: WorkflowViewer + DataTableViewer, ProjectNavigator + DocumentViewer.
const masterDetailArchetype = Archetype(
  name: 'master-detail',
  description:
      'Two-panel layout where selecting an item in the master list '
      'updates the detail panel via refreshOn.',
  slots: {
    // Master
    'masterService': SlotDef(type: 'string', description: 'Master data service', required: true),
    'masterMethod': SlotDef(type: 'string', description: 'Master data method', required: true),
    'masterArgs': SlotDef(type: 'list', description: 'Master method args', required: true),
    'masterPrimaryField': SlotDef(type: 'string', description: 'Master item name field', required: true),
    'masterIcon': SlotDef(type: 'string', description: 'Master item icon', defaultValue: 'description'),
    'selectionChannel': SlotDef(type: 'string', description: 'Channel linking master → detail', required: true),
    'selectionIdField': SlotDef(type: 'string', description: 'Item field used as selection ID', required: true),

    // Detail
    'detailService': SlotDef(type: 'string', description: 'Detail data service', required: true),
    'detailMethod': SlotDef(type: 'string', description: 'Detail data method', required: true),
    'detailFields': SlotDef(type: 'list', description: 'Detail fields [{field, label}]', required: true),

    // Config
    'promptFields': SlotDef(type: 'list', description: 'PromptRequired fields'),
    'title': SlotDef(type: 'string', description: 'Widget title', defaultValue: 'Browser'),
  },
);
