import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/text_storage_shared.dart';
import 'package:stroom/utils/text_manifest.dart';

void main() {
  test('text name collisions include format and folder', () {
    final records = [
      TextRecord(
        name: 'report',
        hash: 'txt-hash',
        format: 'txt',
        createdAt: DateTime.utc(2024),
        size: 1,
        folder: 'docs',
      ),
      TextRecord(
        name: 'report',
        hash: 'md-hash',
        format: 'md',
        createdAt: DateTime.utc(2024),
        size: 1,
        folder: 'other',
      ),
    ];

    expect(uniqueTextRecordName('report', 'md', 'docs', records, {}), 'report');
    expect(
      uniqueTextRecordName('report', 'txt', 'docs', records, {}),
      'report (2)',
    );
  });
}
