// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

@TestOn('browser')
library;

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/userscript_http_response.dart';
import 'package:stroom/services/userscript_http_web.dart';

void main() {
  test('maps the browser final URL and response fields', () {
    final mapped = mapUserscriptWebResponse(
      statusCode: 200,
      responseUrl: validateUserscriptResponseUrl(
        'https://update.greasyfork.org/script.user.js',
      ),
      contentType: 'text/plain',
      body: '// ==UserScript==\n// ==/UserScript==',
    );

    expect(mapped.responseUrl.host, 'update.greasyfork.org');
    expect(mapped.contentType, 'text/plain');
    expect(mapped.body, contains('==UserScript=='));
    expect(isTrustedUserscriptUri(mapped.responseUrl), isTrue);
  });

  test('rejects a browser-followed redirect to an untrusted final URL', () {
    expect(
      () => validateUserscriptResponseUrl(
        'https://example.com/script.user.js',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a response that omits its final URL', () {
    for (final responseUrl in <String?>[null, '']) {
      expect(
        () => validateUserscriptResponseUrl(responseUrl),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('rejects browser redirects that hide the destination', () {
    expect(
      () => mapUserscriptWebResponse(
        statusCode: 0,
        responseUrl: Uri.https('greasyfork.org', '/script.user.js'),
        responseType: 'opaqueredirect',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('follows trusted redirects without credentials and returns source',
      () async {
    const requestUrl = 'https://greasyfork.org/script.user.js';
    const trustedFinalUrl = 'https://update.greasyfork.org/script.user.js';
    const source = '// ==UserScript==\n// ==/UserScript==';
    var bodyReads = 0;
    final response = await fetchUserscriptHttp(
      requestUrl,
      fetch: (url, options) async {
        _expectRequestOptions(url, requestUrl, options);
        return _fakeResponse(
          url: trustedFinalUrl,
          type: 'cors',
          body: source,
          onText: () => bodyReads++,
        );
      },
    );

    expect(response.responseUrl.toString(), trustedFinalUrl);
    expect(response.body, source);
    expect(bodyReads, 1);
  });

  test('rejects an untrusted final URL before reading its body', () async {
    const requestUrl = 'https://greasyfork.org/script.user.js';
    const source = '// ==UserScript==\n// ==/UserScript==';
    var bodyReads = 0;
    await expectLater(
      fetchUserscriptHttp(
        requestUrl,
        fetch: (url, options) async {
          _expectRequestOptions(url, requestUrl, options);
          return _fakeResponse(
            url: 'https://example.com/script.user.js',
            type: 'cors',
            body: source,
            onText: () => bodyReads++,
          );
        },
      ),
      throwsA(isA<FormatException>()),
    );
    expect(bodyReads, 0);
  });

  test('rejects a missing final URL before reading its body', () async {
    const requestUrl = 'https://greasyfork.org/script.user.js';
    const source = '// ==UserScript==\n// ==/UserScript==';
    for (final finalUrl in <String?>[null, '']) {
      var bodyReads = 0;
      await expectLater(
        fetchUserscriptHttp(
          requestUrl,
          fetch: (url, options) async {
            _expectRequestOptions(url, requestUrl, options);
            return _fakeResponse(
              url: finalUrl,
              type: 'cors',
              body: source,
              onText: () => bodyReads++,
            );
          },
        ),
        throwsA(isA<FormatException>()),
      );
      expect(bodyReads, 0);
    }
  });

  test('continues to reject opaque redirects without reading the body',
      () async {
    const requestUrl = 'https://greasyfork.org/script.user.js';
    const source = '// ==UserScript==\n// ==/UserScript==';
    var bodyReads = 0;
    await expectLater(
      fetchUserscriptHttp(
        requestUrl,
        fetch: (url, options) async {
          _expectRequestOptions(url, requestUrl, options);
          return _fakeResponse(
            url: null,
            type: 'opaqueredirect',
            body: source,
            onText: () => bodyReads++,
          );
        },
      ),
      throwsA(isA<FormatException>()),
    );
    expect(bodyReads, 0);
  });
}

void _expectRequestOptions(String url, String expectedUrl, JSObject options) {
  expect(url, expectedUrl);
  expect(options['method']?.dartify(), 'GET');
  expect(options['credentials']?.dartify(), 'omit');
  expect(options['redirect']?.dartify(), 'follow');
}

JSObject _fakeResponse({
  required String? url,
  required String type,
  required String body,
  required void Function() onText,
}) {
  final headers = JSObject()
    ..setProperty(
      'get'.toJS,
      ((JSString name) =>
          name.toDart == 'content-type' ? 'text/plain'.toJS : null).toJS,
    );
  final response = JSObject()
    ..setProperty('url'.toJS, url?.toJS)
    ..setProperty('type'.toJS, type.toJS)
    ..setProperty('status'.toJS, 200.toJS)
    ..setProperty('headers'.toJS, headers);
  final promiseConstructor =
      JSObject.fromInteropObject(html.window)['Promise']! as JSObject;
  final resolvePromise = promiseConstructor['resolve'] as JSFunction;
  response.setProperty(
    'text'.toJS,
    (() {
      onText();
      return resolvePromise.callAsFunction(promiseConstructor, body.toJS);
    }).toJS,
  );
  return response;
}
