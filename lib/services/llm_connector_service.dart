import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:googleapis_auth/googleapis_auth.dart'
    show ServiceAccountCredentials;
import 'package:uuid/uuid.dart';

import '../models/llm_account.dart';
import 'llm_account_migration_service.dart';
import 'llm_credential_store.dart';
import 'llm_connector_model_catalog.dart';

/// Frozen upstream implementation used to define this connector catalog.
const String kLlmConnectorReferenceRevision =
    'd318bcc3afb9ea8782862f5e8cdb541afdc9dfa5';

const _codexOAuthClientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
const _claudeOAuthClientId = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
const _kimiOAuthClientId = '17e5f671-d194-4dfb-9706-5516cb48c098';
const _xaiOAuthClientId = 'b1a00492-073a-47ea-816f-4c329264a828';

const kLlmAntigravityRequestUserAgent = 'antigravity/hub/2.9.1 darwin/arm64';

enum LlmNativeProtocol {
  openAIResponses,
  anthropicMessages,
  antigravityGenerateContent,
  kimiChatCompletions,
  xaiResponses,
  devinConnectRpc,
  metaResponses,
  geminiGenerateContent,
  geminiInteractions,
  aiStudioRelay,
  vertexGenerateContent,
  openAIChatCompletions,
}

enum LlmNativeTransport { http, websocketRelay }

enum LlmQuotaAvailability { accountQuota, requestUsageOnly, unknown }

class LlmConnectorDefinition {
  final String id;
  final String displayName;
  final LlmNativeProtocol protocol;
  final Set<String> authTypes;
  final List<String> modelCatalog;
  final bool canRefreshCredentials;
  final LlmQuotaAvailability quotaAvailability;

  const LlmConnectorDefinition({
    required this.id,
    required this.displayName,
    required this.protocol,
    required this.authTypes,
    this.modelCatalog = const [],
    this.canRefreshCredentials = false,
    this.quotaAvailability = LlmQuotaAvailability.unknown,
  });
}

/// Registry built from CLIProxyAPI's core auth-manager and executor
/// registrations at [kLlmConnectorReferenceRevision].
///
/// The aliases intentionally include the three Kimi identifiers registered by
/// the source. There is no Gemini CLI authenticator in that snapshot.
abstract final class LlmConnectorRegistry {
  static const List<LlmConnectorDefinition> all = [
    LlmConnectorDefinition(
      id: 'codex',
      displayName: 'OpenAI Codex',
      protocol: LlmNativeProtocol.openAIResponses,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedCodexModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.accountQuota,
    ),
    LlmConnectorDefinition(
      id: 'claude',
      displayName: 'Anthropic Claude Code',
      protocol: LlmNativeProtocol.anthropicMessages,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedClaudeModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'antigravity',
      displayName: 'Google Antigravity',
      protocol: LlmNativeProtocol.antigravityGenerateContent,
      authTypes: {'oauth'},
      modelCatalog: kPinnedAntigravityModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.accountQuota,
    ),
    LlmConnectorDefinition(
      id: 'kimi',
      displayName: 'Moonshot Kimi',
      protocol: LlmNativeProtocol.kimiChatCompletions,
      authTypes: {'oauth'},
      modelCatalog: kPinnedKimiModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'kimi-ai',
      displayName: 'Moonshot Kimi.ai',
      protocol: LlmNativeProtocol.kimiChatCompletions,
      authTypes: {'oauth'},
      modelCatalog: kPinnedKimiModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'kimi.ai',
      displayName: 'Moonshot Kimi.ai',
      protocol: LlmNativeProtocol.kimiChatCompletions,
      authTypes: {'oauth'},
      modelCatalog: kPinnedKimiModels,
      canRefreshCredentials: true,
    ),
    LlmConnectorDefinition(
      id: 'xai',
      displayName: 'xAI Grok Build',
      protocol: LlmNativeProtocol.xaiResponses,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedXaiModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'devin',
      displayName: 'Devin',
      protocol: LlmNativeProtocol.devinConnectRpc,
      authTypes: {'oauth', 'session_token'},
      modelCatalog: kPinnedDevinModels,
      quotaAvailability: LlmQuotaAvailability.accountQuota,
    ),
    LlmConnectorDefinition(
      id: 'meta',
      displayName: 'Meta Muse Code',
      protocol: LlmNativeProtocol.metaResponses,
      authTypes: {'oauth', 'api_key'},
      modelCatalog: kPinnedMetaModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'gemini',
      displayName: 'Google Gemini API',
      protocol: LlmNativeProtocol.geminiGenerateContent,
      authTypes: {'api_key'},
      modelCatalog: kPinnedGeminiModels,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'gemini-interactions',
      displayName: 'Google Gemini Interactions',
      protocol: LlmNativeProtocol.geminiInteractions,
      authTypes: {'api_key'},
      modelCatalog: kPinnedGeminiModels,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'aistudio',
      displayName: 'Google AI Studio relay',
      protocol: LlmNativeProtocol.aiStudioRelay,
      authTypes: {'relay'},
      modelCatalog: kPinnedAistudioModels,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'vertex',
      displayName: 'Google Vertex AI',
      protocol: LlmNativeProtocol.vertexGenerateContent,
      authTypes: {'service_account', 'api_key'},
      modelCatalog: kPinnedVertexModels,
      canRefreshCredentials: true,
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
    LlmConnectorDefinition(
      id: 'openai-compatibility',
      displayName: 'OpenAI-compatible endpoint',
      protocol: LlmNativeProtocol.openAIChatCompletions,
      authTypes: {'api_key', 'none'},
      quotaAvailability: LlmQuotaAvailability.requestUsageOnly,
    ),
  ];

  static LlmConnectorDefinition? find(String id) {
    final normalized = switch (id.trim().toLowerCase()) {
      'anthropic' => 'claude',
      'openai' => 'openai-compatibility',
      final value => value,
    };
    for (final connector in all) {
      if (connector.id == normalized) return connector;
    }
    return null;
  }

  /// M1 migrated legacy provider names before M2's provider registry existed.
  /// Keep those records routable while preserving their account IDs and refs.
  static String canonicalId(String id) => switch (id.trim()) {
        'anthropic' => 'claude',
        'openai' => 'openai-compatibility',
        final normalized => normalized,
      };
}

/// Result of a capability observation. Unknown quota is represented by a
/// null value and is never converted into an available or unlimited balance.
class LlmConnectorObservation {
  final LlmMetricObservation requestUsage;
  final LlmMetricObservation remainingQuota;
  final Map<String, LlmMetricObservation> quotaSignals;

  LlmConnectorObservation({
    this.requestUsage = const LlmMetricObservation.unknown(),
    this.remainingQuota = const LlmMetricObservation.unknown(),
    Map<String, LlmMetricObservation> quotaSignals = const {},
  }) : quotaSignals = Map.unmodifiable(quotaSignals);
}

/// Owns CRUD for M1 account records and their secure credential references.
/// Credentials are committed to secure storage before ordinary preferences are
/// updated. Mutations share the M1 transaction lease with migration and backup.
class LlmAccountConnectorService {
  final LlmAccountPreferences preferences;
  final LlmCredentialStore credentialStore;
  final Dio _dio;

  LlmAccountConnectorService({
    required this.preferences,
    required this.credentialStore,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  Future<List<LlmAccount>> listAccounts() async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    try {
      final records = await _readAccounts();
      return records.map(LlmAccount.fromMap).toList(growable: false);
    } on LlmAccountConnectorException {
      rethrow;
    } catch (_) {
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  Future<LlmAccount?> getAccount(String accountId) async {
    final accounts = await listAccounts();
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  Future<String?> readCredential(String accountId) async {
    final account = await getAccount(accountId);
    final reference = account?.credentialRef;
    if (reference == null) return null;
    try {
      return await credentialStore.read(reference);
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  /// Returns the persisted model mapping when present, otherwise the pinned
  /// upstream catalog. OpenAI-compatible endpoints and Gemini API keys can
  /// query their native model-list endpoint when [refreshRemote] is true.
  Future<List<LlmUpstreamModel>> discoverModels(
    LlmAccount account, {
    bool refreshRemote = false,
  }) async {
    account = _canonicalAccount(account);
    final savedAccount = await getAccount(account.id);
    if (savedAccount != null) {
      if (LlmConnectorRegistry.canonicalId(savedAccount.connectorType) !=
          account.connectorType) {
        throw const LlmAccountConnectorException();
      }
      account = savedAccount;
    }
    final connector = LlmConnectorRegistry.find(account.connectorType);
    if (connector == null || connector.id != account.connectorType) {
      throw const LlmAccountConnectorException();
    }
    final hasRemoteCatalog = account.connectorType == 'openai-compatibility' ||
        account.connectorType == 'gemini' ||
        account.connectorType == 'gemini-interactions';
    if (hasRemoteCatalog && savedAccount == null) {
      throw const LlmAccountConnectorException();
    }
    if (account.models.isNotEmpty && (!refreshRemote || !hasRemoteCatalog)) {
      return List.unmodifiable(account.models);
    }
    if (hasRemoteCatalog) {
      final discovered = await _discoverRemoteModels(account);
      return _mergeModelMappings(discovered, account.models);
    }
    return List.unmodifiable([
      for (var index = 0; index < connector.modelCatalog.length; index++)
        LlmUpstreamModel(
          id: '${account.id}:catalog:$index',
          upstreamModelId: connector.modelCatalog[index],
          displayName: connector.modelCatalog[index],
          config: const {
            'catalogSource': 'CLIProxyAPI@$kLlmConnectorReferenceRevision',
          },
        ),
    ]);
  }

  static List<LlmUpstreamModel> _mergeModelMappings(
    List<LlmUpstreamModel> discovered,
    List<LlmUpstreamModel> configured,
  ) {
    final merged = <String, LlmUpstreamModel>{};
    for (final model in discovered) {
      merged[model.upstreamModelId] = model;
    }
    for (final model in configured) {
      merged[model.upstreamModelId] = model;
    }
    return List.unmodifiable(merged.values);
  }

  /// Refreshes an OAuth credential using the provider's pinned refresh flow.
  /// Returns false for connectors that do not advertise token refresh.
  Future<bool> refreshCredential(LlmAccount suppliedAccount) async {
    suppliedAccount = _canonicalAccount(suppliedAccount);
    final account = await getAccount(suppliedAccount.id);
    if (account == null ||
        LlmConnectorRegistry.canonicalId(account.connectorType) !=
            suppliedAccount.connectorType) {
      throw const LlmAccountConnectorException();
    }
    final connector = LlmConnectorRegistry.find(account.connectorType);
    if (connector == null) throw const LlmAccountConnectorException();
    if (!connector.canRefreshCredentials) {
      return false;
    }
    final reference = account.credentialRef;
    if (reference == null) throw const LlmAccountConnectorException();
    final rawCredential = await _readSecureValue(reference);
    if (rawCredential == null) throw const LlmAccountConnectorException();
    final bundle = _decodeCredentialBundle(rawCredential);

    if (account.connectorType == 'vertex' &&
        account.authType == 'service_account') {
      return _refreshVertexServiceAccount(account, bundle);
    }
    if (account.connectorType == 'meta' && account.authType == 'oauth') {
      return _refreshMetaDca(account, bundle);
    }
    if (account.authType != 'oauth') return false;

    final refreshToken = _firstString(bundle, const [
      'refresh_token',
      'refreshToken',
    ]);
    if (refreshToken == null) return false;

    final spec = _refreshRequest(account, bundle, refreshToken);
    if (spec == null) return false;
    try {
      final response = await _dio.postUri<Object?>(
        spec.uri,
        data: spec.body,
        options: Options(
          headers: spec.headers,
          contentType: spec.contentType,
          responseType: ResponseType.json,
        ),
      );
      final tokenResponse = _asJsonMap(response.data);
      final accessToken = _firstString(tokenResponse, const [
        'access_token',
        'accessToken',
      ]);
      if (accessToken == null) throw const LlmAccountConnectorException();
      final freshFields = tokenResponse ?? const <String, dynamic>{};
      final updated = Map<String, dynamic>.from(bundle)
        ..addAll(freshFields)
        ..['access_token'] = accessToken;
      if (_firstString(updated, const ['refresh_token', 'refreshToken']) ==
          null) {
        updated['refresh_token'] = refreshToken;
      }
      final expiresIn = updated['expires_in'];
      final seconds = expiresIn is num
          ? expiresIn.toInt()
          : expiresIn is String
              ? int.tryParse(expiresIn)
              : null;
      if (seconds != null && seconds > 0) {
        final expiry = DateTime.now().toUtc().add(Duration(seconds: seconds));
        updated['expires_at'] = expiry.toIso8601String();
        updated['expired'] = expiry.toIso8601String();
      }
      await saveAccount(account, secret: jsonEncode(updated));
      return true;
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  /// Resolves and persists the account project required by Antigravity's
  /// native generation endpoint. Project identity is safe account metadata;
  /// the OAuth credential remains in secure storage.
  Future<LlmAccount> ensureAntigravityProjectId(
    LlmAccount suppliedAccount,
  ) async {
    final account = await getAccount(suppliedAccount.id);
    if (account == null ||
        account.connectorType != suppliedAccount.connectorType) {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType != 'antigravity') return account;
    final configuredProject = LlmNativeRequestBuilder._configString(
      account.endpointConfig,
      'projectId',
    );
    if (configuredProject != null) return account;

    final reference = account.credentialRef;
    if (reference == null) throw const LlmAccountConnectorException();
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        var rawCredential = await _readSecureValue(reference);
        if (rawCredential == null || rawCredential.trim().isEmpty) {
          throw const LlmAccountConnectorException();
        }
        var bundle = _decodeCredentialBundle(rawCredential);
        late final String token;
        try {
          token = LlmNativeRequestBuilder._credentialValue(
            account,
            rawCredential,
          );
        } on LlmAccountConnectorException {
          if (attempt == 0 && await refreshCredential(account)) continue;
          rethrow;
        }
        final expiryValue = bundle['expires_at'] ?? bundle['expired'];
        final expiry = expiryValue is String
            ? DateTime.tryParse(expiryValue)
            : expiryValue is num
                ? DateTime.fromMillisecondsSinceEpoch(
                    expiryValue.toInt() * 1000,
                    isUtc: true,
                  )
                : null;
        final isExpiring = expiry != null &&
            !expiry.isAfter(
              DateTime.now().toUtc().add(const Duration(seconds: 30)),
            );
        if (attempt == 0 && isExpiring) {
          if (!await refreshCredential(account)) {
            throw const LlmAccountConnectorException();
          }
          continue;
        }
        final uri = Uri.parse(
          'https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist',
        );
        final response = await _dio.postUri<Object?>(
          uri,
          data: const {
            'metadata': {'ideType': 'ANTIGRAVITY'},
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': '*/*',
              'User-Agent': kLlmAntigravityRequestUserAgent,
            },
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
            validateStatus: (status) => status != null,
          ),
        );
        final status = response.statusCode ?? 0;
        if (status == 401 && attempt == 0 && await refreshCredential(account)) {
          continue;
        }
        if (status < 200 || status >= 300) {
          throw const LlmAccountConnectorException();
        }
        final projectId = _antigravityProjectId(_asJsonMap(response.data));
        if (projectId == null) throw const LlmAccountConnectorException();

        final endpointConfig = Map<String, dynamic>.from(account.endpointConfig)
          ..['projectId'] = projectId;
        final updated = LlmAccount(
          id: account.id,
          connectorType: account.connectorType,
          authType: account.authType,
          displayName: account.displayName,
          status: account.status,
          credentialRef: account.credentialRef,
          endpointConfig: endpointConfig,
          models: account.models,
          policy: account.policy,
          usageByWindow: account.usageByWindow,
        );
        return saveAccount(updated);
      }
      throw const LlmAccountConnectorException();
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static String? _antigravityProjectId(Map<String, dynamic>? response) {
    final project = response?['cloudaicompanionProject'];
    if (project is String && project.trim().isNotEmpty) return project.trim();
    if (project is Map) {
      final id = project['id'] ?? project['projectId'] ?? project['project_id'];
      if (id is String && id.trim().isNotEmpty) return id.trim();
    }
    final direct = response?['projectId'] ?? response?['project_id'];
    return direct is String && direct.trim().isNotEmpty ? direct.trim() : null;
  }

  Future<bool> _refreshMetaDca(
    LlmAccount account,
    Map<String, dynamic> bundle,
  ) async {
    var dcaToken = _firstString(bundle, const ['dca_token', 'dcaToken']);
    final accessToken = _firstString(bundle, const [
      'access_token',
      'accessToken',
    ]);
    if (dcaToken == null && accessToken?.startsWith('dca:') == true) {
      dcaToken = accessToken;
    }
    if (dcaToken == null) return false;

    try {
      final response = await _dio.postUri<Object?>(
        Uri.parse('https://api.meta.ai/muse-code/key'),
        data: {'dca_token': dcaToken},
        options: Options(
          headers: {
            'Authorization': 'Bearer $dcaToken',
            'User-Agent': 'muse-code/1.0.2',
            'Accept': 'application/json',
          },
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );
      final minted = _asJsonMap(response.data);
      final apiKey = _firstString(minted, const ['api_key', 'apiKey']);
      if (apiKey == null) throw const LlmAccountConnectorException();
      final updated = Map<String, dynamic>.from(bundle)
        ..addAll(minted ?? const <String, dynamic>{})
        ..['api_key'] = apiKey
        ..['access_token'] = apiKey
        ..['dca_token'] = dcaToken;
      await saveAccount(account, secret: jsonEncode(updated));
      return true;
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  Future<bool> _refreshVertexServiceAccount(
    LlmAccount account,
    Map<String, dynamic> bundle,
  ) async {
    try {
      final serviceAccount = _serviceAccountCredential(bundle);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccount);
      const scope = 'https://www.googleapis.com/auth/cloud-platform';
      final issuedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = _base64UrlJson({'alg': 'RS256', 'typ': 'JWT'});
      final claims = _base64UrlJson({
        'iss': credentials.email,
        'scope': scope,
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': issuedAt,
        'exp': issuedAt + 3600,
      });
      final signingInput = '$header.$claims';
      final signature = base64Url
          .encode(credentials.sign(utf8.encode(signingInput)))
          .replaceAll('=', '');
      final assertion = '$signingInput.$signature';
      final response = await _dio.postUri<Object?>(
        Uri.parse('https://oauth2.googleapis.com/token'),
        data: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': assertion,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          responseType: ResponseType.json,
        ),
      );
      final tokenResponse = _asJsonMap(response.data);
      final accessToken = _firstString(tokenResponse, const ['access_token']);
      if (accessToken == null) throw const LlmAccountConnectorException();
      final updated = Map<String, dynamic>.from(bundle)
        ..addAll(tokenResponse ?? const <String, dynamic>{})
        ..['access_token'] = accessToken;
      final expiresIn = _intValue(updated['expires_in']);
      if (expiresIn != null && expiresIn > 0) {
        updated['expires_at'] = DateTime.now()
            .toUtc()
            .add(Duration(seconds: expiresIn))
            .toIso8601String();
      }
      await saveAccount(account, secret: jsonEncode(updated));
      return true;
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static Map<String, dynamic> _serviceAccountCredential(
    Map<String, dynamic> bundle,
  ) {
    final nested = bundle['service_account'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return bundle;
  }

  static String _base64UrlJson(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  static int? _intValue(Object? value) => value is num
      ? value.toInt()
      : value is String
          ? int.tryParse(value)
          : null;

  static Map<String, dynamic> _decodeCredentialBundle(String secret) {
    try {
      final decoded = jsonDecode(secret);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  static String? _firstString(Map<String, dynamic>? map, List<String> names) {
    if (map == null) return null;
    for (final name in names) {
      final value = map[name];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static _LlmTokenRefreshRequest? _refreshRequest(
    LlmAccount account,
    Map<String, dynamic> bundle,
    String refreshToken,
  ) {
    const formContentType = 'application/x-www-form-urlencoded';
    switch (account.connectorType) {
      case 'codex':
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://auth.openai.com/oauth/token'),
          body: {
            'client_id': _codexOAuthClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'scope': 'openid profile email',
          },
          contentType: formContentType,
        );
      case 'claude':
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://platform.claude.com/v1/oauth/token'),
          body: {
            'client_id': _claudeOAuthClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'scope':
                'user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload',
          },
          contentType: Headers.jsonContentType,
          headers: const {
            'Accept': 'application/json, text/plain, */*',
            'User-Agent': 'axios/1.15.2',
            'Cache-Control': 'no-cache',
          },
        );
      case 'antigravity':
        // OAuth application credentials stay in the secure account bundle.
        final clientId = _firstString(bundle, const ['client_id', 'clientId']);
        final clientSecret =
            _firstString(bundle, const ['client_secret', 'clientSecret']);
        if (clientId == null || clientSecret == null) return null;
        return _LlmTokenRefreshRequest(
          uri: Uri.parse('https://oauth2.googleapis.com/token'),
          body: {
            'client_id': clientId,
            'client_secret': clientSecret,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      case 'kimi' || 'kimi-ai' || 'kimi.ai':
        final domain = _firstString(bundle, const ['domain']) ??
            (account.connectorType == 'kimi' ? 'kimi.com' : 'kimi.ai');
        final host = domain.toLowerCase().contains('kimi.ai')
            ? 'auth.kimi.ai'
            : 'auth.kimi.com';
        return _LlmTokenRefreshRequest(
          uri: Uri.https(host, '/api/oauth/token'),
          body: {
            'client_id': _kimiOAuthClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      case 'xai':
        final endpoint = _firstString(bundle, const [
          'token_endpoint',
          'tokenEndpoint',
        ]);
        final uri = endpoint == null ? null : Uri.tryParse(endpoint);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.userInfo.isNotEmpty ||
            !(uri.host == 'auth.x.ai' || uri.host.endsWith('.auth.x.ai'))) {
          return null;
        }
        return _LlmTokenRefreshRequest(
          uri: uri,
          body: {
            'client_id': _xaiOAuthClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
          contentType: formContentType,
        );
      default:
        return null;
    }
  }

  Future<List<LlmUpstreamModel>> _discoverRemoteModels(
    LlmAccount account,
  ) async {
    _validateSafeConfig(account.endpointConfig);
    final isGemini = account.connectorType == 'gemini' ||
        account.connectorType == 'gemini-interactions';
    final fallbackBase =
        isGemini ? 'https://generativelanguage.googleapis.com' : null;
    final base = LlmNativeRequestBuilder._configString(
          account.endpointConfig,
          'baseUrl',
        ) ??
        fallbackBase;
    if (base == null || base.isEmpty) {
      throw const LlmAccountConnectorException();
    }
    final uri = _modelListUri(base, isGemini: isGemini);
    LlmNativeRequestBuilder._validateProviderBaseUrl(account, uri);
    final headers = <String, String>{'Accept': 'application/json'};
    final configuredHeaders = account.endpointConfig['headers'];
    if (configuredHeaders is Map) {
      for (final entry in configuredHeaders.entries) {
        if (entry.key is String && entry.value is String) {
          headers[entry.key as String] = entry.value as String;
        }
      }
    }
    final secret = account.credentialRef == null
        ? null
        : await _readSecureValue(account.credentialRef!);
    if (account.authType == 'api_key') {
      if (secret == null || secret.isEmpty) {
        throw const LlmAccountConnectorException();
      }
      final key = LlmNativeRequestBuilder._credentialValue(account, secret);
      if (isGemini) {
        headers['x-goog-api-key'] = key;
      } else {
        headers['Authorization'] = 'Bearer $key';
      }
    } else if (account.authType == 'none') {
      // OpenAI-compatible public or local endpoints may omit authentication.
    } else {
      throw const LlmAccountConnectorException();
    }

    try {
      final response = await _dio.getUri<Object?>(
        uri,
        options: Options(headers: headers),
      );
      final data = _asJsonMap(response.data);
      final rawModels = data?['data'] ?? data?['models'];
      if (rawModels is! List) return const [];
      final models = <LlmUpstreamModel>[];
      for (final raw in rawModels) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final rawId = map['id'] ?? map['name'];
        if (rawId is! String || rawId.trim().isEmpty) continue;
        final modelId = rawId.trim().replaceFirst(RegExp(r'^models/'), '');
        final methods = map['supportedGenerationMethods'];
        if (isGemini &&
            methods is List &&
            !methods.contains('generateContent') &&
            !methods.contains('streamGenerateContent')) {
          continue;
        }
        models.add(
          LlmUpstreamModel(
            id: '${account.id}:remote:${models.length}',
            upstreamModelId: modelId,
            displayName: (map['displayName'] ?? map['display_name']) is String
                ? (map['displayName'] ?? map['display_name']) as String
                : modelId,
            capabilities: {
              if (methods is List)
                'supportedGenerationMethods': List<String>.from(
                  methods.whereType<String>(),
                ),
            },
            config: const {'catalogSource': 'upstream_models_endpoint'},
          ),
        );
      }
      return List.unmodifiable(models);
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  Future<String?> _readSecureValue(String reference) async {
    try {
      return await credentialStore.read(reference);
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static Map<String, dynamic>? _asJsonMap(Object? data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Uri _modelListUri(String base, {required bool isGemini}) {
    final parsed = Uri.tryParse(base.trim());
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        (parsed.scheme != 'https' &&
            !(parsed.scheme == 'http' &&
                LlmNativeRequestBuilder._isLoopbackHost(parsed.host)))) {
      throw const LlmAccountConnectorException();
    }
    final path = parsed.path.replaceFirst(RegExp(r'/+$'), '');
    final suffix = isGemini ? '/v1beta/models' : '/models';
    final apiRoot = isGemini
        ? path
        : path.replaceFirst(RegExp(r'/(chat/completions|responses)$'), '');
    final requestPath = path.endsWith('/models')
        ? path
        : isGemini && path.endsWith('/v1beta')
            ? '$path/models'
            : '$apiRoot$suffix';
    return parsed.replace(path: requestPath, query: null, fragment: null);
  }

  /// Adds or updates an account. Pass [secret] to replace its secure value;
  /// omit it to retain the existing value. API/OAuth/service-account secrets
  /// never enter the account's endpoint configuration or preference record.
  Future<LlmAccount> saveAccount(LlmAccount account, {String? secret}) async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    String? reference;
    String? credentialToDelete;
    String? oldCredential;
    var credentialWasChanged = false;
    String? oldAccountJson;
    var preferencesWriteAttempted = false;
    try {
      account = _canonicalAccount(account);
      _validateAccount(account);
      if (secret != null) _validateCredential(account, secret);
      final currentRecords = await _readAccounts();
      oldAccountJson = await preferences.getString(
        LlmAccountMigrationService.accountsPreferenceKey,
      );
      final index = currentRecords.indexWhere(
        (record) => record['id'] == account.id,
      );
      final previous = index < 0 ? null : currentRecords[index];
      final previousReference = previous?['credentialRef'] as String?;
      if (previous != null &&
          (previous['authType'] != account.authType ||
              previous['connectorType'] != account.connectorType) &&
          _requiresSecret(account.authType) &&
          secret == null) {
        throw const LlmAccountConnectorException();
      }
      if (account.credentialRef != null && previousReference == null) {
        throw const LlmAccountConnectorException();
      }
      if (previousReference != null &&
          account.credentialRef != null &&
          account.credentialRef != previousReference) {
        throw const LlmAccountConnectorException();
      }
      reference = account.credentialRef ??
          previousReference ??
          _newCredentialReference(account.id);
      final otherOwners = currentRecords
          .where(
            (record) =>
                record['id'] != account.id &&
                record['credentialRef'] == reference,
          )
          .toList(growable: false);
      if (otherOwners.isNotEmpty && secret != null) {
        if (previousReference != reference) {
          throw const LlmAccountConnectorException();
        }
        reference = _newUniqueCredentialReference(account.id, currentRecords);
      } else if (otherOwners.isNotEmpty && previousReference != reference) {
        throw const LlmAccountConnectorException();
      }
      if (_requiresSecret(account.authType) &&
          secret == null &&
          account.credentialRef == null &&
          previous?['credentialRef'] == null) {
        throw const LlmAccountConnectorException();
      }
      if (secret != null && !_requiresSecret(account.authType)) {
        throw const LlmAccountConnectorException();
      }
      if (!_requiresSecret(account.authType) && previousReference != null) {
        final stillOwned = currentRecords.any(
          (record) =>
              record['id'] != account.id &&
              record['credentialRef'] == previousReference,
        );
        if (!stillOwned) {
          credentialToDelete = previousReference;
        }
      }

      if (secret != null) {
        if (secret.trim().isEmpty) {
          throw const LlmAccountConnectorException();
        }
        oldCredential = await credentialStore.read(reference);
        credentialWasChanged = true;
        await credentialStore.write(reference, secret);
        if (await credentialStore.read(reference) != secret) {
          throw const LlmAccountConnectorException();
        }
      } else if (_requiresSecret(account.authType)) {
        if (await credentialStore.read(reference) == null) {
          throw const LlmAccountConnectorException();
        }
      } else if (credentialToDelete != null) {
        oldCredential = await credentialStore.read(credentialToDelete);
      }

      final savedRecord = <String, dynamic>{...?previous, ...account.toMap()};
      if (_requiresSecret(account.authType)) {
        savedRecord['credentialRef'] = reference;
      } else {
        savedRecord.remove('credentialRef');
      }
      if (index < 0) {
        currentRecords.add(savedRecord);
      } else {
        currentRecords[index] = savedRecord;
      }
      final encoded = _encodeEnvelope(currentRecords);
      preferencesWriteAttempted = true;
      if (!await preferences.setString(
        LlmAccountMigrationService.accountsPreferenceKey,
        encoded,
      )) {
        throw const LlmAccountConnectorException();
      }
      if (await preferences.getString(
            LlmAccountMigrationService.accountsPreferenceKey,
          ) !=
          encoded) {
        throw const LlmAccountConnectorException();
      }
      if (credentialToDelete != null) {
        credentialWasChanged = true;
        await credentialStore.delete(credentialToDelete);
        if (await credentialStore.read(credentialToDelete) != null) {
          throw const LlmAccountConnectorException();
        }
      }
      return LlmAccount.fromMap(savedRecord);
    } catch (_) {
      if (preferencesWriteAttempted) {
        await _restorePreference(
          LlmAccountMigrationService.accountsPreferenceKey,
          oldAccountJson,
        );
      }
      if (credentialWasChanged && reference != null) {
        await _restoreCredential(reference, oldCredential);
      }
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  /// Deletes an account, an unshared secure credential and its group members.
  /// Stable model-group IDs are retained even when the removed account was the
  /// last member so callers can decide how to repair the group.
  Future<void> deleteAccount(String accountId) async {
    final lease =
        await LlmAccountMigrationService.acquireCredentialTransaction();
    final preferenceKeys = [
      LlmAccountMigrationService.accountsPreferenceKey,
      LlmAccountMigrationService.modelGroupsPreferenceKey,
    ];
    final snapshots = <String, String?>{};
    String? credentialReference;
    String? credentialValue;
    var preferenceWriteAttempted = false;
    try {
      if (accountId.trim().isEmpty) {
        throw const LlmAccountConnectorException();
      }
      for (final key in preferenceKeys) {
        snapshots[key] = await preferences.getString(key);
      }
      final accounts = await _readEnvelope(snapshots[preferenceKeys[0]]);
      final groups = await _readEnvelope(snapshots[preferenceKeys[1]]);
      final accountIndex = accounts.indexWhere(
        (item) => item['id'] == accountId,
      );
      if (accountIndex < 0) return;
      final removed = accounts.removeAt(accountIndex);
      credentialReference = removed['credentialRef'] as String?;
      if (credentialReference != null) {
        credentialValue = await credentialStore.read(credentialReference);
      }
      var groupsChanged = false;
      for (final group in groups) {
        final rawMembers = group['members'];
        if (rawMembers is! List) continue;
        final members = rawMembers
            .whereType<Map>()
            .where((member) => member['accountId'] != accountId)
            .toList();
        if (members.length != rawMembers.length) {
          group['members'] = members;
          groupsChanged = true;
        }
      }

      final encodedAccounts = _encodeEnvelope(accounts);
      final encodedGroups = _encodeEnvelope(groups);
      preferenceWriteAttempted = true;
      if (!await preferences.setString(preferenceKeys[0], encodedAccounts) ||
          (groupsChanged &&
              !await preferences.setString(preferenceKeys[1], encodedGroups))) {
        throw const LlmAccountConnectorException();
      }
      if (await preferences.getString(preferenceKeys[0]) != encodedAccounts ||
          (groupsChanged &&
              await preferences.getString(preferenceKeys[1]) !=
                  encodedGroups)) {
        throw const LlmAccountConnectorException();
      }
      final hasRemainingOwner = credentialReference != null &&
          accounts.any(
            (record) => record['credentialRef'] == credentialReference,
          );
      if (credentialReference != null && !hasRemainingOwner) {
        await credentialStore.delete(credentialReference);
        if (await credentialStore.read(credentialReference) != null) {
          throw const LlmAccountConnectorException();
        }
      }
    } catch (_) {
      if (preferenceWriteAttempted) {
        for (final entry in snapshots.entries) {
          await _restorePreference(entry.key, entry.value);
        }
      }
      if (credentialReference != null && credentialValue != null) {
        await _restoreCredential(credentialReference, credentialValue);
      }
      throw const LlmAccountConnectorException();
    } finally {
      lease.release();
    }
  }

  Future<List<Map<String, dynamic>>> _readAccounts() async {
    final records = await _readEnvelope(
      await preferences.getString(
        LlmAccountMigrationService.accountsPreferenceKey,
      ),
    );
    for (final record in records) {
      final rawType = record['connectorType'];
      if (rawType is! String) continue;
      final canonicalType = LlmConnectorRegistry.canonicalId(rawType);
      if (canonicalType == rawType) continue;
      record['connectorType'] = canonicalType;
      final rawConfig = record['endpointConfig'];
      final config = rawConfig is Map
          ? Map<String, dynamic>.from(rawConfig)
          : <String, dynamic>{};
      if ((canonicalType == 'claude' ||
              canonicalType == 'openai-compatibility') &&
          config['baseUrl'] == null &&
          config['host'] is String &&
          (config['host'] as String).trim().isNotEmpty) {
        config['baseUrl'] = (config['host'] as String).trim();
      }
      record['endpointConfig'] = config;
    }
    return records;
  }

  Future<List<Map<String, dynamic>>> _readEnvelope(String? encoded) async {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map || decoded['items'] is! List) {
        throw const LlmAccountConnectorException();
      }
      final records = <Map<String, dynamic>>[];
      final ids = <String>{};
      for (final item in decoded['items'] as List) {
        if (item is! Map) throw const LlmAccountConnectorException();
        final record = Map<String, dynamic>.from(item);
        final id = record['id'];
        if (id is! String || id.isEmpty || !ids.add(id)) {
          throw const LlmAccountConnectorException();
        }
        records.add(record);
      }
      return records;
    } on LlmAccountConnectorException {
      rethrow;
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  String _newCredentialReference(String accountId) =>
      'stroom.llm.credential.${Uri.encodeComponent(accountId)}';

  String _newUniqueCredentialReference(
    String accountId,
    List<Map<String, dynamic>> records,
  ) {
    final existing = records
        .map((record) => record['credentialRef'])
        .whereType<String>()
        .toSet();
    String reference;
    do {
      reference =
          '${_newCredentialReference(accountId)}.rotation.${const Uuid().v4()}';
    } while (existing.contains(reference));
    return reference;
  }

  static LlmAccount _canonicalAccount(LlmAccount account) {
    final connectorType = LlmConnectorRegistry.canonicalId(
      account.connectorType,
    );
    if (connectorType == account.connectorType) return account;
    final endpointConfig = Map<String, dynamic>.from(account.endpointConfig);
    if ((connectorType == 'claude' ||
            connectorType == 'openai-compatibility') &&
        endpointConfig['baseUrl'] == null &&
        endpointConfig['host'] is String &&
        (endpointConfig['host'] as String).trim().isNotEmpty) {
      endpointConfig['baseUrl'] = (endpointConfig['host'] as String).trim();
    }
    return LlmAccount(
      id: account.id,
      connectorType: connectorType,
      authType: account.authType,
      displayName: account.displayName,
      status: account.status,
      credentialRef: account.credentialRef,
      endpointConfig: endpointConfig,
      models: account.models,
      policy: account.policy,
      usageByWindow: account.usageByWindow,
    );
  }

  Future<void> _restorePreference(String key, String? oldValue) async {
    try {
      if (oldValue == null) {
        await preferences.remove(key);
      } else {
        await preferences.setString(key, oldValue);
      }
    } catch (_) {
      // Keep the public error generic; the credential remains in secure storage
      // if rollback cannot safely establish the former state.
    }
  }

  Future<void> _restoreCredential(String reference, String? oldValue) async {
    try {
      if (oldValue == null) {
        await credentialStore.delete(reference);
      } else {
        await credentialStore.write(reference, oldValue);
        if (await credentialStore.read(reference) != oldValue) return;
      }
    } catch (_) {
      // Storage exception text may contain provider data; never forward it.
    }
  }

  static String _encodeEnvelope(List<Map<String, dynamic>> items) =>
      jsonEncode({'version': 1, 'items': items});

  static bool _requiresSecret(String authType) =>
      authType == 'api_key' ||
      authType == 'oauth' ||
      authType == 'service_account' ||
      authType == 'session_token';

  static void _validateAccount(LlmAccount account) {
    final connector = LlmConnectorRegistry.find(account.connectorType);
    if (account.id.trim().isEmpty ||
        account.displayName.trim().isEmpty ||
        connector == null ||
        connector.id !=
            LlmConnectorRegistry.canonicalId(account.connectorType) ||
        !connector.authTypes.contains(account.authType)) {
      throw const LlmAccountConnectorException();
    }
    _validateSafeConfig(account.endpointConfig);
    for (final model in account.models) {
      _validateCredentialFreeModelData(model.capabilities);
      _validateCredentialFreeModelData(model.config);
    }
  }

  static void _validateCredential(LlmAccount account, String secret) {
    if (account.connectorType != 'vertex' ||
        account.authType != 'service_account') {
      return;
    }
    try {
      final decoded = jsonDecode(secret);
      final serviceAccount = decoded is Map && decoded['service_account'] is Map
          ? decoded['service_account']
          : decoded;
      ServiceAccountCredentials.fromJson(serviceAccount);
    } catch (_) {
      throw const LlmAccountConnectorException();
    }
  }

  static void _validateSafeConfig(Object? value) {
    const forbiddenKeys = {
      'key',
      'apikey',
      'accesskey',
      'accesstoken',
      'refreshtoken',
      'token',
      'secret',
      'password',
      'authorization',
      'credential',
      'privatekey',
      'clientsecret',
      'cookie',
      'sig',
      'signature',
    };
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (forbiddenKeys.contains(normalized) ||
            normalized.endsWith('key') ||
            normalized.endsWith('sig') ||
            normalized.contains('apikey') ||
            normalized.contains('accesskey') ||
            normalized.contains('token') ||
            normalized.contains('secret') ||
            normalized.contains('password') ||
            normalized.contains('auth') ||
            normalized.contains('credential') ||
            normalized.contains('authorization') ||
            normalized.contains('privatekey') ||
            normalized.contains('signature') ||
            normalized.contains('cookie')) {
          throw const LlmAccountConnectorException();
        }
        if (normalized == 'baseurl' && entry.value is String) {
          final uri = Uri.tryParse((entry.value as String).trim());
          if (uri == null || uri.userInfo.isNotEmpty || uri.hasFragment) {
            throw const LlmAccountConnectorException();
          }
          const sensitiveQueryKeys = {
            'key',
            'apikey',
            'accesskey',
            'accesstoken',
            'refreshtoken',
            'token',
            'secret',
            'password',
            'authorization',
            'credential',
            'sig',
            'signature',
          };
          if (uri.queryParameters.keys.any((key) {
            final normalizedQueryKey = key.toLowerCase().replaceAll(
                  RegExp(r'[^a-z]'),
                  '',
                );
            return sensitiveQueryKeys.contains(normalizedQueryKey) ||
                normalizedQueryKey.contains('apikey') ||
                normalizedQueryKey.contains('accesskey') ||
                normalizedQueryKey.contains('token') ||
                normalizedQueryKey.contains('secret') ||
                normalizedQueryKey.contains('password') ||
                normalizedQueryKey.contains('auth') ||
                normalizedQueryKey.contains('authorization') ||
                normalizedQueryKey.contains('credential') ||
                normalizedQueryKey.contains('privatekey') ||
                normalizedQueryKey.contains('signature') ||
                normalizedQueryKey.endsWith('key') ||
                normalizedQueryKey.endsWith('sig') ||
                normalizedQueryKey.contains('cookie');
          })) {
            throw const LlmAccountConnectorException();
          }
        }
        _validateSafeConfig(entry.value);
      }
    } else if (value is Iterable && value is! String) {
      for (final item in value) {
        _validateSafeConfig(item);
      }
    }
  }

  static void _validateCredentialFreeModelData(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final normalized = entry.key.toString().toLowerCase().replaceAll(
              RegExp(r'[^a-z]'),
              '',
            );
        if (normalized == 'key' ||
            normalized.endsWith('key') ||
            normalized == 'token' ||
            normalized.startsWith('token') ||
            normalized.endsWith('token') ||
            normalized.endsWith('sig') ||
            normalized.contains('signature') ||
            normalized.contains('apikey') ||
            normalized.contains('accesskey') ||
            normalized.contains('secret') ||
            normalized.contains('password') ||
            normalized.contains('auth') ||
            normalized.contains('authorization') ||
            normalized.contains('credential') ||
            normalized.contains('privatekey') ||
            normalized.contains('cookie')) {
          throw const LlmAccountConnectorException();
        }
        if ({'baseurl', 'endpointurl', 'url'}.contains(normalized) &&
            entry.value is String) {
          _validateSafeConfig({'baseUrl': entry.value});
        }
        _validateCredentialFreeModelData(entry.value);
      }
    } else if (value is Iterable && value is! String) {
      for (final item in value) {
        _validateCredentialFreeModelData(item);
      }
    }
  }
}

/// Prepared native request. Its diagnostic string omits header values and the
/// body because both may contain secrets or private prompt content.
class LlmPreparedNativeRequest {
  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final Object? body;
  final LlmNativeTransport transport;

  LlmPreparedNativeRequest({
    required this.uri,
    required this.method,
    required Map<String, String> headers,
    required this.body,
    this.transport = LlmNativeTransport.http,
  }) : headers = Map.unmodifiable(headers);

  @override
  String toString() {
    final safeUri = uri.replace(
      userInfo: uri.userInfo.isEmpty ? '' : '<redacted>',
      path: uri.path.isEmpty ? '' : '/<redacted>',
      query: uri.hasQuery ? '<redacted>' : null,
      fragment: null,
    );
    return 'LlmPreparedNativeRequest(method: $method, uri: $safeUri, '
        'headerNames: ${headers.keys.toList()}, body: <omitted>)';
  }
}

/// Builds provider-native HTTP request paths and authentication headers from
/// account data. Request bodies are already in that connector's native format;
/// this class does not translate between client protocols.
class LlmNativeRequestBuilder {
  static const _defaultJsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  LlmPreparedNativeRequest build({
    required LlmAccount account,
    required String? credential,
    required String modelId,
    required Object? body,
    bool stream = false,
    String? nativeFormat,
  }) {
    final connector = LlmConnectorRegistry.find(account.connectorType);
    if (connector == null ||
        connector.id != account.connectorType ||
        !connector.authTypes.contains(account.authType) ||
        (stream && account.connectorType == 'devin') ||
        (stream &&
            _isVertexImagen(
              account,
              modelId,
              config: account.endpointConfig,
              nativeFormat: nativeFormat,
            ))) {
      throw const LlmAccountConnectorException();
    }
    LlmAccountConnectorService._validateSafeConfig(account.endpointConfig);

    final headers = <String, String>{..._defaultJsonHeaders};
    final secret = _credentialValue(account, credential);
    final config = account.endpointConfig;
    final configuredHeaders = config['headers'];
    if (configuredHeaders is Map) {
      for (final entry in configuredHeaders.entries) {
        if (entry.key is String && entry.value is String) {
          headers[entry.key as String] = entry.value as String;
        }
      }
    }

    final uri = _buildUri(
      account: account,
      config: config,
      credential: credential,
      modelId: modelId,
      stream: stream,
      nativeFormat: nativeFormat,
    );
    switch (account.connectorType) {
      case 'claude':
        if (account.authType == 'api_key') {
          headers['x-api-key'] = secret;
        } else {
          headers['Authorization'] = 'Bearer $secret';
          headers['anthropic-beta'] = 'oauth-2025-04-20,claude-code-20250219';
        }
        headers['anthropic-version'] = '2023-06-01';
        headers['X-App'] = 'cli';
        break;
      case 'codex':
        if (account.authType == 'oauth') {
          final accountId = _credentialBundleString(credential, const [
            'account_id',
            'accountId',
          ]);
          if (accountId != null) {
            headers['Chatgpt-Account-Id'] = accountId;
          }
        }
        if (secret.isNotEmpty) headers['Authorization'] = 'Bearer $secret';
        break;
      case 'gemini':
        if (account.authType == 'api_key') {
          headers['x-goog-api-key'] = secret;
        }
        break;
      case 'gemini-interactions':
        headers.putIfAbsent('Api-Revision', () => '2026-05-20');
        if (account.authType == 'api_key') {
          headers['x-goog-api-key'] = secret;
        }
        break;
      case 'vertex':
        if (_usesVertexInteractions(config, nativeFormat)) {
          headers.putIfAbsent('Api-Revision', () => '2026-05-20');
        }
        if (account.authType == 'api_key') {
          headers['x-goog-api-key'] = secret;
        } else if (account.authType == 'service_account') {
          headers['Authorization'] = 'Bearer $secret';
        }
        break;
      case 'meta':
        headers['Authorization'] = 'Bearer $secret';
        headers['User-Agent'] =
            'muse-build/1.3.0 (interactive; macos-aarch64; build ac7280f2aca67769d1455a8847bb502b617d50f6)';
        headers['X-Client-Id'] = 'tbh:tui';
        break;
      case 'antigravity':
        headers['Authorization'] = 'Bearer $secret';
        headers['User-Agent'] = kLlmAntigravityRequestUserAgent;
        break;
      case 'devin':
        headers['Authorization'] = 'Basic $secret-$secret';
        headers['Connect-Protocol-Version'] = '1';
        headers['Content-Type'] = 'application/connect+proto';
        headers['Accept'] = 'application/connect+proto';
        break;
      case 'aistudio':
        break;
      default:
        if (secret.isNotEmpty) headers['Authorization'] = 'Bearer $secret';
        break;
    }
    if (stream) headers['Accept'] = 'text/event-stream';

    return LlmPreparedNativeRequest(
      uri: uri,
      method: 'POST',
      headers: headers,
      body: account.connectorType == 'antigravity'
          ? _antigravityPayload(account, credential, modelId, body)
          : _isVertexImagen(
              account,
              modelId,
              config: config,
              nativeFormat: nativeFormat,
            )
              ? _vertexImagenPayload(body)
              : _applyBodyStreamOption(
                  account: account,
                  config: config,
                  body: body,
                  stream: stream,
                  nativeFormat: nativeFormat,
                ),
      transport: account.connectorType == 'aistudio'
          ? LlmNativeTransport.websocketRelay
          : LlmNativeTransport.http,
    );
  }

  static Object? _applyBodyStreamOption({
    required LlmAccount account,
    required Map<String, dynamic> config,
    required Object? body,
    required bool stream,
    required String? nativeFormat,
  }) {
    if (!_usesBodyStreamOption(account, config, nativeFormat)) return body;
    if (body is! Map) {
      if (stream) throw const LlmAccountConnectorException();
      return body;
    }
    if (!stream && !body.containsKey('stream')) return body;
    return Map<String, dynamic>.from(body)..['stream'] = stream;
  }

  static bool _usesBodyStreamOption(
    LlmAccount account,
    Map<String, dynamic> config,
    String? nativeFormat,
  ) =>
      switch (account.connectorType) {
        'codex' ||
        'claude' ||
        'kimi' ||
        'kimi-ai' ||
        'kimi.ai' ||
        'xai' ||
        'meta' ||
        'gemini-interactions' ||
        'openai-compatibility' =>
          true,
        'vertex' => _usesVertexInteractions(config, nativeFormat),
        _ => false,
      };

  static String _credentialValue(LlmAccount account, String? credential) {
    if (account.authType == 'none' || account.authType == 'relay') return '';
    if (credential == null || credential.trim().isEmpty) {
      throw const LlmAccountConnectorException();
    }
    Object? decoded;
    var isJson = false;
    try {
      decoded = jsonDecode(credential);
      isJson = true;
    } catch (_) {
      // API keys and session tokens are commonly stored as opaque strings.
    }
    if (isJson && decoded is Map) {
      final candidates = switch (account.authType) {
        'api_key' => const ['api_key', 'apiKey', 'key'],
        'oauth' => account.connectorType == 'meta'
            ? const ['api_key', 'apiKey', 'access_token', 'accessToken']
            : const ['access_token', 'accessToken'],
        'session_token' => const [
            'session_token',
            'sessionToken',
            'access_token',
            'accessToken',
          ],
        'service_account' => const ['access_token', 'accessToken'],
        _ => const <String>[],
      };
      for (final key in candidates) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) {
          if (account.connectorType == 'meta' &&
              account.authType == 'oauth' &&
              value.startsWith('dca:') &&
              decoded['api_key'] == null) {
            break;
          }
          return value;
        }
      }
      throw const LlmAccountConnectorException();
    }
    if (isJson && (account.authType != 'api_key' || decoded is! num)) {
      throw const LlmAccountConnectorException();
    }
    if (account.authType == 'service_account') {
      throw const LlmAccountConnectorException();
    }
    if (account.connectorType == 'meta' &&
        account.authType == 'oauth' &&
        credential.trim().startsWith('dca:')) {
      throw const LlmAccountConnectorException();
    }
    if (account.authType != 'api_key' &&
        account.authType != 'oauth' &&
        account.authType != 'session_token') {
      throw const LlmAccountConnectorException();
    }
    return credential;
  }

  static String? _credentialBundleString(
    String? credential,
    List<String> keys,
  ) {
    if (credential == null) return null;
    try {
      final decoded = jsonDecode(credential);
      if (decoded is! Map) return null;
      for (final key in keys) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    } catch (_) {
      // Opaque credential strings have no ancillary account identity fields.
    }
    return null;
  }

  static Map<String, dynamic> _antigravityPayload(
    LlmAccount account,
    String? credential,
    String modelId,
    Object? body,
  ) {
    if (body is! Map) throw const LlmAccountConnectorException();
    final payload = Map<String, dynamic>.from(body);
    final requestValue = payload['request'];
    final request = requestValue is Map
        ? Map<String, dynamic>.from(requestValue)
        : <String, dynamic>{};
    payload['model'] = modelId;
    payload['userAgent'] = 'antigravity';
    var requestType = payload['requestType'];
    if (requestType is! String || requestType.trim().isEmpty) {
      requestType =
          modelId.toLowerCase().contains('image') ? 'image_gen' : 'agent';
      payload['requestType'] = requestType;
    }
    final projectId = _configString(account.endpointConfig, 'projectId') ??
        _projectIdFromCredential(credential);
    if (projectId == null || projectId.isEmpty) {
      payload.remove('project');
    } else {
      payload['project'] = projectId;
    }
    final isImageModel = modelId.toLowerCase().contains('image');
    if (isImageModel) {
      payload['requestId'] =
          'image_gen/${DateTime.now().millisecondsSinceEpoch}/'
          '${const Uuid().v4()}/12';
    } else if (requestType != 'web_search') {
      payload['requestId'] = 'agent-${const Uuid().v4()}';
      final sessionId = request['sessionId'];
      if (sessionId is! String || sessionId.trim().isEmpty) {
        request['sessionId'] = _antigravitySessionId(request);
      }
    }
    request.remove('safetySettings');
    if (payload['toolConfig'] != null && request['toolConfig'] == null) {
      request['toolConfig'] = payload.remove('toolConfig');
    }
    payload['request'] = request;
    return payload;
  }

  static String _antigravitySessionId(Map<String, dynamic> request) {
    final contents = request['contents'];
    if (contents is List) {
      for (final content in contents) {
        if (content is! Map || content['role'] != 'user') continue;
        final parts = content['parts'];
        if (parts is! List || parts.isEmpty || parts.first is! Map) continue;
        final text = (parts.first as Map)['text'];
        if (text is! String || text.isEmpty) continue;
        final digest = crypto.sha256.convert(utf8.encode(text)).bytes;
        var value = 0;
        for (var index = 0; index < 8; index++) {
          value = (value << 8) | digest[index];
        }
        value &= 0x7fffffffffffffff;
        return '-$value';
      }
    }
    final random = const Uuid().v4().replaceAll('-', '').substring(0, 15);
    return '-${int.parse(random, radix: 16)}';
  }

  static String? _projectIdFromCredential(String? credential) {
    if (credential == null) return null;
    try {
      final decoded = jsonDecode(credential);
      if (decoded is! Map) return null;
      final serviceAccount = decoded['service_account'] is Map
          ? decoded['service_account'] as Map
          : decoded;
      final value = serviceAccount['project_id'] ?? serviceAccount['projectId'];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    } catch (_) {
      return null;
    }
  }

  static Uri _buildUri({
    required LlmAccount account,
    required Map<String, dynamic> config,
    required String? credential,
    required String modelId,
    required bool stream,
    required String? nativeFormat,
  }) {
    String baseUrl;
    String path;
    String? query;
    switch (account.connectorType) {
      case 'codex':
        baseUrl = _baseUrl(
          config,
          account.authType == 'oauth'
              ? 'https://chatgpt.com/backend-api/codex'
              : 'https://api.openai.com/v1',
        );
        path = '/responses';
      case 'claude':
        baseUrl = _baseUrl(config, 'https://api.anthropic.com');
        path = '/v1/messages';
        if (account.authType == 'oauth') query = 'beta=true';
      case 'antigravity':
        baseUrl = _baseUrl(config, 'https://cloudcode-pa.googleapis.com');
        path = stream
            ? '/v1internal:streamGenerateContent'
            : '/v1internal:generateContent';
        if (stream) query = 'alt=sse';
      case 'kimi' || 'kimi-ai' || 'kimi.ai':
        baseUrl = _baseUrl(
          config,
          account.connectorType == 'kimi'
              ? 'https://api.kimi.com/coding'
              : 'https://api.kimi.ai/coding',
        );
        path = switch (nativeFormat) {
          'responses' => '/v1/responses',
          'anthropic' => '/v1/messages',
          _ => '/v1/chat/completions',
        };
      case 'xai':
        baseUrl = _baseUrl(
          config,
          account.authType == 'oauth'
              ? 'https://cli-chat-proxy.grok.com/v1'
              : 'https://api.x.ai/v1',
        );
        path = '/responses';
      case 'devin':
        baseUrl = _baseUrl(config, 'https://server.codeium.com');
        path = '/exa.api_server_pb.ApiServerService/GetChatMessage';
      case 'meta':
        baseUrl = _baseUrl(
          config,
          _metaBaseUrl(credential) ?? 'https://api.meta.ai/v1',
        );
        path = '/responses';
      case 'gemini':
        baseUrl = _baseUrl(config, 'https://generativelanguage.googleapis.com');
        path = '/v1beta/models/${Uri.encodeComponent(modelId)}:'
            '${stream ? 'streamGenerateContent' : 'generateContent'}';
        if (stream) query = 'alt=sse';
      case 'gemini-interactions':
        baseUrl = _baseUrl(config, 'https://generativelanguage.googleapis.com');
        path = '/v1beta/interactions';
        if (stream) query = 'alt=sse';
      case 'aistudio':
        baseUrl = _baseUrl(config, 'https://generativelanguage.googleapis.com');
        path = '/v1beta/models/${Uri.encodeComponent(modelId)}:'
            '${stream ? 'streamGenerateContent' : 'generateContent'}';
        if (stream) query = 'alt=sse';
      case 'vertex':
        if (_usesVertexInteractions(config, nativeFormat)) {
          final projectId = _configString(config, 'projectId') ??
              _projectIdFromCredential(credential);
          baseUrl = _baseUrl(config, 'https://aiplatform.googleapis.com');
          path = projectId == null || projectId.isEmpty
              ? '/v1beta1/interactions'
              : '/v1beta1/projects/${Uri.encodeComponent(projectId)}'
                  '/locations/global/interactions';
          if (stream) query = 'alt=sse';
          break;
        }
        final location = _configString(config, 'location') ?? 'us-central1';
        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(location)) {
          throw const LlmAccountConnectorException();
        }
        baseUrl = _baseUrl(
          config,
          location == 'global'
              ? 'https://aiplatform.googleapis.com'
              : 'https://$location-aiplatform.googleapis.com',
        );
        final projectId = _configString(config, 'projectId') ??
            _projectIdFromCredential(credential);
        final model = Uri.encodeComponent(modelId);
        final action = _isVertexImagen(
          account,
          modelId,
          config: config,
          nativeFormat: nativeFormat,
        )
            ? 'predict'
            : stream
                ? 'streamGenerateContent'
                : 'generateContent';
        if (projectId == null || projectId.isEmpty) {
          path = '/v1/publishers/google/models/$model:$action';
        } else {
          path = '/v1/projects/${Uri.encodeComponent(projectId)}'
              '/locations/${Uri.encodeComponent(location)}'
              '/publishers/google/models/$model:$action';
        }
        if (stream) query = 'alt=sse';
      case 'openai-compatibility':
        baseUrl = _baseUrl(config, '');
        final baseUri = Uri.tryParse(baseUrl);
        if (baseUri == null ||
            !baseUri.hasScheme ||
            baseUri.host.isEmpty ||
            (baseUri.scheme != 'https' && baseUri.scheme != 'http') ||
            baseUri.userInfo.isNotEmpty) {
          throw const LlmAccountConnectorException();
        }
        final endpointPath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
        if (endpointPath.endsWith('/chat/completions')) {
          path = '';
        } else {
          path = '/chat/completions';
        }
      default:
        throw const LlmAccountConnectorException();
    }
    final base = _baseUrl(config, baseUrl);
    final parsed = Uri.tryParse(base);
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        !_isBaseSchemeAllowed(account, parsed)) {
      throw const LlmAccountConnectorException();
    }
    _validateProviderBaseUrl(account, parsed);
    final basePath = account.connectorType == 'openai-compatibility'
        ? parsed.path.replaceFirst(RegExp(r'/+$'), '')
        : parsed.path;
    final joinedPath = _joinPath(basePath, path);
    final queryParameters = <String, dynamic>{
      ...parsed.queryParametersAll,
      if (query != null) ...Uri.splitQueryString(query),
    };
    if (queryParameters.isEmpty) {
      return parsed.replace(path: joinedPath, fragment: null);
    }
    return parsed.replace(
      path: joinedPath,
      queryParameters: queryParameters,
      fragment: null,
    );
  }

  static bool _isBaseSchemeAllowed(LlmAccount account, Uri base) {
    if (account.connectorType == 'openai-compatibility') {
      return base.scheme == 'https' ||
          (base.scheme == 'http' && _isLoopbackHost(base.host));
    }
    return base.scheme == 'https' ||
        (base.scheme == 'http' && _isLoopbackHost(base.host));
  }

  static bool _isLoopbackHost(String host) {
    final normalized =
        host.toLowerCase().replaceAll('[', '').replaceAll(']', '');
    if (normalized == 'localhost' || normalized == '::1') return true;
    final octets = normalized.split('.');
    if (octets.length != 4 || octets.first != '127') return false;
    return octets.every((octet) {
      final value = int.tryParse(octet);
      return value != null && value >= 0 && value <= 255;
    });
  }

  static bool _usesVertexInteractions(
    Map<String, dynamic> config,
    String? nativeFormat,
  ) {
    if (nativeFormat != 'interactions') return false;
    final value = config['interactions'];
    if (value is bool) return value;
    if (value is String) {
      return value.trim().toLowerCase() == 'true' || value.trim() == '1';
    }
    return false;
  }

  static bool _isVertexImagen(
    LlmAccount account,
    String modelId, {
    required Map<String, dynamic> config,
    required String? nativeFormat,
  }) =>
      account.connectorType == 'vertex' &&
      !_usesVertexInteractions(config, nativeFormat) &&
      modelId.toLowerCase().contains('imagen');

  static Map<String, dynamic> _vertexImagenPayload(Object? body) {
    if (body is! Map) throw const LlmAccountConnectorException();

    String? prompt;
    final contents = body['contents'];
    if (contents is List && contents.isNotEmpty && contents.first is Map) {
      final parts = (contents.first as Map)['parts'];
      if (parts is List && parts.isNotEmpty && parts.first is Map) {
        final text = (parts.first as Map)['text'];
        if (text is String && text.isNotEmpty) prompt = text;
      }
    }
    if (prompt == null) {
      final messages = body['messages'];
      if (messages is List) {
        for (final message in messages) {
          if (message is Map && message['content'] is String) {
            final content = message['content'] as String;
            if (content.isNotEmpty) {
              prompt = content;
              break;
            }
          }
        }
      }
    }
    if (prompt == null && body['prompt'] is String) {
      prompt = body['prompt'] as String;
    }
    if (prompt == null || prompt.isEmpty) {
      throw const LlmAccountConnectorException();
    }

    final parameters = <String, dynamic>{'sampleCount': 1};
    if (body.containsKey('aspectRatio')) {
      parameters['aspectRatio'] = body['aspectRatio'].toString();
    }
    if (body.containsKey('sampleCount')) {
      final value = body['sampleCount'];
      parameters['sampleCount'] =
          value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
    }
    final instance = <String, dynamic>{'prompt': prompt};
    if (body.containsKey('negativePrompt')) {
      instance['negativePrompt'] = body['negativePrompt'].toString();
    }
    return {
      'instances': [instance],
      'parameters': parameters,
    };
  }

  static void _validateProviderBaseUrl(LlmAccount account, Uri base) {
    if (account.connectorType == 'openai-compatibility') return;
    final host = base.host.toLowerCase();
    final hasCustomBaseUrl =
        _configString(account.endpointConfig, 'baseUrl') != null;
    final supportsCustomApiKeyEndpoint = account.authType == 'api_key' &&
        {'codex', 'claude', 'vertex'}.contains(account.connectorType);
    if (hasCustomBaseUrl && supportsCustomApiKeyEndpoint) return;
    final location =
        _configString(account.endpointConfig, 'location') ?? 'us-central1';
    final allowed = switch (account.connectorType) {
      'codex' => {'chatgpt.com', 'api.openai.com'}.contains(host),
      'claude' => host == 'api.anthropic.com',
      'antigravity' => host == 'cloudcode-pa.googleapis.com',
      'kimi' => host == 'api.kimi.com',
      'kimi-ai' || 'kimi.ai' => host == 'api.kimi.ai',
      'xai' => {'cli-chat-proxy.grok.com', 'api.x.ai'}.contains(host),
      'devin' => host == 'server.codeium.com',
      'meta' => host == 'api.meta.ai',
      'gemini' ||
      'gemini-interactions' ||
      'aistudio' =>
        host == 'generativelanguage.googleapis.com',
      'vertex' => host == 'aiplatform.googleapis.com' ||
          host == '$location-aiplatform.googleapis.com',
      _ => false,
    };
    if (!allowed) throw const LlmAccountConnectorException();
  }

  static String? _metaBaseUrl(String? credential) {
    if (credential == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(credential);
    } catch (_) {
      return null;
    }
    final value = decoded is Map ? decoded['base_url'] : null;
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'api.meta.ai' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery) {
      throw const LlmAccountConnectorException();
    }
    final path = uri.path.isEmpty || uri.path == '/' ? '/v1' : uri.path;
    return uri.replace(path: path).toString().replaceFirst(RegExp(r'/+$'), '');
  }

  static String _baseUrl(Map<String, dynamic> config, String fallback) =>
      _configString(config, 'baseUrl') ?? fallback;

  static String? _configString(Map<String, dynamic> config, String key) {
    final value = config[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String _joinPath(String base, String suffix) {
    if (suffix.isEmpty) return base.isEmpty ? '/' : base;
    if (base.isEmpty || base == '/') return suffix;
    return '${base.replaceFirst(RegExp(r'/+$'), '')}$suffix';
  }
}

/// Safe, content-free failure type for account storage and connector setup.
class LlmAccountConnectorException implements Exception {
  const LlmAccountConnectorException();

  @override
  String toString() => 'LLM connector operation could not be completed.';
}

class _LlmTokenRefreshRequest {
  final Uri uri;
  final Map<String, dynamic> body;
  final String contentType;
  final Map<String, String> headers;

  const _LlmTokenRefreshRequest({
    required this.uri,
    required this.body,
    required this.contentType,
    this.headers = const {},
  });
}

/// Makes response usage observations without assuming an account balance.
LlmConnectorObservation parseLlmConnectorObservation(
  String connectorType,
  Object? responseBody, {
  DateTime? observedAt,
}) {
  final observed = observedAt ?? DateTime.now().toUtc();
  if (connectorType == 'devin' &&
      (responseBody is Uint8List || responseBody is List<int>)) {
    return _parseDevinConnectUsage(
      responseBody is Uint8List
          ? responseBody
          : Uint8List.fromList(responseBody as List<int>),
      observed,
    );
  }
  if (responseBody is! Map) return LlmConnectorObservation();
  Map? usage;
  if (responseBody['usage'] is Map) {
    usage = responseBody['usage'] as Map;
  } else if (responseBody['usageMetadata'] is Map) {
    usage = responseBody['usageMetadata'] as Map;
  } else if (responseBody['response'] is Map &&
      (responseBody['response'] as Map)['usage'] is Map) {
    usage = (responseBody['response'] as Map)['usage'] as Map;
  } else if (responseBody['message'] is Map &&
      (responseBody['message'] as Map)['usage'] is Map) {
    usage = (responseBody['message'] as Map)['usage'] as Map;
  }
  final input = _firstNumber(usage, const [
    'input_tokens',
    'prompt_tokens',
    'promptTokenCount',
  ]);
  final output = _firstNumber(usage, const [
    'output_tokens',
    'completion_tokens',
    'candidatesTokenCount',
  ]);
  final total = _firstNumber(usage, const ['totalTokenCount', 'total_tokens']);
  final hasUsage = input != null || output != null || total != null;
  final requestUsage = !hasUsage
      ? const LlmMetricObservation.unknown()
      : LlmMetricObservation.reported(
          total ?? (input ?? 0) + (output ?? 0),
          unit: 'tokens',
          source: connectorType,
          observedAt: observed,
        );
  final quotaSignals = connectorType == 'codex'
      ? _parseCodexQuotaSignals(responseBody, observed)
      : const <String, LlmMetricObservation>{};
  return LlmConnectorObservation(
    requestUsage: requestUsage,
    remainingQuota: const LlmMetricObservation.unknown(),
    quotaSignals: quotaSignals,
  );
}

LlmConnectorObservation parseLlmConnectorHeaderObservation(
  String connectorType,
  Map<String, List<String>> headers, {
  DateTime? observedAt,
}) {
  if (connectorType != 'codex') return LlmConnectorObservation();
  final normalized = <String, String>{};
  for (final entry in headers.entries) {
    if (entry.value.isNotEmpty) {
      normalized[entry.key.toLowerCase()] = entry.value.first;
    }
  }
  final observed = observedAt ?? DateTime.now().toUtc();
  final signals = <String, LlmMetricObservation>{};
  for (final (headerName, signalName) in const [
    ('x-codex-primary-used-percent', 'primaryRemainingPercent'),
    ('x-codex-secondary-used-percent', 'secondaryRemainingPercent'),
    ('x-codex-code-review-used-percent', 'codeReviewRemainingPercent'),
  ]) {
    final used = num.tryParse(normalized[headerName] ?? '');
    if (used == null || used < 0 || used > 100) continue;
    signals[signalName] = LlmMetricObservation.reported(
      100 - used,
      unit: 'percent',
      source: 'codex.$signalName',
      observedAt: observed,
    );
  }
  return LlmConnectorObservation(quotaSignals: signals);
}

LlmConnectorObservation mergeLlmConnectorObservations(
  LlmConnectorObservation first,
  LlmConnectorObservation second,
) =>
    LlmConnectorObservation(
      requestUsage: second.requestUsage.isKnown
          ? second.requestUsage
          : first.requestUsage,
      remainingQuota: second.remainingQuota.isKnown
          ? second.remainingQuota
          : first.remainingQuota,
      quotaSignals: {...first.quotaSignals, ...second.quotaSignals},
    );

class LlmConnectorSseObservationAccumulator {
  final String connectorType;
  final DateTime? observedAt;
  num? _claudeInputTokens;
  num? _claudeOutputTokens;

  LlmConnectorSseObservationAccumulator(
    this.connectorType, {
    this.observedAt,
  });

  LlmConnectorObservation observe(Map frame) {
    final frameObservation = parseLlmConnectorObservation(
      connectorType,
      frame,
      observedAt: observedAt,
    );
    if (connectorType != 'claude') return frameObservation;

    final eventType = frame['type'];
    final Map? usage = switch (eventType) {
      'message_start' when frame['message'] is Map =>
        (frame['message'] as Map)['usage'] is Map
            ? (frame['message'] as Map)['usage'] as Map
            : null,
      'message_delta' when frame['usage'] is Map => frame['usage'] as Map,
      _ => null,
    };
    if (usage == null) return frameObservation;

    final inputTokens = _firstNumber(usage, const [
      'input_tokens',
      'prompt_tokens',
    ]);
    final outputTokens = _firstNumber(usage, const [
      'output_tokens',
      'completion_tokens',
    ]);
    if (inputTokens != null) _claudeInputTokens = inputTokens;
    if (outputTokens != null) _claudeOutputTokens = outputTokens;
    if (_claudeInputTokens == null && _claudeOutputTokens == null) {
      return frameObservation;
    }
    return LlmConnectorObservation(
      requestUsage: LlmMetricObservation.reported(
        (_claudeInputTokens ?? 0) + (_claudeOutputTokens ?? 0),
        unit: 'tokens',
        source: connectorType,
        observedAt: observedAt ?? DateTime.now().toUtc(),
      ),
      remainingQuota: frameObservation.remainingQuota,
      quotaSignals: frameObservation.quotaSignals,
    );
  }
}

LlmConnectorObservation parseLlmConnectorSseObservation(
  String connectorType,
  List<int> bytes, {
  DateTime? observedAt,
}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final dataLines = <String>[];
  var observation = LlmConnectorObservation();
  var dataLinesLength = 0;
  var discardingOversizedFrame = false;
  final accumulator = LlmConnectorSseObservationAccumulator(
    connectorType,
    observedAt: observedAt,
  );
  const maxSseFrameCharacters = 1048576;

  void clearFrame() {
    dataLines.clear();
    dataLinesLength = 0;
  }

  void addDataLine(String data) {
    if (discardingOversizedFrame) return;
    if (dataLinesLength + data.length + 1 > maxSseFrameCharacters) {
      clearFrame();
      discardingOversizedFrame = true;
      return;
    }
    dataLines.add(data);
    dataLinesLength += data.length + 1;
  }

  void observeFrame() {
    if (discardingOversizedFrame) {
      clearFrame();
      discardingOversizedFrame = false;
      return;
    }
    if (dataLines.isEmpty) return;
    final data = dataLines.join('\n').trim();
    clearFrame();
    if (data.isEmpty || data == '[DONE]') return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        observation = mergeLlmConnectorObservations(
          observation,
          accumulator.observe(decoded),
        );
      }
    } catch (_) {
      // Non-JSON event data is not an observation.
    }
  }

  var lineStart = 0;
  while (lineStart < text.length) {
    final newline = text.indexOf('\n', lineStart);
    final lineEnd = newline < 0 ? text.length : newline;
    final lineLength = lineEnd - lineStart;
    if (lineLength > maxSseFrameCharacters) {
      clearFrame();
      discardingOversizedFrame = true;
    } else {
      var line = text.substring(lineStart, lineEnd);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.isEmpty) {
        observeFrame();
      } else if (line.startsWith('data:')) {
        var data = line.substring(5);
        if (data.startsWith(' ')) data = data.substring(1);
        addDataLine(data);
      }
    }
    if (newline < 0) break;
    lineStart = newline + 1;
  }
  observeFrame();
  return observation;
}

LlmConnectorObservation _parseDevinConnectUsage(
  Uint8List response,
  DateTime observedAt,
) {
  var offset = 0;
  num? promptTokens;
  num? completionTokens;
  num? cachedTokens;
  var foundFrame = false;

  while (offset + 5 <= response.length) {
    final flag = response[offset];
    final length = (response[offset + 1] << 24) |
        (response[offset + 2] << 16) |
        (response[offset + 3] << 8) |
        response[offset + 4];
    offset += 5;
    final end = offset + length;
    if ((flag != 0 && flag != 2) || length < 0 || end > response.length) {
      return LlmConnectorObservation();
    }
    foundFrame = true;
    if (flag == 0) {
      final parsed = _parseDevinFrameUsage(response.sublist(offset, end));
      promptTokens = parsed.promptTokens ?? promptTokens;
      completionTokens = parsed.completionTokens ?? completionTokens;
      cachedTokens = parsed.cachedTokens ?? cachedTokens;
    }
    offset = end;
  }
  if (!foundFrame || offset != response.length) {
    return LlmConnectorObservation();
  }
  final prompt = (promptTokens ?? 0) + (cachedTokens ?? 0);
  final total = prompt + (completionTokens ?? 0);
  if (total == 0 && promptTokens == null && completionTokens == null) {
    return LlmConnectorObservation();
  }
  return LlmConnectorObservation(
    requestUsage: LlmMetricObservation.reported(
      total,
      unit: 'tokens',
      source: 'devin',
      observedAt: observedAt,
    ),
  );
}

({num? promptTokens, num? completionTokens, num? cachedTokens})
    _parseDevinFrameUsage(Uint8List payload) {
  var offset = 0;
  num? promptTokens;
  num? completionTokens;
  num? cachedTokens;
  while (offset < payload.length) {
    final tag = _readProtoVarint(payload, offset);
    if (tag == null || tag.value == 0) break;
    offset = tag.nextOffset;
    final fieldNumber = tag.value >> 3;
    final wireType = tag.value & 7;
    if (wireType == 2) {
      final size = _readProtoVarint(payload, offset);
      if (size == null || size.value < 0) break;
      offset = size.nextOffset;
      final end = offset + size.value;
      if (end > payload.length) break;
      if (fieldNumber == 7) {
        final usage = _parseDevinUsage(payload.sublist(offset, end));
        promptTokens = usage.promptTokens ?? promptTokens;
        completionTokens = usage.completionTokens ?? completionTokens;
        cachedTokens = usage.cachedTokens ?? cachedTokens;
      } else if (fieldNumber == 28) {
        final dimensions = _parseDevinDimensionGroup(
          payload.sublist(offset, end),
        );
        promptTokens = dimensions.promptTokens ?? promptTokens;
        completionTokens = dimensions.completionTokens ?? completionTokens;
        cachedTokens = dimensions.cachedTokens ?? cachedTokens;
      }
      offset = end;
      continue;
    }
    final next = _skipProtoValue(payload, offset, wireType);
    if (next == null) break;
    offset = next;
  }
  return (
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    cachedTokens: cachedTokens,
  );
}

({num? promptTokens, num? completionTokens, num? cachedTokens})
    _parseDevinUsage(Uint8List payload) {
  var offset = 0;
  num? promptTokens;
  num? completionTokens;
  num? cachedTokens;
  while (offset < payload.length) {
    final tag = _readProtoVarint(payload, offset);
    if (tag == null || tag.value == 0) break;
    offset = tag.nextOffset;
    final fieldNumber = tag.value >> 3;
    final wireType = tag.value & 7;
    if (wireType == 0) {
      final value = _readProtoVarint(payload, offset);
      if (value == null) break;
      offset = value.nextOffset;
      switch (fieldNumber) {
        case 2:
          promptTokens = value.value;
        case 3:
          completionTokens = value.value;
        case 5:
          cachedTokens = value.value;
      }
      continue;
    }
    final next = _skipProtoValue(payload, offset, wireType);
    if (next == null) break;
    offset = next;
  }
  return (
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    cachedTokens: cachedTokens,
  );
}

({num? promptTokens, num? completionTokens, num? cachedTokens})
    _parseDevinDimensionGroup(Uint8List payload) {
  var offset = 0;
  String? title;
  final metrics = <String, num>{};
  while (offset < payload.length) {
    final tag = _readProtoVarint(payload, offset);
    if (tag == null || tag.value == 0) break;
    offset = tag.nextOffset;
    final fieldNumber = tag.value >> 3;
    final wireType = tag.value & 7;
    if (wireType != 2) {
      final next = _skipProtoValue(payload, offset, wireType);
      if (next == null) break;
      offset = next;
      continue;
    }
    final size = _readProtoVarint(payload, offset);
    if (size == null || size.value < 0) break;
    offset = size.nextOffset;
    final end = offset + size.value;
    if (end > payload.length) break;
    final value = payload.sublist(offset, end);
    offset = end;
    if (fieldNumber == 1) {
      title = utf8.decode(value, allowMalformed: true);
    } else if (fieldNumber == 2) {
      final metric = _parseDevinMetric(value);
      if (metric.$1 != null && metric.$2 != null) {
        metrics[metric.$1!] = metric.$2!;
      }
    }
  }
  if (title != 'Token Usage') {
    return (promptTokens: null, completionTokens: null, cachedTokens: null);
  }
  return (
    promptTokens: metrics['input_tokens'],
    completionTokens: metrics['output_tokens'],
    cachedTokens: metrics['cached_input_tokens'],
  );
}

(String?, num?) _parseDevinMetric(Uint8List payload) {
  var offset = 0;
  String? key;
  num? value;
  while (offset < payload.length) {
    final tag = _readProtoVarint(payload, offset);
    if (tag == null || tag.value == 0) break;
    offset = tag.nextOffset;
    final fieldNumber = tag.value >> 3;
    final wireType = tag.value & 7;
    if (wireType != 2) {
      final next = _skipProtoValue(payload, offset, wireType);
      if (next == null) break;
      offset = next;
      continue;
    }
    final size = _readProtoVarint(payload, offset);
    if (size == null || size.value < 0) break;
    offset = size.nextOffset;
    final end = offset + size.value;
    if (end > payload.length) break;
    final nested = payload.sublist(offset, end);
    offset = end;
    if (fieldNumber == 5) {
      key = utf8.decode(nested, allowMalformed: true);
    } else if (fieldNumber == 4) {
      var nestedOffset = 0;
      while (nestedOffset < nested.length) {
        final nestedTag = _readProtoVarint(nested, nestedOffset);
        if (nestedTag == null || nestedTag.value == 0) break;
        nestedOffset = nestedTag.nextOffset;
        final nestedField = nestedTag.value >> 3;
        final nestedWire = nestedTag.value & 7;
        if (nestedWire == 5 &&
            nestedField == 2 &&
            nestedOffset + 4 <= nested.length) {
          value = ByteData.sublistView(
            nested,
            nestedOffset,
            nestedOffset + 4,
          ).getFloat32(0, Endian.little);
        }
        final next = _skipProtoValue(nested, nestedOffset, nestedWire);
        if (next == null) break;
        nestedOffset = next;
      }
    }
  }
  return (key, value);
}

({int value, int nextOffset})? _readProtoVarint(Uint8List bytes, int offset) {
  var value = 0;
  var shift = 0;
  while (offset < bytes.length && shift < 64) {
    final byte = bytes[offset++];
    value |= (byte & 0x7f) << shift;
    if (byte & 0x80 == 0) return (value: value, nextOffset: offset);
    shift += 7;
  }
  return null;
}

int? _skipProtoValue(Uint8List bytes, int offset, int wireType) {
  switch (wireType) {
    case 0:
      return _readProtoVarint(bytes, offset)?.nextOffset;
    case 1:
      return offset + 8 <= bytes.length ? offset + 8 : null;
    case 2:
      final size = _readProtoVarint(bytes, offset);
      if (size == null) return null;
      final end = size.nextOffset + size.value;
      return end <= bytes.length ? end : null;
    case 5:
      return offset + 4 <= bytes.length ? offset + 4 : null;
    default:
      return null;
  }
}

Map<String, LlmMetricObservation> _parseCodexQuotaSignals(
  Map responseBody,
  DateTime observedAt,
) {
  if (responseBody['type'] != 'codex.rate_limits') {
    return const <String, LlmMetricObservation>{};
  }
  final rawLimits = responseBody['rate_limits'];
  if (rawLimits is! Map) return const <String, LlmMetricObservation>{};
  final signals = <String, LlmMetricObservation>{};
  for (final window in const ['primary', 'secondary', 'code_review']) {
    final rawWindow = rawLimits[window];
    if (rawWindow is! Map) continue;
    final used = _firstNumber(rawWindow, const ['used_percent', 'usedPercent']);
    if (used == null || used < 0 || used > 100) continue;
    final key =
        '${window == 'code_review' ? 'codeReview' : window}RemainingPercent';
    signals[key] = LlmMetricObservation.reported(
      100 - used,
      unit: 'percent',
      source: 'codex.$window',
      observedAt: observedAt,
    );
  }
  return signals;
}

num? _firstNumber(Map? values, List<String> names) {
  if (values == null) return null;
  for (final name in names) {
    final value = values[name];
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}
