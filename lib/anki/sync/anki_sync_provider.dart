import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages custom sync server configuration, matching AnkiDroid's approach.
///
/// Persists the server URL, certificate, and enabled state to [SharedPreferences].
class AnkiSyncNotifier extends Notifier<AnkiSyncState> {
  static const _keyUrl = 'custom_sync_server_collection_url';
  static const _keyCert = 'custom_sync_certificate';
  static const _keyEnabled = 'custom_sync_server_enabled';

  @override
  AnkiSyncState build() {
    _load();
    return const AnkiSyncState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AnkiSyncState(
      url: prefs.getString(_keyUrl) ?? '',
      certificate: prefs.getString(_keyCert) ?? '',
      enabled: prefs.getBool(_keyEnabled) ?? false,
    );
  }

  Future<void> setSyncUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url);
    state = AnkiSyncState(
      url: url,
      certificate: state.certificate,
      enabled: state.enabled,
    );
  }

  Future<void> setCertificate(String cert) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCert, cert);
    state = AnkiSyncState(
      url: state.url,
      certificate: cert,
      enabled: state.enabled,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    state = AnkiSyncState(
      url: state.url,
      certificate: state.certificate,
      enabled: enabled,
    );
  }
}

/// Custom sync server configuration state.
class AnkiSyncState {
  final String url;
  final String certificate;
  final bool enabled;

  const AnkiSyncState({
    this.url = '',
    this.certificate = '',
    this.enabled = false,
  });

  /// Whether the custom sync config is complete enough to attempt a connection.
  bool get isConfigured => enabled && url.isNotEmpty;
}

final ankiSyncProvider = NotifierProvider<AnkiSyncNotifier, AnkiSyncState>(
  AnkiSyncNotifier.new,
);
