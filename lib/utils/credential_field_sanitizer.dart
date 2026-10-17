/// Normalizes a JSON property name before checking whether it stores a secret.
String normalizeCredentialFieldName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Returns true for a field that can carry a credential rather than a public
/// identifier or reference.
bool isCredentialFieldName(String name) {
  final normalized = normalizeCredentialFieldName(name);
  if (normalized.isEmpty ||
      normalized == 'publickey' ||
      normalized == 'keyid' ||
      normalized == 'credentialref' ||
      normalized == 'credentialreference') {
    return false;
  }
  if (const {
    'key',
    'credential',
    'credentials',
    'secret',
    'password',
    'authorization',
    'authorizationheader',
    'authheader',
    'authkey',
    'cookie',
    'cookieheader',
    'setcookie',
    'setcookieheader',
    'bearer',
    'secretkey',
  }.contains(normalized)) {
    return true;
  }
  return normalized.endsWith('apikey') ||
      normalized.endsWith('accesskey') ||
      normalized.endsWith('credentialkey') ||
      normalized.endsWith('functionskey') ||
      normalized.endsWith('subscriptionkey') ||
      normalized.endsWith('secretkey') ||
      normalized.endsWith('authorization') ||
      normalized.endsWith('secret') ||
      normalized.endsWith('password') ||
      normalized.endsWith('token') ||
      normalized.endsWith('privatekey');
}

/// Reports whether [value] contains a non-empty credential property.
bool containsCredentialValue(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String &&
          isCredentialFieldName(key) &&
          _hasNonEmptyValue(entry.value)) {
        return true;
      }
      if (containsCredentialValue(entry.value)) return true;
    }
  } else if (value is List) {
    for (final item in value) {
      if (containsCredentialValue(item)) return true;
    }
  }
  return false;
}

/// Copies JSON shaped [value], omitting credential properties at every depth.
/// Safe metadata such as `credentialRef` and `publicKey` is retained.
Object? sanitizeCredentialFields(Object? value) {
  if (value is Map) {
    final result = <Object?, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String && isCredentialFieldName(key)) continue;
      result[key] = sanitizeCredentialFields(entry.value);
    }
    return result;
  }
  if (value is List) {
    return value.map(sanitizeCredentialFields).toList();
  }
  return value;
}

bool _hasNonEmptyValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Map) return value.values.any(_hasNonEmptyValue);
  if (value is List) return value.any(_hasNonEmptyValue);
  return true;
}
