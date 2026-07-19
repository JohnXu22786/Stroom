import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'anki_sync_client.dart';

/// Manages AnkiWeb login state.
///
/// Persists the session key (hkey) to SharedPreferences so the user
/// stays logged in across app restarts.
class AnkiSyncNotifier extends Notifier<AnkiSyncState> {
  @override
  AnkiSyncState build() {
    _load();
    return const AnkiSyncState.loggedOut();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('anki_sync_key');
    final email = prefs.getString('anki_sync_email');
    if (key != null && email != null && key.isNotEmpty) {
      state = AnkiSyncState.loggedIn(email: email, key: key);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AnkiSyncState.loading();
    try {
      final key = await AnkiSyncClient.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('anki_sync_key', key);
      await prefs.setString('anki_sync_email', email);
      state = AnkiSyncState.loggedIn(email: email, key: key);
    } catch (e) {
      state = AnkiSyncState.error(e.toString());
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('anki_sync_key');
    await prefs.remove('anki_sync_email');
    state = const AnkiSyncState.loggedOut();
  }
}

/// Login state.
class AnkiSyncState {
  final String? email;
  final String? key;
  final String? error;
  final bool isLoading;

  const AnkiSyncState._(
      {this.email, this.key, this.error, this.isLoading = false});

  const AnkiSyncState() : this._();
  const AnkiSyncState.loggedOut() : this._();
  const AnkiSyncState.loggedIn({required String email, required String key})
      : this._(email: email, key: key);
  const AnkiSyncState.loading() : this._(isLoading: true);
  const AnkiSyncState.error(String error) : this._(error: error);

  bool get isLoggedIn => key != null && key!.isNotEmpty;
  bool get isLoggedOut => !isLoggedIn && !isLoading && error == null;
}

final ankiSyncProvider = NotifierProvider<AnkiSyncNotifier, AnkiSyncState>(
  AnkiSyncNotifier.new,
);
