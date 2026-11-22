import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/utils/atomic_file.dart';

final class _RealIO extends IOOverrides {}

class _ControlledFile extends Fake implements File {
  _ControlledFile(this.file, {this.beforeWrite, this.failRename = false});

  final File file;
  final Future<void> Function()? beforeWrite;
  final bool failRename;

  @override
  String get path => file.path;

  @override
  File get absolute => file.absolute;

  @override
  Future<bool> exists() => file.exists();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      file.delete(recursive: recursive);

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    await beforeWrite?.call();
    return file.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await beforeWrite?.call();
    return file.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  Future<File> rename(String newPath) {
    if (failRename) {
      throw FileSystemException('Replacement is locked', newPath);
    }
    return file.rename(newPath);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atomic_file_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AtomicFile', () {
    test('unknown Windows directory sensitivity keeps path case', () {
      String pathKey(String path, bool? sensitivity) {
        // ignore: invalid_use_of_visible_for_testing_member
        return AtomicFile.windowsPathKeyForTesting(
          path,
          directoryIsCaseSensitive: (_) => sensitivity,
          fold: (component) => component.toUpperCase(),
        );
      }

      final lowerPath = pathKey(r'C:\CaseDir\tasks.json', null);
      final upperPath = pathKey(r'C:\CaseDir\TASKS.JSON', null);
      final insensitiveLower = pathKey(r'C:\CaseDir\tasks.json', false);
      final insensitiveUpper = pathKey(r'C:\CaseDir\TASKS.JSON', false);

      expect(lowerPath, isNot(upperPath));
      expect(insensitiveLower, insensitiveUpper);
    });

    test(
      'cancelled staged bytes preserve shared file and remove temporary output',
      () async {
        final file = File('${tempDir.path}/shared.txt');
        await file.writeAsString('existing');
        var cancelled = false;
        final staged = Completer<void>();
        final release = Completer<void>();
        final realIO = _RealIO();
        final operation = IOOverrides.runZoned(
          () => AtomicFile.writeBytes(
            file,
            [1, 2, 3],
            beforeCommit: () {
              if (cancelled) throw StateError('cancelled');
            },
          ),
          createFile: (path) => _ControlledFile(
            realIO.createFile(path),
            beforeWrite: () async {
              staged.complete();
              await release.future;
            },
          ),
        );
        final assertion = expectLater(operation, throwsStateError);
        await staged.future;
        cancelled = true;
        release.complete();
        await assertion;
        expect(await file.readAsString(), 'existing');
        expect(tempDir.listSync().map((entry) => entry.path), [file.path]);
      },
    );

    test('writeString creates the file with full content', () async {
      final file = File('${tempDir.path}/tasks.json');
      await AtomicFile.writeString(file, '{"a":1}');
      expect(await file.readAsString(), '{"a":1}');
    });

    test('overwrites existing content atomically', () async {
      final file = File('${tempDir.path}/tasks.json');
      await AtomicFile.writeString(file, 'old-content');
      await AtomicFile.writeString(file, 'new-content');
      expect(await file.readAsString(), 'new-content');
    });

    test('failed streamed write preserves destination and cleans its partial',
        () async {
      final file = File('${tempDir.path}/restored.bin');
      await file.writeAsBytes([1, 2, 3]);

      await expectLater(
        AtomicFile.writeFromSync(file, (output) {
          output.writeFromSync([9, 8]);
          throw const FormatException('injected extraction failure');
        }),
        throwsFormatException,
      );

      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(tempDir.listSync().map((entry) => entry.path), [file.path]);
    });

    test('successful streamed write replaces destination with all bytes',
        () async {
      final file = File('${tempDir.path}/restored.bin');
      await file.writeAsBytes([1, 2, 3]);

      await AtomicFile.writeFromSync(file, (output) {
        output.writeFromSync([9, 8, 7, 6]);
      });

      expect(await file.readAsBytes(), [9, 8, 7, 6]);
      expect(tempDir.listSync().map((entry) => entry.path), [file.path]);
    });

    test(
      'replacement preserves restrictive permissions on POSIX',
      () async {
        final file = File('${tempDir.path}/private.txt');
        await file.writeAsString('private');
        final chmod = await Process.run('chmod', ['0600', file.path]);
        expect(chmod.exitCode, 0);

        await AtomicFile.writeString(file, 'updated');

        expect((await file.stat()).mode & 0x1ff, 0x180);
      },
      skip: Platform.isWindows,
    );

    test('leaves no temporary data behind after success', () async {
      final file = File('${tempDir.path}/tasks.json');
      await AtomicFile.writeString(file, 'data');
      expect(tempDir.listSync().map((entry) => entry.path), [file.path]);
    });

    test('writeBytes writes exact bytes', () async {
      final file = File('${tempDir.path}/data.bin');
      await AtomicFile.writeBytes(file, [1, 2, 3, 255]);
      expect(await file.readAsBytes(), [1, 2, 3, 255]);
    });

    test('reports failure when target directory does not exist', () async {
      final file = File('${tempDir.path}/missing_dir/tasks.json');
      await expectLater(
        AtomicFile.writeString(file, 'data'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.exists(), isFalse);
    });

    test('reports replacement failure and cleans temporary files', () async {
      final file = File('${tempDir.path}/tasks.json');
      // 目标路径是目录：rename 失败时异常传播给调用方，且不残留临时文件。
      await Directory('${tempDir.path}/tasks.json').create();
      await expectLater(
        AtomicFile.writeString(file, 'data'),
        throwsA(isA<FileSystemException>()),
      );
      expect(tempDir.listSync().map((entry) => entry.path), [file.path]);
      await Directory('${tempDir.path}/tasks.json').delete();
    });

    test(
      'partial temporary write failure preserves the previous file',
      () async {
        final file = File('${tempDir.path}/tasks.json');
        await file.writeAsString('previous');
        final overrides = IOOverrides.current ?? _RealIO();
        await IOOverrides.runZoned(
          () async {
            await expectLater(
              AtomicFile.writeString(file, 'replacement'),
              throwsA(isA<FileSystemException>()),
            );
          },
          createFile: (path) {
            final realFile = IOOverrides.runWithIOOverrides(
              () => File(path),
              overrides,
            );
            return _ControlledFile(
              realFile,
              beforeWrite: () async {
                await realFile.writeAsString('partial');
                throw FileSystemException('Disk is full', path);
              },
            );
          },
        );
        expect(await file.readAsString(), 'previous');
        expect(tempDir.listSync().map((entry) => entry.path), [file.path]);
      },
    );

    test('failed replacement preserves the previous complete file', () async {
      final file = File('${tempDir.path}/tasks.json');
      await file.writeAsString('previous');
      final overrides = IOOverrides.current ?? _RealIO();
      await IOOverrides.runZoned(
        () async {
          await expectLater(
            AtomicFile.writeString(file, 'replacement'),
            throwsA(isA<FileSystemException>()),
          );
        },
        createFile: (path) {
          final realFile = IOOverrides.runWithIOOverrides(
            () => File(path),
            overrides,
          );
          return _ControlledFile(realFile, failRename: true);
        },
      );

      expect(await file.readAsString(), 'previous');
      expect(tempDir.listSync().map((entry) => entry.path), [file.path]);
      await AtomicFile.writeString(file, 'retry');
      expect(await file.readAsString(), 'retry');
    });

    test(
      'overlapping string and byte writes finish in invocation order',
      () async {
        final file = File('${tempDir.path}/tasks.json');
        final started = Completer<void>();
        final release = Completer<void>();
        final overrides = IOOverrides.current ?? _RealIO();
        var writes = 0;
        await IOOverrides.runZoned(
          () async {
            final first = AtomicFile.writeString(file, 'first');
            await started.future;
            var secondFinished = false;
            final bytes = utf8.encode('second');
            final second = AtomicFile.writeBytes(
              file,
              bytes,
            ).then((_) => secondFinished = true);
            bytes[0] = 0;
            try {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              expect(writes, 1);
              expect(secondFinished, isFalse);
            } finally {
              release.complete();
              await Future.wait([first, second]);
            }
          },
          createFile: (path) {
            final realFile = IOOverrides.runWithIOOverrides(
              () => File(path),
              overrides,
            );
            return _ControlledFile(
              realFile,
              beforeWrite: () async {
                writes++;
                if (writes == 1) {
                  started.complete();
                  await release.future;
                }
              },
            );
          },
        );
        expect(await file.readAsString(), 'second');
        expect(tempDir.listSync().map((entry) => entry.path), [file.path]);
      },
    );

    test('case aliases share a queue on Windows', () async {
      final file = File('${tempDir.path}/tasksσ.json');
      final driveLetter = file.path[0];
      final oppositeDriveCase = driveLetter == driveLetter.toUpperCase()
          ? driveLetter.toLowerCase()
          : driveLetter.toUpperCase();
      final alias = File(
        '$oppositeDriveCase${file.path.substring(1).replaceFirst('σ', 'ς')}',
      );
      final started = Completer<void>();
      final release = Completer<void>();
      final overrides = IOOverrides.current ?? _RealIO();
      var writes = 0;
      await IOOverrides.runZoned(
        () async {
          final first = AtomicFile.writeString(file, 'first');
          await started.future;
          var secondFinished = false;
          final second = AtomicFile.writeString(
            alias,
            'second',
          ).then((_) => secondFinished = true);
          try {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            expect(writes, 1);
            expect(secondFinished, isFalse);
          } finally {
            release.complete();
            await Future.wait([first, second]);
          }
        },
        createFile: (path) {
          final realFile = IOOverrides.runWithIOOverrides(
            () => File(path),
            overrides,
          );
          return _ControlledFile(
            realFile,
            beforeWrite: () async {
              writes++;
              if (writes == 1) {
                started.complete();
                await release.future;
              }
            },
          );
        },
      );
      expect(await file.readAsString(), 'second');
    }, skip: !Platform.isWindows);

    test(
      'case-distinct paths remain separate on case-sensitive systems',
      () async {
        final probe = File('${tempDir.path}/case_sensitivity_probe');
        await probe.writeAsString('probe');
        final upperProbe = File(probe.path.toUpperCase());
        if (await upperProbe.exists()) {
          await probe.delete();
          return;
        }

        final lowerFile = File('${tempDir.path}/tasks.json');
        final upperFile = File('${tempDir.path}/TASKS.JSON');
        final started = Completer<void>();
        final release = Completer<void>();
        final upperStarted = Completer<void>();
        final overrides = IOOverrides.current ?? _RealIO();
        await IOOverrides.runZoned(
          () async {
            final first = AtomicFile.writeString(lowerFile, 'lower');
            await started.future;
            final second = AtomicFile.writeString(upperFile, 'upper');
            try {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              expect(upperStarted.isCompleted, isTrue);
            } finally {
              release.complete();
              await Future.wait([first, second]);
            }
          },
          createFile: (path) {
            final realFile = IOOverrides.runWithIOOverrides(
              () => File(path),
              overrides,
            );
            return _ControlledFile(
              realFile,
              beforeWrite: () async {
                if (path.contains('.tasks.json.tmp-')) {
                  started.complete();
                  await release.future;
                } else {
                  upperStarted.complete();
                }
              },
            );
          },
        );
        expect(await lowerFile.readAsString(), 'lower');
        expect(await upperFile.readAsString(), 'upper');
      },
      skip: Platform.isWindows,
    );

    test(
      'case-sensitive ancestors keep differently cased child paths apart',
      () async {
        final sensitiveRoot = Directory('${tempDir.path}/sensitive_root');
        await sensitiveRoot.create();
        final enabled = Process.runSync('fsutil', [
          'file',
          'setCaseSensitiveInfo',
          sensitiveRoot.path,
          'enable',
        ]);
        if (enabled.exitCode != 0) {
          markTestSkipped(
            'The filesystem does not support case-sensitive directories.',
          );
          return;
        }

        final firstDir = Directory('${sensitiveRoot.path}/DirA');
        final secondDir = Directory('${sensitiveRoot.path}/dira');
        await firstDir.create();
        await secondDir.create();
        final insensitiveChild = Process.runSync('fsutil', [
          'file',
          'setCaseSensitiveInfo',
          firstDir.path,
          'disable',
        ]);
        if (insensitiveChild.exitCode != 0) {
          markTestSkipped(
            'Could not configure the child directory as insensitive.',
          );
          return;
        }

        final firstFile = File('${firstDir.path}/tasks.json');
        final secondFile = File('${secondDir.path}/tasks.json');
        final started = Completer<void>();
        final secondStarted = Completer<void>();
        final release = Completer<void>();
        final overrides = IOOverrides.current ?? _RealIO();
        var writes = 0;
        await IOOverrides.runZoned(
          () async {
            final first = AtomicFile.writeString(firstFile, 'first');
            await started.future;
            final second = AtomicFile.writeString(secondFile, 'second');
            try {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              expect(secondStarted.isCompleted, isTrue);
            } finally {
              release.complete();
              await Future.wait([first, second]);
            }
          },
          createFile: (path) {
            final realFile = IOOverrides.runWithIOOverrides(
              () => File(path),
              overrides,
            );
            return _ControlledFile(
              realFile,
              beforeWrite: () async {
                writes++;
                if (writes == 1) {
                  started.complete();
                  await release.future;
                } else if (writes == 2) {
                  secondStarted.complete();
                }
              },
            );
          },
        );
        expect(await firstFile.readAsString(), 'first');
        expect(await secondFile.readAsString(), 'second');

        final aliasFile = File('${firstDir.path}/TASKS.JSON');
        final aliasStarted = Completer<void>();
        final aliasRelease = Completer<void>();
        var aliasWrites = 0;
        await IOOverrides.runZoned(
          () async {
            final first = AtomicFile.writeString(firstFile, 'first alias');
            await aliasStarted.future;
            final second = AtomicFile.writeString(aliasFile, 'second alias');
            try {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              expect(aliasWrites, 1);
            } finally {
              aliasRelease.complete();
              await Future.wait([first, second]);
            }
          },
          createFile: (path) {
            final realFile = IOOverrides.runWithIOOverrides(
              () => File(path),
              overrides,
            );
            return _ControlledFile(
              realFile,
              beforeWrite: () async {
                aliasWrites++;
                if (aliasWrites == 1) {
                  aliasStarted.complete();
                  await aliasRelease.future;
                }
              },
            );
          },
        );
        expect(await firstFile.readAsString(), 'second alias');
      },
      skip: !Platform.isWindows,
    );
  });
}
