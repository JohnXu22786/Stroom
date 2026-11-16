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
      final requestReceived = Completer<void>();
      final secondRequestReceived = Completer<void>();
      final responseGate = Completer<void>();
      final closeResponseGate = Completer<void>();
      var requestCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverTask = server.listen((request) async {
        if (++requestCount == 1) {
          requestReceived.complete();
          await responseGate.future;
          request.response
            ..statusCode = HttpStatus.ok
            ..contentLength = 8;
          request.response.add([1, 2, 3, 4]);
          await request.response.flush();
          await closeResponseGate.future;
          request.response.add([5, 6, 7, 8]);
          await request.response.close();
        } else {
          secondRequestReceived.complete();
          request.response
            ..statusCode = HttpStatus.ok
            ..contentLength = 4
            ..add([1, 2, 3, 4]);
          await request.response.close();
        }
      });
      addTearDown(() async {
        if (!responseGate.isCompleted) responseGate.complete();
        if (!closeResponseGate.isCompleted) closeResponseGate.complete();
        await serverTask.cancel();
        await server.close(force: true);
        PathProviderPlatform.instance = previousPathProvider;
        await tempDirectory.delete(recursive: true);
      });

      Widget previewWidget() => ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaPreviewSheet(
              resource: MediaResource(
                url: 'http://127.0.0.1:${server.port}/preview.mp4',
                name: 'sample',
                ext: 'mp4',
              ),
              taskTitle: 'Preview',
            ),
          ),
        ),
      );

      await tester.pumpWidget(previewWidget());
      await tester.pump();
      await requestReceived.future;

      await tester.pumpWidget(const SizedBox.shrink());
      Future<List<File>> findPreviewFiles() async {
        final files = <File>[];
        await for (final entity in tempDirectory.list()) {
          if (entity is File &&
              p.basename(entity.path).startsWith('preview_sample_') &&
              entity.path.endsWith('.mp4')) {
            files.add(entity);
          }
        }
        return files;
      }

      expect(await findPreviewFiles(), isEmpty);

      responseGate.complete();
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && (await findPreviewFiles()).isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      final oldPreviewFile = (await findPreviewFiles()).single;
      expect(await oldPreviewFile.exists(), isTrue);

      await tester.pumpWidget(previewWidget());
      await secondRequestReceived.future;
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && (await findPreviewFiles()).length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      final previewFiles = await findPreviewFiles();
      expect(previewFiles, hasLength(2));
      final reopenedPreviewFile = previewFiles.singleWhere(
        (file) => file.path != oldPreviewFile.path,
      );

      closeResponseGate.complete();
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && await oldPreviewFile.exists(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(await oldPreviewFile.exists(), isFalse);
      expect(await reopenedPreviewFile.exists(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
