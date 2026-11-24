import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/dialogs/audio_preview_dialog.dart';
import 'package:stroom/pages/chat/dialogs/file_info_dialog.dart';
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';
import 'package:stroom/pages/chat/dialogs/json_inspection_dialog.dart';
import 'package:stroom/pages/chat/dialogs/message_save_destination_dialog.dart';
import 'package:stroom/pages/chat/dialogs/video_preview_dialog.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  Widget localizedApp(
    Widget home, {
    TextScaler textScaler = TextScaler.noScaling,
  }) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      );

  testWidgets('save destination dialog shows localized actions',
      (tester) async {
    await tester.pumpWidget(localizedApp(Builder(
      builder: (context) => TextButton(
        onPressed: () => showMessageSaveDestinationDialog(context),
        child: const Text('open'),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('保存消息'), findsOneWidget);
    expect(find.text('保存到应用文件'), findsOneWidget);
    expect(find.text('保存到设备'), findsOneWidget);
  });

  testWidgets('file information dialog shows localized field labels',
      (tester) async {
    final attachment = Attachment(
      fileName: 'notes.txt',
      mimeType: 'text/plain',
      fileType: 'document',
      hash: 'test-hash',
      storagePath: '/tmp/notes.txt',
      fileSize: 32,
    );

    await tester.pumpWidget(localizedApp(Builder(
      builder: (context) => TextButton(
        onPressed: () => showFileInfoPreviewDialog(
          context: context,
          attachment: attachment,
        ),
        child: const Text('open'),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('类型'), findsOneWidget);
    expect(find.text('大小'), findsOneWidget);
    expect(find.text('路径'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('file information labels stay bounded in narrow locales',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final attachment = Attachment(
      fileName: 'sample.pdf',
      mimeType: 'application/pdf',
      fileType: 'document',
      hash: 'fixture-hash',
      storagePath: '/local/fixture/sample.pdf',
      fileSize: 2048,
    );

    for (final locale in const [Locale('fr'), Locale('de'), Locale('ar')]) {
      for (final scale in const [1.0, 1.5]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFileInfoPreviewDialog(
                  context: context,
                  attachment: attachment,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(ConstrainedText), findsNWidgets(4));
        expect(
          tester
              .widgetList<ConstrainedText>(find.byType(ConstrainedText))
              .every((text) => text.maxLines == 1),
          isTrue,
        );
        expect(find.text('/local/fixture/sample.pdf'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: '$locale at $scale× scale');
        await tester.ensureVisible(find.byIcon(Icons.close));
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('keeps fitting Arabic file names unchanged for native shaping',
      (tester) async {
    const fileName = 'تقرير.pdf';
    final attachment = Attachment(
      fileName: fileName,
      mimeType: 'application/pdf',
      fileType: 'document',
      hash: 'test-hash',
      storagePath: '/tmp/report.pdf',
      fileSize: 32,
    );

    await tester.pumpWidget(localizedApp(Builder(
      builder: (context) => TextButton(
        onPressed: () => showFileInfoPreviewDialog(
          context: context,
          attachment: attachment,
        ),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final fileNameFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.semanticsLabel == fileName,
    );
    expect(fileNameFinder, findsOneWidget);
    expect(tester.widget<Text>(fileNameFinder).data, fileName);
  });

  testWidgets(
      'long file paths scroll on a narrow phone and keep close reachable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fileName = List.filled(140, 'f').join();
    final mimeType = List.filled(140, 'm').join();
    final storagePath =
        '/application/support/attachments/${List.filled(600, 'a').join()}/notes.txt';
    final attachment = Attachment(
      fileName: fileName,
      mimeType: mimeType,
      fileType: 'document',
      hash: 'test-hash',
      storagePath: storagePath,
      fileSize: 32,
    );

    await tester.pumpWidget(localizedApp(Builder(
      builder: (context) => TextButton(
        onPressed: () => showFileInfoPreviewDialog(
          context: context,
          attachment: attachment,
        ),
        child: const Text('open'),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final dialogSurface = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(Material),
    );
    expect(tester.getRect(dialogSurface.first).bottom, lessThanOrEqualTo(600));
    final fileNameFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.semanticsLabel == fileName,
    );
    expect(fileNameFinder, findsOneWidget);
    expect(tester.getSize(fileNameFinder).height, greaterThan(36));
    final mimeTypeFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.semanticsLabel?.contains(mimeType) == true,
    );
    expect(mimeTypeFinder, findsOneWidget);
    expect(tester.getSize(mimeTypeFinder).height, greaterThan(26));
    final pathFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.semanticsLabel == storagePath,
    );
    expect(pathFinder, findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(
            find.descendant(of: pathFinder, matching: find.byType(RichText)),
          )
          .maxLines,
      isNull,
    );
    expect(tester.takeException(), isNull);

    final closeFinder = find.text('关闭');
    await tester.ensureVisible(closeFinder);
    await tester.tap(closeFinder);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('JSON inspection dialog localizes the title and empty states',
      (tester) async {
    await tester.pumpWidget(localizedApp(Builder(
      builder: (context) => TextButton(
        onPressed: () => showJsonInspectionDialog(
          context: context,
          rawRequest: null,
          rawResponse: null,
        ),
        child: const Text('open'),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('JSON 审查'), findsOneWidget);
    expect(find.text('无请求数据'), findsOneWidget);
  });

  testWidgets('JSON inspection title keeps a bounded slot beside close action',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.8),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showJsonInspectionDialog(
              context: context,
              rawRequest: null,
              rawResponse: null,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final title = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'JSON-Prüfung',
    );
    expect(title, findsOneWidget);
    expect(tester.getSize(title).width, lessThan(256));
    expect(
      tester.getSize(find.byType(IconButton).last).width,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio preview dialog shows the localized close action',
      (tester) async {
    await tester.pumpWidget(localizedApp(const AudioPreviewDialog(
      filePath: '/missing/audio.wav',
      fileName: 'audio.wav',
    )));
    await tester.pump();

    expect(find.text('audio.wav'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('audio preview initialization failure shows localized retry',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(localizedApp(AudioPreviewDialog(
      filePath: '/missing/audio.wav',
      fileName: 'audio.wav',
      playerFactory: () => _FakeAudioPlayer(fail: attempts++ == 0),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(attempts, 2);
    expect(find.text('加载失败'), findsNothing);
    expect(find.text('重试'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('audio preview success still shows playback controls',
      (tester) async {
    await tester.pumpWidget(localizedApp(AudioPreviewDialog(
      filePath: '/missing/audio.wav',
      fileName: 'audio.wav',
      playerFactory: _FakeAudioPlayer.new,
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('加载失败'), findsNothing);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('video preview dialog stops loading and shows localized errors',
      (tester) async {
    await tester.pumpWidget(localizedApp(const VideoPreviewDialog(
      filePath: '/missing/video.mp4',
      fileName: 'video.mp4',
    )));
    await tester.pumpAndSettle();

    expect(find.text('video.mp4'), findsOneWidget);
    expect(find.text('视频加载失败'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('HTML preview dialog shows localized title and close tooltip',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousPlatform = InAppWebViewPlatform.instance;
    InAppWebViewPlatform.instance = _NeverCreatedWebViewPlatform();
    addTearDown(() {
      // The plugin interface rejects null, so when no platform was registered
      // before this test, restore the inert test platform as its neutral state.
      InAppWebViewPlatform.instance =
          previousPlatform ?? _NeverCreatedWebViewPlatform();
    });

    await tester.pumpWidget(localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showHtmlPreviewDialog(
            context: context,
            htmlCode: '<p>preview</p>',
            showEditSourceAction: true,
          ),
          child: const Text('open'),
        ),
      ),
      textScaler: TextScaler.linear(3),
    ));

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.text('HTML 预览'), findsOneWidget);
    expect(find.byTooltip('关闭预览'), findsOneWidget);
    expect(find.byTooltip('编辑'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NeverCreatedWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) =>
      _NeverCreatedWebView(params);
}

class _NeverCreatedWebView extends PlatformInAppWebViewWidget {
  _NeverCreatedWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;

  @override
  void dispose() {}
}

class _FakeAudioPlayer extends AudioPlayer {
  _FakeAudioPlayer({this.fail = false});

  final bool fail;

  @override
  Future<Duration?> setFilePath(
    String filePath, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    if (fail) throw Exception('test load failure');
    return const Duration(seconds: 10);
  }

  @override
  Duration? get duration => const Duration(seconds: 10);

  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  Stream<PlayerState> get playerStateStream =>
      Stream.value(PlayerState(false, ProcessingState.ready));

  @override
  Stream<ProcessingState> get processingStateStream =>
      Stream.value(ProcessingState.ready);

  @override
  Future<void> dispose() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration? position, {int? index}) async {}
}
