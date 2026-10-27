import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anki_sync_protocol_client.dart';

enum AnkiSyncMode { ankiWeb, selfHosted }

/// Stores the selected sync destination and migrates the former custom-server
/// switch without dropping its URL or certificate.
class AnkiSyncNotifier extends Notifier<AnkiSyncState> {
  static const _keyUrl = 'custom_sync_server_collection_url';
  static const _keyCert = 'custom_sync_certificate';
  static const _keyEnabled = 'custom_sync_server_enabled';
  static const _keyMode = 'anki_sync_mode';

  @override
  AnkiSyncState build() {
    _load();
    return const AnkiSyncState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_keyMode);
    final migratedMode = savedMode == null
        ? ((prefs.getBool(_keyEnabled) ?? false)
            ? AnkiSyncMode.selfHosted
            : AnkiSyncMode.ankiWeb)
        : AnkiSyncMode.values.firstWhere(
            (mode) => mode.name == savedMode,
            orElse: () => AnkiSyncMode.ankiWeb,
          );

    if (savedMode == null) {
      await prefs.setString(_keyMode, migratedMode.name);
    }

    state = AnkiSyncState(
      mode: migratedMode,
      selfHostedUrl: prefs.getString(_keyUrl) ?? '',
      certificate: prefs.getString(_keyCert) ?? '',
      isLoaded: true,
    );
  }

  Future<void> setMode(AnkiSyncMode mode) async {
    if (!state.isLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode.name);
    // Keep the former flag in sync for older app builds that may still read it.
    await prefs.setBool(_keyEnabled, mode == AnkiSyncMode.selfHosted);
    state = state.copyWith(mode: mode);
  }

  Future<void> setSyncUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url);
    state = state.copyWith(selfHostedUrl: url);
  }

  Future<void> setCertificate(String cert) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCert, cert);
    state = state.copyWith(certificate: cert);
  }

  /// Kept for compatibility with callers from earlier builds.
  Future<void> setEnabled(bool enabled) =>
      setMode(enabled ? AnkiSyncMode.selfHosted : AnkiSyncMode.ankiWeb);
}

class AnkiSyncState {
  final AnkiSyncMode mode;
  final String selfHostedUrl;
  final String certificate;
  final bool isLoaded;

  const AnkiSyncState({
    this.mode = AnkiSyncMode.ankiWeb,
    this.selfHostedUrl = '',
    this.certificate = '',
    this.isLoaded = false,
  });

  bool get isConfigured =>
      isLoaded &&
      (mode == AnkiSyncMode.ankiWeb || selfHostedUrl.trim().isNotEmpty);

  // Compatibility getters used by the old settings page/API.
  String get url => selfHostedUrl;
  bool get enabled => mode == AnkiSyncMode.selfHosted;

  /// Session keys are partitioned by destination, so changing modes or
  /// self-hosted servers cannot accidentally reuse another server's key.
  String get secureStorageKey {
    final destination = mode == AnkiSyncMode.ankiWeb
        ? 'https://sync.ankiweb.net/sync/'
        : _normalizedSelfHostedIdentity(selfHostedUrl);
    final digest = sha256.convert(utf8.encode(destination));
    return 'anki.sync.host_key.${mode.name}.$digest';
  }

  AnkiSyncState copyWith({
    AnkiSyncMode? mode,
    String? selfHostedUrl,
    String? certificate,
    bool? isLoaded,
  }) =>
      AnkiSyncState(
        mode: mode ?? this.mode,
        selfHostedUrl: selfHostedUrl ?? this.selfHostedUrl,
        certificate: certificate ?? this.certificate,
        isLoaded: isLoaded ?? this.isLoaded,
      );
}

String _normalizedSelfHostedIdentity(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasAuthority) return value.trim();
  return uri.replace(
    userInfo: '',
    fragment: '',
    queryParameters: const <String, String>{},
  ).toString();
}

final ankiSyncProvider = NotifierProvider<AnkiSyncNotifier, AnkiSyncState>(
  AnkiSyncNotifier.new,
);

final ankiSyncSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

typedef AnkiSyncProtocolClientFactory = AnkiSyncProtocolClient Function(
  AnkiSyncState config,
  String? hostKey,
);

final ankiSyncProtocolClientFactoryProvider =
    Provider<AnkiSyncProtocolClientFactory>(
  (ref) => (config, hostKey) => config.mode == AnkiSyncMode.ankiWeb
      ? AnkiSyncProtocolClient.ankiWeb(hostKey: hostKey)
      : AnkiSyncProtocolClient.selfHosted(
          endpoint: config.selfHostedUrl,
          certificate: config.certificate,
          hostKey: hostKey,
        ),
);
