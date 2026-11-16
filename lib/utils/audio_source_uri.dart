/// Builds the URI used by native audio sources from a URL or local path.
Uri audioSourceUri(String source) {
  final parsed = Uri.tryParse(source);
  final isWindowsDrivePath = RegExp(r'^[a-zA-Z]:').hasMatch(source);

  if (parsed != null &&
      parsed.hasScheme &&
      !isWindowsDrivePath &&
      (parsed.scheme == 'data' ||
          parsed.scheme == 'file' ||
          parsed.hasAuthority)) {
    return parsed;
  }

  return Uri.file(source);
}
