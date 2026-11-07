Future<void> append(String path, String line) async {
  throw UnsupportedError('Native stream journal storage is unavailable');
}

Future<List<String>?> readLines(String path) async {
  throw UnsupportedError('Native stream journal storage is unavailable');
}

Future<bool> delete(String path) async {
  throw UnsupportedError('Native stream journal storage is unavailable');
}
