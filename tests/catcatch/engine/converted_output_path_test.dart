import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/catcatch/engine/executor_utils.dart';

void main() {
  test('reserves distinct converted paths for same-basename inputs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'catcatch_convert_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final outputDir = p.join(directory.path, 'converted');
    final paths = await Future.wait([
      reserveConvertedOutputPath(outputDir, '/downloads/clip.ts'),
      reserveConvertedOutputPath(outputDir, '/downloads/clip.flv'),
    ]);

    expect(
      paths.map((reservation) => reservation.outputPath).toSet(),
      hasLength(2),
    );
    for (final reservation in paths) {
      final output = File(reservation.outputPath);
      final marker = File('${reservation.outputPath}.reserve');
      expect(await output.exists(), isFalse);
      expect(await marker.exists(), isTrue);
    }

    final firstOutput = File(paths.first.outputPath);
    await firstOutput.writeAsString('completed conversion');
    await paths.first.release();
    expect(await firstOutput.readAsString(), 'completed conversion');
    await paths.last.release();
  });
}
