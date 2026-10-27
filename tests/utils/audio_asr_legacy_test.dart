import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/asr_legacy_audio.dart';

void main() {
  test(
    'legacy Base64 validation yields between bounded decode batches',
    () async {
      final bytes = Uint8List(32 * 1024);
      final encoded = base64Encode(bytes);
      var yieldCount = 0;
      var firstBatchTimerFired = false;
      var responsiveBetweenBatches = false;

      final byteLength = await validateAsrLegacyBase64AudioByteLength(
        encoded,
        onYield: () {
          yieldCount++;
          if (yieldCount == 1) {
            Timer.run(() => firstBatchTimerFired = true);
          } else if (yieldCount == 2) {
            responsiveBetweenBatches = firstBatchTimerFired;
          }
        },
      );

      expect(byteLength, bytes.length);
      expect(yieldCount, greaterThan(0));
      expect(responsiveBetweenBatches, isTrue);
    },
  );

  test('legacy Base64 validation stops at cancellation boundaries', () async {
    final encoded = base64Encode(Uint8List(64 * 1024));
    var checks = 0;
    var yields = 0;

    await expectLater(
      validateAsrLegacyBase64AudioByteLength(
        encoded,
        checkCanceled: () {
          checks++;
          if (checks == 3) throw StateError('canceled');
        },
        onYield: () => yields++,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'canceled',
        ),
      ),
    );

    expect(checks, 3);
    expect(yields, 1);
  });

  test(
    'legacy Base64 validation rejects empty and malformed payloads',
    () async {
      for (final value in ['', '%%%', 'A']) {
        expect(await validateAsrLegacyBase64AudioByteLength(value), isNull);
      }
    },
  );

  test(
    'legacy Base64 decoding yields between batches and preserves bytes',
    () async {
      final bytes = Uint8List.fromList(
        List<int>.generate(32 * 1024, (index) => index & 0xff),
      );
      final encoded = base64Encode(bytes);
      var yieldCount = 0;
      var firstBatchTimerFired = false;
      var responsiveBetweenBatches = false;

      final decoded = await decodeAsrLegacyBase64Audio(
        encoded,
        onYield: () {
          yieldCount++;
          if (yieldCount == 1) {
            Timer.run(() => firstBatchTimerFired = true);
          } else if (yieldCount == 2) {
            responsiveBetweenBatches = firstBatchTimerFired;
          }
        },
      );

      expect(decoded, bytes);
      expect(yieldCount, greaterThan(0));
      expect(responsiveBetweenBatches, isTrue);
      await expectLater(
        decodeAsrLegacyBase64Audio('%%%'),
        throwsFormatException,
      );
    },
  );

  test('legacy Base64 decoding stops at cancellation boundaries', () async {
    final encoded = base64Encode(Uint8List(64 * 1024));
    var checks = 0;

    await expectLater(
      decodeAsrLegacyBase64Audio(
        encoded,
        checkCanceled: () {
          checks++;
          if (checks == 3) throw StateError('canceled');
        },
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'canceled',
        ),
      ),
    );
    expect(checks, 3);
  });
}
