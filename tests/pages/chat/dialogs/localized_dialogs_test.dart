import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/dialogs/audio_preview_dialog.dart';
import 'package:stroom/pages/chat/dialogs/file_info_dialog.dart';
import 'package:stroom/pages/chat/dialogs/html_preview_dialog.dart';
import 'package:stroom/pages/chat/dialogs/json_inspection_dialog.dart';
import 'package:stroom/pages/chat/dialogs/message_save_destination_dialog.dart';
import 'package:stroom/pages/chat/dialogs/video_preview_dialog.dart';

void main() {
  Widget localizedApp(Widget home) => MaterialApp(
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
    final previousPlatform = InAppWebViewPlatform.instance;
    InAppWebViewPlatform.instance = _NeverCreatedWebViewPlatform();
    addTearDown(() {
      // The plugin interface rejects null, so when no platform was registered
      // before this test, restore the inert test platform as its neutral state.
      InAppWebViewPlatform.instance =
          previousPlatform ?? _NeverCreatedWebViewPlatform();
    });

    await tester.pumpWidget(localizedApp(Builder(
      builder: (context) => TextButton(
        onPressed: () => showHtmlPreviewDialog(
          context: context,
          htmlCode: '<p>preview</p>',
        ),
        child: const Text('open'),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.text('HTML 预览'), findsOneWidget);
    expect(find.byTooltip('关闭预览'), findsOneWidget);
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
