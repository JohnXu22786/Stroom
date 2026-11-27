// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/providers/tts_provider.dart';

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.responses);

  final List<ResponseBody> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    return responses[requests.length - 1];
  }

  @override
  void close({bool force = false}) {}
}

Stream<Uint8List> _partialThenFailure(RequestOptions options) async* {
  yield Uint8List.fromList([1, 2, 3]);
  throw DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
    message: 'stream interrupted',
  );
}

void main() {
  test(
    'does not append full fallback audio after partial stream data',
    () async {
      final adapter = _SequenceAdapter([
        ResponseBody(_partialThenFailure(RequestOptions(path: '/speech')), 200),
        ResponseBody.fromBytes([4, 5, 6], 200),
      ]);
      final provider = CustomTTSProvider(
        baseUrl: 'https://tts.example.com/speech',
        apiKey: 'test-key',
        dio: Dio()..httpClientAdapter = adapter,
      );

      await expectLater(
        provider.streamSynthesize('hello').toList(),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.data, containsPair('stream', true));
    },
  );

  test('falls back when the stream fails before emitting any bytes', () async {
    final adapter = _SequenceAdapter([
      ResponseBody(
        Stream<Uint8List>.error(
          DioException(
            requestOptions: RequestOptions(path: '/speech'),
            type: DioExceptionType.connectionError,
          ),
        ),
        200,
      ),
      ResponseBody.fromBytes([4, 5, 6], 200),
    ]);
    final provider = CustomTTSProvider(
      baseUrl: 'https://tts.example.com/speech',
      apiKey: 'test-key',
      dio: Dio()..httpClientAdapter = adapter,
    );

    final chunks = await provider.streamSynthesize('hello').toList();

    expect(chunks, hasLength(1));
    expect(chunks.single, isNotEmpty);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.data, containsPair('stream', true));
    expect(adapter.requests.last.data, isNot(contains('stream')));
  });
}
