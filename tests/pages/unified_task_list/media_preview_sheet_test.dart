import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/media_preview_sheet.dart';

class _TemporaryDirectoryPathProvider extends PathProviderPlatform {
  _TemporaryDirectoryPathProvider(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'removes downloaded preview file when sheet is disposed mid-download',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'media_preview_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        tempDirectory.path,
      );
      final downloadStarted = Completer<void>();
      final firstChunkWritten = Completer<void>();
      final finishDownload = Completer<void>();
      final downloadFinished = Completer<void>();
      addTearDown(() {
        if (!finishDownload.isCompleted) finishDownload.complete();
        PathProviderPlatform.instance = previousPathProvider;
        tempDirectory.deleteSync(recursive: true);
      });

      Widget previewWidget() => ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaPreviewSheet(
              resource: MediaResource(
                url: 'https://example.com/preview.mp4',
                name: 'sample',
                ext: 'mp4',
              ),
              taskTitle: 'Preview',
              downloadToFile: (_, file) async {
                downloadStarted.complete();
                final output = file.openWrite();
                output.add([1, 2, 3, 4]);
                await output.flush();
                firstChunkWritten.complete();
                await finishDownload.future;
                output.add([5, 6, 7, 8]);
                await output.close();
                downloadFinished.complete();
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(previewWidget());
      await tester.pump();
      await tester.runAsync(() => downloadStarted.future);
      await tester.runAsync(() => firstChunkWritten.future);

      await tester.pumpWidget(const SizedBox.shrink());
      List<File> previewFiles() => tempDirectory
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                p.basename(file.path).startsWith('preview_sample_') &&
                file.path.endsWith('.mp4'),
          )
          .toList();
      expect(previewFiles(), hasLength(1));

      finishDownload.complete();
      await tester.runAsync(() => downloadFinished.future);
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && previewFiles().isNotEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(previewFiles(), isEmpty);
    },
  );
}
