// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/services/block_executors/chat_executor.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previous;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('catcatch_chat_mime_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();
  });

  tearDown(() async {
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  for (final sample in [
    (name: 'video_only.webm', type: IOType.video, mime: 'video/webm'),
    (name: 'audio_only.webm', type: IOType.audio, mime: 'audio/webm'),
    (name: 'audio_only.flv', type: IOType.audio, mime: 'audio/x-flv'),
    (name: 'video_only.flv', type: IOType.video, mime: 'video/x-flv'),
    (name: 'audio_only.mov', type: IOType.audio, mime: 'audio/quicktime'),
    (name: 'audio_only.avi', type: IOType.audio, mime: 'audio/x-msvideo'),
    (name: 'audio_only.mp4', type: IOType.audio, mime: 'audio/mp4'),
    (name: 'video_only.mkv', type: IOType.video, mime: 'video/x-matroska'),
    (name: 'audio_only.mkv', type: IOType.audio, mime: 'audio/x-matroska'),
    (name: 'video_only.ogg', type: IOType.video, mime: 'video/ogg'),
    (
      name: 'audio_only.mpg',
      type: IOType.audio,
      mime: 'audio/x-mpeg-program-stream'
    ),
  ]) {
    test(
        '${sample.name} retains verified track MIME through chat attachment storage',
        () async {
      final file =
          await File(p.join('tests', 'fixtures', 'catcatch', sample.name))
              .copy(p.join(directory.path, sample.name));
      final output = await catCatchOutputPayload(file.path);
      expect(output.type, sample.type);
      expect(output.mimeType, sample.mime);
      final restored = FlowPayload.fromMap(output.toMap());
      final message = await prepareFlowChatMessage(restored, 'conversation',
          endpointType: 'gemini');
      final attachment = message.attachments.single;
      expect(attachment.fileType, sample.type.name);
      expect(attachment.mimeType, sample.mime);
      expect(attachment.conversationId, 'conversation');
      expect(await AttachmentStorage.readFile(attachment.storagePath),
          await file.readAsBytes());
    });
  }

  for (final strongMagic in ['png', 'mp3', 'wav']) {
    test('$strongMagic bytes cannot be spoofed by a shared-container MIME',
        () async {
      final file = File(p.join(directory.path, 'spoofed.webm'));
      if (strongMagic == 'png') {
        await file
            .writeAsBytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      } else {
        await File(p.join(
                'tests', 'fixtures', 'catcatch', 'audio_only.$strongMagic'))
            .copy(file.path);
      }
      await expectLater(
          prepareFlowChatMessage(
              FlowPayload.file(
                  fileReference: file.path,
                  type: IOType.video,
                  mimeType: 'video/webm'),
              'conversation',
              endpointType: 'gemini'),
          throwsA(isA<FormatException>()));
      expect(await Directory(p.join(directory.path, 'attachments')).exists(),
          isFalse);
    });
  }

  test('metadata for another container family cannot override MP4 bytes',
      () async {
    final file = await File('tests/fixtures/catcatch/video_only.mp4')
        .copy(p.join(directory.path, 'spoofed.webm'));
    await expectLater(
        prepareFlowChatMessage(
            FlowPayload.file(
                fileReference: file.path,
                type: IOType.audio,
                mimeType: 'audio/webm'),
            'conversation',
            endpointType: 'gemini'),
        throwsA(isA<FormatException>()));
    expect(await Directory(p.join(directory.path, 'attachments')).exists(),
        isFalse);
  });

  test('FLV MIME metadata does not override strong MP3 bytes', () async {
    final file = await File('tests/fixtures/catcatch/audio_only.mp3')
        .copy(p.join(directory.path, 'spoofed.flv'));
    await expectLater(
        prepareFlowChatMessage(
            FlowPayload.file(
                fileReference: file.path,
                type: IOType.video,
                mimeType: 'video/x-flv'),
            'conversation',
            endpointType: 'gemini'),
        throwsA(isA<FormatException>()));
    expect(await Directory(p.join(directory.path, 'attachments')).exists(),
        isFalse);
  });

  test('ordinary file MIME fallback remains available', () {
    expect(
        flowFileMimeType('notes.txt',
            headerBytes: [1, 2, 3], mimeType: 'video/webm'),
        'text/plain');
  });
}
