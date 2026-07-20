import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages custom sync server configuration.
///
/// Persists the server URL and enabled state to SharedPreferences.
class AnkiSyncNotifier extends Notifier<AnkiSyncState> {
  static const _keyUrl = 'anki_custom_sync_url';
  static const _keyEnabled = 'anki_custom_sync_enabled';

  @override
  AnkiSyncState build() {
    _load();
    return const AnkiSyncState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyUrl) ?? '';
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    state = AnkiSyncState(url: url, enabled: enabled);
  }

  Future<void> setSyncUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url);
    state = AnkiSyncState(url: url, enabled: state.enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    state = AnkiSyncState(url: state.url, enabled: enabled);
  }
}

/// Custom sync server configuration state.
class AnkiSyncState {
  final String url;
  final bool enabled;

  const AnkiSyncState({
    this.url = '',
    this.enabled = false,
  });
}

final ankiSyncProvider = NotifierProvider<AnkiSyncNotifier, AnkiSyncState>(
  AnkiSyncNotifier.new,
);
