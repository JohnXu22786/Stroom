/// Formats a file size in bytes to a human-readable string.
///
/// Returns the size in B, KB, MB, or GB as appropriate.
/// Examples:
///   - 0      -> '0 B'
///   - 1024   -> '1.0 KB'
///   - 1048576 -> '1.0 MB'
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
