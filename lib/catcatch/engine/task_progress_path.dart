/// Returns the progress filename for a task ID without treating the ID as a
/// filesystem path component.
///
/// Ordinary path-safe IDs keep their existing names. IDs that need encoding
/// use a reserved filename namespace so they cannot collide with a safe ID.
String taskProgressFileName(String taskId) {
  const windowsUnsafeCharacters = '<>:"/\\|?*';
  final hasUnsafeCharacter = taskId.codeUnits.any(
    (codeUnit) =>
        codeUnit < 0x20 || windowsUnsafeCharacters.codeUnits.contains(codeUnit),
  );
  final encodedId = taskId.codeUnits
      .map((unit) => unit.toRadixString(16).padLeft(4, '0'))
      .join();
  final fileId =
      hasUnsafeCharacter || taskId.startsWith('~') ? '~$encodedId' : taskId;
  return '${fileId}_dl_progress.json';
}
