import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/pages/unified_task_list/file_opener.dart';

void main() {
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
