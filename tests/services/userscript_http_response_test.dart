import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/userscript_http_response.dart';

void main() {
  test('classifies redirects and successful responses by status range', () {
    final redirect = UserscriptHttpResponse(
      statusCode: 302,
      responseUrl: Uri.https('greasyfork.org', '/'),
      location: 'https://update.greasyfork.org/script.user.js',
      contentType: null,
      body: null,
    );
    final success = UserscriptHttpResponse(
      statusCode: 200,
      responseUrl: Uri.https('raw.githubusercontent.com', '/'),
      location: null,
      contentType: 'application/javascript',
      body: 'error();',
    );
    final error = UserscriptHttpResponse(
      statusCode: 404,
      responseUrl: Uri.https('raw.githubusercontent.com', '/'),
      location: null,
      contentType: 'text/plain',
      body: 'Not found',
    );

    expect(redirect.isRedirect, isTrue);
    expect(redirect.isSuccess, isFalse);
    expect(success.isRedirect, isFalse);
    expect(success.isSuccess, isTrue);
    expect(error.isRedirect, isFalse);
    expect(error.isSuccess, isFalse);
  });
}
