import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/data_integrity_json_parser_io.dart'
    as json_parser;
import 'package:stroom/services/startup_data_validation_unavailable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fails closed when JSON batch parsing cannot start its Isolate',
    () async {
      final previousRunner = json_parser.debugJsonBatchIsolateRunnerForTesting;
      json_parser.debugJsonBatchIsolateRunnerForTesting =
          (_) async => throw StateError('simulated Isolate failure');

      try {
        await expectLater(
          json_parser.parseJsonBatch(['{broken']),
          throwsA(isA<StartupDataValidationUnavailable>()),
        );
      } finally {
        json_parser.debugJsonBatchIsolateRunnerForTesting = previousRunner;
      }
    },
  );
}
