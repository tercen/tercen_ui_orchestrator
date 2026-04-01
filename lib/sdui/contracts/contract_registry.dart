import 'package:sdui/sdui.dart';

export 'package:sdui/src/contracts/contract_registry.dart';

/// The built-in contract definitions for the Tercen SDUI system.
ContractRegistry createDefaultRegistry() {
  final registry = ContractRegistry();

  registry.register(const EventContract(
    name: 'selection',
    description: 'User selected an entity (project, workflow, file, step, team member, etc.)',
    fields: {
      'id': ContractField(type: 'string', required: true, description: 'Entity ID'),
      'name': ContractField(type: 'string', description: 'Entity display name'),
      'kind': ContractField(type: 'string', description: 'Entity type/kind (e.g., Workflow, FileDocument)'),
      'parentId': ContractField(type: 'string', description: 'Parent entity ID (e.g., projectId)'),
    },
  ));

  registry.register(const EventContract(
    name: 'navigation',
    description: 'Request to open/navigate to a resource in a new or existing window',
    fields: {
      'resourceId': ContractField(type: 'string', required: true, description: 'Resource to open'),
      'resourceType': ContractField(type: 'string', description: 'Type of resource (maps to widget type or intent)'),
      'resourceName': ContractField(type: 'string', description: 'Display name for window title'),
      'parentId': ContractField(type: 'string', description: 'Parent context (e.g., projectId for a workflow)'),
    },
  ));

  registry.register(const EventContract(
    name: 'dataChanged',
    description: 'Underlying data was created, updated, or deleted — consumers should refresh',
    fields: {
      'entityId': ContractField(type: 'string', description: 'ID of changed entity'),
      'entityKind': ContractField(type: 'string', description: 'Type of changed entity'),
      'action': ContractField(type: 'string', required: true, description: 'What happened',
          enumValues: ['created', 'updated', 'deleted']),
    },
  ));

  registry.register(const EventContract(
    name: 'command',
    description: 'A user action/command (toggle theme, save layout, sign out, etc.)',
    fields: {
      'action': ContractField(type: 'string', required: true, description: 'Command name'),
      'value': ContractField(type: 'string', description: 'Optional command value'),
    },
  ));

  registry.register(const EventContract(
    name: 'notification',
    description: 'User-facing notification message',
    fields: {
      'severity': ContractField(type: 'string', required: true, description: 'Level',
          enumValues: ['info', 'success', 'warning', 'error']),
      'message': ContractField(type: 'string', required: true, description: 'Message text'),
    },
  ));

  registry.register(const EventContract(
    name: 'taskStatus',
    description: 'A background task changed state',
    fields: {
      'taskId': ContractField(type: 'string', required: true, description: 'Task ID'),
      'state': ContractField(type: 'string', required: true, description: 'New state',
          enumValues: ['running', 'done', 'failed', 'cancelled']),
      'progress': ContractField(type: 'number', description: '0.0-1.0 progress'),
    },
  ));

  registry.register(const EventContract(
    name: 'formSubmit',
    description: 'A form was submitted with field values',
    fields: {
      'formId': ContractField(type: 'string', description: 'Form identifier'),
      'values': ContractField(type: 'object', required: true, description: 'Field name->value map'),
    },
  ));

  registry.register(const EventContract(
    name: 'stateChange',
    description: 'Local widget state mutation',
    fields: {
      'op': ContractField(type: 'string', required: true, description: 'Mutation operation',
          enumValues: ['merge', 'increment', 'decrement', 'toggle', 'reset']),
      'key': ContractField(type: 'string', description: 'State key to mutate'),
      'values': ContractField(type: 'object', description: 'Values to merge'),
      'amount': ContractField(type: 'number', description: 'Amount for increment/decrement'),
    },
  ));

  return registry;
}
