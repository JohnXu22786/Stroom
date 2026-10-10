import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/ocr_service.dart';
import 'package:stroom/services/ocr_task_runner.dart';
import 'package:stroom/utils/text_manifest.dart';

const _config = OcrConfig(host: 'https://ocr.test/chat', apiKey: 'key');

class _ControlledAdapter implements HttpClientAdapter {
  final requested = Completer<RequestOptions>();
  final response = Completer<ResponseBody>();
  bool closed = false;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    calls++;
    requested.complete(options);
    // Deliberately permit a late response; the token must fence saving.
    return response.future;
  }

  void succeed() => response.complete(ResponseBody.fromString(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'owned text'},
              'finish_reason': 'stop'
            }
          ]
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      ));

  @override
  void close({bool force = false}) => closed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late BackgroundTaskNotifier notifier;
  late _ControlledAdapter adapter;
  late OcrTaskRunner runner;
  late String id;
  late Uint8List input;
  late Map<String, dynamic> typeConfig;
  int saves = 0;
  Completer<void>? writeGate;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('ocr_owned_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
    notifier = BackgroundTaskNotifier();
    id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'owned');
    adapter = _ControlledAdapter();
    saves = 0;
    writeGate = null;
    input = Uint8List.fromList([1, 2, 3]);
    typeConfig = {'userInstruction': 'original'};
    runner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config.copyWith(typeConfig: typeConfig),
      images: [(input, 'png')],
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = adapter,
      ),
      writeText: (name, text, {beforeCommit}) async {
        saves++;
        await writeGate?.future;
        beforeCommit?.call();
        return '/texts/$name';
      },
      onSaved: () {},
    );
  });

  tearDown(() async {
    if (notifier.mounted) notifier.dispose();
    await notifier.pendingPersistence;
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  test('owned runner snapshots input and duplicate run submits only once',
      () async {
    input[0] = 99;
    typeConfig['userInstruction'] = 'changed';
    final first = runner.run();
    final second = runner.run();
    final request = await adapter.requested.future;
    final body = request.data as Map;
    final content = (body['messages'] as List)[1]['content'] as List;
    expect(content[0]['image_url']['url'], 'data:image/png;base64,AQID');
    expect(content[1]['text'], 'original');
    adapter.succeed();
    await Future.wait([first, second]);
    expect(adapter.calls, 1);
    expect(saves, 1);
    expect(notifier.state.single.status, TaskStatus.completed);
    expect((await TextManifest.loadRecords()).single.folder, 'captured folder');
    expect(adapter.closed, isTrue);
  });

  test('delete aborts request and a late response cannot save', () async {
    final running = runner.run();
    final request = await adapter.requested.future;
    notifier.removeTask(id);
    expect(request.cancelToken!.isCancelled, isTrue);
    adapter.succeed();
    await running;
    expect(saves, 0);
    expect(await TextManifest.loadRecords(), isEmpty);
    expect(adapter.closed, isTrue);
  });

  test('persisted deletion cancels before awaiting storage', () async {
    final running = runner.run();
    final request = await adapter.requested.future;
    final removal = notifier.removeTasksPersisted([id]);
    expect(request.cancelToken!.isCancelled, isTrue);
    adapter.succeed();
    await running;
    expect(await removal, isTrue);
    expect(saves, 0);
  });

  test('batch uses one cancellable request with body-sized upload timeout',
      () async {
    final service =
        OcrService(config: _config, dio: Dio()..httpClientAdapter = adapter);
    final token = CancelToken();
    final stages = <OcrRequestStage>[];
    final running = service.recognizeBatch(
      imageBytesList: [(Uint8List(2 * 1024 * 1024), 'png'), (input, 'png')],
      cancelToken: token,
      onStage: stages.add,
    );
    final assertion = expectLater(running, throwsA(isA<Exception>()));
    final request = await adapter.requested.future;
    expect(request.sendTimeout, const Duration(minutes: 1, seconds: 4));
    expect(request.connectTimeout, const Duration(seconds: 30));
    expect(request.receiveTimeout, const Duration(minutes: 60));
    request.onSendProgress!(10, 10);
    expect(stages, [OcrRequestStage.uploading, OcrRequestStage.waiting]);
    token.cancel();
    adapter.succeed();
    await assertion;
    service.close();
    expect(adapter.calls, 1);
    expect(stages, isNot(contains(OcrRequestStage.parsing)));
  });

  test('notifier disposal cancels owned request and closes client', () async {
    final running = runner.run();
    final request = await adapter.requested.future;
    notifier.dispose();
    expect(request.cancelToken!.isCancelled, isTrue);
    adapter.succeed();
    await running;
    expect(saves, 0);
    expect(adapter.closed, isTrue);
  });

  test('cancel during file write prevents record commit', () async {
    writeGate = Completer<void>();
    final running = runner.run();
    await adapter.requested.future;
    adapter.succeed();
    while (saves == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    notifier.cancelTask(id);
    writeGate!.complete();
    await running;
    expect(await TextManifest.loadRecords(), isEmpty);
    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.error, '已取消');
    expect(adapter.closed, isTrue);
  });

  for (final shared in [false, true]) {
    test(
        'cancel after file publication cleans new data and preserves shared=$shared',
        () async {
      final hash =
          computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
      final name = '$hash.txt';
      if (shared) {
        await TextManifest.writeText(name, 'owned text');
        await TextManifest.addRecord(TextRecord(
            name: 'existing', hash: hash, createdAt: DateTime.now(), size: 10));
      }
      final published = Completer<void>();
      final release = Completer<void>();
      final owned = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [(input, 'png')],
        title: 'owned',
        folder: '',
        onSaved: () {},
        serviceFactory: (config) =>
            OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
        writeText: (name, text, {beforeCommit}) async {
          final path = await TextManifest.writeText(name, text,
              beforeCommit: beforeCommit);
          published.complete();
          await release.future;
          return path;
        },
      );
      final running = owned.run();
      await adapter.requested.future;
      adapter.succeed();
      await published.future;
      notifier.cancelTask(id);
      release.complete();
      await running;
      expect(await TextManifest.readText(name), shared ? 'owned text' : isNull);
      expect((await TextManifest.loadRecords()).length, shared ? 1 : 0);
    });
  }

  test('cancelling queued OCR preserves an earlier in-flight same-hash writer',
      () async {
    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    final published = Completer<void>();
    final release = Completer<void>();
    final earlier = TextManifest.withSaveLock(hash, () async {
      await TextManifest.writeText('$hash.txt', 'owned text');
      published.complete();
      await release.future;
      await TextManifest.addRecord(TextRecord(
          name: 'earlier', hash: hash, createdAt: DateTime.now(), size: 10));
    });
    await published.future;
    final running = runner.run();
    await adapter.requested.future;
    adapter.succeed();
    while (!notifier.state.single.steps[4].running) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(saves, 0);
    notifier.cancelTask(id);
    release.complete();
    await Future.wait([earlier, running]);
    expect(await TextManifest.readText('$hash.txt'), 'owned text');
    expect((await TextManifest.loadRecords()).single.name, 'earlier');
  });

  test('competing same-hash writer waits through cancelled OCR rollback',
      () async {
    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    final published = Completer<void>();
    final release = Completer<void>();
    final owned = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [(input, 'png')],
      title: 'owned',
      folder: '',
      onSaved: () {},
      serviceFactory: (config) =>
          OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
      writeText: (name, text, {beforeCommit}) async {
        final path = await TextManifest.writeText(name, text,
            beforeCommit: beforeCommit);
        published.complete();
        await release.future;
        return path;
      },
    );
    final running = owned.run();
    await adapter.requested.future;
    adapter.succeed();
    await published.future;
    var competingPublished = false;
    final competing = () async {
      await TextManifest.writeText('$hash.txt', 'owned text');
      competingPublished = true;
      await TextManifest.addRecord(TextRecord(
          name: 'competing', hash: hash, createdAt: DateTime.now(), size: 10));
    }();
    await Future<void>.delayed(Duration.zero);
    expect(competingPublished, isFalse);
    notifier.cancelTask(id);
    release.complete();
    await Future.wait([running, competing]);
    expect(await TextManifest.readText('$hash.txt'), 'owned text');
    expect((await TextManifest.loadRecords()).single.name, 'competing');
  });

  test('cancel rollback does not invalidate another hash during record commit',
      () async {
    final published = Completer<void>();
    final release = Completer<void>();
    final owned = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [(input, 'png')],
      title: 'owned',
      folder: '',
      onSaved: () {},
      serviceFactory: (config) =>
          OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
      writeText: (name, text, {beforeCommit}) async {
        final path = await TextManifest.writeText(name, text,
            beforeCommit: beforeCommit);
        published.complete();
        await release.future;
        return path;
      },
    );
    final running = owned.run();
    await adapter.requested.future;
    adapter.succeed();
    await published.future;
    var cancelled = false;
    await TextManifest.addRecord(
        TextRecord(
            name: 'other hash',
            hash: 'other',
            createdAt: DateTime.now(),
            size: 10), beforeCommit: () {
      if (!cancelled) {
        cancelled = true;
        notifier.cancelTask(id);
        release.complete();
      }
    });
    await running;
    expect((await TextManifest.loadRecords()).single.name, 'other hash');
  });

  test('rollback reads current DB references without replacing shared cache',
      () async {
    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    final published = Completer<void>();
    final release = Completer<void>();
    await TextManifest.loadRecords(); // Deliberately keep an older cached view.
    final owned = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [(input, 'png')],
      title: 'owned',
      folder: '',
      onSaved: () {},
      serviceFactory: (config) =>
          OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
      writeText: (name, text, {beforeCommit}) async {
        final path = await TextManifest.writeText(name, text,
            beforeCommit: beforeCommit);
        published.complete();
        await release.future;
        return path;
      },
    );
    final running = owned.run();
    await adapter.requested.future;
    adapter.succeed();
    await published.future;
    await ManifestDatabase.insertTextRecord(TextRecord(
            name: 'DB reference',
            hash: hash,
            createdAt: DateTime.now(),
            size: 10)
        .toMap());
    notifier.cancelTask(id);
    release.complete();
    await running;
    expect(await TextManifest.readText('$hash.txt'), 'owned text');
    expect(
        (await TextManifest.loadRecordsUncached()).single.name, 'DB reference');
    expect(await TextManifest.loadRecords(), isEmpty,
        reason: "rollback lookup must not replace another caller's cache");
  });

  test('progress follows actual upload, server wait, parse and save', () async {
    final stages = <int>[];
    notifier.addListener((tasks) {
      final index = tasks.single.steps.indexWhere((step) => step.running);
      if (index >= 0 && (stages.isEmpty || stages.last != index)) {
        stages.add(index);
      }
    }, fireImmediately: false);
    writeGate = Completer<void>();
    final running = runner.run();
    final request = await adapter.requested.future;
    expect(notifier.state.single.steps[0].running, isTrue);
    request.onSendProgress!(5, 10);
    expect(notifier.state.single.steps[1].running, isTrue);
    expect(notifier.state.single.steps[1].label, contains('50%'));
    request.onSendProgress!(10, 10);
    expect(notifier.state.single.steps[2].running, isTrue);
    adapter.succeed();
    while (saves == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(stages, [0, 1, 2, 3, 4]);
    expect(notifier.state.single.steps[4].running, isTrue);
    writeGate!.complete();
    await running;
  });

  for (final timeout in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('$timeout fails once without saving or replay and closes client',
        () async {
      final running = runner.run();
      final request = await adapter.requested.future;
      expect(request.connectTimeout, const Duration(seconds: 30));
      expect(request.sendTimeout, const Duration(minutes: 1));
      expect(request.receiveTimeout, const Duration(minutes: 60));
      adapter.response
          .completeError(DioException(requestOptions: request, type: timeout));
      await running;
      expect(adapter.calls, 1);
      expect(saves, 0);
      expect(notifier.state.single.status, TaskStatus.failed);
      expect(adapter.closed, isTrue);
    });
  }
}
