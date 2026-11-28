import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:stroom/pages/audio_separation_page.dart';

final class _DelayedXFile extends XFile {
  _DelayedXFile(this.readBytes) : super('delayed-video.mp4');

  final Future<Uint8List> Function() readBytes;

  @override
  String get name => 'delayed-video.mp4';

  @override
  Future<Uint8List> readAsBytes() => readBytes();
}

void main() {
  test(
    'discards a video read that completes after the page is disposed',
    () async {
      final readStarted = Completer<void>();
      final finishRead = Completer<Uint8List>();
      var isMounted = true;

      // This repo uses `tests/` rather than the analyzer-recognized `test/`.
      // ignore: invalid_use_of_visible_for_testing_member
      final result = readPickedVideoFiles([
        _DelayedXFile(() {
          readStarted.complete();
          return finishRead.future;
        }),
      ], isMounted: () => isMounted);

      await readStarted.future;
      isMounted = false;
      finishRead.complete(Uint8List.fromList([1, 2, 3]));

      expect(await result, isNull);
    },
  );
}
