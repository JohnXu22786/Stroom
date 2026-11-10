import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/catcatch/config/default_rules.dart';
import 'package:stroom/catcatch/engine/task_executor.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/services/storage_service.dart';

class _DocumentsDirectory extends PathProviderPlatform {
  _DocumentsDirectory(this.path);

  final String path;

  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resumes a single-file download from its existing staging file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'catcatch_resume_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _DocumentsDirectory(directory.path);
      AppStorage.resetCache();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      const contents = 'complete file contents';
      String? requestedRange;
      final serverDone = server.listen((request) async {
        requestedRange = request.headers.value(HttpHeaders.rangeHeader);
        final startByte = requestedRange == 'bytes=7-'
            ? 7
            : requestedRange == null
                ? 0
                : contents.length;
        request.response.statusCode =
            requestedRange == null ? HttpStatus.ok : HttpStatus.partialContent;
        request.response.write(contents.substring(startByte));
        await request.response.close();
      });

      try {
        const fileName = 'resume.mp4';
        final downloadDirectory = p.join(
          directory.path,
          'catcatch',
          'downloads',
        );
        final partial = File(
          p.join(
            downloadDirectory,
            '$fileName${DefaultRules.tempFileSuffix}',
          ),
        )
          ..createSync(recursive: true)
          ..writeAsStringSync(contents.substring(0, 7));
        final task = CatCatchTask(
          id: 'resume-single-file',
          url: 'https://example.com/video',
          expectedDurationSec: 0,
          createdAt: DateTime(2026),
          detectedMedia: [
            MediaResource(
              url: 'http://${server.address.address}:${server.port}/video',
              name: 'resume',
              ext: 'mp4',
            ),
          ],
          selectedMedia: MediaResource(
            url: 'http://${server.address.address}:${server.port}/video',
            name: 'resume',
            ext: 'mp4',
          ),
          steps: [
            for (final type in StepType.values)
              type == StepType.downloading
                  ? StepStatus.pending(type)
                  : StepStatus.done(type),
          ],
        );

        final downloadedPath = await HttpOverrides.runWithHttpOverrides(
          () => TaskExecutor.executeTask(task: task, onUpdate: (_) {}),
          _RealHttpOverrides(),
        );

        expect(requestedRange, 'bytes=7-');
        expect(await File(downloadedPath!).readAsString(), contents);
        expect(await partial.exists(), isFalse);
      } finally {
        await serverDone.cancel();
        await server.close(force: true);
        PathProviderPlatform.instance = previousPathProvider;
        AppStorage.resetCache();
        await directory.delete(recursive: true);
      }
    },
  );
}
