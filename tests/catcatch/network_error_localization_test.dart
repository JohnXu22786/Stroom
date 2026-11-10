import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/executor_utils.dart';

void main() {
  group('CatCatch network error localization', () {
    test('localizes framing and preserves dynamic Dio error details', () {
      final request = RequestOptions(path: 'https://example.com/media');

      for (final locale in [
        const Locale('en', 'US'),
        const Locale('zh', 'CN'),
      ]) {
        final timeout = formatDioError(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionTimeout,
            message: 'socket detail from platform',
          ),
          locale: locale,
        );
        final badResponse = formatDioError(
          DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            message: 'upstream detail',
            response: Response<String>(
              requestOptions: request,
              statusCode: 503,
              data: 'maintenance window',
            ),
          ),
          locale: locale,
        );

        if (locale.languageCode == 'en') {
          expect(timeout, startsWith('Connection timed out'));
          expect(
            timeout,
            contains('Original error: socket detail from platform'),
          );
          expect(
            badResponse,
            startsWith('The server returned an error (HTTP 503)'),
          );
        } else {
          expect(timeout, startsWith('连接超时'));
          expect(timeout, contains('原始错误：socket detail from platform'));
          expect(badResponse, startsWith('服务器返回错误 (HTTP 503)'));
        }
        expect(badResponse, contains('maintenance window'));
        expect(badResponse, contains('upstream detail'));
      }
    });

    test('localizes the web download hint and preserves attribution', () {
      final english = webDownloadHint(locale: const Locale('en', 'US'));
      final chinese = webDownloadHint(locale: const Locale('zh', 'CN'));

      expect(
        english,
        contains('Web browsers cannot download media files directly'),
      );
      expect(chinese, contains('Web 端不支持直接下载媒体文件'));
      for (final hint in [english, chinese]) {
        expect(hint, contains('CatCatch'));
        expect(hint, contains('xifangczy'));
        expect(hint, contains('https://github.com/xifangczy/cat-catch'));
      }
    });
  });
}
