import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stroom/anki/database/sqlite_error_classifier.dart';

class _TestDatabaseException extends DatabaseException {
  _TestDatabaseException(String message, this.resultCode) : super(message);

  final int? resultCode;

  @override
  int? getResultCode() => resultCode;

  @override
  Object? get result => null;
}

void main() {
  group('SQLite error classification', () {
    test('recognizes local file and storage result codes', () {
      for (final code in [3, 8, 10, 13, 14, 266]) {
        expect(
          isSqliteLocalFileFailure(
              _TestDatabaseException('SQLite error', code)),
          isTrue,
          reason: 'SQLite result code $code should be a local file failure',
        );
      }
    });

    test('keeps corruption result codes separate from local file failures', () {
      for (final code in [11, 26]) {
        final error = _TestDatabaseException('SQLite error', code);
        expect(isSqliteLocalFileFailure(error), isFalse);
        expect(isSqliteCorruption(error), isTrue);
      }
    });

    test('recognizes corruption messages when no result code is available', () {
      expect(
        isSqliteCorruption(
          _TestDatabaseException('Database disk image is malformed', null),
        ),
        isTrue,
      );
      expect(
        isSqliteCorruption(
          _TestDatabaseException('File is not a database', null),
        ),
        isTrue,
      );
      expect(
        isSqliteCorruption(
            _TestDatabaseException('Generic SQLite error', null)),
        isFalse,
      );
    });
  });
}
