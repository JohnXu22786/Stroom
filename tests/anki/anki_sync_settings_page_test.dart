// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/anki/sync/anki_sync_provider.dart';
import 'package:stroom/anki/sync/anki_sync_protocol_client.dart';
import 'package:stroom/pages/anki_sync_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders both sync modes in the settings page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => const _FakeSecureStorage(),
          ),
        ],
        child: const MaterialApp(home: AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择同步方式'), findsOneWidget);
    expect(find.text('AnkiWeb'), findsOneWidget);
    expect(find.text('自建服务器'), findsOneWidget);
    expect(find.text('登录AnkiWeb'), findsOneWidget);
    expect(find.textContaining('双向同步会合并 collection'), findsOneWidget);
  });

  testWidgets('does not allow switching modes before settings load', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncProvider.overrideWith(_UnloadedAnkiSyncNotifier.new),
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => const _FakeSecureStorage(),
          ),
        ],
        child: const MaterialApp(home: AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('自建服务器').first);
    await tester.pumpAndSettle();

    expect(find.text('登录AnkiWeb'), findsOneWidget);
    expect(find.text('登录自建同步服务器'), findsNothing);
  });

  testWidgets('shows the retained custom server after migrating settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'custom_sync_server_enabled': true,
      'custom_sync_server_collection_url': 'https://sync.example.invalid/sync/',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => const _FakeSecureStorage(),
          ),
        ],
        child: const MaterialApp(home: AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('https://sync.example.invalid/sync/'), findsOneWidget);
    expect(find.text('登录自建同步服务器'), findsOneWidget);
  });

  testWidgets('saves an edited server URL before checking sync status', (
    tester,
  ) async {
    const oldUrl = 'https://old.example.invalid/sync/';
    const newUrl = 'https://new.example.invalid/sync/';
    SharedPreferences.setMockInitialValues({
      'anki_sync_mode': 'selfHosted',
      'custom_sync_server_enabled': true,
      'custom_sync_server_collection_url': oldUrl,
    });
    final oldConfig = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: oldUrl,
      isLoaded: true,
    );
    final requests = <Uri>[];
    final factoryUrls = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => _StoredSecureStorage({
              oldConfig.secureStorageKey: 'old-server-key',
            }),
          ),
          ankiSyncProtocolClientFactoryProvider.overrideWithValue((
            config,
            hostKey,
          ) {
            factoryUrls.add(config.selfHostedUrl);
            return AnkiSyncProtocolClient.selfHosted(
              endpoint: config.selfHostedUrl,
              client: _RecordingHttpClient(requests),
              hostKey: hostKey,
            );
          }),
        ],
        child: const MaterialApp(home: AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('检查服务器状态'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, newUrl);
    await tester.ensureVisible(find.text('检查服务器状态'));
    await tester.tap(find.text('检查服务器状态'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('custom_sync_server_collection_url'), newUrl);
    expect(factoryUrls, [oldUrl]);
    expect(requests, isEmpty);
    expect(find.text('登录自建同步服务器'), findsOneWidget);
  });

  testWidgets('blocks a second sync tap while saving server settings', (
    tester,
  ) async {
    const serverUrl = 'https://sync.example.invalid/sync/';
    SharedPreferences.setMockInitialValues({});
    final config = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: serverUrl,
      isLoaded: true,
    );
    final notifier = _GatedAnkiSyncNotifier(config);
    final requests = <Uri>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncProvider.overrideWith(() => notifier),
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => _StoredSecureStorage({config.secureStorageKey: 'saved-key'}),
          ),
          ankiSyncProtocolClientFactoryProvider.overrideWithValue(
            (config, hostKey) => AnkiSyncProtocolClient.selfHosted(
              endpoint: config.selfHostedUrl,
              client: _RecordingHttpClient(requests),
              hostKey: hostKey,
            ),
          ),
          ankiDatabaseProvider.overrideWith((ref) async {
            throw StateError('Stop before touching a collection in this test');
          }),
        ],
        child: const MaterialApp(home: AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查服务器状态'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('双向同步'), findsOneWidget);

    final urlWritesBeforeSync = notifier.urlWriteCount;
    notifier.holdUrlWrites = true;
    await tester.tap(find.text('双向同步'));
    await tester.pump();
    expect(notifier.urlWriteStarted.isCompleted, isTrue);
    await tester.tap(find.text('双向同步'));
    expect(notifier.urlWriteCount, urlWritesBeforeSync + 1);

    notifier.releaseUrlWrites.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows invalid server URL errors when submitted from keyboard', (
    tester,
  ) async {
    const validUrl = 'https://sync.example.invalid/sync/';
    SharedPreferences.setMockInitialValues({});
    final config = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: validUrl,
      isLoaded: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncProvider.overrideWith(() => _GatedAnkiSyncNotifier(config)),
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => _StoredSecureStorage({config.secureStorageKey: 'saved-key'}),
          ),
        ],
        child: const MaterialApp(home: AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'http://sync.example.invalid/sync/',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('设置未保存：服务器地址须为 HTTPS'), findsOneWidget);
  });

  testWidgets(
    'restores the newly selected mode after an old key read finishes',
    (tester) async {
      const selfHostedUrl = 'https://sync.example.invalid/sync/';
      SharedPreferences.setMockInitialValues({
        'anki_sync_mode': 'ankiWeb',
        'custom_sync_server_collection_url': selfHostedUrl,
      });
      final oldKey = const AnkiSyncState(isLoaded: true).secureStorageKey;
      final newKey = AnkiSyncState(
        mode: AnkiSyncMode.selfHosted,
        selfHostedUrl: selfHostedUrl,
        isLoaded: true,
      ).secureStorageKey;
      final storage = _DelayedSecureStorage({
        oldKey: 'ankiweb-key',
        newKey: 'self-hosted-key',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ankiSyncSecureStorageProvider.overrideWith((_) => storage),
          ],
          child: const MaterialApp(home: AnkiSyncSettingsPage()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(storage.reads, [oldKey]);

      await tester.tap(find.text('自建服务器').first);
      await tester.pump();
      await tester.pump();
      storage.complete(oldKey);
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });

      expect(storage.reads, [oldKey, newKey]);
      storage.complete(newKey);
      await tester.pump();
      await tester.pump();
      expect(find.text('检查服务器状态'), findsOneWidget);
    },
  );

  testWidgets('rejects HTTP for remote self-hosted servers', (tester) async {
    SharedPreferences.setMockInitialValues({
      'anki_sync_mode': 'selfHosted',
      'custom_sync_server_enabled': true,
      'custom_sync_server_collection_url': 'https://sync.example.invalid/sync/',
    });
    final oldConfig = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: 'https://sync.example.invalid/sync/',
      isLoaded: true,
    );
    final requests = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) =>
                _StoredSecureStorage({oldConfig.secureStorageKey: 'saved-key'}),
          ),
          ankiSyncProtocolClientFactoryProvider.overrideWithValue(
            (config, hostKey) => AnkiSyncProtocolClient.selfHosted(
              endpoint: config.selfHostedUrl,
              certificate: config.certificate,
              client: _RecordingHttpClient(requests),
              hostKey: hostKey,
            ),
          ),
        ],
        child: const MaterialApp(home: AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'http://sync.example.invalid/sync/',
    );
    await tester.ensureVisible(find.text('检查服务器状态'));
    await tester.tap(find.text('检查服务器状态'));
    await tester.pumpAndSettle();

    expect(find.textContaining('须为 HTTPS'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('allows HTTP for a loopback self-hosted server', (tester) async {
    SharedPreferences.setMockInitialValues({
      'anki_sync_mode': 'selfHosted',
      'custom_sync_server_enabled': true,
      'custom_sync_server_collection_url': 'https://sync.example.invalid/sync/',
    });
    final oldConfig = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: 'https://sync.example.invalid/sync/',
      isLoaded: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) =>
                _StoredSecureStorage({oldConfig.secureStorageKey: 'saved-key'}),
          ),
        ],
        child: const MaterialApp(home: AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    const localUrl = 'http://127.0.0.1:8765/sync/';
    await tester.enterText(find.byType(TextField).first, localUrl);
    await tester.ensureVisible(find.text('检查服务器状态'));
    await tester.tap(find.text('检查服务器状态'));
    await tester.pumpAndSettle();

    expect(
      (await SharedPreferences.getInstance()).getString(
        'custom_sync_server_collection_url',
      ),
      localUrl,
    );
    expect(find.textContaining('须为 HTTPS'), findsNothing);
  });
}

class _FakeSecureStorage extends FlutterSecureStorage {
  const _FakeSecureStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      null;
}

class _UnloadedAnkiSyncNotifier extends AnkiSyncNotifier {
  @override
  AnkiSyncState build() => const AnkiSyncState();
}

class _StoredSecureStorage extends FlutterSecureStorage {
  _StoredSecureStorage(this.values);

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];
}

class _GatedAnkiSyncNotifier extends AnkiSyncNotifier {
  _GatedAnkiSyncNotifier(this.initialState);

  final AnkiSyncState initialState;
  final Completer<void> urlWriteStarted = Completer<void>();
  final Completer<void> releaseUrlWrites = Completer<void>();
  bool holdUrlWrites = false;
  int urlWriteCount = 0;

  @override
  AnkiSyncState build() => initialState;

  @override
  Future<void> setSyncUrl(String url) async {
    urlWriteCount++;
    if (holdUrlWrites) {
      if (!urlWriteStarted.isCompleted) urlWriteStarted.complete();
      await releaseUrlWrites.future;
    }
    state = state.copyWith(selfHostedUrl: url);
  }

  @override
  Future<void> setCertificate(String cert) async {
    state = state.copyWith(certificate: cert);
  }
}

class _DelayedSecureStorage extends FlutterSecureStorage {
  _DelayedSecureStorage(this.values);

  final Map<String, String> values;
  final Map<String, Completer<String?>> _pendingReads = {};
  final List<String> reads = [];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    reads.add(key);
    return (_pendingReads[key] ??= Completer<String?>()).future;
  }

  void complete(String key) => _pendingReads[key]!.complete(values[key]);
}

class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this.requests);

  final List<Uri> requests;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(
          jsonEncode({
            'mod': 1,
            'scm': 1,
            'usn': 0,
            'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'msg': '',
            'cont': true,
            'hostNum': 1,
            'empty': false,
            'media_usn': 0,
          }),
        ),
      ),
      HttpStatus.ok,
      request: request,
    );
  }
}
