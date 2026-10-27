import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../database/anki_database.dart';
import 'anki_sync_protocol_client.dart';

/// Anki `/msync/` client backed by a small sidecar index. Media sync metadata
/// is kept beside (not inside) collection.anki2 so collection schema 11 stays
/// byte-for-byte compatible with Anki.
class AnkiMediaSync {
  static const int _maxFilesPerRequest = 25;
  static const int _maxMediaFileBytes = 100 * 1024 * 1024;
  static const int _maxMediaArchiveBytes =
      AnkiSyncProtocolClient.maxMediaArchiveBytes;
  static const int _maxMediaManifestBytes = 1024 * 1024;
  static const int _maxMediaArchiveEntries = _maxFilesPerRequest + 1;
  static const int _maxMediaFilenameBytes = 120;
  static const int _maxServerMediaFilenameBytes = 255;
  static const int _targetZipBytes = 2621440;
  static const List<String> _sqliteSuffixes = ['', '-wal', '-shm', '-journal'];

  const AnkiMediaSync._();

  static Future<AnkiMediaSyncResult> sync(
    AnkiSyncProtocolClient client, {
    String? syncIdentity,
    String? documentsPath,
    AnkiDatabase? database,
  }) async {
    final docs =
        documentsPath ?? (await getApplicationDocumentsDirectory()).path;
    final mediaPath = p.join(docs, 'collection.media');
    final folder = Directory(mediaPath);
    if (!await folder.exists()) await folder.create(recursive: true);
    final indexPath = _indexPath(
      docs,
      syncIdentity ?? client.destinationIdentity,
    );
    final index = await openDatabase(
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
        await db.insert('media_meta', {'id': 1, 'last_sync_usn': 0});
      },
    );

    AnkiDatabase? ownedCollection;
    try {
      await _registerLocalChanges(index, folder);
      final begin = await client.requestMediaJson('begin', {
        'v': 'stroom:0.4.47',
      });
      if (begin is! Map) {
        throw const AnkiSyncException('媒体同步 begin 响应无法解析');
      }
      final remoteUsn = _int(begin['usn']);
      final localMeta = (await index.query(
        'media_meta',
        where: 'id = 1',
      ))
          .first;
      var lastUsn = _int(localMeta['last_sync_usn']);
      if (lastUsn > remoteUsn) {
        await index.transaction((txn) async {
          await txn.update('media_meta', {'last_sync_usn': 0}, where: 'id = 1');
          await txn.update(
              'media_files',
              {
                'usn': -1,
                'sync_required': 1,
              },
              where: 'sha1 IS NOT NULL');
        });
        lastUsn = 0;
      }
      var received = 0;
      var uploaded = 0;
      var deleted = 0;

      if (lastUsn != remoteUsn) {
        while (true) {
          final response = await client.requestMediaJson('mediaChanges', {
            'lastUsn': lastUsn,
          });
          if (response is! List) {
            throw const AnkiSyncException('媒体变更列表无法解析');
          }
          if (response.isEmpty) break;

          final changes = response.map(_mediaChange).toList();
          final nextUsn = changes.last.usn;
          if (nextUsn <= lastUsn) {
            throw const AnkiSyncException('媒体同步服务器返回了重复变更');
          }
          final actions = <_MediaAction>[];
          for (final remote in changes) {
            final local = await _find(index, remote.filename);
            final localSha = local?['sha1'] as String? ?? '';
            final pending = _int(local?['sync_required']) == 1;
            final action = _requiredAction(localSha, remote.sha1, pending);
            actions.add(_MediaAction(remote, action));
          }

          final downloads = actions
              .where((item) => item.action == _MediaActionKind.download)
              .map((item) => item.change.filename)
              .toList();
          final localFilenames = <String, String>{};
          if (downloads.isNotEmpty) {
            final staging = await folder.createTemp('.stroom-download-stage-');
            try {
              final stagedFiles = <String, File>{};
              final expectedShas = {
                for (final item in actions)
                  if (item.action == _MediaActionKind.download)
                    item.change.filename: item.change.sha1,
              };
              for (final name in downloads) {
                final zip = await client.downloadMediaZip([name]);
                final archiveFiles = decodeDownloadArchive(zip);
                if (archiveFiles.keys.any((filename) => filename != name)) {
                  throw const AnkiSyncException('媒体服务器返回了未请求的文件');
                }
                final content = archiveFiles[name];
                if (content == null) {
                  throw const AnkiSyncException('媒体服务器没有返回请求的文件');
                }
                if (sha1.convert(content).toString() !=
                    expectedShas[name]!.toLowerCase()) {
                  throw const AnkiSyncException('媒体文件校验失败，请重试同步');
                }
                final stagedFile = File(
                  p.join(staging.path, stagedFiles.length.toString()),
                );
                await stagedFile.writeAsBytes(content, flush: true);
                stagedFiles[name] = stagedFile;
              }
              localFilenames.addAll(
                await _writeDownloadedFiles(folder, stagedFiles),
              );
            } finally {
              if (await staging.exists()) await staging.delete(recursive: true);
            }
          }

          final renamedFiles = {
            for (final entry in localFilenames.entries)
              if (entry.key != entry.value) entry.key: entry.value,
          };
          if (renamedFiles.isNotEmpty) {
            var collection = database;
            if (collection == null) {
              final collectionFile = File(p.join(docs, 'collection.anki2'));
              if (await collectionFile.exists()) {
                ownedCollection ??= AnkiDatabase(basePath: docs);
                await ownedCollection.open();
                collection = ownedCollection;
              }
            }
            await collection?.col.replaceMediaReferences(renamedFiles);
          }

          await index.transaction((txn) async {
            for (final item in actions) {
              final change = item.change;
              switch (item.action) {
                case _MediaActionKind.download:
                  final localFilename = localFilenames[change.filename];
                  if (localFilename == null) {
                    throw const AnkiSyncException('媒体服务器没有返回请求的文件');
                  }
                  if (localFilename == change.filename) {
                    await _put(
                      txn,
                      localFilename,
                      change.sha1,
                      change.usn,
                      false,
                    );
                  } else {
                    // Keep the server's old file until the updated note
                    // references have been sent by collection sync. The next
                    // media pass will see it missing locally and queue its
                    // tombstone after that collection update.
                    await _put(
                      txn,
                      change.filename,
                      change.sha1,
                      change.usn,
                      false,
                    );
                    await _put(txn, localFilename, change.sha1, -1, true);
                  }
                  received++;
                case _MediaActionKind.delete:
                  await _removeFile(folder, change.filename);
                  await _put(txn, change.filename, null, change.usn, false);
                  deleted++;
                case _MediaActionKind.clearPending:
                  await _put(
                    txn,
                    change.filename,
                    change.sha1,
                    change.usn,
                    false,
                  );
                case _MediaActionKind.none:
                  if (change.sha1.isNotEmpty) {
                    await _put(
                      txn,
                      change.filename,
                      change.sha1,
                      change.usn,
                      _int(
                            (await _find(
                              txn,
                              change.filename,
                            ))?['sync_required'],
                          ) ==
                          1,
                    );
                  }
              }
            }
            await txn.update(
                'media_meta',
                {
                  'last_sync_usn': nextUsn,
                },
                where: 'id = 1');
          });
          lastUsn = nextUsn;
        }
      }

      while (true) {
        final pending = await index.query(
          'media_files',
          where: 'sync_required = 1',
          orderBy: 'fname',
          limit: _maxFilesPerRequest,
        );
        if (pending.isEmpty) break;
        final batch = <AnkiMediaUploadEntry>[];
        var batchBytes = 0;
        for (final row in pending) {
          if (batch.isNotEmpty && batchBytes > _targetZipBytes) break;
          final name = row['fname'] as String;
          final sha = row['sha1'] as String?;
          if (sha == null) {
            batch.add(AnkiMediaUploadEntry(name, null));
            continue;
          }
          final file = File(p.join(mediaPath, name));
          if (!await file.exists()) {
            batch.add(AnkiMediaUploadEntry(name, null));
            continue;
          }
          final length = await file.length();
          if (length == 0 || length > _maxMediaFileBytes) {
            throw const AnkiSyncException(
              '待上传媒体文件为空或超过 100 MB，请修复后重试同步',
            );
          }
          final bytes = await file.readAsBytes();
          batch.add(AnkiMediaUploadEntry(name, bytes));
          batchBytes += bytes.length;
        }
        final reply = await client.uploadMediaZip(encodeUploadArchive(batch));
        final processed = _int(reply['processed']);
        final currentUsn = _int(reply['currentUsn']);
        if (processed <= 0 || processed > batch.length) {
          throw const AnkiSyncException('媒体服务器没有接受待上传文件');
        }
        final accepted = batch.take(processed).toList();
        await index.transaction((txn) async {
          for (final entry in accepted) {
            final sha = entry.bytes == null
                ? null
                : sha1.convert(entry.bytes!).toString();
            await _put(txn, entry.filename, sha, currentUsn, false);
            if (entry.bytes == null) {
              deleted++;
            } else {
              uploaded++;
            }
          }
          final current = (await txn.query(
            'media_meta',
            where: 'id = 1',
          ))
              .first;
          final expectedUsn = _int(current['last_sync_usn']) + processed;
          if (expectedUsn == currentUsn) {
            await txn.update(
                'media_meta',
                {
                  'last_sync_usn': currentUsn,
                },
                where: 'id = 1');
          }
        });
      }

      final localCount = await index.rawQuery(
        'SELECT COUNT(*) AS n FROM media_files WHERE sha1 IS NOT NULL',
      );
      final sanity = await client.requestMediaJson('mediaSanity', {
        'local': _int(localCount.first['n']),
      });
      if (sanity != 'OK') {
        throw const AnkiSyncException('媒体同步校验失败，请重试');
      }
      return AnkiMediaSyncResult(
        downloadedFiles: received,
        uploadedFiles: uploaded,
        deletedFiles: deleted,
      );
    } finally {
      await index.close();
      await ownedCollection?.close();
    }
  }

  /// Move aside local media and reset this destination's sync cursor before a
  /// confirmed full collection download. This prevents old local files from
  /// being treated as new uploads into the downloaded collection.
  static Future<AnkiMediaDownloadReset> prepareForFullDownload({
    required AnkiSyncProtocolClient client,
    String? documentsPath,
  }) async {
    final docs =
        documentsPath ?? (await getApplicationDocumentsDirectory()).path;
    final mediaPath = p.join(docs, 'collection.media');
    final folder = Directory(mediaPath);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final backupPath = '$mediaPath.pre-sync-$stamp';
    final existed = await folder.exists();
    final indexPath = _indexPath(docs, client.destinationIdentity);
    final backupIndexPath = '$indexPath.pre-sync-$stamp';
    var moved = false;
    try {
      if (existed) {
        await folder.rename(backupPath);
        moved = true;
      }
      await Directory(mediaPath).create(recursive: true);
      for (final suffix in _sqliteSuffixes) {
        final indexFile = File('$indexPath$suffix');
        if (await indexFile.exists()) {
          await indexFile.rename('$backupIndexPath$suffix');
        }
      }
      await _deleteSqliteFiles(indexPath);
      return AnkiMediaDownloadReset(
        mediaPath: mediaPath,
        backupPath: moved ? backupPath : null,
        indexPath: indexPath,
        backupIndexPath: backupIndexPath,
      );
    } catch (_) {
      if (moved) {
        final current = Directory(mediaPath);
        if (await current.exists()) await current.delete(recursive: true);
        if (await Directory(backupPath).exists()) {
          await Directory(backupPath).rename(mediaPath);
        }
      }
      await _restoreIndexFiles(indexPath, backupIndexPath);
      rethrow;
    }
  }

  static String _indexPath(String docs, String identity) {
    final nameHash = sha256.convert(utf8.encode(identity)).toString();
    return p.join(docs, 'collection.media.sync.$nameHash.db');
  }

  /// Removes media sync cursors for all destinations after the shared local
  /// media directory is cleared. Keeping an index would turn the missing
  /// indexed files into remote deletion requests on the next sync.
  static Future<void> clearSyncIndexes({String? documentsPath}) async {
    final docs =
        documentsPath ?? (await getApplicationDocumentsDirectory()).path;
    final directory = Directory(docs);
    if (!await directory.exists()) return;
    final indexFileName = RegExp(
      r'^collection\.media\.sync\.[0-9a-f]{64}\.db(?:-(?:wal|shm|journal))?$',
    );
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && indexFileName.hasMatch(p.basename(entity.path))) {
        await entity.delete();
      }
    }
  }

  static Future<void> _deleteSqliteFiles(String path) async {
    for (final suffix in _sqliteSuffixes) {
      final file = File('$path$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  static Future<void> _restoreIndexFiles(
    String indexPath,
    String backupIndexPath, {
    bool clearCurrent = false,
  }) async {
    if (clearCurrent) await _deleteSqliteFiles(indexPath);
    for (final suffix in _sqliteSuffixes) {
      final backup = File('$backupIndexPath$suffix');
      if (!await backup.exists()) continue;
      final original = File('$indexPath$suffix');
      if (await original.exists()) await original.delete();
      await backup.rename(original.path);
    }
  }

  static Future<void> _registerLocalChanges(
    DatabaseExecutor index,
    Directory folder,
  ) async {
    final seen = <String>{};
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File) continue;
      final filename = p.basename(entity.path);
      final lowercaseFilename = filename.toLowerCase();
      if (lowercaseFilename == '.nomedia' ||
          lowercaseFilename == '.ds_store' ||
          lowercaseFilename == 'thumbs.db') {
        continue;
      }
      // A file may still exist locally even when its name cannot be sent to
      // the server unchanged. Keep it out of the missing-file pass below so
      // that an existing server entry is not accidentally tombstoned.
      seen.add(filename);
      final length = await entity.length();
      if (!_isNormalizedFilename(filename)) {
        final existing = await _find(index, filename);
        if (existing != null &&
            length > 0 &&
            length <= _maxMediaFileBytes &&
            _int(existing['sync_required']) != 1 &&
            existing['sha1'] ==
                sha1.convert(await entity.readAsBytes()).toString()) {
          continue;
        }
        throw const AnkiSyncException('本地媒体文件名不符合 Anki 同步规则，请先重命名后重试同步');
      }
      if (length == 0 || length > _maxMediaFileBytes) {
        final existing = await _find(index, filename);
        if (existing?['sha1'] != null &&
            _int(existing?['sync_required']) != 1) {
          throw const AnkiSyncException('已同步的本地媒体文件为空或超过 100 MB，请修复后重试同步');
        }
        continue;
      }
      final bytes = await entity.readAsBytes();
      final hash = sha1.convert(bytes).toString();
      final existing = await _find(index, filename);
      if (existing == null) {
        await _put(index, filename, hash, -1, true);
      } else if (existing['sha1'] != hash) {
        await _put(index, filename, hash, -1, true);
      }
    }
    final known = await index.query('media_files');
    for (final row in known) {
      final filename = row['fname'] as String;
      if (!seen.contains(filename) && row['sha1'] != null) {
        await _put(index, filename, null, -1, true);
      }
    }
  }

  static Future<Map<String, Object?>?> _find(
    DatabaseExecutor executor,
    String filename,
  ) async {
    final rows = await executor.query(
      'media_files',
      where: 'fname = ?',
      whereArgs: [filename],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> _put(
    DatabaseExecutor executor,
    String filename,
    String? sha,
    int usn,
    bool pending,
  ) async {
    await executor.insert(
        'media_files',
        {
          'fname': filename,
          'sha1': sha,
          'usn': usn,
          'sync_required': pending ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, String>> _writeDownloadedFiles(
    Directory folder,
    Map<String, File> downloaded,
  ) async {
    final localFilenames = <String, String>{};
    final staging = await folder.createTemp('.stroom-sync-install-');
    var preserveStaging = false;
    var sequence = 0;
    final installed = <(File, File, bool)>[];
    try {
      try {
        for (final entry in downloaded.entries) {
          _validateFilename(entry.key);
          final content = await entry.value.readAsBytes();
          if (content.isEmpty || content.length > _maxMediaFileBytes) {
            throw const AnkiSyncException('下载的媒体文件为空或超过 100 MB');
          }
          final normalizedFilename = _normalizeFilename(entry.key);
          if (normalizedFilename.isEmpty ||
              normalizedFilename == '.' ||
              normalizedFilename == '..') {
            throw const AnkiSyncException('媒体文件名无法安全归一化');
          }
          final localFilename = await _availableNormalizedFilename(
            folder,
            entry.key,
            normalizedFilename,
            content,
          );
          localFilenames[entry.key] = localFilename;
          final destination = File(p.join(folder.path, localFilename));
          if (localFilename != entry.key && await destination.exists()) {
            final existingHash = sha1.convert(await destination.readAsBytes());
            if (existingHash == sha1.convert(content)) continue;
          }
          final stagingId = sequence++;
          final temp = File(p.join(staging.path, 'download-$stagingId'));
          final displaced = File(p.join(staging.path, 'original-$stagingId'));
          await temp.writeAsBytes(content, flush: true);
          final hadOriginal = await destination.exists();
          if (hadOriginal) await destination.rename(displaced.path);
          try {
            await temp.rename(destination.path);
            installed.add((destination, displaced, hadOriginal));
          } catch (_) {
            if (hadOriginal && await displaced.exists()) {
              try {
                await displaced.rename(destination.path);
              } catch (_) {
                preserveStaging = true;
              }
            }
            rethrow;
          } finally {
            if (await temp.exists()) await temp.delete();
          }
        }
      } catch (_) {
        for (final record in installed.reversed) {
          final (destination, displaced, hadOriginal) = record;
          try {
            if (await destination.exists()) await destination.delete();
            if (hadOriginal && await displaced.exists()) {
              await displaced.rename(destination.path);
            }
          } catch (_) {
            preserveStaging = true;
          }
        }
        rethrow;
      }

      for (final record in installed) {
        final (_, displaced, hadOriginal) = record;
        if (!hadOriginal || !await displaced.exists()) continue;
        try {
          await displaced.delete();
        } catch (_) {
          preserveStaging = true;
        }
      }
      return localFilenames;
    } finally {
      if (!preserveStaging && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  static Future<void> _removeFile(Directory folder, String filename) async {
    _validateFilename(filename);
    if (!_isNormalizedFilename(filename)) return;
    final file = File(p.join(folder.path, filename));
    if (await file.exists()) await file.delete();
  }

  static _MediaChange _mediaChange(Object? raw) {
    if (raw is! List || raw.length < 3) {
      throw const AnkiSyncException('媒体变更记录无法解析');
    }
    final name = raw[0]?.toString() ?? '';
    _validateFilename(name);
    final sha1 = raw[2];
    if (sha1 is! String) {
      throw const AnkiSyncException('媒体变更记录无法解析');
    }
    return _MediaChange(name, _int(raw[1]), sha1);
  }

  static _MediaActionKind _requiredAction(
    String localSha,
    String remoteSha,
    bool pending,
  ) {
    if (remoteSha.isEmpty) {
      if (localSha.isEmpty || !pending) return _MediaActionKind.delete;
      return _MediaActionKind.none;
    }
    // Anki resolves a server change against a local deletion by restoring the
    // server file, matching its upstream media change policy.
    if (localSha.isEmpty) return _MediaActionKind.download;
    if (pending && localSha == remoteSha) return _MediaActionKind.clearPending;
    if (localSha == remoteSha) return _MediaActionKind.none;
    return _MediaActionKind.download;
  }

  /// Build the exact ZIP body expected by `/msync/uploadChanges`.
  static List<int> encodeUploadArchive(List<AnkiMediaUploadEntry> entries) {
    if (entries.length > _maxFilesPerRequest) {
      throw const AnkiSyncException('单次媒体上传不能超过 25 个文件');
    }
    final archive = Archive();
    final meta = <List<Object?>>[];
    var index = 0;
    for (final entry in entries) {
      _validateFilename(entry.filename);
      if (entry.bytes == null) {
        meta.add([entry.filename, null]);
      } else {
        final name = '$index';
        archive.addFile(ArchiveFile(name, entry.bytes!.length, entry.bytes!));
        meta.add([entry.filename, name]);
        index++;
      }
    }
    final bytes = utf8.encode(jsonEncode(meta));
    archive.addFile(ArchiveFile('_meta', bytes.length, bytes));
    return ZipEncoder().encode(archive);
  }

  /// Decode the server's ZIP format and validate each returned filename.
  static Map<String, List<int>> decodeDownloadArchive(List<int> bytes) {
    try {
      if (bytes.length > _maxMediaArchiveBytes) {
        throw const AnkiSyncException('媒体 ZIP 压缩数据超过 128 MB');
      }
      _checkArchiveHeaders(bytes);
      var archiveEntryCount = 0;
      final archive = ZipDecoder().decodeBytes(
        bytes,
        callback: (_) {
          archiveEntryCount++;
          if (archiveEntryCount > _maxMediaArchiveEntries) {
            throw const AnkiSyncException('媒体 ZIP 文件数量超出限制');
          }
        },
      );
      final metaFiles = archive.files
          .where((file) => file.name == '_meta' && file.isFile)
          .toList();
      if (metaFiles.length != 1) {
        throw const AnkiSyncException('媒体 ZIP 缺少文件清单');
      }
      final metaFile = metaFiles.single;
      if (metaFile.size <= 0 || metaFile.size > _maxMediaManifestBytes) {
        throw const AnkiSyncException('媒体 ZIP 文件清单超过 1 MB');
      }
      final meta = jsonDecode(utf8.decode(_fileBytes(metaFile.content)));
      if (meta is! Map || meta.length > _maxFilesPerRequest) {
        throw const AnkiSyncException('媒体 ZIP 清单无法解析');
      }

      final archiveNames = archive.files.map((file) => file.name).toList();
      final declaredNames = meta.keys.map((key) => key.toString()).toSet();
      final expectedArchiveNames = {...declaredNames, '_meta'};
      if (declaredNames.contains('_meta') ||
          archiveNames.toSet().length != archiveNames.length ||
          archiveNames.length != expectedArchiveNames.length ||
          archive.files.any(
            (file) => !file.isFile || !expectedArchiveNames.contains(file.name),
          )) {
        throw const AnkiSyncException('媒体 ZIP 包含未声明的文件');
      }

      final result = <String, List<int>>{};
      var totalBytes = 0;
      for (final entry in meta.entries) {
        final filename = entry.value?.toString() ?? '';
        _validateFilename(filename);
        final archiveName = entry.key.toString();
        final file = archive.findFile(archiveName);
        if (file == null || !file.isFile || file.size <= 0) {
          throw const AnkiSyncException('媒体 ZIP 文件缺失或为空');
        }
        if (file.size > _maxMediaFileBytes ||
            file.size > _maxMediaFileBytes - totalBytes) {
          throw const AnkiSyncException('媒体 ZIP 文件超过 100 MB 总限制');
        }
        totalBytes += file.size;
        final content = _fileBytes(file.content);
        if (content.isEmpty || content.length != file.size) {
          throw const AnkiSyncException('媒体 ZIP 文件为空或超过 100 MB');
        }
        result[filename] = content;
      }
      return result;
    } on AnkiSyncException {
      rethrow;
    } catch (_) {
      throw const AnkiSyncException('媒体 ZIP 无法安全读取');
    }
  }

  static void _checkArchiveHeaders(List<int> bytes) {
    final directory = ZipDirectory()..read(InputMemoryStream(bytes));
    final headers = directory.fileHeaders;
    if (headers.length > _maxMediaArchiveEntries) {
      throw const AnkiSyncException('媒体 ZIP 文件数量超出限制');
    }
    final manifests = headers.where((header) => header.filename == '_meta');
    if (manifests.length != 1) {
      throw const AnkiSyncException('媒体 ZIP 缺少文件清单');
    }
    final manifestSize = manifests.single.uncompressedSize;
    if (manifestSize <= 0 || manifestSize > _maxMediaManifestBytes) {
      throw const AnkiSyncException('媒体 ZIP 文件清单超过 1 MB');
    }

    var totalBytes = 0;
    for (final header in headers) {
      if (header.filename == '_meta') continue;
      final size = header.uncompressedSize;
      if (size <= 0 ||
          size > _maxMediaFileBytes ||
          size > _maxMediaFileBytes - totalBytes) {
        throw const AnkiSyncException('媒体 ZIP 文件超过 100 MB 总限制');
      }
      totalBytes += size;
    }
  }

  static List<int> _fileBytes(Object? content) {
    if (content is List<int>) return content;
    if (content is Uint8List) return content;
    throw const AnkiSyncException('媒体 ZIP 内容格式无效');
  }

  static void _validateFilename(String filename) {
    if (filename.isEmpty ||
        utf8.encode(filename).length > _maxServerMediaFilenameBytes ||
        filename == '.' ||
        filename == '..' ||
        filename.contains('/') ||
        filename.contains('\\') ||
        filename.contains('\u0000') ||
        p.basename(filename) != filename) {
      throw const AnkiSyncException('媒体文件名不安全，已停止同步');
    }
  }

  static bool _isNormalizedFilename(String filename) {
    try {
      _validateFilename(filename);
    } on AnkiSyncException {
      return false;
    }
    return _normalizeFilename(filename) == filename;
  }

  static String _normalizeFilename(String filename) {
    var normalized = unorm
        .nfc(filename)
        .replaceAll(RegExp(r'[\[\]<>:"/?*^\\|]'), '')
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
        .replaceAll('\u00a0', ' ');

    final deviceName = RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?=\.|$)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (deviceName != null) {
      final deviceNameLength = deviceName.group(1)!.length;
      normalized = '${normalized.substring(0, deviceNameLength)}_'
          '${normalized.substring(deviceNameLength)}';
    }
    if (normalized.endsWith(' ') || normalized.endsWith('.')) {
      normalized = '${normalized}_';
    }
    return _truncateFilename(normalized, _maxMediaFilenameBytes);
  }

  static Future<String> _availableNormalizedFilename(
    Directory folder,
    String remoteFilename,
    String normalizedFilename,
    List<int> contents,
  ) async {
    final caseMatches = await _caseInsensitiveFiles(folder, normalizedFilename);
    final aliases = caseMatches
        .where((file) => p.basename(file.path) != normalizedFilename)
        .toList();
    final incomingHash = sha1.convert(contents).toString();
    if (remoteFilename == normalizedFilename && aliases.isEmpty) {
      return normalizedFilename;
    }
    if (remoteFilename != normalizedFilename && caseMatches.isEmpty) {
      return normalizedFilename;
    }

    final collidingFiles =
        remoteFilename == normalizedFilename ? aliases : caseMatches;
    final collidingHashes = <String>{};
    for (final file in collidingFiles) {
      collidingHashes.add(sha1.convert(await file.readAsBytes()).toString());
    }
    if (collidingHashes.isNotEmpty &&
        collidingHashes.every((hash) => hash == incomingHash)) {
      return normalizedFilename;
    }
    // Use a unique path when an existing file has a different casing or when
    // normalization would collide with another file's contents.

    final extensionIndex = normalizedFilename.lastIndexOf('.');
    final stem = extensionIndex <= 0
        ? normalizedFilename
        : normalizedFilename.substring(0, extensionIndex);
    final extension = extensionIndex <= 0
        ? ''
        : normalizedFilename.substring(extensionIndex + 1);
    final extensionBytes = _takeUtf8Bytes(extension, 10);
    final extensionSuffix = extensionBytes.isEmpty ? '' : '.$extensionBytes';
    var collision = 0;
    while (true) {
      final hashSuffix =
          collision == 0 ? '-$incomingHash' : '-$incomingHash-$collision';
      final maxStemBytes = _maxMediaFilenameBytes -
          utf8.encode(hashSuffix).length -
          utf8.encode(extensionSuffix).length;
      final truncatedStem = _takeUtf8Bytes(
        stem,
        maxStemBytes > 0 ? maxStemBytes : 0,
      );
      final candidate = '$truncatedStem$hashSuffix$extensionSuffix';
      final candidateMatches = await _caseInsensitiveFiles(folder, candidate);
      if (candidateMatches.isEmpty) return candidate;
      final candidateHashes = <String>[];
      for (final file in candidateMatches) {
        candidateHashes.add(sha1.convert(await file.readAsBytes()).toString());
      }
      if (candidateHashes.every(
        (candidateHash) => candidateHash == incomingHash,
      )) {
        return candidate;
      }
      collision++;
    }
  }

  static Future<List<File>> _caseInsensitiveFiles(
    Directory folder,
    String filename,
  ) async {
    final expected = filename.toLowerCase();
    final matches = <File>[];
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is File && p.basename(entity.path).toLowerCase() == expected) {
        matches.add(entity);
      }
    }
    return matches;
  }

  static String _truncateFilename(String filename, int maxBytes) {
    if (utf8.encode(filename).length <= maxBytes) return filename;

    final extensionIndex = filename.lastIndexOf('.');
    final stem =
        extensionIndex < 0 ? filename : filename.substring(0, extensionIndex);
    final extension =
        extensionIndex < 0 ? '' : filename.substring(extensionIndex + 1);
    final truncatedExtension = _takeUtf8Bytes(extension, 10);
    final maxStemBytes = maxBytes - utf8.encode(truncatedExtension).length - 2;
    var truncated = _takeUtf8Bytes(stem, maxStemBytes);
    if (truncatedExtension.isNotEmpty) {
      truncated = '$truncated.$truncatedExtension';
    }
    if (truncated.endsWith(' ') || truncated.endsWith('.')) {
      truncated = '${truncated}_';
    }
    return truncated;
  }

  static String _takeUtf8Bytes(String value, int maxBytes) {
    final result = StringBuffer();
    var usedBytes = 0;
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final characterBytes = utf8.encode(character).length;
      if (usedBytes + characterBytes > maxBytes) break;
      result.write(character);
      usedBytes += characterBytes;
    }
    return result.toString();
  }

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class AnkiMediaSyncResult {
  final int downloadedFiles;
  final int uploadedFiles;
  final int deletedFiles;

  const AnkiMediaSyncResult({
    required this.downloadedFiles,
    required this.uploadedFiles,
    required this.deletedFiles,
  });
}

class AnkiMediaDownloadReset {
  final String mediaPath;
  final String? backupPath;
  final String indexPath;
  final String backupIndexPath;
  bool _settled = false;

  AnkiMediaDownloadReset({
    required this.mediaPath,
    required this.backupPath,
    required this.indexPath,
    required this.backupIndexPath,
  });

  Future<void> commit() async {
    if (_settled) return;
    _settled = true;
    final backup = backupPath == null ? null : Directory(backupPath!);
    if (backup != null && await backup.exists()) {
      try {
        await backup.delete(recursive: true);
      } catch (_) {
        // Keep the recoverable backup if cleanup is unavailable.
      }
    }
    try {
      await AnkiMediaSync._deleteSqliteFiles(backupIndexPath);
    } catch (_) {
      // Keep the recoverable index backup if cleanup is unavailable.
    }
  }

  Future<void> rollback() async {
    if (_settled) return;
    _settled = true;
    try {
      final current = Directory(mediaPath);
      if (await current.exists()) await current.delete(recursive: true);
      if (backupPath != null && await Directory(backupPath!).exists()) {
        await Directory(backupPath!).rename(mediaPath);
      }
    } finally {
      await AnkiMediaSync._restoreIndexFiles(
        indexPath,
        backupIndexPath,
        clearCurrent: true,
      );
    }
  }
}

class _MediaChange {
  final String filename;
  final int usn;
  final String sha1;

  const _MediaChange(this.filename, this.usn, this.sha1);
}

enum _MediaActionKind { none, download, delete, clearPending }

class _MediaAction {
  final _MediaChange change;
  final _MediaActionKind action;

  const _MediaAction(this.change, this.action);
}

class AnkiMediaUploadEntry {
  final String filename;
  final List<int>? bytes;

  const AnkiMediaUploadEntry(this.filename, this.bytes);
}
