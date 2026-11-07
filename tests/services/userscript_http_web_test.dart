import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/userscript_http_response.dart';

void main() {
  test('maps the browser final URL and response fields', () {
    final mapped = mapUserscriptWebResponse(
      statusCode: 200,
      requestUrl: 'https://greasyfork.org/script.user.js',
      responseUrl: 'https://update.greasyfork.org/script.user.js',
      contentType: 'text/plain',
      body: '// ==UserScript==\n// ==/UserScript==',
    );

    expect(mapped.responseUrl.host, 'update.greasyfork.org');
    expect(mapped.contentType, 'text/plain');
    expect(mapped.body, contains('==UserScript=='));
  });

  test('falls back to the requested URL when the browser omits response URL',
      () {
    final mapped = mapUserscriptWebResponse(
      statusCode: 200,
      requestUrl: 'https://raw.githubusercontent.com/owner/repo/main/script.js',
      responseUrl: '',
      body: 'source',
    );

    expect(mapped.responseUrl.host, 'raw.githubusercontent.com');
    expect(mapped.body, 'source');
  });

  test('rejects browser redirects that hide the destination', () {
    expect(
      () => mapUserscriptWebResponse(
        statusCode: 0,
        requestUrl: 'https://greasyfork.org/script.user.js',
        responseType: 'opaqueredirect',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
