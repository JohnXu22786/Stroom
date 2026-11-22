import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/browser_page.dart';
import 'package:stroom/services/userscript_http.dart';
import 'package:stroom/widgets/constrained_text.dart';

// Tests for the UserScript match-rule engine used by BrowserPage._injectScripts.
void main() {
  group('UserScript settings and metadata', () {
    test('legacy storage remains enabled and has a manual origin', () {
      final script = UserScript.fromMap({'name': 'legacy', 'code': 'run();'});

      expect(script.enabled, isTrue);
      expect(script.origin, 'manual');
      expect(script.id, isNotEmpty);
    });

    test('new manual and imported scripts use the expected enable defaults',
        () {
      final manual = UserScript(name: 'manual', code: 'run();');
      final imported = UserScript(
        name: 'imported',
        code: 'run();',
        enabled: false,
        origin: 'https://raw.githubusercontent.com/a/b/main/script.js',
      );

      expect(manual.enabled, isTrue);
      expect(manual.origin, 'manual');
      expect(imported.enabled, isFalse);
      expect(imported.origin, startsWith('https://'));
    });

    test('enable state, origin, and @version survive persistence', () {
      const source = '''
// ==UserScript==
// @version 2.4.1
// ==/UserScript==
run();
''';
      final imported = UserScript(
        name: 'imported',
        code: source,
        enabled: false,
        origin: 'https://raw.githubusercontent.com/a/b/main/script.js',
      );
      final restored = UserScript.fromMap(imported.toMap());

      expect(restored.enabled, isFalse);
      expect(restored.origin, imported.origin);
      expect(restored.id, imported.id);
      expect(restored.version, '2.4.1');
    });

    test('disabled scripts are excluded from injection eligibility', () {
      final disabled = UserScript(
        name: 'disabled',
        code: 'run();',
        enabled: false,
      );
      final enabled = UserScript(name: 'enabled', code: 'run();');

      expect(disabled.shouldRunAt('https://example.com/'), isFalse);
      expect(enabled.shouldRunAt('https://example.com/'), isTrue);
    });

    test('manager changes inject only newly enabled or edited scripts', () {
      final existing = UserScript(name: 'existing', code: 'existing();');
      final disabled = UserScript(
        name: 'newly enabled',
        code: 'newlyEnabled();',
        enabled: false,
      );
      final enabled = UserScript(
        id: disabled.id,
        name: disabled.name,
        code: disabled.code,
        enabled: true,
      );

      final toInject = scriptsToInjectAfterManagerChange(
        previous: [existing, disabled],
        updated: [existing, enabled],
        currentUrl: 'https://example.com/',
      );

      expect(toInject.map((script) => script.id), [disabled.id]);
    });
  });

  group('UserScript.matchesUrl', () {
    test('empty matches list means "run everywhere"', () {
      final script = UserScript(name: 'x', code: 'y', matches: []);
      expect(script.matchesUrl('https://anywhere.example/path'), isTrue);
    });

    test('wildcard scheme/host pattern matches subdomains', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.example.com/*'],
      );
      expect(script.matchesUrl('https://m.example.com/page'), isTrue);
      expect(script.matchesUrl('http://www.example.com/a/b'), isTrue);
    });

    test('wildcard pattern does not match unrelated hosts', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.example.com/*'],
      );
      // evil-example.com is not under example.com
      expect(script.matchesUrl('https://evil-example.com/'), isFalse);
      expect(script.matchesUrl('https://example.org/'), isFalse);
    });

    test('host wildcard cannot bleed into the path', () {
      // Regression: a flat glob would let the host wildcard consume "/" and
      // match URLs whose PATH merely contains ".example.com/".
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.example.com/*'],
      );
      expect(
        script.matchesUrl('https://attacker.com/x.example.com/y'),
        isFalse,
      );
      expect(
        script.matchesUrl('https://attacker.com/example.com'),
        isFalse,
      );
    });

    test('leading *. host wildcard also matches the apex domain', () {
      // Chrome match-pattern semantics: *://*.example.com/* matches the
      // apex domain too.
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.example.com/*'],
      );
      expect(script.matchesUrl('https://example.com/'), isTrue);
      expect(script.matchesUrl('https://deep.sub.example.com/'), isTrue);
    });

    test('scheme and host match case-insensitively', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['HTTPS://EXAMPLE.com/*'],
      );
      expect(script.matchesUrl('https://example.com/path'), isTrue);
      expect(script.matchesUrl('https://EXAMPLE.com/Path'), isTrue);
    });

    test('pattern without scheme defaults to any scheme', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['example.com/*'],
      );
      expect(script.matchesUrl('https://example.com/a'), isTrue);
      expect(script.matchesUrl('http://example.com/a'), isTrue);
      expect(script.matchesUrl('https://other.com/a'), isFalse);
    });

    test('pattern without path matches any path', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com'],
      );
      expect(script.matchesUrl('https://example.com/'), isTrue);
      expect(script.matchesUrl('https://example.com/a/b'), isTrue);
    });

    test('path matching is case-sensitive (scheme/host are not)', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com/API/*'],
      );
      expect(script.matchesUrl('https://example.com/API/list'), isTrue);
      expect(script.matchesUrl('https://example.com/api/list'), isFalse);
    });

    test('ports are ignored in the host pattern', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com:8080/*'],
      );
      expect(script.matchesUrl('https://example.com:8080/a'), isTrue);
      expect(script.matchesUrl('https://example.com/a'), isTrue);
    });

    test('file:///* matches file URLs (empty host)', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['file:///*'],
      );
      expect(script.matchesUrl('file:///C:/docs/video.mp4'), isTrue);
      expect(script.matchesUrl('https://example.com/'), isFalse);
    });

    test('a "://" inside a query does not confuse scheme detection', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['example.com/redirect?to=http://x'],
      );
      expect(
        script.matchesUrl('https://example.com/redirect?to=http://x'),
        isTrue,
      );
      expect(
          script.matchesUrl('https://other.com/redirect?to=http://x'), isFalse);
    });

    test('userinfo in the pattern is ignored', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://user:pass@example.com/*'],
      );
      expect(script.matchesUrl('https://example.com/a'), isTrue);
    });

    test('IPv6 host patterns match (brackets are normalized)', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://[::1]/*'],
      );
      expect(script.matchesUrl('https://[::1]/x'), isTrue);
      expect(script.matchesUrl('https://[::1]:8080/x'), isTrue);
      expect(script.matchesUrl('https://example.com/x'), isFalse);
    });

    test('path-only pattern matches the path on any host', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['/foo/*'],
      );
      expect(script.matchesUrl('https://example.com/foo/a'), isTrue);
      expect(script.matchesUrl('https://other.org/foo/a'), isTrue);
      expect(script.matchesUrl('https://example.com/bar/a'), isFalse);
    });

    test('exact scheme pattern only matches that scheme', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com/*'],
      );
      expect(script.matchesUrl('https://example.com/path'), isTrue);
      expect(script.matchesUrl('http://example.com/path'), isFalse);
    });

    test('any URL pattern matches everything', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*/*'],
      );
      expect(script.matchesUrl('https://a.b/c'), isTrue);
    });

    test('pattern special characters are escaped, not treated as regex', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['https://example.com/a.b?c=d'],
      );
      // '.' in the pattern must match a literal dot, not any character.
      expect(script.matchesUrl('https://example.com/aXb?cXd'), isFalse);
      expect(script.matchesUrl('https://example.com/a.b?c=d'), isTrue);
    });

    test('matches is OR: any matching rule suffices', () {
      final script = UserScript(
        name: 'x',
        code: 'y',
        matches: ['*://*.foo.com/*', '*://*.bar.com/*'],
      );
      expect(script.matchesUrl('https://x.bar.com/'), isTrue);
      expect(script.matchesUrl('https://x.baz.com/'), isFalse);
    });
  });

  testWidgets('deletion requires explicit confirmation', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmBrowserUserScriptDeletion(context)
                  .then((value) => confirmed = value),
              child: const Text('Open deletion prompt'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open deletion prompt'));
    await tester.pumpAndSettle();
    expect(find.text('Delete script?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);

    await tester.tap(find.text('Open deletion prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('manual script labels fit without changing native text editing',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    UserScript? saved;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBrowserUserScriptEditDialog(
                context,
                UserScript(name: 'Example', code: 'console.log("hello");'),
              ).then((value) => saved = value),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(2));
    expect(fields[0].decoration!.label, isA<ConstrainedText>());
    expect(fields[1].decoration!.label, isA<ConstrainedText>());
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Changed');
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.tap(find.byType(TextField).last);
    await tester.enterText(
      find.byType(TextField).last,
      'console.log("edited");',
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).last)
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(saved?.name, 'Changed');
    expect(saved?.code, 'console.log("edited");');
  });

  testWidgets('URL import validates locally without making a network request',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var fetchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBrowserUserScriptImportDialog(
                context,
                fetchSource: (url) async {
                  normalizeUserscriptUrl(url);
                  fetchCalls++;
                  return 'run();';
                },
              ),
              child: const Text('Open import'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open import'));
    await tester.pumpAndSettle();
    final urlField = tester.widget<TextField>(find.byType(TextField));
    expect(urlField.decoration!.label, isA<ConstrainedText>());
    expect(urlField.keyboardType, TextInputType.url);
    await tester.enterText(find.byType(TextField), 'http://example.com/a.js');
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    expect(find.text('Saisissez une URL HTTPS valide.'), findsOneWidget);
    expect(fetchCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import preview loads mocked content and saves it',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    UserScript? saved;
    final fetchCompleter = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBrowserUserScriptImportDialog(
                context,
                fetchSource: (_) => fetchCompleter.future,
              ).then((value) => saved = value),
              child: const Text('Open import'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open import'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://raw.githubusercontent.com/example/repo/main/test.user.js',
    );
    await tester.tap(find.byIcon(Icons.download));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fetchCompleter.complete(
      '// ==UserScript==\n// @name Preview test\n// ==/UserScript==\nconsole.log("preview");',
    );
    await tester.pumpAndSettle();
    final preview = tester.widget<InputDecorator>(
      find.byType(InputDecorator).last,
    );
    expect(preview.decoration.label, isA<ConstrainedText>());
    expect(find.byType(SelectableText), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(saved?.name, 'Preview test');
    expect(saved?.code, contains('console.log("preview");'));
    expect(saved?.enabled, isFalse);
  });

  testWidgets('cancelling import discards any fetched preview', (tester) async {
    UserScript? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBrowserUserScriptImportDialog(
                context,
                fetchSource: (_) async => 'run();',
              ).then((value) => result = value),
              child: const Text('Open import'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open import'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://raw.githubusercontent.com/example/repo/main/test.user.js',
    );
    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
