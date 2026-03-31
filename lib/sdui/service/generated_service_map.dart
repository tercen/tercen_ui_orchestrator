// GENERATED — do not edit manually.
// Run: dart ../sci/sci_api/bin/generate_openapi.dart
// Then: flutter test test/sdui/validator/generate_schema_test.dart
//
// Generated from tercen-api.openapi.json

/// Maps service name strings to ServiceFactory accessor names.
/// Used by ServiceCallDispatcher._getService().
const serviceNames = <String>{
  'activityService',
  'cranLibraryService',
  'documentService',
  'eventService',
  'fileService',
  'folderService',
  'garbageCollectorService',
  'lockService',
  'operatorService',
  'patchRecordService',
  'persistentService',
  'projectDocumentService',
  'projectService',
  'queryService',
  'subscriptionPlanService',
  'tableSchemaService',
  'taskService',
  'teamService',
  'userSecretService',
  'userService',
  'workerService',
  'workflowService',
};

/// Maps find* method names to their CouchDB view type.
/// 'startKeys' = range query, 'keys' = key lookup.
const viewTypes = <String, String>{
  'findByOwnerNameVersion': 'startKeys',
  'findGarbageTasks2ByDate': 'startKeys',
  'findFileByWorkflowIdAndStepId': 'startKeys',
  'findByDataUri': 'startKeys',
  'findByOwner': 'keys',
  'findSubscriptionPlanByCheckoutSessionId': 'keys',
  'findDeleted': 'keys',
  'findByKind': 'keys',
  'findByUserAndDate': 'startKeys',
  'findByTeamAndDate': 'startKeys',
  'findByProjectAndDate': 'startKeys',
  'findFolderByParentFolderAndName': 'startKeys',
  'findSchemaByDataDirectory': 'startKeys',
  'findByHash': 'startKeys',
  'findGCTaskByLastModifiedDate': 'startKeys',
  'findSecretByUserId': 'keys',
  'findByChannelIdAndSequence': 'startKeys',
  'findByChannelAndDate': 'startKeys',
  'findTeamMembers': 'keys',
  'findUserByCreatedDateAndName': 'startKeys',
  'findUserByEmail': 'keys',
  'findByOwnerAndKindAndDate': 'keys',
  'findByOwnerAndProjectAndKindAndDate': 'startKeys',
  'findByOwnerAndKind': 'keys',
  'findPublicByKind': 'keys',
  'findByProjectAndKindAndDate': 'startKeys',
  'findProjectObjectsByLastModifiedDate': 'startKeys',
  'findProjectObjectsByFolderAndName': 'startKeys',
  'findFileByLastModifiedDate': 'startKeys',
  'findSchemaByLastModifiedDate': 'startKeys',
  'findSchemaByOwnerAndLastModifiedDate': 'startKeys',
  'findFileByOwnerAndLastModifiedDate': 'startKeys',
  'findTeamByOwner': 'keys',
  'findByIsPublicAndLastModifiedDate': 'startKeys',
  'findByTeamAndIsPublicAndLastModifiedDate': 'startKeys',
  'findWorkflowByTagOwnerCreatedDate': 'startKeys',
  'findProjectByOwnersAndName': 'startKeys',
  'findProjectByOwnersAndCreatedDate': 'startKeys',
  'findOperatorByOwnerLastModifiedDate': 'startKeys',
  'findOperatorByUrlAndVersion': 'startKeys',
};

/// Maps findKeys method names to their CouchDB view names.
/// For startKeys methods, the method name IS the view name.
/// For findKeys methods, strip 'find' prefix and lowercase first char.
const findKeysViewNames = <String, String>{
  'findByOwner': 'byOwner',
  'findSubscriptionPlanByCheckoutSessionId': 'subscriptionPlanByCheckoutSessionId',
  'findDeleted': 'deleted',
  'findByKind': 'byKind',
  'findSecretByUserId': 'secretByUserId',
  'findTeamMembers': 'teamMembers',
  'findUserByEmail': 'userByEmail',
  'findByOwnerAndKindAndDate': 'byOwnerAndKindAndDate',
  'findByOwnerAndKind': 'byOwnerAndKind',
  'findPublicByKind': 'publicByKind',
  'findTeamByOwner': 'teamByOwner',
};
