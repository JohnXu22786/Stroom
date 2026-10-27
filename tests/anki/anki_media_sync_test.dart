import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/sync/anki_sync_provider.dart';
import 'package:stroom/anki/sync/anki_media_sync.dart';
import 'package:stroom/anki/sync/anki_sync_protocol_client.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  group('Anki media sync archives', () {
    test('encodes upload metadata and file bytes in Anki ZIP format', () {
      final bytes = AnkiMediaSync.encodeUploadArchive([
        const AnkiMediaUploadEntry('front.jpg', [1, 2, 3]),
        const AnkiMediaUploadEntry('old.ogg', null),
      ]);
      final archive = ZipDecoder().decodeBytes(bytes);
      final metaFile = archive.findFile('_meta')!;
      final meta = jsonDecode(utf8.decode(metaFile.content as List<int>));

      expect(meta, [
        ['front.jpg', '0'],
        ['old.ogg', null],
      ]);
      expect(archive.findFile('0')!.content, [1, 2, 3]);
    });

    test('decodes downloaded files using Anki media index names', () {
      final archive = Archive();
      final fileBytes = [7, 8, 9];
      final metaBytes = utf8.encode(jsonEncode({'0': 'back.png'}));
      archive.addFile(ArchiveFile('0', fileBytes.length, fileBytes));
      archive.addFile(ArchiveFile('_meta', metaBytes.length, metaBytes));
      final bytes = ZipEncoder().encode(archive);

      expect(AnkiMediaSync.decodeDownloadArchive(bytes), {
        'back.png': fileBytes,
      });
    });

    test(
      'does not reuse a media cursor for another account on the same server',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_account_identity_test_',
        );
        const firstAccountKey = 'first-account-host-key';
        const secondAccountKey = 'second-account-host-key';
        final firstClient = AnkiSyncProtocolClient.ankiWeb(
          client: _QueueHttpClient(),
          hostKey: firstAccountKey,
        );
        final fake = _QueueHttpClient();
        final secondClient = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: secondAccountKey,
        );
        final storageSlot = AnkiSyncState(isLoaded: true).secureStorageKey;
        await _seedMediaIndex(
          workDir,
          storageSlot,
          lastSyncUsn: 7,
          files: const [],
        );
        fake.responseFor = (request, body) async {
          switch (request.url.path) {
            case '/msync/begin':
              return _jsonResponse({
                'data': {'usn': 7, 'sk': secondAccountKey},
                'err': '',
              });
            case '/msync/mediaChanges':
              return _jsonResponse({'data': [], 'err': ''});
            case '/msync/mediaSanity':
              return _jsonResponse({'data': 'OK', 'err': ''});
            default:
              return _jsonResponse({'data': null, 'err': ''});
          }
        };
        expect(
          firstClient.destinationIdentity,
          isNot(secondClient.destinationIdentity),
        );

        try {
          await AnkiMediaSync.sync(secondClient, documentsPath: workDir.path);

          expect(fake.paths, contains('/msync/mediaChanges'));
        } finally {
          firstClient.close();
          secondClient.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test(
      'rejects a media ZIP entry by declared size before reading content',
      () {
        const declaredSize = 100 * 1024 * 1024 + 1;
        final archive = Archive()
          ..addFile(ArchiveFile('0', declaredSize, [7]))
          ..addFile(ArchiveFile.string('_meta', jsonEncode({'0': 'back.png'})));

        expect(
          () =>
              AnkiMediaSync.decodeDownloadArchive(ZipEncoder().encode(archive)),
          throwsA(isA<AnkiSyncException>()),
        );
      },
    );

    test('checks ZIP entry sizes before decoding Unix symlink payloads', () {
      const oversizedEntrySize = 100 * 1024 * 1024 + 1;
      final payload = ArchiveFile.bytes('0', List.filled(1024, 7))
        ..compression = CompressionType.deflate;
      final archive = Archive()
        ..addFile(payload)
        ..addFile(ArchiveFile.string('_meta', jsonEncode({'0': 'back.png'})));
      final bytes = List<int>.from(ZipEncoder().encode(archive));
      final centralDirectorySignature = [0x50, 0x4b, 0x01, 0x02];
      final filename = [0x30];
      final centralOffset = _indexOf(bytes, centralDirectorySignature, 0);
      expect(centralOffset, isNonNegative);
      expect(bytes.sublist(centralOffset + 46, centralOffset + 47), filename);

      // Mark the file as a Unix symlink and give it an oversized declared
      // length. ZipDecoder eagerly reads symlink contents while parsing.
      bytes[centralOffset + 4] = 20;
      bytes[centralOffset + 5] = 3;
      bytes[centralOffset + 38] = 0;
      bytes[centralOffset + 39] = 0;
      bytes[centralOffset + 40] = 0;
      bytes[centralOffset + 41] = 0xa0;
      for (var i = 0; i < 4; i++) {
        bytes[centralOffset + 24 + i] = (oversizedEntrySize >> (8 * i)) & 0xff;
      }

      final localHeaderSignature = [0x50, 0x4b, 0x03, 0x04];
      final localOffset = _indexOf(bytes, localHeaderSignature, 0);
      expect(localOffset, isNonNegative);
      final compressedOffset = localOffset +
          30 +
          bytes[localOffset + 26] +
          bytes[localOffset + 27] * 256;
      bytes[compressedOffset] = 0xff;

      expect(
        () => AnkiMediaSync.decodeDownloadArchive(bytes),
        throwsA(
          isA<AnkiSyncException>().having(
            (error) => error.message,
            'message',
            contains('100 MB'),
          ),
        ),
      );
    });

    test('caps the total declared media bytes in a downloaded ZIP', () {
      const declaredFileSize = 60 * 1024 * 1024;
      final archive = Archive()
        ..addFile(ArchiveFile('0', declaredFileSize, [7]))
        ..addFile(ArchiveFile('1', declaredFileSize, [8]))
        ..addFile(
          ArchiveFile.string(
            '_meta',
            jsonEncode({'0': 'front.png', '1': 'back.png'}),
          ),
        );

      expect(
        () => AnkiMediaSync.decodeDownloadArchive(ZipEncoder().encode(archive)),
        throwsA(isA<AnkiSyncException>()),
      );
    });

    test('rejects undeclared entries in a downloaded media ZIP', () {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('0', [7]))
        ..addFile(ArchiveFile.bytes('unexpected', [8]))
        ..addFile(ArchiveFile.string('_meta', jsonEncode({'0': 'front.png'})));

      expect(
        () => AnkiMediaSync.decodeDownloadArchive(ZipEncoder().encode(archive)),
        throwsA(isA<AnkiSyncException>()),
      );
    });

    test('stops decoding a media ZIP after the allowed entry count', () {
      final metadata = <String, String>{};
      final archive = Archive();
      for (var index = 0; index < 26; index++) {
        final name = '$index';
        metadata[name] = 'file-$name.png';
        archive.addFile(ArchiveFile.bytes(name, [index]));
      }
      archive.addFile(ArchiveFile.string('_meta', jsonEncode(metadata)));

      expect(
        () => AnkiMediaSync.decodeDownloadArchive(ZipEncoder().encode(archive)),
        throwsA(isA<AnkiSyncException>()),
      );
    });

    test('rejects an oversized media ZIP manifest before reading it', () {
      const declaredSize = 1024 * 1024 + 1;
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('0', [7]))
        ..addFile(
          ArchiveFile(
            '_meta',
            declaredSize,
            utf8.encode(jsonEncode({'0': 'front.png'})),
          ),
        );

      expect(
        () => AnkiMediaSync.decodeDownloadArchive(ZipEncoder().encode(archive)),
        throwsA(isA<AnkiSyncException>()),
      );
    });

    test('rejects path traversal in upload and download filenames', () {
      expect(
        () => AnkiMediaSync.encodeUploadArchive([
          const AnkiMediaUploadEntry('../outside.txt', [1]),
        ]),
        throwsA(isA<AnkiSyncException>()),
      );

      final archive = Archive();
      const payload = [1];
      final metaBytes = utf8.encode(jsonEncode({'0': '../outside.txt'}));
      archive.addFile(ArchiveFile('0', payload.length, payload));
      archive.addFile(ArchiveFile('_meta', metaBytes.length, metaBytes));
      expect(
        () => AnkiMediaSync.decodeDownloadArchive(ZipEncoder().encode(archive)),
        throwsA(isA<AnkiSyncException>()),
      );
    });

    test(
      'accepts Anki tuple upload response and uppercase sanity status',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_test_',
        );
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        await File('${mediaDir.path}/front.png').writeAsBytes([1, 2, 3]);
        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 0, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({
              'data': [1, 1],
              'err': '',
            }),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: 'ankiweb:test',
            documentsPath: workDir.path,
          );

          expect(result.uploadedFiles, 1);
          expect(fake.paths, [
            '/msync/begin',
            '/msync/uploadChanges',
            '/msync/mediaSanity',
          ]);
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test(
      'skips empty and oversized local files while syncing other media',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_unavailable_local_test_',
        );
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        await File('${mediaDir.path}/empty.bin').writeAsBytes([]);
        final oversized = await File('${mediaDir.path}/oversized.bin')
            .open(mode: FileMode.write);
        await oversized.truncate(100 * 1024 * 1024 + 1);
        await oversized.close();
        await File('${mediaDir.path}/keep.png').writeAsBytes([1, 2, 3]);
        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 0, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({
              'data': [1, 1],
              'err': '',
            }),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: 'ankiweb:skip-invalid-local-media',
            documentsPath: workDir.path,
          );

          expect(result.uploadedFiles, 1);
          expect(fake.paths, [
            '/msync/begin',
            '/msync/uploadChanges',
            '/msync/mediaSanity',
          ]);
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test(
        'fails before syncing when an indexed media file exceeds the upload limit',
        () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_indexed_oversized_test_',
      );
      const identity = 'ankiweb:indexed-oversized-media';
      final mediaDir = Directory('${workDir.path}/collection.media');
      await mediaDir.create();
      final oversized = await File('${mediaDir.path}/oversized.bin')
          .open(mode: FileMode.write);
      await oversized.truncate(100 * 1024 * 1024 + 1);
      await oversized.close();
      await _seedMediaIndex(
        workDir,
        identity,
        files: [
          {
            'fname': 'oversized.bin',
            'sha1': sha1.convert([7, 8, 9]).toString(),
            'usn': 0,
            'sync_required': 0,
          },
        ],
      );
      final fake = _QueueHttpClient()
        ..responses.addAll([
          _jsonResponse({
            'data': {'usn': 1, 'sk': 'test-host-key'},
            'err': '',
          }),
          _jsonResponse({'data': [], 'err': ''}),
          _jsonResponse({'data': 'OK', 'err': ''}),
        ]);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        await expectLater(
          AnkiMediaSync.sync(
            client,
            syncIdentity: identity,
            documentsPath: workDir.path,
          ),
          throwsA(isA<AnkiSyncException>()),
        );

        expect(fake.paths, isEmpty);
        expect(await File('${mediaDir.path}/oversized.bin').exists(), isTrue);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test('does not upload Finder or Explorer metadata files', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_os_files_test_',
      );
      final mediaDir = Directory('${workDir.path}/collection.media');
      await mediaDir.create();
      await File('${mediaDir.path}/.DS_Store').writeAsBytes([4, 5]);
      await File('${mediaDir.path}/Thumbs.db').writeAsBytes([6, 7]);
      await File('${mediaDir.path}/keep.png').writeAsBytes([1, 2, 3]);
      final fake = _QueueHttpClient()
        ..responses.addAll([
          _jsonResponse({
            'data': {'usn': 0, 'sk': 'test-host-key'},
            'err': '',
          }),
          _jsonResponse({
            'data': [1, 1],
            'err': '',
          }),
          _jsonResponse({'data': 'OK', 'err': ''}),
        ]);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        final result = await AnkiMediaSync.sync(
          client,
          syncIdentity: 'ankiweb:skip-os-media-files',
          documentsPath: workDir.path,
        );

        expect(result.uploadedFiles, 1);
        expect(fake.paths, [
          '/msync/begin',
          '/msync/uploadChanges',
          '/msync/mediaSanity',
        ]);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test(
        'fails visibly before syncing an unindexed local filename Anki cannot upload',
        () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_invalid_local_name_test_',
      );
      final mediaDir = Directory('${workDir.path}/collection.media');
      await mediaDir.create();
      await File('${mediaDir.path}/a:b.png').writeAsBytes([1, 2, 3]);
      final fake = _QueueHttpClient()
        ..responses.addAll([
          _jsonResponse({
            'data': {'usn': 0, 'sk': 'test-host-key'},
            'err': '',
          }),
          _jsonResponse({'data': 'OK', 'err': ''}),
        ]);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        await expectLater(
          AnkiMediaSync.sync(
            client,
            syncIdentity: 'ankiweb:invalid-local-media-name',
            documentsPath: workDir.path,
          ),
          throwsA(isA<AnkiSyncException>()),
        );

        expect(fake.paths, isEmpty);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test(
      'does not tombstone an existing file with a non-normalized name',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_non_normalized_existing_test_',
        );
        const identity = 'ankiweb:non-normalized-existing-media';
        const filename = 'unsafe:name.png';
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        final bytes = [1, 2, 3];
        await File('${mediaDir.path}/$filename').writeAsBytes(bytes);
        await _seedMediaIndex(
          workDir,
          identity,
          files: [
            {
              'fname': filename,
              'sha1': sha1.convert(bytes).toString(),
              'usn': 0,
              'sync_required': 0,
            },
          ],
        );

        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 0, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        fake.responseFor = (request, body) async {
          if (request.url.path != '/msync/uploadChanges') return null;
          return _jsonResponse({
            'data': [1, 1],
            'err': '',
          });
        };
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: identity,
            documentsPath: workDir.path,
          );

          expect(result.deletedFiles, 0);
          expect(fake.paths, ['/msync/begin', '/msync/mediaSanity']);
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test(
      'does not let skipped files block later pending media uploads',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_skip_batch_test_',
        );
        const identity = 'ankiweb:skip-batch-media';
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        final skippedNames = [
          for (var index = 0; index < 25; index++)
            'a${index.toString().padLeft(2, '0')}.bin',
        ];
        for (final name in skippedNames) {
          await File('${mediaDir.path}/$name').writeAsBytes([]);
        }
        final uploadBytes = [1, 2, 3];
        await File('${mediaDir.path}/z-valid.png').writeAsBytes(uploadBytes);
        await _seedMediaIndex(
          workDir,
          identity,
          files: [
            for (final name in skippedNames)
              {
                'fname': name,
                'sha1': sha1.convert([4, 5, 6]).toString(),
                'usn': 0,
                'sync_required': 1,
              },
          ],
        );

        List<Object?>? uploadedMetadata;
        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 0, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        fake.responseFor = (request, body) async {
          if (request.url.path != '/msync/uploadChanges') return null;
          final fields = _multipartFields(request, body);
          final archive = ZipDecoder().decodeBytes(fields['data']!);
          uploadedMetadata = jsonDecode(
            utf8.decode(archive.findFile('_meta')!.content as List<int>),
          ) as List<Object?>;
          return _jsonResponse({
            'data': [1, 1],
            'err': '',
          });
        };
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: identity,
            documentsPath: workDir.path,
          );

          expect(result.uploadedFiles, 1);
          expect(uploadedMetadata, [
            ['z-valid.png', '0'],
          ]);
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test(
      'fails on an indexed empty file without deleting local media',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_skip_preserve_test_',
        );
        const identity = 'ankiweb:preserve-skipped-media';
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        await File('${mediaDir.path}/empty.bin').writeAsBytes([]);
        final oversized = await File('${mediaDir.path}/oversized.bin')
            .open(mode: FileMode.write);
        await oversized.truncate(100 * 1024 * 1024 + 1);
        await oversized.close();
        await _seedMediaIndex(
          workDir,
          identity,
          files: [
            {
              'fname': 'empty.bin',
              'sha1': sha1.convert([4, 5, 6]).toString(),
              'usn': 0,
              'sync_required': 0,
            },
          ],
        );

        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 0, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          await expectLater(
            AnkiMediaSync.sync(
              client,
              syncIdentity: identity,
              documentsPath: workDir.path,
            ),
            throwsA(isA<AnkiSyncException>()),
          );

          expect(fake.paths, isEmpty);
          expect(await File('${mediaDir.path}/empty.bin').exists(), isTrue);
          expect(await File('${mediaDir.path}/oversized.bin').exists(), isTrue);
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test('fails on new empty or oversized media files', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_new_invalid_test_',
      );
      const identity = 'ankiweb:new-invalid-media';
      final mediaDir = Directory('${workDir.path}/collection.media');
      await mediaDir.create();
      await File('${mediaDir.path}/empty.bin').writeAsBytes([]);
      final oversized = await File('${mediaDir.path}/oversized.bin')
          .open(mode: FileMode.write);
      await oversized.truncate(100 * 1024 * 1024 + 1);
      await oversized.close();
      await _seedMediaIndex(workDir, identity, files: []);
      final fake = _QueueHttpClient();
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'new-invalid-host-key',
      );

      try {
        await expectLater(
          AnkiMediaSync.sync(
            client,
            syncIdentity: identity,
            documentsPath: workDir.path,
          ),
          throwsA(isA<AnkiSyncException>()),
        );

        expect(fake.paths, isEmpty);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test('keeps invalid pending media uploads pending and fails sync', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_pending_invalid_test_',
      );
      const identity = 'ankiweb:pending-invalid-media';
      final mediaDir = Directory('${workDir.path}/collection.media');
      await mediaDir.create();
      await File('${mediaDir.path}/empty.bin').writeAsBytes([]);
      final oversized = await File('${mediaDir.path}/oversized.bin')
          .open(mode: FileMode.write);
      await oversized.truncate(100 * 1024 * 1024 + 1);
      await oversized.close();
      final emptyHash = sha1.convert([1, 2, 3]).toString();
      final oversizedHash = sha1.convert([4, 5, 6]).toString();
      await _seedMediaIndex(
        workDir,
        identity,
        files: [
          {
            'fname': 'empty.bin',
            'sha1': emptyHash,
            'usn': -1,
            'sync_required': 1,
          },
          {
            'fname': 'oversized.bin',
            'sha1': oversizedHash,
            'usn': -1,
            'sync_required': 1,
          },
        ],
      );
      final fake = _QueueHttpClient()
        ..responseFor = (request, body) async {
          switch (request.url.path) {
            case '/msync/begin':
              return _jsonResponse({
                'data': {'usn': 0, 'sk': 'pending-invalid-host-key'},
                'err': '',
              });
            case '/msync/mediaSanity':
              return _jsonResponse({'data': 'OK', 'err': ''});
            default:
              return _jsonResponse({'data': null, 'err': ''});
          }
        };
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'pending-invalid-host-key',
      );

      try {
        await expectLater(
          AnkiMediaSync.sync(
            client,
            syncIdentity: identity,
            documentsPath: workDir.path,
          ),
          throwsA(isA<AnkiSyncException>()),
        );

        expect(fake.paths, isNot(contains('/msync/uploadChanges')));
        final indexHash = sha256.convert(utf8.encode(identity)).toString();
        final index = await sqflite.openDatabase(
          '${workDir.path}/collection.media.sync.$indexHash.db',
          version: 1,
        );
        final files = await index.query('media_files', orderBy: 'fname');
        await index.close();
        expect(files.map((file) => file['sync_required']), [1, 1]);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test(
      'normalizes unsafe remote filenames before writing and syncing them',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_normalized_remote_test_',
        );
        final firstContent = [1, 2, 3];
        final secondContent = [4, 5, 6];
        final thirdContent = [7, 8, 9];
        const decomposedFilename = 'cafe\u0301.txt';
        final contentByRemoteName = <String, List<int>>{
          'CON': firstContent,
          'a:b': secondContent,
          decomposedFilename: thirdContent,
        };
        http.Response archiveResponse(String filename) {
          final content = contentByRemoteName[filename]!;
          final archive = Archive()
            ..addFile(ArchiveFile('0', content.length, content));
          final metadataBytes = utf8.encode(jsonEncode({'0': filename}));
          archive.addFile(
            ArchiveFile('_meta', metadataBytes.length, metadataBytes),
          );
          return http.Response.bytes(
            ZipEncoder().encode(archive),
            HttpStatus.ok,
          );
        }

        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 3, 'sk': 'test-host-key'},
              'err': '',
            }),
            http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'data': [
                    ['CON', 1, sha1.convert(firstContent).toString()],
                    ['a:b', 2, sha1.convert(secondContent).toString()],
                    [
                      decomposedFilename,
                      3,
                      sha1.convert(thirdContent).toString(),
                    ],
                  ],
                  'err': '',
                }),
              ),
              HttpStatus.ok,
            ),
            _jsonResponse({'data': [], 'err': ''}),
            _jsonResponse({
              'data': [3, 6],
              'err': '',
            }),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        fake.responseFor = (request, body) async {
          if (request.url.path != '/msync/downloadFiles') return null;
          final fields = _multipartFields(request, body);
          final payload =
              jsonDecode(utf8.decode(gzip.decode(fields['data']!))) as Map;
          final filenames = (payload['files'] as List).cast<String>();
          return archiveResponse(filenames.single);
        };
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: 'ankiweb:normalize-remote-media',
            documentsPath: workDir.path,
          );
          final mediaDir = Directory('${workDir.path}/collection.media');

          expect(result.downloadedFiles, 3);
          expect(result.uploadedFiles, 3);
          expect(result.deletedFiles, 0);
          expect(
            await File('${mediaDir.path}/CON_').readAsBytes(),
            firstContent,
          );
          expect(
            await File('${mediaDir.path}/ab').readAsBytes(),
            secondContent,
          );
          expect(
            await File('${mediaDir.path}/café.txt').readAsBytes(),
            thirdContent,
          );
          expect(await File('${mediaDir.path}/CON').exists(), isFalse);
          expect(await File('${mediaDir.path}/a:b').exists(), isFalse);
          expect(
            await File('${mediaDir.path}/$decomposedFilename').exists(),
            isFalse,
          );
          expect(fake.paths, [
            '/msync/begin',
            '/msync/mediaChanges',
            '/msync/downloadFiles',
            '/msync/downloadFiles',
            '/msync/downloadFiles',
            '/msync/mediaChanges',
            '/msync/uploadChanges',
            '/msync/mediaSanity',
          ]);

          final followupFake = _QueueHttpClient()
            ..responses.addAll([
              _jsonResponse({
                'data': {'usn': 6, 'sk': 'test-host-key'},
                'err': '',
              }),
              _jsonResponse({
                'data': [3, 9],
                'err': '',
              }),
              _jsonResponse({'data': 'OK', 'err': ''}),
            ]);
          final followupClient = AnkiSyncProtocolClient.ankiWeb(
            client: followupFake,
            hostKey: 'test-host-key',
          );
          try {
            final followup = await AnkiMediaSync.sync(
              followupClient,
              syncIdentity: 'ankiweb:normalize-remote-media',
              documentsPath: workDir.path,
            );
            expect(followup.deletedFiles, 3);
            expect(followupFake.paths, [
              '/msync/begin',
              '/msync/uploadChanges',
              '/msync/mediaSanity',
            ]);
          } finally {
            followupClient.close();
            followupFake.close();
          }
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test(
      'does not overwrite a conflicting normalized fallback filename',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_filename_collision_test_',
        );
        const identity = 'ankiweb:normalized-fallback-collision';
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        final normalizedBytes = [1, 2, 3];
        final conflictingBytes = [7, 8, 9];
        final incomingBytes = [4, 5, 6];
        final incomingSha = sha1.convert(incomingBytes).toString();
        final fallbackFilename = 'ab-$incomingSha';
        await File('${mediaDir.path}/ab').writeAsBytes(normalizedBytes);
        final conflictingFallback = File('${mediaDir.path}/$fallbackFilename');
        await conflictingFallback.writeAsBytes(conflictingBytes);
        await _seedMediaIndex(
          workDir,
          identity,
          files: [
            {
              'fname': 'ab',
              'sha1': sha1.convert(normalizedBytes).toString(),
              'usn': 0,
              'sync_required': 0,
            },
            {
              'fname': fallbackFilename,
              'sha1': sha1.convert(conflictingBytes).toString(),
              'usn': 0,
              'sync_required': 0,
            },
          ],
        );
        final archive = Archive()
          ..addFile(ArchiveFile('0', incomingBytes.length, incomingBytes));
        final metadataBytes = utf8.encode(jsonEncode({'0': 'a:b'}));
        archive.addFile(
          ArchiveFile('_meta', metadataBytes.length, metadataBytes),
        );
        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 1, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({
              'data': [
                ['a:b', 1, incomingSha],
              ],
              'err': '',
            }),
            _jsonResponse({'data': [], 'err': ''}),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        fake.responseFor = (request, body) async {
          if (request.url.path == '/msync/downloadFiles') {
            return http.Response.bytes(
              ZipEncoder().encode(archive),
              HttpStatus.ok,
            );
          }
          if (request.url.path == '/msync/uploadChanges') {
            return _jsonResponse({
              'data': [1, 2],
              'err': '',
            });
          }
          return null;
        };
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: identity,
            documentsPath: workDir.path,
          );

          expect(result.downloadedFiles, 1);
          expect(await conflictingFallback.readAsBytes(), conflictingBytes);
          final files = <File>[];
          await for (final entity in mediaDir.list()) {
            if (entity is File) files.add(entity);
          }
          final incomingFiles = <File>[];
          for (final file in files) {
            if (sha1.convert(await file.readAsBytes()).toString() ==
                incomingSha) {
              incomingFiles.add(file);
            }
          }
          expect(incomingFiles, hasLength(1));
          expect(incomingFiles.single.path, isNot(conflictingFallback.path));
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test(
      'disambiguates media names that collide by case on some filesystems',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_case_collision_test_',
        );
        const identity = 'ankiweb:case-insensitive-media-collision';
        const existingName = 'A.png';
        const remoteName = 'a.png';
        final existingBytes = [1, 2, 3];
        final incomingBytes = [4, 5, 6];
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        await File('${mediaDir.path}/$existingName')
            .writeAsBytes(existingBytes);
        await _seedMediaIndex(
          workDir,
          identity,
          files: [
            {
              'fname': existingName,
              'sha1': sha1.convert(existingBytes).toString(),
              'usn': 1,
              'sync_required': 0,
            },
          ],
        );
        final incomingHash = sha1.convert(incomingBytes).toString();
        final archive = Archive()
          ..addFile(ArchiveFile('0', incomingBytes.length, incomingBytes));
        final metadataBytes = utf8.encode(jsonEncode({'0': remoteName}));
        archive.addFile(
          ArchiveFile('_meta', metadataBytes.length, metadataBytes),
        );
        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 2, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({
              'data': [
                [remoteName, 2, incomingHash],
              ],
              'err': '',
            }),
            _jsonResponse({'data': [], 'err': ''}),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        fake.responseFor = (request, body) async {
          if (request.url.path == '/msync/downloadFiles') {
            return http.Response.bytes(
              ZipEncoder().encode(archive),
              HttpStatus.ok,
            );
          }
          if (request.url.path == '/msync/uploadChanges') {
            return _jsonResponse({
              'data': [1, 1],
              'err': '',
            });
          }
          return null;
        };
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: identity,
            documentsPath: workDir.path,
          );

          expect(result.downloadedFiles, 1);
          expect(result.uploadedFiles, 1);
          expect(
            await File('${mediaDir.path}/$existingName').readAsBytes(),
            existingBytes,
          );
          expect(
            await File('${mediaDir.path}/a-$incomingHash.png').readAsBytes(),
            incomingBytes,
          );
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test('downloads media changes from Anki tuples and ZIP metadata', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_download_test_',
      );
      final content = [4, 5, 6];
      final archive = Archive()
        ..addFile(ArchiveFile('0', content.length, content))
        ..addFile(
          ArchiveFile(
            '_meta',
            utf8.encode(jsonEncode({'0': 'back.png'})).length,
            utf8.encode(jsonEncode({'0': 'back.png'})),
          ),
        );
      final fake = _QueueHttpClient()
        ..responses.addAll([
          _jsonResponse({
            'data': {'usn': 1, 'sk': 'test-host-key'},
            'err': '',
          }),
          _jsonResponse({
            'data': [
              ['back.png', 1, sha1.convert(content).toString()],
            ],
            'err': '',
          }),
          http.Response.bytes(ZipEncoder().encode(archive), HttpStatus.ok),
          _jsonResponse({'data': [], 'err': ''}),
          _jsonResponse({'data': 'OK', 'err': ''}),
        ]);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        final result = await AnkiMediaSync.sync(
          client,
          syncIdentity: 'ankiweb:download-test',
          documentsPath: workDir.path,
        );

        expect(result.downloadedFiles, 1);
        expect(
          await File('${workDir.path}/collection.media/back.png').readAsBytes(),
          content,
        );
        expect(fake.paths, [
          '/msync/begin',
          '/msync/mediaChanges',
          '/msync/downloadFiles',
          '/msync/mediaChanges',
          '/msync/mediaSanity',
        ]);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test(
      'preserves media files whose names match download temporary suffixes',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_temp_name_collision_test_',
        );
        const identity = 'ankiweb:media-temp-name-collision';
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        const target = 'foo';
        const tempName = 'foo.stroom-sync-tmp';
        const backupName = 'foo.stroom-sync-old';
        final originalBytes = [1, 2, 3];
        final tempBytes = [4, 5, 6];
        final backupBytes = [7, 8, 9];
        final downloadedBytes = [10, 11, 12];
        await File('${mediaDir.path}/$target').writeAsBytes(originalBytes);
        await File('${mediaDir.path}/$tempName').writeAsBytes(tempBytes);
        await File('${mediaDir.path}/$backupName').writeAsBytes(backupBytes);
        final downloadedSha = sha1.convert(downloadedBytes).toString();
        await _seedMediaIndex(
          workDir,
          identity,
          lastSyncUsn: 0,
          files: [
            {
              'fname': target,
              'sha1': sha1.convert(originalBytes).toString(),
              'usn': 0,
              'sync_required': 0,
            },
            {
              'fname': tempName,
              'sha1': sha1.convert(tempBytes).toString(),
              'usn': 0,
              'sync_required': 0,
            },
            {
              'fname': backupName,
              'sha1': sha1.convert(backupBytes).toString(),
              'usn': 0,
              'sync_required': 0,
            },
          ],
        );
        final archive = Archive()
          ..addFile(ArchiveFile('0', downloadedBytes.length, downloadedBytes))
          ..addFile(
            ArchiveFile(
              '_meta',
              utf8.encode(jsonEncode({'0': target})).length,
              utf8.encode(jsonEncode({'0': target})),
            ),
          );
        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 1, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({
              'data': [
                [target, 1, downloadedSha],
              ],
              'err': '',
            }),
            http.Response.bytes(ZipEncoder().encode(archive), HttpStatus.ok),
            _jsonResponse({'data': [], 'err': ''}),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: identity,
            documentsPath: workDir.path,
          );

          expect(result.downloadedFiles, 1);
          expect(
            await File('${mediaDir.path}/$target').readAsBytes(),
            downloadedBytes,
          );
          expect(
            await File('${mediaDir.path}/$tempName').readAsBytes(),
            tempBytes,
          );
          expect(
            await File('${mediaDir.path}/$backupName').readAsBytes(),
            backupBytes,
          );
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test(
      'rewrites note references when a remote filename is normalized',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_reference_migration_test_',
        );
        final collection = AnkiDatabase(basePath: workDir.path);
        await collection.open();
        await collection.col.load();
        final notetype = collection.col.getModel(
          collection.col.modelList.first.id,
        )!;
        notetype.templates.first
          ..qfmt = '{{Front}}<img src="a:b">'
          ..afmt = '<div style="background-image:url(a:b)">{{Back}}</div>';
        notetype.css = '.card { background-image: url("a:b"); }';
        await collection.col.save();
        final note = Note.createNew(
          notetype_id: collection.col.modelList.first.id,
          fields: ['<img alt="src=a:b" src="a:b">', '[sound:a:b]'],
        );
        await collection.notes.insert(note);
        await collection.db.update(
          'notes',
          {'usn': 0},
          where: 'id = ?',
          whereArgs: [note.id],
        );
        await collection.close();

        final content = [4, 5, 6];
        final archive = Archive()
          ..addFile(ArchiveFile('0', content.length, content));
        final meta = utf8.encode(jsonEncode({'0': 'a:b'}));
        archive.addFile(ArchiveFile('_meta', meta.length, meta));
        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 1, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({
              'data': [
                ['a:b', 1, sha1.convert(content).toString()],
              ],
              'err': '',
            }),
            http.Response.bytes(ZipEncoder().encode(archive), HttpStatus.ok),
            _jsonResponse({'data': [], 'err': ''}),
            _jsonResponse({
              'data': [1, 2],
              'err': '',
            }),
            _jsonResponse({'data': 'OK', 'err': ''}),
          ]);
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          final result = await AnkiMediaSync.sync(
            client,
            syncIdentity: 'ankiweb:normalize-media-references',
            documentsPath: workDir.path,
          );

          final installed = AnkiDatabase(basePath: workDir.path);
          await installed.open();
          await installed.col.load();
          final updated = (await installed.notes.get(note.id))!;
          final updatedNotetype = installed.col.getModel(note.notetype_id)!;
          expect(result.downloadedFiles, 1);
          expect(updated.fields[0], '<img alt="src=a:b" src="ab">');
          expect(updated.fields[1], '[sound:ab]');
          expect(updated.usn, -1);
          expect(updated.sort_field, ' ab ');
          expect(
            updatedNotetype.templates.first.qfmt,
            '{{Front}}<img src="ab">',
          );
          expect(
            updatedNotetype.templates.first.afmt,
            '<div style="background-image:url(ab)">{{Back}}</div>',
          );
          expect(updatedNotetype.css, '.card { background-image: url("ab"); }');
          expect(updatedNotetype.usn, -1);
          expect(
            await File('${workDir.path}/collection.media/ab').readAsBytes(),
            content,
          );
          await installed.close();
        } finally {
          await AnkiDatabase.closeOpenedInstance();
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test('stages media downloads before requesting the next file', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_staging_test_',
      );
      final files = <String, List<int>>{
        'first.png': [1, 2, 3],
        'second.png': [4, 5, 6],
      };
      final changes = [
        for (var index = 0; index < files.length; index++)
          [
            files.keys.elementAt(index),
            index + 1,
            sha1.convert(files.values.elementAt(index)).toString(),
          ],
      ];
      http.Response archiveResponse(List<String> names) {
        final archive = Archive();
        final metadata = <String, String>{};
        for (var index = 0; index < names.length; index++) {
          final name = names[index];
          final content = files[name]!;
          final archiveName = index.toString();
          metadata[archiveName] = name;
          archive.addFile(ArchiveFile(archiveName, content.length, content));
        }
        final metadataBytes = utf8.encode(jsonEncode(metadata));
        archive.addFile(
          ArchiveFile('_meta', metadataBytes.length, metadataBytes),
        );
        return http.Response.bytes(ZipEncoder().encode(archive), HttpStatus.ok);
      }

      final mediaDir = Directory('${workDir.path}/collection.media');
      var downloadRequests = 0;
      var singleFileRequests = true;
      var firstFileStagedBeforeNextRequest = false;
      final fake = _QueueHttpClient()
        ..responses.addAll([
          _jsonResponse({
            'data': {'usn': 2, 'sk': 'test-host-key'},
            'err': '',
          }),
          _jsonResponse({'data': changes, 'err': ''}),
          _jsonResponse({'data': [], 'err': ''}),
          _jsonResponse({'data': 'OK', 'err': ''}),
        ]);
      fake.responseFor = (request, body) async {
        if (request.url.path != '/msync/downloadFiles') return null;
        final fields = _multipartFields(request, body);
        final payload =
            jsonDecode(utf8.decode(gzip.decode(fields['data']!))) as Map;
        final names = (payload['files'] as List).cast<String>();
        downloadRequests++;
        if (names.length != 1) singleFileRequests = false;
        if (downloadRequests == 2) {
          final stagedFiles = await mediaDir
              .list(recursive: true)
              .where((entity) => entity is File)
              .cast<File>()
              .toList();
          for (final stagedFile in stagedFiles) {
            if (sha1.convert(await stagedFile.readAsBytes()) ==
                sha1.convert(files['first.png']!)) {
              firstFileStagedBeforeNextRequest = true;
              break;
            }
          }
        }
        return archiveResponse(names);
      };
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        final result = await AnkiMediaSync.sync(
          client,
          syncIdentity: 'ankiweb:media-staging-test',
          documentsPath: workDir.path,
        );

        expect(result.downloadedFiles, 2);
        expect(downloadRequests, 2);
        expect(singleFileRequests, isTrue);
        expect(firstFileStagedBeforeNextRequest, isTrue);
        for (final entry in files.entries) {
          expect(
            await File('${mediaDir.path}/${entry.key}').readAsBytes(),
            entry.value,
          );
        }
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test(
      'restores earlier files when a later download cannot be installed',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_install_rollback_test_',
        );
        const identity = 'ankiweb:media-install-rollback';
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        const originalBytes = [1, 2, 3];
        const replacementBytes = [4, 5, 6];
        await File('${mediaDir.path}/first.png').writeAsBytes(originalBytes);
        await Directory('${mediaDir.path}/second.png').create();
        await _seedMediaIndex(
          workDir,
          identity,
          files: [
            {
              'fname': 'first.png',
              'sha1': sha1.convert(originalBytes).toString(),
              'usn': 0,
              'sync_required': 0,
            },
          ],
        );
        final files = <String, List<int>>{
          'first.png': replacementBytes,
          'second.png': [7, 8, 9],
        };
        var sentChanges = false;
        final fake = _QueueHttpClient();
        fake.responseFor = (request, body) async {
          switch (request.url.path) {
            case '/msync/begin':
              return _jsonResponse({
                'data': {'usn': 2, 'sk': 'test-host-key'},
                'err': '',
              });
            case '/msync/mediaChanges':
              if (sentChanges) return _jsonResponse({'data': [], 'err': ''});
              sentChanges = true;
              return _jsonResponse({
                'data': [
                  [
                    'first.png',
                    1,
                    sha1.convert(files['first.png']!).toString(),
                  ],
                  [
                    'second.png',
                    2,
                    sha1.convert(files['second.png']!).toString(),
                  ],
                ],
                'err': '',
              });
            case '/msync/downloadFiles':
              final fields = _multipartFields(request, body);
              final payload =
                  jsonDecode(utf8.decode(gzip.decode(fields['data']!))) as Map;
              final name = (payload['files'] as List).cast<String>().single;
              final archive = Archive()
                ..addFile(ArchiveFile('0', files[name]!.length, files[name]!))
                ..addFile(
                  ArchiveFile.string('_meta', jsonEncode({'0': name})),
                );
              return http.Response.bytes(ZipEncoder().encode(archive), 200);
            default:
              return _jsonResponse({'data': 'OK', 'err': ''});
          }
        };
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          await expectLater(
            AnkiMediaSync.sync(
              client,
              syncIdentity: identity,
              documentsPath: workDir.path,
            ),
            throwsA(isA<FileSystemException>()),
          );

          expect(
            await File('${mediaDir.path}/first.png').readAsBytes(),
            originalBytes,
          );
          expect(await Directory('${mediaDir.path}/second.png').exists(), isTrue);
          final indexHash = sha256.convert(utf8.encode(identity)).toString();
          final index = await sqflite.openDatabase(
            '${workDir.path}/collection.media.sync.$indexHash.db',
            version: 1,
          );
          final metadata = await index.query('media_meta');
          final firstFile = await index.query(
            'media_files',
            where: 'fname = ?',
            whereArgs: ['first.png'],
          );
          await index.close();
          expect(metadata.single['last_sync_usn'], 0);
          expect(
            firstFile.single['sha1'],
            sha1.convert(originalBytes).toString(),
          );
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );


    test('downloads a remote change over a pending local deletion', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_delete_conflict_',
      );
      const identity = 'ankiweb:pending-delete-conflict';
      final indexHash = sha256.convert(utf8.encode(identity)).toString();
      final index = await sqflite.openDatabase(
        '${workDir.path}/collection.media.sync.$indexHash.db',
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE media_files (
              fname TEXT PRIMARY KEY,
              sha1 TEXT,
              usn INTEGER NOT NULL DEFAULT -1,
              sync_required INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE media_meta (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              last_sync_usn INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.insert('media_meta', {'id': 1, 'last_sync_usn': 0});
          await db.insert('media_files', {
            'fname': 'remote.png',
            'sha1': null,
            'usn': -1,
            'sync_required': 1,
          });
        },
      );
      await index.close();
      final content = [4, 5, 6];
      final metaBytes = utf8.encode(jsonEncode({'0': 'remote.png'}));
      final archive = Archive()
        ..addFile(ArchiveFile('0', content.length, content))
        ..addFile(ArchiveFile('_meta', metaBytes.length, metaBytes));
      final remoteSha = sha1.convert(content).toString();
      final fake = _QueueHttpClient()
        ..responses.addAll([
          _jsonResponse({
            'data': {'usn': 1, 'sk': 'test-host-key'},
            'err': '',
          }),
          _jsonResponse({
            'data': [
              ['remote.png', 1, remoteSha],
            ],
            'err': '',
          }),
          http.Response.bytes(ZipEncoder().encode(archive), HttpStatus.ok),
          _jsonResponse({'data': [], 'err': ''}),
          _jsonResponse({'data': 'OK', 'err': ''}),
        ]);
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        final result = await AnkiMediaSync.sync(
          client,
          syncIdentity: identity,
          documentsPath: workDir.path,
        );

        expect(result.downloadedFiles, 1);
        expect(result.uploadedFiles, 0);
        expect(
          await File('${workDir.path}/collection.media/remote.png')
              .readAsBytes(),
          content,
        );
        expect(fake.paths, [
          '/msync/begin',
          '/msync/mediaChanges',
          '/msync/downloadFiles',
          '/msync/mediaChanges',
          '/msync/mediaSanity',
        ]);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test(
      'fails visibly and keeps a local file with an unsupported name',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_unsafe_tombstone_test_',
        );
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        final unsafeFile = File('${mediaDir.path}/a:b');
        const originalBytes = [9, 8, 7];
        await unsafeFile.writeAsBytes(originalBytes);
        final fake = _QueueHttpClient();
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          await expectLater(
            AnkiMediaSync.sync(
              client,
              syncIdentity: 'ankiweb:unsafe-media-tombstone',
              documentsPath: workDir.path,
            ),
            throwsA(isA<AnkiSyncException>()),
          );

          expect(fake.paths, isEmpty);
          expect(await unsafeFile.readAsBytes(), originalBytes);
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
      skip: Platform.isWindows
          ? 'Colon is a Windows alternate data stream'
          : false,
    );

    test(
      'rejects downloaded bytes that do not match the server SHA-1',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_checksum_test_',
        );
        final content = [4, 5, 6];
        final metaBytes = utf8.encode(jsonEncode({'0': 'back.png'}));
        final archive = Archive()
          ..addFile(ArchiveFile('0', content.length, content))
          ..addFile(ArchiveFile('_meta', metaBytes.length, metaBytes));
        final fake = _QueueHttpClient()
          ..responses.addAll([
            _jsonResponse({
              'data': {'usn': 1, 'sk': 'test-host-key'},
              'err': '',
            }),
            _jsonResponse({
              'data': [
                ['back.png', 1, '0000000000000000000000000000000000000000'],
              ],
              'err': '',
            }),
            http.Response.bytes(ZipEncoder().encode(archive), HttpStatus.ok),
          ]);
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          await expectLater(
            AnkiMediaSync.sync(
              client,
              syncIdentity: 'ankiweb:checksum-test',
              documentsPath: workDir.path,
            ),
            throwsA(isA<AnkiSyncException>()),
          );
          expect(
            await File('${workDir.path}/collection.media/back.png').exists(),
            isFalse,
          );
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test('uploads a local media file named _meta', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_meta_upload_test_',
      );
      final mediaDir = Directory('${workDir.path}/collection.media');
      await mediaDir.create();
      final fileBytes = [1, 2, 3];
      await File('${mediaDir.path}/_meta').writeAsBytes(fileBytes);
      List<Object?>? uploadedMetadata;
      List<int>? uploadedBytes;
      final fake = _QueueHttpClient()
        ..responseFor = (request, body) async {
          switch (request.url.path) {
            case '/msync/begin':
              return _jsonResponse({
                'data': {'usn': 0, 'sk': 'test-host-key'},
                'err': '',
              });
            case '/msync/uploadChanges':
              final fields = _multipartFields(request, body);
              final archive = ZipDecoder().decodeBytes(fields['data']!);
              uploadedMetadata = jsonDecode(
                utf8.decode(archive.findFile('_meta')!.content as List<int>),
              ) as List<Object?>;
              uploadedBytes = List<int>.from(
                archive.findFile('0')!.content as List<int>,
              );
              return _jsonResponse({
                'data': [1, 1],
                'err': '',
              });
            case '/msync/mediaSanity':
              return _jsonResponse({'data': 'OK', 'err': ''});
            default:
              return _jsonResponse({'data': [], 'err': ''});
          }
        };
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        final result = await AnkiMediaSync.sync(
          client,
          syncIdentity: 'ankiweb:media-file-named-meta',
          documentsPath: workDir.path,
        );

        expect(result.uploadedFiles, 1);
        expect(uploadedMetadata, [
          ['_meta', '0'],
        ]);
        expect(uploadedBytes, fileBytes);
        expect(fake.paths, [
          '/msync/begin',
          '/msync/uploadChanges',
          '/msync/mediaSanity',
        ]);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test(
      'rejects a missing media SHA without deleting local files',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_invalid_sha_test_',
        );
        const identity = 'ankiweb:invalid-media-sha';
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        const localBytes = [1, 2, 3];
        await File('${mediaDir.path}/tracked.png').writeAsBytes(localBytes);
        await _seedMediaIndex(
          workDir,
          identity,
          files: [
            {
              'fname': 'tracked.png',
              'sha1': sha1.convert(localBytes).toString(),
              'usn': 0,
              'sync_required': 0,
            },
          ],
        );
        final fake = _QueueHttpClient();
        fake.responseFor = (request, body) async {
          switch (request.url.path) {
            case '/msync/begin':
              return _jsonResponse({
                'data': {'usn': 1, 'sk': 'test-host-key'},
                'err': '',
              });
            case '/msync/mediaChanges':
              return _jsonResponse({
                'data': [
                  ['tracked.png', 1, null],
                ],
                'err': '',
              });
            default:
              return _jsonResponse({'data': 'OK', 'err': ''});
          }
        };
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          await expectLater(
            AnkiMediaSync.sync(
              client,
              syncIdentity: identity,
              documentsPath: workDir.path,
            ),
            throwsA(isA<AnkiSyncException>()),
          );

          expect(
            await File('${mediaDir.path}/tracked.png').readAsBytes(),
            localBytes,
          );
          final indexHash = sha256.convert(utf8.encode(identity)).toString();
          final index = await sqflite.openDatabase(
            '${workDir.path}/collection.media.sync.$indexHash.db',
            version: 1,
          );
          final metadata = await index.query('media_meta');
          final trackedFile = await index.query(
            'media_files',
            where: 'fname = ?',
            whereArgs: ['tracked.png'],
          );
          await index.close();
          expect(metadata.single['last_sync_usn'], 0);
          expect(
            trackedFile.single['sha1'],
            sha1.convert(localBytes).toString(),
          );
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test('does not tombstone a tracked local file named _meta', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_meta_tombstone_test_',
      );
      final mediaDir = Directory('${workDir.path}/collection.media');
      await mediaDir.create();
      final fileBytes = [4, 5, 6];
      await File('${mediaDir.path}/_meta').writeAsBytes(fileBytes);
      const identity = 'ankiweb:tracked-media-file-named-meta';
      await _seedMediaIndex(
        workDir,
        identity,
        files: [
          {
            'fname': '_meta',
            'sha1': sha1.convert(fileBytes).toString(),
            'usn': 0,
            'sync_required': 0,
          },
        ],
      );
      final fake = _QueueHttpClient()
        ..responseFor = (request, body) async {
          switch (request.url.path) {
            case '/msync/begin':
              return _jsonResponse({
                'data': {'usn': 0, 'sk': 'test-host-key'},
                'err': '',
              });
            case '/msync/uploadChanges':
              return _jsonResponse({
                'data': [1, 1],
                'err': '',
              });
            case '/msync/mediaSanity':
              return _jsonResponse({'data': 'OK', 'err': ''});
            default:
              return _jsonResponse({'data': [], 'err': ''});
          }
        };
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: fake,
        hostKey: 'test-host-key',
      );

      try {
        final result = await AnkiMediaSync.sync(
          client,
          syncIdentity: identity,
          documentsPath: workDir.path,
        );

        expect(result.deletedFiles, 0);
        expect(fake.paths, ['/msync/begin', '/msync/mediaSanity']);
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

    test(
      'restores local media after a failed full collection download',
      () async {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_rollback_test_',
        );
        final fake = _QueueHttpClient();
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'rollback-test-host-key',
        );
        final identity = client.destinationIdentity;
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        final localBytes = [1, 2, 3];
        await File('${mediaDir.path}/local.png').writeAsBytes(localBytes);
        final indexHash = sha256.convert(utf8.encode(identity)).toString();
        final indexPath = '${workDir.path}/collection.media.sync.$indexHash.db';
        Future<sqflite.Database> openIndex() => sqflite.openDatabase(
              indexPath,
              version: 1,
              onCreate: (db, _) async {
                await db.execute('''
                CREATE TABLE media_files (
                  fname TEXT PRIMARY KEY,
                  sha1 TEXT,
                  usn INTEGER NOT NULL DEFAULT -1,
                  sync_required INTEGER NOT NULL DEFAULT 1
                )
              ''');
                await db.execute('''
                CREATE TABLE media_meta (
                  id INTEGER PRIMARY KEY CHECK (id = 1),
                  last_sync_usn INTEGER NOT NULL DEFAULT 0
                )
              ''');
                await db.insert('media_meta', {'id': 1, 'last_sync_usn': 7});
              },
            );
        final oldIndex = await openIndex();
        await oldIndex.insert('media_files', {
          'fname': 'local.png',
          'sha1': sha1.convert(localBytes).toString(),
          'usn': 5,
          'sync_required': 0,
        });
        await oldIndex.close();

        try {
          final reset = await AnkiMediaSync.prepareForFullDownload(
            client: client,
            documentsPath: workDir.path,
          );
          final replacementIndex = await openIndex();
          await replacementIndex.insert('media_files', {
            'fname': 'remote.png',
            'sha1': sha1.convert([4, 5, 6]).toString(),
            'usn': -1,
            'sync_required': 1,
          });
          await replacementIndex.close();
          await File('${mediaDir.path}/remote.png').writeAsBytes([4, 5, 6]);

          await reset.rollback();

          expect(
            await File('${mediaDir.path}/local.png').readAsBytes(),
            localBytes,
          );
          expect(await File('${mediaDir.path}/remote.png').exists(), isFalse);
          final restoredIndex = await openIndex();
          final files = await restoredIndex.query('media_files');
          final meta = await restoredIndex.query('media_meta');
          await restoredIndex.close();
          expect(files, hasLength(1));
          expect(files.single['fname'], 'local.png');
          expect(files.single['sha1'], sha1.convert(localBytes).toString());
          expect(files.single['usn'], 5);
          expect(files.single['sync_required'], 0);
          expect(meta.single['last_sync_usn'], 7);
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      },
    );

    test('clears media sync indexes when Anki data is cleared', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_clear_test_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TestDocumentsPathProvider(workDir.path);
      AppStorage.resetCache();
      const identity = 'ankiweb:media-clear-test';
      final indexHash = sha256.convert(utf8.encode(identity)).toString();
      final indexPath = '${workDir.path}/collection.media.sync.$indexHash.db';
      final mediaDir = Directory('${workDir.path}/collection.media');
      final content = [1, 2, 3];
      try {
        await mediaDir.create();
        await File('${mediaDir.path}/synced.png').writeAsBytes(content);
        await _seedMediaIndex(
          workDir,
          identity,
          lastSyncUsn: 7,
          files: [
            {
              'fname': 'synced.png',
              'sha1': sha1.convert(content).toString(),
              'usn': 7,
              'sync_required': 0,
            },
          ],
        );
        for (final suffix in ['-wal', '-shm', '-journal']) {
          await File('$indexPath$suffix').writeAsString('sqlite sidecar');
        }

        await BackupService.clearSelectedData(
          const BackupSelection(
            chatRecordsAndAttachments: false,
            settings: false,
            pictures: false,
            audio: false,
            videos: false,
            texts: false,
            tasks: false,
            ankiData: true,
            browserCookies: false,
          ),
        );

        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          expect(
            await File('$indexPath$suffix').exists(),
            isFalse,
            reason: 'stale media index file $suffix must be removed',
          );
        }
        expect(await mediaDir.exists(), isFalse);
      } finally {
        PathProviderPlatform.instance = previousPathProvider;
        AppStorage.resetCache();
        await workDir.delete(recursive: true);
      }
    });

    test(
      'keeps media sync indexes when media directory deletion fails',
      () async {
        if (!Platform.isLinux) return;
        final uid = await Process.run('id', ['-u']);
        if (uid.stdout.toString().trim() == '0') return;

        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_clear_failure_test_',
        );
        final previousPathProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance =
            _TestDocumentsPathProvider(workDir.path);
        AppStorage.resetCache();
        const identity = 'ankiweb:media-clear-failure-test';
        final indexHash = sha256.convert(utf8.encode(identity)).toString();
        final indexPath =
            '${workDir.path}/collection.media.sync.$indexHash.db';
        final mediaDir = Directory('${workDir.path}/collection.media');
        try {
          await mediaDir.create();
          await File('${mediaDir.path}/synced.png').writeAsBytes([1, 2, 3]);
          await _seedMediaIndex(
            workDir,
            identity,
            files: [
              {
                'fname': 'synced.png',
                'sha1': sha1.convert([1, 2, 3]).toString(),
                'usn': 7,
                'sync_required': 0,
              },
            ],
          );
          final chmodResult =
              await Process.run('chmod', ['0555', mediaDir.path]);
          expect(chmodResult.exitCode, 0);

          await expectLater(
            BackupService.clearSelectedData(
              const BackupSelection(
                chatRecordsAndAttachments: false,
                settings: false,
                pictures: false,
                audio: false,
                videos: false,
                texts: false,
                tasks: false,
                ankiData: true,
                browserCookies: false,
              ),
            ),
            throwsA(isA<Exception>()),
          );

          expect(await mediaDir.exists(), isTrue);
          expect(await File(indexPath).exists(), isTrue);
        } finally {
          await Process.run('chmod', ['0755', mediaDir.path]);
          PathProviderPlatform.instance = previousPathProvider;
          AppStorage.resetCache();
          await workDir.delete(recursive: true);
        }
      },
    );
  });
}

class _TestDocumentsPathProvider extends PathProviderPlatform {
  _TestDocumentsPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

http.Response _jsonResponse(Object? value) =>
    http.Response(jsonEncode(value), HttpStatus.ok);

Future<void> _seedMediaIndex(
  Directory workDir,
  String identity, {
  required List<Map<String, Object?>> files,
  int lastSyncUsn = 0,
}) async {
  final indexHash = sha256.convert(utf8.encode(identity)).toString();
  final index = await sqflite.openDatabase(
    '${workDir.path}/collection.media.sync.$indexHash.db',
    version: 1,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE media_files (
          fname TEXT PRIMARY KEY,
          sha1 TEXT,
          usn INTEGER NOT NULL DEFAULT -1,
          sync_required INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE media_meta (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          last_sync_usn INTEGER NOT NULL DEFAULT 0
        )
      ''');
    },
  );
  await index.insert('media_meta', {'id': 1, 'last_sync_usn': lastSyncUsn});
  for (final file in files) {
    await index.insert('media_files', file);
  }
  await index.close();
}

class _QueueHttpClient extends http.BaseClient {
  final responses = <http.Response>[];
  final paths = <String>[];
  Future<http.Response?> Function(http.BaseRequest, List<int>)? responseFor;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().fold<List<int>>(
      <int>[],
      (collected, chunk) => collected..addAll(chunk),
    );
    paths.add(request.url.path);
    final response =
        await responseFor?.call(request, body) ?? responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

Map<String, List<int>> _multipartFields(
  http.BaseRequest request,
  List<int> body,
) {
  final boundary = RegExp(r'boundary=(.+)$')
      .firstMatch(request.headers['content-type']!)!
      .group(1)!;
  final delimiter = ascii.encode('--$boundary\r\n');
  final nextPart = ascii.encode('\r\n--$boundary');
  final output = <String, List<int>>{};
  var offset = 0;
  while (true) {
    final partStart = _indexOf(body, delimiter, offset);
    if (partStart < 0) break;
    final headersStart = partStart + delimiter.length;
    final headersEnd = _indexOf(body, ascii.encode('\r\n\r\n'), headersStart);
    if (headersEnd < 0) break;
    final headers = utf8.decode(body.sublist(headersStart, headersEnd));
    final name = RegExp(r'name="([^"]+)"').firstMatch(headers)?.group(1);
    final dataStart = headersEnd + 4;
    final dataEnd = _indexOf(body, nextPart, dataStart);
    if (name == null || dataEnd < 0) break;
    output[name] = body.sublist(dataStart, dataEnd);
    offset = dataEnd + 2;
  }
  return output;
}

int _indexOf(List<int> source, List<int> pattern, int start) {
  for (var i = start; i <= source.length - pattern.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length; j++) {
      if (source[i + j] != pattern[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return -1;
}
