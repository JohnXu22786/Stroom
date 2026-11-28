import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/ffmpeg_converter_io.dart';

void main() {
  test('cancellation resolves the conversion waiter promptly', () async {
    final cancelToken = CancelToken();
    var stopCalls = 0;
    final waiter = FvpConversionWaiter(
      cancelToken: cancelToken,
      stopPlayer: () => stopCalls++,
    );

    cancelToken.cancel();

    await expectLater(
      waiter.future.timeout(const Duration(seconds: 1)),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Task was cancelled'),
        ),
      ),
    );
    expect(stopCalls, 1);

    waiter.complete();
    expect(waiter.isCompleted, isTrue);
    expect(stopCalls, 1);
  });
}
