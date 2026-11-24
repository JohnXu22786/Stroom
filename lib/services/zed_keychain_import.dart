import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../ai_gateway/ai_gateway_contracts.dart';

/// A safe reference to a Zed keychain item. It never contains the credential.
class ZedKeychainCredentialCandidate {
  final String provider;
  final String service;
  final String account;
  final String fingerprint;

  const ZedKeychainCredentialCandidate({
    required this.provider,
    required this.service,
    required this.account,
    required this.fingerprint,
  });
}

/// The only operations exposed by the native Zed keychain bridge.
abstract interface class ZedKeychainReader {
  Future<List<ZedKeychainCredentialCandidate>> discover();

  Future<String?> readSecret(String service, String account);
}

/// Native desktop keychain reader backed by the platform's secure key store.
/// macOS, Linux, and Windows register this channel in their native runners.
class MethodChannelZedKeychainReader implements ZedKeychainReader {
  static const _channel = MethodChannel('com.johntsui.stroom/zed_keychain');

  const MethodChannelZedKeychainReader();

  @override
  Future<List<ZedKeychainCredentialCandidate>> discover() async {
    final values = await _channel.invokeListMethod<Object?>('discover');
    return [
      for (final value in values ?? const <Object?>[])
        if (value is Map)
          ZedKeychainCredentialCandidate(
            provider: value['provider'] as String? ?? '',
            service: value['service'] as String? ?? '',
            account: value['account'] as String? ?? '',
            fingerprint: value['fingerprint'] as String? ?? '',
          ),
    ];
  }

  @override
  Future<String?> readSecret(String service, String account) =>
      _channel.invokeMethod<String>('readSecret', {
        'service': service,
        'account': account,
      });
}

typedef ZedKeychainAccountSaver = Future<AiGatewayAccount> Function(
  AiGatewayAccount account, {
  required String secret,
});

/// Imports a user-confirmed Zed provider key into Stroom's regular account
/// registry. The provider's own account identity remains visible in the name
/// and safe endpoint metadata; it is never stored as Zed OAuth.
class ZedKeychainImportService {
  final ZedKeychainReader reader;
  final ZedKeychainAccountSaver saveAccount;

  const ZedKeychainImportService({
    required this.reader,
    required this.saveAccount,
  });

  static const _providerByService = <String, String>{
    'zed-openai': 'openai',
    'ai.zed.openai': 'openai',
    'zed.openai': 'openai',
    'Zed-OpenAI': 'openai',
    'zed-anthropic': 'anthropic',
    'ai.zed.anthropic': 'anthropic',
    'zed.anthropic': 'anthropic',
    'Zed-Anthropic': 'anthropic',
    'zed-google': 'google',
    'ai.zed.google': 'google',
    'zed.google': 'google',
    'Zed-Google': 'google',
    'zed-mistral': 'mistral',
    'ai.zed.mistral': 'mistral',
    'zed.mistral': 'mistral',
    'Zed-Mistral': 'mistral',
    'zed-xai': 'xai',
    'ai.zed.xai': 'xai',
    'zed.xai': 'xai',
    'Zed-xAI': 'xai',
  };

  static String? providerForService(String service) =>
      _providerByService[service];

  static String fingerprint(String service, String account, String secret) =>
      sha256
          .convert(utf8.encode('$service|$account|$secret'))
          .toString()
          .substring(0, 16);

  Future<List<ZedKeychainCredentialCandidate>> discover() async {
    try {
      final candidates = await reader.discover();
      return candidates
          .where((candidate) =>
              providerForService(candidate.service) == candidate.provider &&
              candidate.account.trim().isNotEmpty &&
              RegExp(r'^[a-f0-9]{16}$').hasMatch(candidate.fingerprint))
          .toList(growable: false);
    } catch (_) {
      throw const ZedKeychainImportException();
    }
  }

  /// Call only after the user explicitly confirms this candidate.
  Future<AiGatewayAccount> importConfirmed(
    ZedKeychainCredentialCandidate candidate,
  ) async {
    final provider = providerForService(candidate.service);
    if (provider == null ||
        provider != candidate.provider ||
        candidate.account.trim().isEmpty ||
        !RegExp(r'^[a-f0-9]{16}$').hasMatch(candidate.fingerprint)) {
      throw const ZedKeychainImportException();
    }

    try {
      final secret = await reader.readSecret(
        candidate.service,
        candidate.account,
      );
      if (secret == null ||
          secret.isEmpty ||
          fingerprint(candidate.service, candidate.account, secret) !=
              candidate.fingerprint) {
        throw const ZedKeychainImportException();
      }

      final account = _accountFor(candidate, provider);
      return await saveAccount(account, secret: secret);
    } catch (_) {
      // Native keychain errors can contain account or credential data.
      throw const ZedKeychainImportException();
    }
  }

  AiGatewayAccount _accountFor(
    ZedKeychainCredentialCandidate candidate,
    String provider,
  ) {
    final connectorType = switch (provider) {
      'openai' => 'openai-api',
      'anthropic' => 'claude',
      'google' => 'gemini',
      'xai' => 'xai',
      // Stroom routes Mistral's public OpenAI-compatible API through its
      // generic endpoint connector while retaining vendor identity below.
      'mistral' => 'openai-compatibility',
      _ => throw const ZedKeychainImportException(),
    };
    final providerName = switch (provider) {
      'openai' => 'OpenAI',
      'anthropic' => 'Anthropic',
      'google' => 'Google',
      'mistral' => 'Mistral',
      'xai' => 'xAI',
      _ => throw const ZedKeychainImportException(),
    };
    final endpointConfig = <String, dynamic>{
      'credentialSource': 'zed-keychain',
      'sourceProvider': provider,
      'sourceService': candidate.service,
      'sourceAccount': candidate.account,
      if (provider == 'mistral') 'baseUrl': 'https://api.mistral.ai/v1',
    };
    final accountId = 'zed-$provider-${fingerprint(
      candidate.service,
      candidate.account,
      '',
    )}';
    return AiGatewayAccount(
      id: accountId,
      connectorType: connectorType,
      authType: 'api_key',
      displayName: '$providerName (Zed: ${candidate.account})',
      hasCredential: true,
      endpointConfig: endpointConfig,
    );
  }
}

/// Generic error used so native error details cannot leak keychain values.
class ZedKeychainImportException implements Exception {
  const ZedKeychainImportException();
}
