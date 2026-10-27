import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/services/flow_temporary_artifact_storage.dart';
import 'package:stroom/utils/web_file_store.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);

  final String path;

  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

class _GatedDocuments extends PathProviderPlatform {
  _GatedDocuments(this.path);

  final String path;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String> getApplicationDocumentsPath() async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late PathProviderPlatform previousDocuments;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('flow_temp_storage_');
    previousDocuments = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(documents.path);
    AppStorage.resetCache();
    WebFileStore.disableTestMode();
  });

  tearDown(() async {
    WebFileStore.disableTestMode();
    PathProviderPlatform.instance = previousDocuments;
    AppStorage.resetCache();
    await documents.delete(recursive: true);
  });

  test(
      'native artifacts are copied into owner-scoped storage and deleted safely',
      () async {
    final sourceBytes = Uint8List.fromList([1, 2, 3, 4]);
    final source = File('${documents.path}/source.wav')
      ..writeAsBytesSync(sourceBytes);
    final copiedReference = await FlowTemporaryArtifactStorage.copyNativeFile(
      sourcePath: source.path,
      executionId: 'execution-1',
      blockId: 'block-1',
    );

    expect(
      await FlowTemporaryArtifactStorage.ownsReference(
        executionId: 'execution-1',
        blockId: 'block-1',
        reference: copiedReference,
      ),
      isTrue,
    );
    expect(
      await FlowTemporaryArtifactStorage.ownsReference(
        executionId: 'execution-1',
        blockId: 'block-2',
        reference: copiedReference,
      ),
      isFalse,
    );
    expect(await File(copiedReference).readAsBytes(), sourceBytes);

    expect(
      await FlowTemporaryArtifactStorage.deleteArtifact(
        FlowTemporaryArtifact(
          executionId: 'other-execution',
          blockId: 'block-1',
          reference: copiedReference,
        ),
      ),
      isFalse,
    );
    expect(await File(copiedReference).exists(), isTrue);
    expect(
      await FlowTemporaryArtifactStorage.deleteArtifact(
        FlowTemporaryArtifact(
          executionId: 'execution-1',
          blockId: 'block-1',
          reference: source.path,
        ),
      ),
      isFalse,
    );
    expect(await source.exists(), isTrue);

    expect(
      await FlowTemporaryArtifactStorage.deleteArtifact(
        FlowTemporaryArtifact(
          executionId: 'execution-1',
          blockId: 'block-1',
          reference: copiedReference,
        ),
      ),
      isTrue,
    );
    expect(await File(copiedReference).exists(), isFalse);
    expect(await source.readAsBytes(), sourceBytes);
  });

  test('native execution cleanup leaves another execution intact', () async {
    final first = await FlowTemporaryArtifactStorage.writeBytes(
      executionId: 'execution-1',
      blockId: 'block-1',
      fileName: 'voice.wav',
      bytes: Uint8List.fromList([1]),
    );
    final second = await FlowTemporaryArtifactStorage.writeBytes(
      executionId: 'execution-2',
      blockId: 'block-1',
      fileName: 'voice.wav',
      bytes: Uint8List.fromList([2]),
    );

    expect(await File(first).readAsBytes(), [1]);
    expect(await File(second).readAsBytes(), [2]);
    await FlowTemporaryArtifactStorage.deleteExecution('execution-1');

    expect(await File(first).exists(), isFalse);
    expect(await File(second).readAsBytes(), [2]);
  });

  test('deletion guard is rechecked after async ownership validation',
      () async {
    final reference = await FlowTemporaryArtifactStorage.writeBytes(
      executionId: 'execution-1',
      blockId: 'block-1',
      fileName: 'voice.wav',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    final artifact = FlowTemporaryArtifact(
      executionId: 'execution-1',
      blockId: 'block-1',
      reference: reference,
    );
    final gatedDocuments = _GatedDocuments(documents.path);
    PathProviderPlatform.instance = gatedDocuments;
    AppStorage.resetCache();
    var cleanupAllowed = true;
    final deletion = FlowTemporaryArtifactStorage.deleteArtifact(
      artifact,
      shouldDelete: () => cleanupAllowed,
    );

    await gatedDocuments.entered.future;
    cleanupAllowed = false;
    gatedDocuments.release.complete();

    expect(await deletion, isFalse);
    expect(await File(reference).readAsBytes(), [1, 2, 3]);
  });

  test(
      'Web artifacts use private keys and deletion stays in the owner namespace',
      () async {
    WebFileStore.enableTestMode();
    const unrelatedKey = 'attachments/shared.wav';
    await WebFileStore.write(unrelatedKey, Uint8List.fromList([9]));
    final ownReference = await FlowTemporaryArtifactStorage.writeBytes(
      executionId: 'execution-1',
      blockId: 'block-1',
      fileName: '../voice.wav',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    final otherExecutionReference =
        await FlowTemporaryArtifactStorage.writeBytes(
      executionId: 'execution-2',
      blockId: 'block-1',
      fileName: 'voice.wav',
      bytes: Uint8List.fromList([4]),
    );

    expect(ownReference, startsWith('task_flow_temporary/'));
    expect(await WebFileStore.read(ownReference), [1, 2, 3]);
    expect(
      await FlowTemporaryArtifactStorage.ownsReference(
        executionId: 'execution-1',
        blockId: 'block-2',
        reference: ownReference,
      ),
      isFalse,
    );
    expect(
      await FlowTemporaryArtifactStorage.deleteArtifact(
        FlowTemporaryArtifact(
          executionId: 'execution-2',
          blockId: 'block-1',
          reference: ownReference,
        ),
      ),
      isFalse,
    );
    expect(await WebFileStore.read(ownReference), [1, 2, 3]);

    await FlowTemporaryArtifactStorage.deleteExecution('execution-1');
    expect(await WebFileStore.read(ownReference), isNull);
    expect(await WebFileStore.read(otherExecutionReference), [4]);
    expect(await WebFileStore.read(unrelatedKey), [9]);
  });
}
