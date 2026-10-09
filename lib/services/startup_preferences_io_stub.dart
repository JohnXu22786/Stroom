Future<Map<String, Object?>> readValues(Set<String> keys) async =>
    throw UnsupportedError('Desktop preference files are unavailable.');

Future<Set<String>> readKeys() async =>
    throw UnsupportedError('Desktop preference files are unavailable.');

Future<void> writeValue(String key, Object value) async =>
    throw UnsupportedError('Desktop preference files are unavailable.');

Future<void> removeValue(String key) async =>
    throw UnsupportedError('Desktop preference files are unavailable.');
