Warning: truncated output (original token count: 22427)
Total output lines: 2689

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
    test('localizes media directory setup failures', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_directory_error_test_',
      );
      final mediaPath = '${workDir.path}/collection.media';
      await File(mediaPath).writeAsString('not a directory');
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: _QueueHttpClient(),
        hostKey: 'localization-test-host-key',
      );

      try {
        await expectLater(
          AnkiMediaSync.sync(client, documentsPath: workDir.path),
          throwsA(
            isA<AnkiSyncException>().having(
              (error) => error.failureCode,
              'failureCode',
              AnkiSyncFailureCode.localFileFailure,
            ),
          ),
        );
        await expectLater(
          AnkiMediaSync.prepareForFullDownload(
            client: client,
            documentsPath: workDir.path,
          ),
          throwsA(
            isA<AnkiSyncException>().having(
              (error) => error.failureCode,
              'failureCode',
              AnkiSyncFailureCode.localFileFailure,
            ),
          ),
        );
      } finally {
        client.close();
        await workDir.delete(recursive: true);
      }
    });

    test('localizes media index filesystem open failures', () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_index_open_error_test_',
      );
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: _QueueHttpClient(),
        hostKey: 'localization-test-host-key',
      );
      final indexHash =
          sha256.convert(utf8.encode(client.destinationIdentity)).toString();
      await Directory(
        '${workDir.path}/collection.media.sync.$indexHash.db',
      ).create();

      try {
        await expectLater(
          AnkiMediaSync.sync(client, documentsPath: workDir.path),
          throwsA(
            isA<AnkiSyncException>().having(
              (error) => error.failureCode,
              'failureCode',
              AnkiSyncFailureCode.localFileFailure,
            ),
          ),
        );
      } finally {
        client.close();
        await workDir.delete(recursive: true);
      }
    });

    test('keeps corrupt media index errors distinct from file failures',
        () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_index_corrupt_test_',
      );
      final client = AnkiSyncProtocolClient.ankiWeb(
        client: _QueueHttpClient(),
        hostKey: 'localization-test-host-key',
      );
      final indexHash =
          sha256.convert(utf8.encode(client.destinationIdentity)).toString();
      await File(
        '${workDir.path}/collection.media.sync.$indexHash.db',
      ).writeAsString('not a SQLite database');

      try {
        await expectLater(
          AnkiMediaSync.sync(client, documentsPath: workDir.path),
          throwsA(
            isA<AnkiSyncException>().having(
              (error) => error.failureCode,
              'failureCode',
              AnkiSyncFailureCode.mediaIndexCorrupt,
            ),
          ),
        );
      } finally {
        client.close();
        await workDir.delete(recursive: true);
      }
    });

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

    test('rejects invalid media cursors without resetting the local index',
        () async {
      for (final invalidUsn in [null, 'not-an-integer', -1]) {
        final workDir = await Directory.systemTemp.createTemp(
          'stroom_anki_media_invalid_cursor_test_',
        );
        const identity = 'ankiweb:invalid-media-cursor';
        final bytes = [1, 2, 3];
        final mediaDir = Directory('${workDir.path}/collection.media');
        await mediaDir.create();
        await File('${mediaDir.path}/tracked.png').writeAsBytes(bytes);
        await _seedMediaIndex(
          workDir,
          identity,
          lastSyncUsn: 7,
          files: [
            {
              'fname': 'tracked.png',
              'sha1': sha1.convert(bytes).toString(),
              'usn': 7,
              'sync_required': 0,
            },
          ],
        );
        final fake = _QueueHttpClient()
          ..responseFor = (request, body) async => _jsonResponse({
                'data': {'usn': invalidUsn},
                'err': '',
              });
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'invalid-cursor-test',
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
          expect(fake.paths, ['/msync/begin']);

          final index = await sqflite.openDatabase(
            '${workDir.path}/collection.media.sync.'
            '${sha256.convert(utf8.encode(identity))}.db',
          );
          try {
            expect(
              (await index.query('media_meta')).single['last_sync_usn'],
              7,
            );
            expect(
              (await index.query('media_files')).single['sync_required'],
              0,
            );
          } finally {
            await index.close();
          }
        } finally {
          client.close();
          fake.close();
          await workDir.delete(recursive: true);
        }
      }
    });

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
      'fails before syncing when a new empty or oversized file exists',
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
        final fake = _QueueHttpClient();
        final client = AnkiSyncProtocolClient.ankiWeb(
          client: fake,
          hostKey: 'test-host-key',
        );

        try {
          await expectLater(
            AnkiMediaSync.sync(
              client,
              syncIdentity: 'ankiweb:reject-invalid-local-media',
              documentsPath: workDir.path,
            ),
            throwsA(isA<AnkiSyncException>()),
          );
          expect(fake.paths, isEmpty);
          expect(await File('${mediaDir.path}/empty.bin').exists(), isTrue);
          expect(await File('${mediaDir.path}/oversized.bin').exists(), isTrue);
          expect(await File('${mediaDir.path}/keep.png').exists(), isTrue);
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
      'rejects invalid files before later pending media uploads',
      () async {
        final w…10427 tokens truncated…t.uploadedFiles, 0);
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

    test('rejects a non-string media filename without deleting local files',
        () async {
      final workDir = await Directory.systemTemp.createTemp(
        'stroom_anki_media_invalid_name_test_',
      );
      const identity = 'ankiweb:invalid-media-name';
      final mediaDir = Directory('${workDir.path}/collection.media');
      await mediaDir.create();
      const localBytes = [1, 2, 3];
      await File('${mediaDir.path}/123').writeAsBytes(localBytes);
      await _seedMediaIndex(
        workDir,
        identity,
        files: [
          {
            'fname': '123',
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
                [123, 1, ''],
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

        expect(await File('${mediaDir.path}/123').readAsBytes(), localBytes);
        expect(fake.paths, ['/msync/begin', '/msync/mediaChanges']);
        final indexHash = sha256.convert(utf8.encode(identity)).toString();
        final index = await sqflite.openDatabase(
          '${workDir.path}/collection.media.sync.$indexHash.db',
          version: 1,
        );
        final metadata = await index.query('media_meta');
        final trackedFile = await index.query(
          'media_files',
          where: 'fname = ?',
          whereArgs: ['123'],
        );
        await index.close();
        expect(metadata.single['last_sync_usn'], 0);
        expect(trackedFile.single['sha1'], sha1.convert(localBytes).toString());
      } finally {
        client.close();
        fake.close();
        await workDir.delete(recursive: true);
      }
    });

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
        final indexPath = '${workDir.path}/collection.media.sync.$indexHash.db';
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
