import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

String awsRegionalEndpointHost(String service, String region) =>
    '$service.$region.${region.startsWith('cn-') ? 'amazonaws.com.cn' : 'amazonaws.com'}';

/// AWS credentials kept in the platform credential store, never in account
/// preferences or request diagnostics.
class AwsSigV4Credentials {
  final String accessKeyId;
  final String secretAccessKey;
  final String? sessionToken;

  const AwsSigV4Credentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });

  factory AwsSigV4Credentials.fromJson(Map<String, dynamic> json) {
    String? first(List<String> names) {
      for (final name in names) {
        final value = json[name];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final accessKeyId = first(const [
      'accessKeyId',
      'AccessKeyId',
      'aws_access_key_id',
    ]);
    final secretAccessKey = first(const [
      'secretAccessKey',
      'SecretAccessKey',
      'aws_secret_access_key',
    ]);
    final sessionToken = first(const [
      'sessionToken',
      'SessionToken',
      'Token',
      'aws_session_token',
    ]);
    if (accessKeyId == null || secretAccessKey == null) {
      throw ArgumentError('AWS access key credentials are incomplete.');
    }
    return AwsSigV4Credentials(
      accessKeyId: accessKeyId,
      secretAccessKey: secretAccessKey,
      sessionToken: sessionToken,
    );
  }
}

/// Implements AWS Signature Version 4 header authentication.
///
/// The returned map contains the request headers with the signature attached.
/// The caller must send the exact [uri], [method], and [payload] supplied here.
abstract final class AwsSigV4 {
  static Map<String, String> sign({
    required String method,
    required Uri uri,
    required String region,
    required String service,
    required Map<String, String> headers,
    required Uint8List payload,
    required AwsSigV4Credentials credentials,
    required DateTime now,
  }) {
    if (credentials.accessKeyId.trim().isEmpty ||
        credentials.secretAccessKey.isEmpty ||
        region.trim().isEmpty ||
        service.trim().isEmpty ||
        !now.isUtc ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw ArgumentError('AWS signing input is incomplete.');
    }

    final timestamp = _timestamp(now);
    final date = timestamp.substring(0, 8);
    final payloadHash = sha256.convert(payload).toString();
    final result = <String, String>{
      for (final entry in headers.entries) entry.key: entry.value,
      'host': uri.authority,
      'x-amz-date': timestamp,
      'x-amz-content-sha256': payloadHash,
      if (credentials.sessionToken != null &&
          credentials.sessionToken!.isNotEmpty)
        'x-amz-security-token': credentials.sessionToken!,
    };

    final canonicalHeaders = <String, String>{};
    for (final entry in result.entries) {
      final name = entry.key.trim().toLowerCase();
      if (name == 'authorization' ||
          name == 'user-agent' ||
          name == 'expect' ||
          name == 'x-amzn-trace-id') {
        continue;
      }
      canonicalHeaders[name] = entry.value.trim().replaceAll(
            RegExp(r'\s+'),
            ' ',
          );
    }
    final sortedNames = canonicalHeaders.keys.toList()..sort();
    final signedHeaders = sortedNames.join(';');
    final canonicalHeaderBlock =
        sortedNames.map((name) => '$name:${canonicalHeaders[name]}').join('\n');
    final canonicalRequest = [
      method.toUpperCase(),
      _canonicalPath(uri),
      _canonicalQuery(uri),
      canonicalHeaderBlock,
      signedHeaders,
      payloadHash,
    ].join('\n');
    final scope = '$date/$region/$service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      timestamp,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');
    final dateKey = _hmac(
      utf8.encode('AWS4${credentials.secretAccessKey}'),
      date,
    );
    final regionKey = _hmac(dateKey, region);
    final serviceKey = _hmac(regionKey, service);
    final signingKey = _hmac(serviceKey, 'aws4_request');
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

    result['Authorization'] = 'AWS4-HMAC-SHA256 '
        'Credential=${credentials.accessKeyId}/$scope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';
    return Map.unmodifiable(result);
  }

  static String _timestamp(DateTime value) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}'
        'T${two(value.hour)}${two(value.minute)}${two(value.second)}Z';
  }

  static String _canonicalPath(Uri uri) {
    final segments = uri.pathSegments.map(_encode).join('/');
    final path = uri.path.startsWith('/') ? '/$segments' : segments;
    return path.isEmpty ? '/' : path;
  }

  static String _canonicalQuery(Uri uri) {
    final pairs = <(String, String)>[];
    uri.queryParametersAll.forEach((key, values) {
      for (final value in values) {
        pairs.add((_encode(key), _encode(value)));
      }
    });
    pairs.sort((left, right) {
      final keyOrder = left.$1.compareTo(right.$1);
      return keyOrder != 0 ? keyOrder : left.$2.compareTo(right.$2);
    });
    return pairs.map((pair) => '${pair.$1}=${pair.$2}').join('&');
  }

  static String _encode(String value) => Uri.encodeComponent(value)
      .replaceAll('!', '%21')
      .replaceAll("'", '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29')
      .replaceAll('*', '%2A');

  static List<int> _hmac(List<int> key, String value) =>
      Hmac(sha256, key).convert(utf8.encode(value)).bytes;
}
