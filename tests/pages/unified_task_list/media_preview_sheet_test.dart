import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      Directory? tempDirectory;
      await tester.runAsync(() async {
        tempDirectory = await Directory.systemTemp.createTemp(
          'media_preview_',
        );
      });
      final temporaryDirectory = tempDirectory!;
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryDirectoryPathProvider(
        temporaryDirectory.path,
      );
      final downloadStarted = Completer<File>();
      final finishDownload = Completer<void>();
      addTearDown(() {
        if (!finishDownload.isCompleted) finishDownload.complete();
        PathProviderPlatform.instance = previousPathProvider;
        temporaryDirectory.deleteSync(recursive: true);
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
                  downloadToFile: (_, file) {
                    downloadStarted.complete(file);
                    return finishDownload.future;
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(previewWidget());
      await tester.pump();
      expect(downloadStarted.isCompleted, isTrue);
      final previewFile = await downloadStarted.future;

      await tester.pumpWidget(const SizedBox.shrink());
      expect(previewFile.existsSync(), isFalse);
      previewFile.writeAsBytesSync([1, 2, 3, 4]);
      expect(previewFile.existsSync(), isTrue);

      finishDownload.complete();
      await tester.pump();
      for (var i = 0; i < 100 && previewFile.existsSync(); i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pump();
      expect(previewFile.existsSync(), isFalse);
    },
  );
}
