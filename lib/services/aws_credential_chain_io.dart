import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'aws_sigv4.dart';

Future<AwsSigV4Credentials?> resolveAwsCredentialChain({
  Map<String, String>? environment,
}) async {
  final values = environment ?? Platform.environment;
  final accessKey = _nonEmpty(values['AWS_ACCESS_KEY_ID']);
  final secretKey = _nonEmpty(values['AWS_SECRET_ACCESS_KEY']);
  if (accessKey != null || secretKey != null) {
    if (accessKey == null || secretKey == null) {
      throw const AwsCredentialChainException();
    }
    return AwsSigV4Credentials(
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
      sessionToken: _nonEmpty(values['AWS_SESSION_TOKEN']),
    );
  }

  final roleArn = _nonEmpty(values['AWS_ROLE_ARN']);
  final webIdentityPath = _nonEmpty(values['AWS_WEB_IDENTITY_TOKEN_FILE']);
  if (roleArn != null || webIdentityPath != null) {
    if (roleArn == null || webIdentityPath == null) {
      throw const AwsCredentialChainException();
    }
    return _webIdentityCredentials(values, roleArn, webIdentityPath);
  }

  final profileCredentials = await _sharedCredentials(values);
  if (profileCredentials != null) return profileCredentials;

  final containerCredentials = await _containerCredentials(values);
  if (containerCredentials != null) return containerCredentials;

  return _instanceCredentials(values);
}

Future<AwsSigV4Credentials?> _sharedCredentials(
  Map<String, String> environment,
) async {
  final profile = _nonEmpty(environment['AWS_PROFILE']) ?? 'default';
  return _profileCredentials(environment, profile, <String>{});
}

Future<AwsSigV4Credentials?> _profileCredentials(
  Map<String, String> environment,
  String profile,
  Set<String> visited,
) async {
  if (!visited.add(profile)) throw const AwsCredentialChainException();
  final home = _homeDirectory(environment);
  final credentialsPath =
      _nonEmpty(environment['AWS_SHARED_CREDENTIALS_FILE']) ??
          (home.isEmpty ? '' : '$home/.aws/credentials');
  final configPath = _nonEmpty(environment['AWS_CONFIG_FILE']) ??
      (home.isEmpty ? '' : '$home/.aws/config');
  final credentialValues = await _readProfileFile(credentialsPath, profile);
  final profileAccessKey = _nonEmpty(credentialValues['aws_access_key_id']);
  final profileSecretKey = _nonEmpty(credentialValues['aws_secret_access_key']);
  if (profileAccessKey != null || profileSecretKey != null) {
    if (profileAccessKey == null || profileSecretKey == null) {
      throw const AwsCredentialChainException();
    }
    return AwsSigV4Credentials(
      accessKeyId: profileAccessKey,
      secretAccessKey: profileSecretKey,
      sessionToken: _nonEmpty(credentialValues['aws_session_token']),
    );
  }

  final configValues = await _readProfileFile(
    configPath,
    profile == 'default' ? 'default' : 'profile $profile',
  );
  final ssoSession = _nonEmpty(configValues['sso_session']);
  final ssoValues = ssoSession == null
      ? configValues
      : {
          ...await _readProfileFile(configPath, 'sso-session $ssoSession'),
          ...configValues,
        };
  if (_nonEmpty(ssoValues['sso_start_url']) != null ||
      _nonEmpty(ssoValues['sso_account_id']) != null) {
    return _ssoCredentials(environment, ssoValues);
  }

  final credentialProcess = _nonEmpty(configValues['credential_process']);
  if (credentialProcess != null) {
    return _credentialProcessCredentials(credentialProcess);
  }

  final roleArn = _nonEmpty(configValues['role_arn']);
  if (roleArn == null) return null;
  final sourceProfile = _nonEmpty(configValues['source_profile']);
  final credentialSource = _nonEmpty(configValues['credential_source']);
  AwsSigV4Credentials? source;
  if (sourceProfile != null) {
    source = await _profileCredentials(environment, sourceProfile, visited);
  } else {
    source = switch (credentialSource) {
      'Environment' => _environmentCredentials(environment),
      'EcsContainer' => await _containerCredentials(environment),
      'Ec2InstanceMetadata' => await _instanceCredentials(environment),
      _ => null,
    };
  }
  if (source == null) throw const AwsCredentialChainException();
  return _assumeRole(environment, configValues, roleArn, source);
}

Future<AwsSigV4Credentials> _credentialProcessCredentials(
  String command,
) async {
  Process? process;
  Future<String>? stdout;
  Future<String>? stderr;
  try {
    final shell = Platform.isWindows ? 'cmd.exe' : '/bin/sh';
    final arguments =
        Platform.isWindows ? ['/d', '/s', '/c', command] : ['-c', command];
    process = await Process.start(shell, arguments);
    stdout = _readLimitedProcessOutput(process.stdout, 1024 * 1024);
    stderr = _readLimitedProcessOutput(process.stderr, 64 * 1024);
    final exitCode = await process.exitCode.timeout(
      const Duration(seconds: 30),
    );
    final output = await stdout;
    await stderr;
    if (exitCode != 0) throw const AwsCredentialChainException();
    final decoded = jsonDecode(output);
    if (decoded is! Map || decoded['Version'] != 1) {
      throw const AwsCredentialChainException();
    }
    final values = Map<String, dynamic>.from(decoded);
    final expirationText = _first(values, const ['Expiration']);
    if (expirationText != null) {
      final expiration = DateTime.tryParse(expirationText);
      if (expiration == null || !expiration.isAfter(DateTime.now().toUtc())) {
        throw const AwsCredentialChainException();
      }
    }
    return _credentials(
      _first(values, const ['AccessKeyId']),
      _first(values, const ['SecretAccessKey']),
      _first(values, const ['SessionToken']),
    );
  } on AwsCredentialChainException {
    process?.kill();
    await _drainProcessOutput(stdout, stderr);
    rethrow;
  } catch (_) {
    process?.kill();
    await _drainProcessOutput(stdout, stderr);
    throw const AwsCredentialChainException();
  }
}

Future<void> _drainProcessOutput(
  Future<String>? stdout,
  Future<String>? stderr,
) async {
  for (final output in [stdout, stderr]) {
    try {
      await output;
    } catch (_) {
      // The caller already converts process output failures to a safe error.
    }
  }
}

Future<String> _readLimitedProcessOutput(
  Stream<List<int>> stream,
  int limit,
) async {
  final bytes = BytesBuilder(copy: false);
  var exceededLimit = false;
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > limit) {
      exceededLimit = true;
    } else if (!exceededLimit) {
      bytes.add(chunk);
    }
  }
  if (exceededLimit) throw const AwsCredentialChainException();
  return utf8.decode(bytes.takeBytes());
}

AwsSigV4Credentials? _environmentCredentials(Map<String, String> environment) {
  final access = _nonEmpty(environment['AWS_ACCESS_KEY_ID']);
  final secret = _nonEmpty(environment['AWS_SECRET_ACCESS_KEY']);
  if (access == null || secret == null) return null;
  return AwsSigV4Credentials(
    accessKeyId: access,
    secretAccessKey: secret,
    sessionToken: _nonEmpty(environment['AWS_SESSION_TOKEN']),
  );
}

Future<Map<String, String>> _readProfileFile(
  String path,
  String profile,
) async {
  if (path.isEmpty) return const {};
  final file = File(path);
  if (!await file.exists()) return const {};
  return _readProfile(await file.readAsLines(), profile);
}

Future<AwsSigV4Credentials?> _assumeRole(
  Map<String, String> environment,
  Map<String, String> config,
  String roleArn,
  AwsSigV4Credentials source,
) async {
  try {
    final region = _nonEmpty(config['region']) ??
        _nonEmpty(environment['AWS_REGION']) ??
        _nonEmpty(environment['AWS_DEFAULT_REGION']) ??
        'us-east-1';
    final uri = Uri.parse(
      _nonEmpty(environment['AWS_ENDPOINT_URL_STS']) ??
          'https://${awsRegionalEndpointHost('sts', region)}/',
    );
    if (!_isSafeServiceEndpoint(uri)) {
      throw const AwsCredentialChainException();
    }
    final form = Uri(
      queryParameters: {
        'Action': 'AssumeRole',
        'Version': '2011-06-15',
        'RoleArn': roleArn,
        'RoleSessionName': _nonEmpty(config['role_session_name']) ??
            'stroom-${DateTime.now().millisecondsSinceEpoch}',
        if (_nonEmpty(config['external_id']) != null)
          'ExternalId': config['external_id']!,
      },
    ).query;
    final payload = utf8.encode(form);
    final headers = AwsSigV4.sign(
      method: 'POST',
      uri: uri,
      region: region,
      service: 'sts',
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      payload: Uint8List.fromList(payload),
      credentials: source,
      now: DateTime.now().toUtc(),
    );
    final response = await _httpRequest(
      uri,
      method: 'POST',
      headers: headers,
      body: form,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw const AwsCredentialChainException();
    }
    return _credentials(
      _xmlElement(response.body, 'AccessKeyId'),
      _xmlElement(response.body, 'SecretAccessKey'),
      _xmlElement(response.body, 'SessionToken'),
    );
  } on AwsCredentialChainException {
    rethrow;
  } catch (_) {
    throw const AwsCredentialChainException();
  }
}

Future<AwsSigV4Credentials?> _ssoCredentials(
  Map<String, String> environment,
  Map<String, String> config,
) async {
  try {
    final startUrl = _nonEmpty(config['sso_start_url']);
    final region = _nonEmpty(config['sso_region']);
    final account = _nonEmpty(config['sso_account_id']);
    final role = _nonEmpty(config['sso_role_name']);
    if (startUrl == null || region == null || account == null || role == null) {
      throw const AwsCredentialChainException();
    }
    final home = _homeDirectory(environment);
    if (home.isEmpty) return null;
    final cacheDirectory = Directory('$home/.aws/sso/cache');
    if (!await cacheDirectory.exists()) return null;
    String? accessToken;
    await for (final file in cacheDirectory.list(followLinks: false)) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map || decoded['startUrl'] != startUrl) continue;
        final expiryText = decoded['expiresAt'];
        final expiry =
            expiryText is String ? DateTime.tryParse(expiryText) : null;
        final token = decoded['accessToken'];
        if (token is String &&
            expiry != null &&
            expiry.isAfter(
              DateTime.now().toUtc().add(const Duration(minutes: 1)),
            )) {
          accessToken = token;
          break;
        }
      } catch (_) {
        // Ignore malformed token cache entries and try other sessions.
      }
    }
    if (accessToken == null) throw const AwsCredentialChainException();
    final endpoint = Uri.parse(
      _nonEmpty(environment['AWS_ENDPOINT_URL_SSO']) ??
          'https://portal.sso.$region.amazonaws.com/federation/credentials',
    ).replace(queryParameters: {'account_id': account, 'role_name': role});
    if (!_isSafeServiceEndpoint(endpoint)) {
      throw const AwsCredentialChainException();
    }
    final response = await _httpRequest(
      endpoint,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != HttpStatus.ok) {
      throw const AwsCredentialChainException();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['roleCredentials'] is! Map) {
      throw const AwsCredentialChainException();
    }
    final credentials = Map<String, dynamic>.from(
      decoded['roleCredentials'] as Map,
    );
    return _credentials(
      _first(credentials, const ['accessKeyId']),
      _first(credentials, const ['secretAccessKey']),
      _first(credentials, const ['sessionToken']),
    );
  } on AwsCredentialChainException {
    rethrow;
  } catch (_) {
    throw const AwsCredentialChainException();
  }
}

Future<AwsSigV4Credentials?> _webIdentityCredentials(
  Map<String, String> environment,
  String roleArn,
  String tokenPath,
) async {
  try {
    final webToken = (await File(tokenPath).readAsString()).trim();
    if (webToken.isEmpty) throw const AwsCredentialChainException();
    final region = _nonEmpty(environment['AWS_REGION']) ??
        _nonEmpty(environment['AWS_DEFAULT_REGION']) ??
        'us-east-1';
    final endpoint = _nonEmpty(environment['AWS_ENDPOINT_URL_STS']) ??
        'https://${awsRegionalEndpointHost('sts', region)}/';
    final uri = Uri.parse(endpoint);
    if (!_isSafeServiceEndpoint(uri)) {
      throw const AwsCredentialChainException();
    }
    final response = await _httpRequest(
      uri,
      method: 'POST',
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: Uri(
        queryParameters: {
          'Action': 'AssumeRoleWithWebIdentity',
          'Version': '2011-06-15',
          'RoleArn': roleArn,
          'RoleSessionName': _nonEmpty(environment['AWS_ROLE_SESSION_NAME']) ??
              'stroom-${DateTime.now().millisecondsSinceEpoch}',
          'WebIdentityToken': webToken,
        },
      ).query,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw const AwsCredentialChainException();
    }
    final access = _xmlElement(response.body, 'AccessKeyId');
    final secret = _xmlElement(response.body, 'SecretAccessKey');
    final token = _xmlElement(response.body, 'SessionToken');
    return _credentials(access, secret, token);
  } on AwsCredentialChainException {
    rethrow;
  } catch (_) {
    throw const AwsCredentialChainException();
  }
}

Future<AwsSigV4Credentials?> _containerCredentials(
  Map<String, String> environment,
) async {
  var endpoint = _nonEmpty(environment['AWS_CONTAINER_CREDENTIALS_FULL_URI']);
  if (endpoint == null) {
    final relative = _nonEmpty(
      environment['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'],
    );
    if (relative != null) {
      if (!relative.startsWith('/') || relative.contains('..')) {
        throw const AwsCredentialChainException();
      }
      endpoint = 'http://169.254.170.2$relative';
    }
  }
  if (endpoint == null) return null;
  final uri = Uri.parse(endpoint);
  if (!_isSafeCredentialEndpoint(uri)) {
    throw const AwsCredentialChainException();
  }
  var authorization = _nonEmpty(
    environment['AWS_CONTAINER_AUTHORIZATION_TOKEN'],
  );
  final tokenFile = _nonEmpty(
    environment['AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE'],
  );
  if (authorization == null && tokenFile != null) {
    authorization = _nonEmpty(await File(tokenFile).readAsString());
  }
  final requestHeaders = <String, String>{};
  if (authorization != null) requestHeaders['Authorization'] = authorization;
  final response = await _httpRequest(uri, headers: requestHeaders);
  if (response.statusCode != HttpStatus.ok) {
    throw const AwsCredentialChainException();
  }
  return _jsonCredentials(response.body);
}

Future<AwsSigV4Credentials?> _instanceCredentials(
  Map<String, String> environment,
) async {
  if (_nonEmpty(environment['AWS_EC2_METADATA_DISABLED'])?.toLowerCase() ==
      'true') {
    return null;
  }
  final endpoint =
      _nonEmpty(environment['AWS_EC2_METADATA_SERVICE_ENDPOINT']) ??
          'http://169.254.169.254';
  final base = Uri.parse(endpoint);
  if (!_isSafeCredentialEndpoint(base)) {
    throw const AwsCredentialChainException();
  }
  final tokenResponse = await _httpRequest(
    base.resolve('/latest/api/token'),
    method: 'PUT',
    headers: const {'X-aws-ec2-metadata-token-ttl-seconds': '21600'},
  );
  if (tokenResponse.statusCode != HttpStatus.ok ||
      tokenResponse.body.trim().isEmpty) {
    return null;
  }
  final token = tokenResponse.body.trim();
  final roleResponse = await _httpRequest(
    base.resolve('/latest/meta-data/iam/security-credentials/'),
    headers: {'X-aws-ec2-metadata-token': token},
  );
  if (roleResponse.statusCode != HttpStatus.ok) return null;
  final role = roleResponse.body.trim().split('\n').first;
  if (role.isEmpty || role.contains('/')) return null;
  final credentialsResponse = await _httpRequest(
    base.resolve(
      '/latest/meta-data/iam/security-credentials/${Uri.encodeComponent(role)}',
    ),
    headers: {'X-aws-ec2-metadata-token': token},
  );
  if (credentialsResponse.statusCode != HttpStatus.ok) return null;
  return _jsonCredentials(credentialsResponse.body);
}

Future<_HttpResult> _httpRequest(
  Uri uri, {
  String method = 'GET',
  Map<String, String> headers = const {},
  String? body,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request =
        await client.openUrl(method, uri).timeout(const Duration(seconds: 3));
    request.followRedirects = false;
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    if (body != null) request.write(body);
    final response = await request.close().timeout(const Duration(seconds: 3));
    final responseBody = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 3));
    return _HttpResult(response.statusCode, responseBody);
  } finally {
    client.close(force: true);
  }
}

AwsSigV4Credentials _jsonCredentials(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) throw const AwsCredentialChainException();
    final map = Map<String, dynamic>.from(decoded);
    return _credentials(
      _first(map, const ['AccessKeyId', 'accessKeyId', 'access_key']),
      _first(map, const ['SecretAccessKey', 'secretAccessKey', 'secret_key']),
      _first(map, const ['Token', 'SessionToken', 'sessionToken', 'token']),
    );
  } on AwsCredentialChainException {
    rethrow;
  } catch (_) {
    throw const AwsCredentialChainException();
  }
}

AwsSigV4Credentials _credentials(
  String? access,
  String? secret,
  String? token,
) {
  if (access == null || secret == null) {
    throw const AwsCredentialChainException();
  }
  return AwsSigV4Credentials(
    accessKeyId: access,
    secretAccessKey: secret,
    sessionToken: token,
  );
}

String? _xmlElement(String source, String name) {
  final match = RegExp('<$name>(.*?)</$name>', dotAll: true).firstMatch(source);
  if (match == null) return null;
  return match
      .group(1)!
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

String? _first(Map<String, dynamic> values, List<String> names) {
  for (final name in names) {
    final value = values[name];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

bool _isSafeServiceEndpoint(Uri uri) =>
    uri.hasAuthority &&
    (uri.scheme == 'https' || (uri.scheme == 'http' && _isLoopback(uri.host)));

bool _isSafeCredentialEndpoint(Uri uri) {
  if (!uri.hasAuthority) return false;
  if (uri.scheme == 'https') return true;
  if (uri.scheme != 'http') return false;
  final host = uri.host.toLowerCase();
  return _isLoopback(host) ||
      host == '169.254.170.2' ||
      host == '169.254.170.23' ||
      host == '169.254.169.254';
}

bool _isLoopback(String host) =>
    host == 'localhost' || host == '::1' || host.startsWith('127.');

Map<String, String> _readProfile(List<String> lines, String profile) {
  final values = <String, String>{};
  var selected = false;
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) continue;
    if (line.startsWith('[') && line.endsWith(']')) {
      selected = line.substring(1, line.length - 1).trim() == profile;
      continue;
    }
    if (!selected) continue;
    final separator = line.indexOf('=');
    if (separator < 0) continue;
    values[line.substring(0, separator).trim().toLowerCase()] =
        line.substring(separator + 1).trim();
  }
  return values;
}

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

String _homeDirectory(Map<String, String> environment) =>
    _nonEmpty(environment['HOME']) ??
    _nonEmpty(environment['USERPROFILE']) ??
    '';

class _HttpResult {
  final int statusCode;
  final String body;

  const _HttpResult(this.statusCode, this.body);
}

class AwsCredentialChainException implements Exception {
  const AwsCredentialChainException();

  @override
  String toString() => 'AWS credentials could not be resolved.';
}
