import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/utils/attachment_preview_path.dart';

void main() {
  test(
    'keeps imported Unix and Windows traversal names inside preview dir',
    () {
      final tempDir = p.join(p.current, 'chat-preview');

      for (final fileName in [
        '../../app.db',
        r'..\..\app.db',
        '/absolute/path/clip.mp4',
        r'C:\outside\clip.mp4',
        '..',
      ]) {
        final previewPath = attachmentPreviewPath(
          tempDir,
          'attachment-1',
          fileName,
        );

        expect(p.isWithin(tempDir, previewPath), isTrue, reason: fileName);
        expect(p.basename(previewPath), isNot(contains('/')), reason: fileName);
        expect(
          p.basename(previewPath),
          isNot(contains(r'\')),
          reason: fileName,
        );
        expect(
          attachmentPreviewPath(tempDir, 'attachment-1', fileName),
          previewPath,
          reason: 'the same attachment should reuse its preview path',
        );
      }

      expect(
        attachmentPreviewPath(tempDir, 'attachment-2', '../../app.db'),
        isNot(attachmentPreviewPath(tempDir, 'attachment-1', '../../app.db')),
      );
      expect(
        attachmentPreviewPath(tempDir, 'a/b', 'clip.mp4'),
        isNot(attachmentPreviewPath(tempDir, r'a\b', 'clip.mp4')),
      );

      final longName = attachmentPreviewPath(
        tempDir,
        'attachment-1',
        '${'a' * 200}.pdf',
      );
      expect(utf8.encode(p.basename(longName)).length, lessThanOrEqualTo(255));
      expect(p.extension(longName), '.pdf');

      final longUnicodeName = attachmentPreviewPath(
        tempDir,
        'attachment-1',
        '${'音' * 100}.mp3',
      );
      expect(
        utf8.encode(p.basename(longUnicodeName)).length,
        lessThanOrEqualTo(255),
      );
      expect(p.extension(longUnicodeName), '.mp3');
    },
  );
}
