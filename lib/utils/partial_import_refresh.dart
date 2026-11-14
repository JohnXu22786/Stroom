/// Imports [items], refreshing persisted state if an item fails after success.
///
/// [importItem] returns whether the item was imported; skipped items return
/// false. Refresh is best-effort so its failure does not replace the original
/// import error.
Future<int> importBatchWithPartialRefresh<T>({
  required Iterable<T> items,
  required Future<bool> Function(T item) importItem,
  required Future<void> Function() refresh,
}) async {
  var importedCount = 0;
  try {
    for (final item in items) {
      if (await importItem(item)) importedCount++;
    }
  } catch (_) {
    if (importedCount > 0) {
      try {
        await refresh();
      } catch (_) {
        // Preserve the import error; the next page load reads persisted state.
      }
    }
    rethrow;
  }
  return importedCount;
}

/// Refreshes persisted import state after a batch operation fails later.
Future<void> refreshAfterPartialImport(
  int importedCount,
  Future<void> Function() refresh,
) async {
  if (importedCount == 0) return;
  try {
    await refresh();
  } catch (_) {
    // Preserve the original error; the next page load reads persisted state.
  }
}
