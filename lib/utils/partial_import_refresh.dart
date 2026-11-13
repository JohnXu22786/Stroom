/// Refreshes persisted import state after a batch fails partway through.
///
/// The callback is best-effort so a refresh error does not replace the
/// original import failure shown to the user.
Future<void> refreshAfterPartialImport(
  int importedCount,
  Future<void> Function() refresh,
) async {
  if (importedCount == 0) return;
  try {
    await refresh();
  } catch (_) {
    // Preserve the import error; the next page load will read persisted state.
  }
}
