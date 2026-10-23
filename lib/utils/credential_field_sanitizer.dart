import 'dart:convert';

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

/// Returns true for metadata fields that carry an identifier or reference.
/// These fields remain in backups only when they do not embed a credential.
bool isCredentialIdentifierFieldName(String name) => const {
      'id',
      'entryid',
      'providerid',
      'configid',
      'accountid',
      'groupid',
      'modelid',
      'localmodelid',
      'upstreammodelid',
      'modelgroupid',
      'credentialref',
      'credentialreference'
    }.contains(normalizeCredentialFieldName(name));

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

/// Collects non-empty values from credential properties anywhere in a
/// JSON-shaped value. Callers that retain identifiers or references alongside
/// redacted data can use this set to ensure those strings do not embed a key.
Set<String> collectCredentialValues(Object? value) {
  final values = <String>{};
  void visit(Object? current) {
    if (current is Map) {
      for (final entry in current.entries) {
        final name = entry.key;
        final nested = entry.value;
        if (name is String && isCredentialFieldName(name)) {
          _collectNonEmptyStrings(nested, values);
        }
        visit(nested);
      }
    } else if (current is List) {
      for (final item in current) {
        visit(item);
      }
    }
  }

  visit(value);
  return values;
}

/// Validates the percent-encoding syntax of app-generated credential
/// references. A raw suffix matching an opaque account ID is accepted as-is;
/// other legacy suffixes remain valid when their escapes are well formed.
bool isValidGeneratedCredentialReference(String reference, String accountId) {
  const prefix = 'stroom.llm.credential.';
  if (!reference.startsWith(prefix)) return true;
  var suffix = reference.substring(prefix.length);
  if (suffix == accountId) return true;
  for (var attempt = 0; attempt < 8; attempt++) {
    try {
      final decoded = Uri.decodeComponent(suffix);
      if (decoded == suffix) return true;
      if (decoded == accountId) return true;
      suffix = decoded;
    } on FormatException {
      return false;
    }
  }
  return false;
}

bool containsAnyCredentialValue(String value, Set<String> credentials) =>
    credentials.any(
        (credential) => credential.isNotEmpty && value.contains(credential));

/// Checks the raw identifier and bounded URI-decoded forms. This catches
/// secrets hidden by normal percent encoding while leaving opaque legacy IDs
/// untouched in the stored/exported data.
bool containsCredentialValueInIdentifier(
    String value, Set<String> credentials) {
  var candidate = value;
  for (var attempt = 0; attempt <= value.length; attempt++) {
    if (containsAnyCredentialValue(candidate, credentials)) return true;
    final decoded = _decodePercentEscapes(candidate);
    if (decoded == candidate) return false;
    candidate = decoded;
  }
  return containsAnyCredentialValue(candidate, credentials);
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

void _collectNonEmptyStrings(Object? value, Set<String> output) {
  if (value is String) {
    if (value.trim().isNotEmpty) output.add(value);
  } else if (value is Map) {
    for (final nested in value.values) {
      _collectNonEmptyStrings(nested, output);
    }
  } else if (value is List) {
    for (final nested in value) {
      _collectNonEmptyStrings(nested, output);
    }
  }
}

String _decodePercentEscapes(String value) {
  final result = StringBuffer();
  var index = 0;
  while (index < value.length) {
    if (value.codeUnitAt(index) != 0x25 || index + 2 >= value.length) {
      result.writeCharCode(value.codeUnitAt(index));
      index++;
      continue;
    }
    final bytes = <int>[];
    while (index + 2 < value.length && value.codeUnitAt(index) == 0x25) {
      final high = _hexValue(value.codeUnitAt(index + 1));
      final low = _hexValue(value.codeUnitAt(index + 2));
      if (high < 0 || low < 0) break;
      bytes.add((high << 4) | low);
      index += 3;
    }
    if (bytes.isEmpty) {
      result.writeCharCode(value.codeUnitAt(index));
      index++;
    } else {
      result.write(utf8.decode(bytes, allowMalformed: true));
    }
  }
  return result.toString();
}

int _hexValue(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
  if (codeUnit >= 0x41 && codeUnit <= 0x46) return codeUnit - 0x41 + 10;
  if (codeUnit >= 0x61 && codeUnit <= 0x66) return codeUnit - 0x61 + 10;
  return -1;
}
