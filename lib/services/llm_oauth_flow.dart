import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Provider OAuth admission is based on a public third-party inference flow,
/// not on an official CLI's private session format.
class LlmOAuthProviderPolicy {
  final String providerId;
  final bool supported;
  final String? reason;

  const LlmOAuthProviderPolicy._({
    required this.providerId,
    required this.supported,
    this.reason,
  });

  static const _policies = <String, LlmOAuthProviderPolicy>{
    'codex': LlmOAuthProviderPolicy._(providerId: 'codex', supported: true),
    'gemini': LlmOAuthProviderPolicy._(providerId: 'gemini', supported: true),
    'aistudio': LlmOAuthProviderPolicy._(
      providerId: 'aistudio',
      supported: true,
    ),
    'claude': LlmOAuthProviderPolicy._(providerId: 'claude', supported: true),
    'antigravity': LlmOAuthProviderPolicy._(
      providerId: 'antigravity',
      supported: false,
      reason:
          'No public third-party OAuth client and model-inference API contract is documented for Antigravity.',
    ),
    'xai': LlmOAuthProviderPolicy._(
      providerId: 'xai',
      supported: false,
      reason:
          'The native xAI API-key connector does not accept OAuth accounts.',
    ),
    'grok-cli': LlmOAuthProviderPolicy._(
      providerId: 'grok-cli',
      supported: true,
    ),
    'xai-oauth': LlmOAuthProviderPolicy._(
      providerId: 'xai-oauth',
      supported: true,
    ),
    'muse-code': LlmOAuthProviderPolicy._(
      providerId: 'muse-code',
      supported: true,
    ),
    'codebuddy-cn': LlmOAuthProviderPolicy._(
      providerId: 'codebuddy-cn',
      supported: true,
    ),
    'codebuddy-intl': LlmOAuthProviderPolicy._(
      providerId: 'codebuddy-intl',
      supported: true,
    ),
    'workbuddy': LlmOAuthProviderPolicy._(
      providerId: 'workbuddy',
      supported: true,
    ),
    'openference': LlmOAuthProviderPolicy._(
      providerId: 'openference',
      supported: true,
    ),
    'qoder': LlmOAuthProviderPolicy._(providerId: 'qoder', supported: true),
    'kilocode': LlmOAuthProviderPolicy._(
      providerId: 'kilocode',
      supported: true,
    ),
    'devin': LlmOAuthProviderPolicy._(providerId: 'devin', supported: true),
    'kimi': LlmOAuthProviderPolicy._(
      providerId: 'kimi',
      supported: false,
      reason:
          'Kimi Code CLI sign-in is not documented as a third-party inference authorization; the public model API uses API keys.',
    ),
    'kimi-ai': LlmOAuthProviderPolicy._(
      providerId: 'kimi-ai',
      supported: false,
      reason:
          'Kimi Code CLI sign-in is not documented as a third-party inference authorization; the public model API uses API keys.',
    ),
    'kimi.ai': LlmOAuthProviderPolicy._(
      providerId: 'kimi.ai',
      supported: false,
      reason:
          'Kimi Code CLI sign-in is not documented as a third-party inference authorization; the public model API uses API keys.',
    ),
    'kimi-coding': LlmOAuthProviderPolicy._(
      providerId: 'kimi-coding',
      supported: true,
    ),
    'google-code-assist': LlmOAuthProviderPolicy._(
      providerId: 'google-code-assist',
      supported: false,
      reason:
          'Code Assist is a separate Google service and no public third-party model-inference OAuth contract is configured here.',
    ),
  };

  static LlmOAuthProviderPolicy forProvider(String providerId) =>
      _policies[providerId.trim().toLowerCase()] ??
      LlmOAuthProviderPolicy._(
        providerId: providerId.trim().toLowerCase(),
        supported: false,
        reason: 'No public third-party OAuth inference flow is registered.',
      );
}

class LlmOAuthFlowException implements Exception {
  const LlmOAuthFlowException();

  @override
  String toString() => 'OAuth authorization could not be completed.';
}

class LlmOAuthCallbackResult {
  final String code;
  final String? clientId;
  final String? scope;

  const LlmOAuthCallbackResult({
    required this.code,
    required this.clientId,
    this.scope,
  });
}

/// Verification details returned by Kimi Code's device authorization grant.
/// The device code remains in memory and is never surfaced by this object.
class LlmKimiDeviceCode {
  final String _deviceCode;
  final String userCode;
  final Uri verificationUri;
  final Uri verificationUriComplete;
  final Duration expiresIn;
  final Duration interval;

  /// Opaque value passed only to the Kimi token-poll request.
  String get deviceCode => _deviceCode;

  factory LlmKimiDeviceCode.fromOAuthResponse({
    required String deviceCode,
    required String userCode,
    required Uri verificationUri,
    required Uri verificationUriComplete,
    required Duration expiresIn,
    required Duration interval,
  }) =>
      LlmKimiDeviceCode._(
        deviceCode: deviceCode,
        userCode: userCode,
        verificationUri: verificationUri,
        verificationUriComplete: verificationUriComplete,
        expiresIn: expiresIn,
        interval: interval,
      );

  const LlmKimiDeviceCode._({
    required String deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  }) : _deviceCode = deviceCode;
}

/// Verification details from Kilo's custom device-code flow. The device code
/// is kept out of UI-facing account data and is never persisted.
class LlmKiloDeviceCode {
  final String _deviceCode;
  final String userCode;
  final Uri verificationUri;
  final Uri verificationUriComplete;
  final Duration interval;

  String get deviceCode => _deviceCode;

  const LlmKiloDeviceCode._({
    required String deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.interval,
  }) : _deviceCode = deviceCode;

  factory LlmKiloDeviceCode.fromResponse({
    required String deviceCode,
    required String userCode,
    required Uri verificationUri,
    required Uri verificationUriComplete,
    required Duration interval,
  }) =>
      LlmKiloDeviceCode._(
        deviceCode: deviceCode,
        userCode: userCode,
        verificationUri: verificationUri,
        verificationUriComplete: verificationUriComplete,
        interval: interval,
      );
}

/// Secret device state for the Tencent desktop CLI authorization flow.
class LlmTencentDeviceCode {
  final String _deviceCode;
  final String userCode;
  final Uri verificationUri;
  final Uri verificationUriComplete;
  final Duration expiresIn;
  final Duration interval;

  String get deviceCode => _deviceCode;

  const LlmTencentDeviceCode._({
    required String deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  }) : _deviceCode = deviceCode;

  factory LlmTencentDeviceCode.fromResponse({
    required String deviceCode,
    required String userCode,
    required Uri verificationUri,
    required Uri verificationUriComplete,
    required Duration expiresIn,
    required Duration interval,
  }) =>
      LlmTencentDeviceCode._(
        deviceCode: deviceCode,
        userCode: userCode,
        verificationUri: verificationUri,
        verificationUriComplete: verificationUriComplete,
        expiresIn: expiresIn,
        interval: interval,
      );
}

/// Verification details returned by Meta Muse's device authorization grant.
/// The device code is kept out of UI-facing account data.
class LlmMetaMuseDeviceCode {
  final String _deviceCode;
  final String userCode;
  final Uri verificationUri;
  final Uri verificationUriComplete;
  final Duration expiresIn;
  final Duration interval;

  String get deviceCode => _deviceCode;

  const LlmMetaMuseDeviceCode._({
    required String deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  }) : _deviceCode = deviceCode;

  factory LlmMetaMuseDeviceCode.fromOAuthResponse({
    required String deviceCode,
    required String userCode,
    required Uri verificationUri,
    required Uri verificationUriComplete,
    required Duration expiresIn,
    required Duration interval,
  }) =>
      LlmMetaMuseDeviceCode._(
        deviceCode: deviceCode,
        userCode: userCode,
        verificationUri: verificationUri,
        verificationUriComplete: verificationUriComplete,
        expiresIn: expiresIn,
        interval: interval,
      );
}

/// Device authorization returned by xAI's public OIDC device grant.
class LlmXaiDeviceCode {
  final String _deviceCode;
  final String tokenEndpoint;
  final String issuer;
  final Uri jwksUri;
  final String scope;
  final String userCode;
  final Uri verificationUri;
  final Uri verificationUriComplete;
  final Duration expiresIn;
  final Duration interval;

  String get deviceCode => _deviceCode;

  const LlmXaiDeviceCode._({
    required String deviceCode,
    required this.tokenEndpoint,
    required this.issuer,
    required this.jwksUri,
    required this.scope,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  }) : _deviceCode = deviceCode;

  factory LlmXaiDeviceCode.fromOAuthResponse({
    required String deviceCode,
    required String tokenEndpoint,
    required String issuer,
    required Uri jwksUri,
    required String scope,
    required String userCode,
    required Uri verificationUri,
    required Uri verificationUriComplete,
    required Duration expiresIn,
    required Duration interval,
  }) =>
      LlmXaiDeviceCode._(
        deviceCode: deviceCode,
        tokenEndpoint: tokenEndpoint,
        issuer: issuer,
        jwksUri: jwksUri,
        scope: scope,
        userCode: userCode,
        verificationUri: verificationUri,
        verificationUriComplete: verificationUriComplete,
        expiresIn: expiresIn,
        interval: interval,
      );
}

/// One-use OAuth authorization attempt. The state, nonce and verifier live in
/// memory until the matching loopback response is consumed.
class LlmOAuthAuthorizationAttempt {
  static const kimiCodeClientId = '17e5f671-d194-4dfb-9706-5516cb48c098';
  static const openferenceClientId = 'omniroute';
  static const openferenceScope =
      'openid profile email model:invoke offline_access';
  static const openAiIssuer = 'https://auth.openai.com';
  static const openAiResource = 'https://api.openai.com/v1';
  static const openAiDynamicClientId = 'dynamic_agent_client';
  static const openAiTokenEndpoint =
      'https://auth.openai.com/api/accounts/oauth/token';
  static const claudeCodeClientId = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
  static const claudeCodeTokenEndpoint =
      'https://platform.claude.com/v1/oauth/token';
  static const claudeCodeScope =
      'user:profile user:inference user:sessions:claude_code '
      'user:mcp_servers user:file_upload';
  static const geminiTokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const geminiScope = 'https://www.googleapis.com/auth/cloud-platform '
      'https://www.googleapis.com/auth/generative-language.retriever';

  final Uri redirectUri;
  final Uri authorizationUri;
  final String state;
  final String nonce;
  final String codeVerifier;
  final String? existingClientId;
  final bool isOpenAiRegistration;
  final bool _isClaudeCode;
  final bool _isDevin;
  final bool _isQoder;
  var _consumed = false;

  LlmOAuthAuthorizationAttempt._({
    required this.redirectUri,
    required this.authorizationUri,
    required this.state,
    required this.nonce,
    required this.codeVerifier,
    required this.existingClientId,
    required this.isOpenAiRegistration,
    bool isClaudeCode = false,
    bool isDevin = false,
    bool isQoder = false,
  })  : _isClaudeCode = isClaudeCode,
        _isDevin = isDevin,
        _isQoder = isQoder;

  factory LlmOAuthAuthorizationAttempt.openAiChatGpt({
    required Uri redirectUri,
    required String hostId,
    String? existingClientId,
    String? idTokenHint,
    String? loginHint,
  }) {
    _validateLoopbackRedirect(redirectUri, '/auth/callback');
    if (hostId.trim().isEmpty ||
        (existingClientId != null && existingClientId.trim().isEmpty) ||
        (existingClientId == openAiDynamicClientId)) {
      throw const LlmOAuthFlowException();
    }
    final state = _secureValue();
    final nonce = _secureValue();
    final verifier = _secureValue();
    final query = <String, String>{
      'client_id': existingClientId ?? openAiDynamicClientId,
      if (existingClientId == null) 'agent_name_hint': 'Stroom',
      'ext_agent_host_id': hostId,
      'response_type': 'code',
      'redirect_uri': redirectUri.toString(),
      'scope':
          'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct',
      'resource': openAiResource,
      'state': state,
      'nonce': nonce,
      'code_challenge_method': 'S256',
      'code_challenge': _challenge(verifier),
      if (existingClientId != null && idTokenHint != null)
        'id_token_hint': idTokenHint,
      if (existingClientId != null && loginHint != null)
        'login_hint': loginHint,
    };
    return LlmOAuthAuthorizationAttempt._(
      redirectUri: redirectUri,
      authorizationUri: Uri.https(
        'auth.openai.com',
        '/api/accounts/authorize',
        query,
      ),
      state: state,
      nonce: nonce,
      codeVerifier: verifier,
      existingClientId: existingClientId,
      isOpenAiRegistration: true,
    );
  }

  factory LlmOAuthAuthorizationAttempt.geminiDeveloperApi({
    required Uri redirectUri,
    required String clientId,
  }) {
    _validateLoopbackRedirect(redirectUri, '');
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) throw const LlmOAuthFlowException();
    final state = _secureValue();
    final nonce = _secureValue();
    final verifier = _secureValue();
    final query = <String, String>{
      'client_id': normalizedClientId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'code',
      'scope': geminiScope,
      'access_type': 'offline',
      'prompt': 'consent',
      'state': state,
      'code_challenge_method': 'S256',
      'code_challenge': _challenge(verifier),
    };
    return LlmOAuthAuthorizationAttempt._(
      redirectUri: redirectUri,
      authorizationUri: Uri.https(
        'accounts.google.com',
        '/o/oauth2/v2/auth',
        query,
      ),
      state: state,
      nonce: nonce,
      codeVerifier: verifier,
      existingClientId: normalizedClientId,
      isOpenAiRegistration: false,
    );
  }

  factory LlmOAuthAuthorizationAttempt.claudeCode({required Uri redirectUri}) {
    _validateLoopbackRedirect(
      redirectUri,
      '/callback',
      host: 'localhost',
      port: 54545,
    );
    final state = _secureValue();
    final verifier = _secureValue();
    final query = <String, String>{
      'code': 'true',
      'client_id': claudeCodeClientId,
      'response_type': 'code',
      'redirect_uri': redirectUri.toString(),
      'scope': claudeCodeScope,
      'code_challenge_method': 'S256',
      'code_challenge': _challenge(verifier),
      'state': state,
    };
    return LlmOAuthAuthorizationAttempt._(
      redirectUri: redirectUri,
      authorizationUri: Uri.https('claude.ai', '/oauth/authorize', query),
      state: state,
      nonce: '',
      codeVerifier: verifier,
      existingClientId: claudeCodeClientId,
      isOpenAiRegistration: false,
      isClaudeCode: true,
    );
  }

  /// Devin's CLI OAuth contract is PKCE based and has no public client ID.
  factory LlmOAuthAuthorizationAttempt.devin({required Uri redirectUri}) {
    _validateLoopbackRedirect(redirectUri, '/callback');
    final state = _secureValue();
    final verifier = _secureValue();
    return LlmOAuthAuthorizationAttempt._(
      redirectUri: redirectUri,
      authorizationUri: Uri.https('app.devin.ai', '/auth/cli/continue', {
        'redirect_uri': redirectUri.toString(),
        'state': state,
        'prompt': 'select_account',
        'code_challenge': _challenge(verifier),
        'code_challenge_method': 'S256',
      }),
      state: state,
      nonce: '',
      codeVerifier: verifier,
      existingClientId: null,
      isOpenAiRegistration: false,
      isDevin: true,
    );
  }

  /// Openference's public installed-app flow uses a fixed-port loopback
  /// callback and PKCE S256. The client id is public and is not a secret.
  factory LlmOAuthAuthorizationAttempt.openference({required Uri redirectUri}) {
    _validateLoopbackRedirect(redirectUri, '/callback', port: 56123);
    final state = _secureValue();
    final verifier = _secureValue();
    return LlmOAuthAuthorizationAttempt._(
      redirectUri: redirectUri,
      authorizationUri: Uri.https('openference.com', '/app/oauth/authorize', {
        'response_type': 'code',
        'client_id': openferenceClientId,
        'redirect_uri': redirectUri.toString(),
        'scope': openferenceScope,
        'code_challenge': _challenge(verifier),
        'code_challenge_method': 'S256',
        'state': state,
      }),
      state: state,
      nonce: '',
      codeVerifier: verifier,
      existingClientId: openferenceClientId,
      isOpenAiRegistration: false,
    );
  }

  /// Qoder's administrator-configured authorization-code flow has no PKCE
  /// contract. Its source uses these fixed phone-login parameters and the
  /// app's validated loopback redirect plus one-use state.
  factory LlmOAuthAuthorizationAttempt.qoder({
    required Uri redirectUri,
    required String authorizeUrl,
    required String clientId,
  }) {
    _validateLoopbackRedirect(redirectUri, '/auth/callback');
    final normalizedClientId = clientId.trim();
    final authorizationEndpoint = validateQoderOAuthEndpoint(authorizeUrl);
    if (normalizedClientId.isEmpty) throw const LlmOAuthFlowException();
    final state = _secureValue();
    return LlmOAuthAuthorizationAttempt._(
      redirectUri: redirectUri,
      authorizationUri: authorizationEndpoint.replace(
        queryParameters: {
          'loginMethod': 'phone',
          'type': 'phone',
          'redirect': redirectUri.toString(),
          'state': state,
          'client_id': normalizedClientId,
        },
      ),
      state: state,
      nonce: '',
      codeVerifier: '',
      existingClientId: normalizedClientId,
      isOpenAiRegistration: false,
      isQoder: true,
    );
  }

  /// Qoder OAuth endpoints are operator supplied; reject insecure or
  /// credential-bearing URLs before sending client secrets or authorization
  /// codes to them.
  static Uri validateQoderOAuthEndpoint(String raw) {
    final uri = Uri.tryParse(raw.trim());
    final host = uri?.host.toLowerCase() ?? '';
    final isIpv4 = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$').hasMatch(host);
    final isIpv6 = host.contains(':');
    if (uri == null ||
        uri.scheme != 'https' ||
        host.isEmpty ||
        host == 'localhost' ||
        host.endsWith('.local') ||
        isIpv4 ||
        isIpv6 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const LlmOAuthFlowException();
    }
    return uri;
  }

  LlmOAuthCallbackResult consumeCallback(Uri callbackUri) {
    if (_consumed) throw const LlmOAuthFlowException();
    if (!_sameCallbackTarget(callbackUri, redirectUri)) {
      throw const LlmOAuthFlowException();
    }
    final query = callbackUri.queryParametersAll;
    final states = query['state'];
    if (states == null ||
        states.length != 1 ||
        !_constantTimeEquals(states.single, state)) {
      throw const LlmOAuthFlowException();
    }
    _consumed = true;

    final errors = query['error'];
    if (errors != null || query.containsKey('error_description')) {
      throw const LlmOAuthFlowException();
    }
    final codes = query['code'];
    if (codes == null || codes.length != 1 || codes.single.trim().isEmpty) {
      throw const LlmOAuthFlowException();
    }
    var code = codes.single.trim();
    if (_isClaudeCode) {
      final codeStateSeparator = code.indexOf('#');
      if (codeStateSeparator >= 0) {
        final codeState = code.substring(codeStateSeparator + 1);
        if (codeState.isEmpty || !_constantTimeEquals(codeState, state)) {
          throw const LlmOAuthFlowException();
        }
        code = code.substring(0, codeStateSeparator);
      }
    }
    if (code.isEmpty) throw const LlmOAuthFlowException();
    final clientIds = query['client_id'];
    if (clientIds != null && clientIds.length != 1) {
      throw const LlmOAuthFlowException();
    }
    final returnedClientId = clientIds?.single;
    final clientId = returnedClientId ?? existingClientId;
    if (!_isDevin &&
        (clientId == null ||
            clientId.trim().isEmpty ||
            clientId == openAiDynamicClientId ||
            (existingClientId != null && clientId != existingClientId) ||
            (!_isQoder &&
                isOpenAiRegistration &&
                returnedClientId == null &&
                existingClientId == null))) {
      throw const LlmOAuthFlowException();
    }
    final scopes = query['scope'];
    if (scopes != null && scopes.length != 1) {
      throw const LlmOAuthFlowException();
    }
    return LlmOAuthCallbackResult(
      code: code,
      clientId: clientId,
      scope: scopes?.single,
    );
  }

  static String _secureValue() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _challenge(String verifier) => base64Url
      .encode(sha256.convert(utf8.encode(verifier)).bytes)
      .replaceAll('=', '');

  static void _validateLoopbackRedirect(
    Uri uri,
    String path, {
    String host = '127.0.0.1',
    int? port,
  }) {
    if (uri.scheme != 'http' ||
        uri.host != host ||
        (port == null ? uri.port < 1 : uri.port != port) ||
        uri.userInfo.isNotEmpty ||
        uri.path != path ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const LlmOAuthFlowException();
    }
  }

  static bool _sameCallbackTarget(Uri value, Uri expected) =>
      value.scheme == expected.scheme &&
      value.host == expected.host &&
      value.port == expected.port &&
      (value.path == expected.path ||
          (expected.path.isEmpty && value.path == '/')) &&
      value.userInfo.isEmpty &&
      !value.hasFragment;

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }
}
