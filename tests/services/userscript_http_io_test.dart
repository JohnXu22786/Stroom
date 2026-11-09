import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/userscript_http_io.dart';

void main() {
  test('maps Dio status, redirect, headers, body, and request URL', () {
    final response = Response<String>(
      requestOptions:
          RequestOptions(path: 'https://greasyfork.org/script.user.js'),
      statusCode: 302,
      headers: Headers.fromMap({
        'location': ['https://update.greasyfork.org/script.user.js'],
        'content-type': ['text/plain'],
      }),
      data: 'source',
    );

    final mapped = mapUserscriptDioResponse(
      response,
      Uri.parse('https://greasyfork.org/script.user.js'),
    );

    expect(mapped.statusCode, 302);
    expect(mapped.responseUrl.host, 'greasyfork.org');
    expect(mapped.location, 'https://update.greasyfork.org/script.user.js');
    expect(mapped.contentType, 'text/plain');
    expect(mapped.body, 'source');
  });
}
