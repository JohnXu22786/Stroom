import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('preview dialog entry points remain available for localized callers',
      () {
    expect(const AudioPreviewDialog(filePath: '/tmp/a.wav', fileName: 'a.wav'),
        isA<AudioPreviewDialog>());
    expect(const VideoPreviewDialog(filePath: '/tmp/a.mp4', fileName: 'a.mp4'),
        isA<VideoPreviewDialog>());
    expect(showHtmlPreviewDialog, isA<Function>());
  });
}
