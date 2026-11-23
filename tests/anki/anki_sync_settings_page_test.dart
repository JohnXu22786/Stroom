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
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/anki/sync/anki_sync_provider.dart';
import 'package:stroom/anki/sync/anki_sync_protocol_client.dart';
import 'package:stroom/pages/anki_sync_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

Widget _localizedApp({
  required Widget home,
  Locale locale = const Locale('zh', 'CN'),
}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('constrains localized login labels according to measured fit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => const _FakeSecureStorage(),
          ),
        ],
        child: _localizedApp(
          home: const AnkiSyncSettingsPage(),
          locale: const Locale('de'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.login),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    final usernameField = tester.widget<TextField>(
      find.byType(TextField).at(0),
    );
    final passwordField = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );
    expect(usernameField.decoration!.label, isA<ConstrainedText>());
    expect(passwordField.decoration!.label, isA<ConstrainedText>());
    expect(
      (usernameField.decoration!.label! as ConstrainedText).data,
      'E-Mail-Adresse / Benutzername',
    );
    expect(
      (passwordField.decoration!.label! as ConstrainedText).data,
      'Passwort',
    );
    final usernameLabel = find.byWidget(usernameField.decoration!.label!);
    final passwordLabel = find.byWidget(passwordField.decoration!.label!);
    expect(
      find.descendant(of: usernameLabel, matching: find.byType(Transform)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: passwordLabel, matching: find.byType(Transform)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('login fields keep native editing state while labels reveal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => const _FakeSecureStorage(),
          ),
        ],
        child: _localizedApp(
          home: const AnkiSyncSettingsPage(),
          locale: const Locale('de'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.login),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    final username = find.byType(TextFormField).at(0);
    final password = find.byType(TextFormField).at(1);
    await tester.tap(username);
    await tester.enterText(username, 'fixture@example.invalid');
    await tester.pump();
    final usernameEditable = tester.widget<EditableText>(
      find.descendant(of: username, matching: find.byType(EditableText)),
    );
    final usernameController = usernameEditable.controller;
    usernameController.selection = const TextSelection.collapsed(offset: 7);
    await tester.pump();

    await tester.tap(password);
    await tester.enterText(password, 'fixture-passphrase');
    await tester.pump();
    final passwordEditable = tester.widget<EditableText>(
      find.descendant(of: password, matching: find.byType(EditableText)),
    );
    final passwordController = passwordEditable.controller;
    passwordController.selection = const TextSelection.collapsed(offset: 8);
    await tester.pump(const Duration(seconds: 3));

    expect(usernameController.text, 'fixture@example.invalid');
    expect(
      usernameController.selection,
      const TextSelection.collapsed(offset: 7),
    );
    expect(passwordController.text, 'fixture-passphrase');
    expect(
      passwordController.selection,
      const TextSelection.collapsed(offset: 8),
    );
    expect(passwordEditable.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders both sync modes in the settings page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => const _FakeSecureStorage(),
          ),
        ],
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择同步方式'), findsOneWidget);
    expect(find.text('AnkiWeb'), findsOneWidget);
    expect(find.text('自建服务器'), findsOneWidget);
    expect(find.text('登录AnkiWeb'), findsOneWidget);
    expect(find.textContaining('双向同步会合并 collection'), findsOneWidget);
    final segmented = find.byWidgetPredicate(
      (widget) => widget is SegmentedButton<AnkiSyncMode>,
    );
    expect(
      find.descendant(of: segmented, matching: find.byType(ConstrainedText)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: segmented, matching: find.byType(Transform)),
      findsNothing,
    );
    expect(
      find.descendant(of: segmented, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets(
    'sync mode labels stay operable when clipped at narrow width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ankiSyncSecureStorageProvider.overrideWith(
              (_) => const _FakeSecureStorage(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('de', 'DE'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const AnkiSyncSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Selbst gehosteter Server'),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      final segmented = find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<AnkiSyncMode>,
      );
      expect(segmented, findsOneWidget);
      final button = tester.widget<SegmentedButton<AnkiSyncMode>>(segmented);
      expect(button.selected, {AnkiSyncMode.ankiWeb});
      expect(button.segments.map((segment) => segment.value), [
        AnkiSyncMode.ankiWeb,
        AnkiSyncMode.selfHosted,
      ]);
      expect(
        button.segments.map((segment) => segment.icon).whereType<Icon>().map(
              (icon) => icon.icon,
            ),
        [Icons.cloud_outlined, Icons.dns_outlined],
      );
      expect(
        find.descendant(of: segmented, matching: find.byType(ConstrainedText)),
        findsNWidgets(2),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      final selfHostedLabel = find.ancestor(
        of: find.text('Selbst gehosteter Server'),
        matching: find.byType(ConstrainedText),
      );
      expect(
        find.descendant(of: selfHostedLabel, matching: find.byType(Transform)),
        findsOneWidget,
      );
      expect(find.text('Selbst gehosteter Server'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final segmentButtons =
          find.descendant(of: segmented, matching: find.byType(TextButton));
      await tester.tap(segmentButtons.at(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final selfHosted =
          tester.widget<SegmentedButton<AnkiSyncMode>>(segmented);
      expect(selfHosted.selected, {AnkiSyncMode.selfHosted});
      expect(find.text('Serveradresse'), findsOneWidget);
      expect(
        find.descendant(of: segmented, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(segmentButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final ankiWeb = tester.widget<SegmentedButton<AnkiSyncMode>>(segmented);
      expect(ankiWeb.selected, {AnkiSyncMode.ankiWeb});
      expect(find.text('Serveradresse'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissing the login dialog does not use disposed controllers', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => const _FakeSecureStorage(),
          ),
        ],
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('登录AnkiWeb'));
    await tester.pumpAndSettle();
    expect(find.text('登录 AnkiWeb'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('登录 AnkiWeb'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads sync actions after a successful AnkiWeb login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => _StoredSecureStorage({}),
          ),
          ankiSyncProtocolClientFactoryProvider.overrideWithValue(
            (config, hostKey) => AnkiSyncProtocolClient.ankiWeb(
              client: _LoginAndMetaHttpClient(requests),
              hostKey: hostKey,
            ),
          ),
        ],
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('登录AnkiWeb'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('登录').last);
    for (var frame = 0;
        frame < 10 && find.text('双向同步').evaluate().isEmpty;
        frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(requests.map((uri) => uri.pathSegments.last), ['hostKey', 'meta']);
    expect(find.text('检查服务器状态'), findsOneWidget);
    expect(find.text('双向同步'), findsOneWidget);
  });

  testWidgets('available remote status heading fits narrow French layout', (
    tester,
  ) async {
    await _showRemoteStatus(tester);
    expect(
      find.text('La collection du serveur est disponible'),
      findsOneWidget,
    );
    _expectRemoteMessageWraps(tester);
  });

  testWidgets('empty remote status heading fits narrow French layout', (
    tester,
  ) async {
    await _showRemoteStatus(tester, isEmpty: true);
    expect(find.text('La collection du serveur est vide'), findsOneWidget);
    _expectRemoteMessageWraps(tester);
  });

  testWidgets('constrains the localized overwrite button on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = await _loginUntilSyncPrompt(
      tester,
      locale: const Locale('de', 'DE'),
      serviceLoginLabel: 'Bei AnkiWeb anmelden',
      dialogLoginLabel: 'Anmelden',
      successPromptContinueLabel: 'Fortfahren',
    );
    await tester.tap(find.text('Fortfahren'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final label = find.text('Serverdaten durch lokale Daten ersetzen');
    await tester.scrollUntilVisible(
      label,
      160,
      scrollable: find.byType(Scrollable).first,
    );

    final overwriteButton = find.ancestor(
      of: label,
      matching: find.byType(FilledButton),
    );
    expect(overwriteButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(overwriteButton).onPressed,
      isNotNull,
    );
    expect(
      find.descendant(
        of: overwriteButton,
        matching: find.byIcon(Icons.cloud_upload_outlined),
      ),
      findsOneWidget,
    );
    final constrainedLabel = find.ancestor(
      of: label,
      matching: find.byType(ConstrainedText),
    );
    expect(constrainedLabel, findsOneWidget);
    expect(
      tester.widget<ConstrainedText>(constrainedLabel).maxLines,
      1,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.descendant(of: constrainedLabel, matching: find.byType(Transform)),
      findsOneWidget,
    );
    expect(requests.map((uri) => uri.pathSegments.last), ['hostKey', 'meta']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers sync after login and keeps the sync button available', (
    tester,
  ) async {
    final requests = await _loginUntilSyncPrompt(tester);

    expect(requests.map((uri) => uri.pathSegments.last), ['hostKey', 'meta']);
    expect(find.text('现在同步收藏集吗？'), findsOneWidget);
    expect(find.text('立即同步'), findsOneWidget);
    expect(find.text('双向同步'), findsOneWidget);
  });

  testWidgets('accepting the login sync prompt starts two-way sync', (
    tester,
  ) async {
    var databaseReads = 0;
    final databaseOverride = ankiDatabaseProvider.overrideWith((ref) async {
      databaseReads++;
      throw StateError('Stop after confirming the sync path starts');
    });
    await _loginUntilSyncPrompt(
      tester,
      additionalOverrides: [databaseOverride],
    );

    await tester.tap(find.text('立即同步'));
    await tester.pumpAndSettle();

    expect(databaseReads, 1);
  });

  testWidgets('cancelling the login sync prompt does not start sync', (
    tester,
  ) async {
    var databaseReads = 0;
    final databaseOverride = ankiDatabaseProvider.overrideWith((ref) async {
      databaseReads++;
      throw StateError('Sync must not start after cancellation');
    });
    await _loginUntilSyncPrompt(
      tester,
      additionalOverrides: [databaseOverride],
    );

    await tester.tap(find.text('继续使用'));
    await tester.pumpAndSettle();

    expect(databaseReads, 0);
    expect(find.text('双向同步'), findsOneWidget);
  });

  testWidgets('keeps the key-save warning after checking server status', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => _FailingWriteSecureStorage(),
          ),
          ankiSyncProtocolClientFactoryProvider.overrideWithValue(
            (config, hostKey) => AnkiSyncProtocolClient.ankiWeb(
              client: _LoginAndMetaHttpClient(requests),
              hostKey: hostKey,
            ),
          ),
        ],
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('登录AnkiWeb'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('登录').last);
    for (var frame = 0;
        frame < 10 && find.text('双向同步').evaluate().isEmpty;
        frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(requests.map((uri) => uri.pathSegments.last), ['hostKey', 'meta']);
    expect(find.text('双向同步'), findsOneWidget);
    expect(
      find.textContaining('登录成功，但无法安全保存同步密钥'),
      findsOneWidget,
    );
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
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('自建服务器').first);
    await tester.pumpAndSettle();

    expect(find.text('登录AnkiWeb'), findsOneWidget);
    expect(find.text('登录自建服务器'), findsNothing);
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
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('https://sync.example.invalid/sync/'), findsOneWidget);
    expect(find.text('登录自建服务器'), findsOneWidget);
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
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
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
    expect(find.text('登录自建服务器'), findsOneWidget);
  });

  testWidgets('formats the server modification time as Unix seconds', (
    tester,
  ) async {
    const serverUrl = 'https://sync.example.invalid/sync/';
    SharedPreferences.setMockInitialValues({
      'anki_sync_mode': 'selfHosted',
      'custom_sync_server_enabled': true,
      'custom_sync_server_collection_url': serverUrl,
    });
    final config = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: serverUrl,
      isLoaded: true,
    );
    final requests = <Uri>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncProvider.overrideWith(() => _GatedAnkiSyncNotifier(config)),
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => _StoredSecureStorage({config.secureStorageKey: 'saved-key'}),
          ),
          ankiSyncProtocolClientFactoryProvider.overrideWithValue(
            (config, hostKey) => AnkiSyncProtocolClient.selfHosted(
              endpoint: config.selfHostedUrl,
              client: _RecordingHttpClient(requests, modified: 1700000000),
              hostKey: hostKey,
            ),
          ),
        ],
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查服务器状态'));
    await tester.pumpAndSettle();

    expect(find.text('连接成功，服务器状态已读取'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    final status = find.textContaining('结构版本戳');
    expect(status, findsOneWidget);
    final statusText = tester.widget<Text>(status.first).data!;
    expect(statusText, contains('修改时间 2023-11-14'));
  });

  testWidgets('keeps an active status request alive after leaving the page', (
    tester,
  ) async {
    const serverUrl = 'https://sync.example.invalid/sync/';
    SharedPreferences.setMockInitialValues({
      'anki_sync_mode': 'selfHosted',
      'custom_sync_server_enabled': true,
      'custom_sync_server_collection_url': serverUrl,
    });
    final config = AnkiSyncState(
      mode: AnkiSyncMode.selfHosted,
      selfHostedUrl: serverUrl,
      isLoaded: true,
    );
    final client = _GatedHttpClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiSyncProvider.overrideWith(() => _GatedAnkiSyncNotifier(config)),
          ankiSyncSecureStorageProvider.overrideWith(
            (_) => _StoredSecureStorage({config.secureStorageKey: 'saved-key'}),
          ),
          ankiSyncProtocolClientFactoryProvider.overrideWithValue(
            (config, hostKey) => AnkiSyncProtocolClient.selfHosted(
              endpoint: config.selfHostedUrl,
              client: client,
              hostKey: hostKey,
            ),
          ),
        ],
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查服务器状态'));
    await tester.pump();
    await client.requestStarted.future;

    Navigator.of(tester.element(find.byType(AnkiSyncSettingsPage)))
        .pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('other page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('other page'), findsOneWidget);
    expect(client.closeCount, 0);
    client.respondWithMeta();
    await tester.runAsync(
      () => client.responseConsumed.future.timeout(const Duration(seconds: 2)),
    );

    // The injected transport belongs to the test; the page-owned protocol
    // client must not close it, and the in-flight response must be consumed.
    expect(client.closeCount, 0);
    expect(tester.takeException(), isNull);
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
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
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
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
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
          child: _localizedApp(home: const AnkiSyncSettingsPage()),
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
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
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
        child: _localizedApp(home: const AnkiSyncSettingsPage()),
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

Future<void> _showRemoteStatus(
  WidgetTester tester, {
  bool isEmpty = false,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final requests = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ankiSyncSecureStorageProvider.overrideWith(
          (_) => _StoredSecureStorage({}),
        ),
        ankiSyncProtocolClientFactoryProvider.overrideWithValue(
          (config, hostKey) => AnkiSyncProtocolClient.ankiWeb(
            client: _LoginAndMetaHttpClient(
              requests,
              isEmpty: isEmpty,
              shouldContinue: false,
              message:
                  'Le serveur indique une information importante qui doit rester lisible sur plusieurs lignes.',
            ),
            hostKey: hostKey,
          ),
        ),
      ],
      child: _localizedApp(
        home: const AnkiSyncSettingsPage(),
        locale: const Locale('fr'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Se connecter à AnkiWeb'), 300);
  await tester.tap(find.text('Se connecter à AnkiWeb'));
  // The localized email label can be clipped at this width and keeps its
  // reveal animation active, so settle the dialog transition with bounded
  // frames instead of waiting for every ticker to stop.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'password');
  await tester.tap(find.text('Se connecter').last);
  for (var frame = 0; frame < 20 && requests.length < 2; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 200));
  expect(requests.map((uri) => uri.pathSegments.last), ['hostKey', 'meta']);
}

void _expectRemoteMessageWraps(WidgetTester tester) {
  final schemaStatus = find.textContaining(
    'Version du schéma 1600000000000 · USN 7',
  );
  expect(schemaStatus, findsOneWidget);
  expect(tester.getSize(schemaStatus).height, greaterThan(20));

  final message = find.text(
    'Le serveur indique une information importante qui doit rester lisible sur plusieurs lignes.',
  );
  expect(message, findsNWidgets(2));
  expect(tester.getSize(message.at(0)).height, greaterThan(20));
  expect(tester.getSize(message.at(1)).height, greaterThan(20));
  expect(tester.takeException(), isNull);
}

Future<List<Uri>> _loginUntilSyncPrompt(
  WidgetTester tester, {
  List<dynamic> additionalOverrides = const [],
  Locale locale = const Locale('zh', 'CN'),
  String serviceLoginLabel = '登录AnkiWeb',
  String dialogLoginLabel = '登录',
  String successPromptContinueLabel = '继续使用',
}) async {
  SharedPreferences.setMockInitialValues({});
  final requests = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ankiSyncSecureStorageProvider.overrideWith(
          (_) => _StoredSecureStorage({}),
        ),
        ankiSyncProtocolClientFactoryProvider.overrideWithValue(
          (config, hostKey) => AnkiSyncProtocolClient.ankiWeb(
            client: _LoginAndMetaHttpClient(requests),
            hostKey: hostKey,
          ),
        ),
        ...additionalOverrides,
      ],
      child: _localizedApp(
        home: const AnkiSyncSettingsPage(),
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(serviceLoginLabel),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(serviceLoginLabel));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'password');
  await tester.tap(find.text(dialogLoginLabel).last);
  for (var frame = 0;
      frame < 20 && find.text(successPromptContinueLabel).evaluate().isEmpty;
      frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return requests;
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

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class _FailingWriteSecureStorage extends FlutterSecureStorage {
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

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw StateError('secure storage write failed');
  }
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
  _RecordingHttpClient(this.requests, {this.modified = 1});

  final List<Uri> requests;
  final int modified;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(
          jsonEncode({
            'mod': modified,
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

class _LoginAndMetaHttpClient extends http.BaseClient {
  _LoginAndMetaHttpClient(
    this.requests, {
    this.isEmpty = false,
    this.shouldContinue = true,
    this.message = '',
  });

  final List<Uri> requests;
  final bool isEmpty;
  final bool shouldContinue;
  final String message;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final body = request.url.path.endsWith('/hostKey')
        ? {'key': 'host-key'}
        : {
            'mod': 1700000000,
            'scm': 1600000000000,
            'usn': 7,
            'ts': 1700000000,
            'msg': message,
            'cont': shouldContinue,
            'hostNum': 1,
            'empty': isEmpty,
            'media_usn': 3,
          };
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      HttpStatus.ok,
      request: request,
    );
  }
}

class _GatedHttpClient extends http.BaseClient {
  final requestStarted = Completer<void>();
  final responseConsumed = Completer<void>();
  final _response = Completer<http.StreamedResponse>();
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!requestStarted.isCompleted) requestStarted.complete();
    return _response.future;
  }

  void respondWithMeta() {
    final response = Stream<List<int>>.value(
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
    ).transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleDone: (sink) {
          if (!responseConsumed.isCompleted) responseConsumed.complete();
          sink.close();
        },
      ),
    );
    _response.complete(
      http.StreamedResponse(
        response,
        HttpStatus.ok,
      ),
    );
  }

  @override
  void close() {
    closeCount++;
    super.close();
  }
}
