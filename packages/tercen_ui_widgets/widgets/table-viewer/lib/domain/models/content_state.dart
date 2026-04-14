/// The four content states every window body must handle.
enum ContentState {
  /// Content is being fetched or computed. Shows spinner.
  loading,

  /// Window has no content to show. Shows icon + message + optional action.
  empty,

  /// Normal content rendering. Type-specific.
  active,

  /// Something went wrong. Shows error icon + message + optional retry.
  error,
}
