import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/pages/unified_task_list/file_opener.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

void main() {
  test('file existence preflight skips unsupported web IO only', () {
    var existsChecks = 0;
    bool existsSync() {
      existsChecks++;
      return false;
    }

    expect(
      shouldAbortFileOpenForMissingFile(isWeb: true, existsSync: existsSync),
      isFalse,
    );
    expect(existsChecks, 0);

    expect(
      shouldAbortFileOpenForMissingFile(isWeb: false, existsSync: existsSync),
      isTrue,
    );
    expect(existsChecks, 1);
  });

  test('reads web text outputs from the browser file store', () async {
    ManifestDatabase.enableTestMode();
    addTearDown(WebFileStore.disableTestMode);
    const fileName = 'completed.txt';
    final bytes = Uint8List.fromList(utf8.encode('task output'));
    await TextManifest.writeFile(fileName, bytes);
    final path = await TextManifest.readFilePath(fileName);

    expect(path, 'texts/$fileName');
    expect(await readFileBytesForOpen(path!, isWeb: true), bytes);
  });

  test('routes .ts as video while .tsx remains text', () async {
    expect(await fileOpenKind('/tmp/recording.ts'), FileOpenKind.video);
    expect(await fileOpenKind('/tmp/app.tsx'), FileOpenKind.text);
  });

  test('routes ambiguous containers to a browser viewer without IO probing',
      () async {
    expect(
      await fileOpenKind('/tmp/recording.mov', isWeb: true),
      FileOpenKind.video,
    );
  });

  for (final fixture in [
    (name: 'audio_only.mov', extension: 'mov', kind: FileOpenKind.audio),
    (name: 'video_only.mov', extension: 'mov', kind: FileOpenKind.video),
    (name: 'audio_only.webm', extension: 'weba', kind: FileOpenKind.audio),
    (name: 'audio_only.mkv', extension: 'mka', kind: FileOpenKind.audio),
    (name: 'audio_only.flv', extension: 'flv', kind: FileOpenKind.audio),
    (name: 'video_only.flv', extension: 'flv', kind: FileOpenKind.video),
    (name: 'video_only.mpeg', extension: 'mpeg', kind: FileOpenKind.video),
    (name: 'video_only.mpeg', extension: 'mpg', kind: FileOpenKind.video),
    (name: 'audio_only.avi', extension: 'avi', kind: FileOpenKind.audio),
    (name: 'video_only.avi', extension: 'avi', kind: FileOpenKind.video),
    (name: 'video_with_aux.avi', extension: 'avi', kind: FileOpenKind.video),
    (name: 'video_type1_dv.avi', extension: 'avi', kind: FileOpenKind.video),
    (name: 'audio_only.mpg', extension: 'mpeg', kind: FileOpenKind.audio),
    (name: 'audio_only.mpg', extension: 'mpg', kind: FileOpenKind.audio),
  ]) {
    test('opens real ${fixture.extension} bytes as ${fixture.kind.name}',
        () async {
      final temp = await Directory.systemTemp.createTemp('catcatch_opener_');
      addTearDown(() => temp.delete(recursive: true));
      final file = File(p.join(temp.path, 'saved.${fixture.extension}'));
      await File(p.join('tests', 'fixtures', 'catcatch', fixture.name))
          .copy(file.path);

      expect(await fileOpenKind(file.path), fixture.kind);
    });
  }
}
