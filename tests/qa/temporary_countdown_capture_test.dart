import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/conversations_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/temporary_countdown_capsule.dart';
import 'package:stroom/widgets/topic_item.dart';

// Functional suite mapping: chat-ai-ui.
const _captureKey = ValueKey('temporary-countdown-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  testWidgets('captures fitting and cramped production countdown rows', (
    tester,
  ) async {
    final cases = [
      (
        const Size(430, 932),
        1.0,
        '../../docs/ui-constrained-text-qa/temporary-countdown/temporary-conversations-fr-430x932-scale1-light.png',
      ),
      (
        const Size(320, 640),
        4.0,
        '../../docs/ui-constrained-text-qa/temporary-countdown/temporary-conversations-fr-320x640-scale4-light.png',
      ),
    ];

    for (final (size, textScale, screenshot) in cases) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final conversation = Conversation(
        id: 'temporary-countdown-capture',
        title: 'Conversation title',
        updatedAt: DateTime(2026, 11, 26, 22),
        isTemporary: true,
        temporaryExpiresAt: DateTime.now().add(const Duration(minutes: 20)),
        temporaryPausedRemainingMilliseconds: 20 * 60 * 1000,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: ProviderScope(
            overrides: [
              conversationsProvider.overrideWith((ref) {
                final notifier = ConversationsNotifier(ref);
                notifier.state = [conversation];
                return notifier;
              }),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('fr'),
              theme: ThemeData.light(useMaterial3: true),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child!,
              ),
              home: ConversationsPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TemporaryCountdownCapsule), findsOneWidget);
      expect(tester.takeException(), isNull);
      final timerRect = tester.getRect(find.byType(TemporaryCountdownCapsule));
      final titleRect = tester.getRect(find.text('Conversation title'));
      expect(timerRect.overlaps(titleRect), isFalse);
      if (textScale == 1) {
        expect(timerRect.center.dy, closeTo(titleRect.center.dy, 1));
      } else {
        expect(timerRect.top, greaterThanOrEqualTo(titleRect.bottom));
      }
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(screenshot),
      );
      if (textScale > 1) {
        final titleFinder = find.text('Conversation title');
        final initialTitleX = tester.getTopLeft(titleFinder).dx;
        for (var second = 1; second <= 17; second += 2) {
          await tester.pump(const Duration(seconds: 2));
          await expectLater(
            find.byKey(_captureKey),
            matchesGoldenFile(
              '../../docs/ui-constrained-text-qa/temporary-countdown/conversation-reveal-${second + 1}s.png',
            ),
          );
        }
        expect(tester.getTopLeft(titleFinder).dx, lessThan(initialTitleX));
        await expectLater(
          find.byKey(_captureKey),
          matchesGoldenFile(
            '../../docs/ui-constrained-text-qa/temporary-countdown/temporary-conversations-fr-320x640-scale4-reveal.png',
          ),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('captures large-scale production topic row reflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const topicCaptureKey = ValueKey('temporary-topic-countdown-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: topicCaptureKey,
        child: ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('fr'),
            theme: ThemeData.light(useMaterial3: true),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(4),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: TopicItem(
                topic: Conversation(
                  id: 'temporary-topic-countdown-capture',
                  title: 'Topic title',
                  updatedAt: DateTime(2026, 11, 26, 22),
                  isTemporary: true,
                  temporaryExpiresAt:
                      DateTime.now().add(const Duration(minutes: 20)),
                  temporaryPausedRemainingMilliseconds: 20 * 60 * 1000,
                ),
                selectionMode: false,
                isSelected: false,
                isActive: false,
                onTap: () {},
                onDelete: () {},
                onPinToggle: () {},
                onRename: () {},
                onAutoRename: () {},
                onReadStateToggle: () {},
                onSelectionToggle: () {},
                onTemporaryToggle: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(topicCaptureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/temporary-countdown/topic-item-fr-320x640-scale4-light.png',
      ),
    );
    final dateFinder = find.textContaining('-');
    final initialDateX = tester.getTopLeft(dateFinder).dx;
    for (var second = 1; second <= 17; second += 2) {
      await tester.pump(const Duration(seconds: 2));
      await expectLater(
        find.byKey(topicCaptureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/temporary-countdown/topic-date-reveal-${second + 1}s.png',
        ),
      );
    }
    expect(tester.getTopLeft(dateFinder).dx, lessThan(initialDateX));
    await expectLater(
      find.byKey(topicCaptureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/temporary-countdown/topic-item-fr-320x640-scale4-reveal.png',
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
