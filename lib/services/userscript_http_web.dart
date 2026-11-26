import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'userscript_http_response.dart';

@JS('fetch')
external JSPromise<JSAny?> _fetch(JSString input, JSAny? init);

typedef UserscriptWebFetch = Future<JSAny?> Function(
  String url,
  JSObject options,
);

Future<UserscriptHttpResponse> fetchUserscriptHttp(
  String url, {
  UserscriptWebFetch? fetch,
}) async {
  final options = JSObject()
    ..setProperty('method'.toJS, 'GET'.toJS)
    ..setProperty('credentials'.toJS, 'omit'.toJS)
    // Browsers hide cross-origin redirect destinations in manual mode. Follow
    // them in Fetch, then let _fetchUserscript validate response.url before it
    // exposes the response source. Fetch does not expose the individual hops.
    ..setProperty('redirect'.toJS, 'follow'.toJS);
  final rawResponse = fetch == null
      ? await _fetch(url.toJS, options).toDart
      : await fetch(url, options);
  final response = rawResponse as JSObject;
  final responseType = response['type']?.dartify() as String?;
  final statusCode = (response['status']?.dartify() as num?)?.toInt() ?? 0;
  if (responseType == 'opaqueredirect') {
    throw const FormatException('redirectedUrl');
  }
  final responseUrl =
      validateUserscriptResponseUrl(response['url']?.dartify() as String?);
  if (statusCode >= 400) throw UserscriptHttpException(statusCode);
  final headers = response['headers'] as JSObject;
  final body =
      await response.callMethod<JSPromise<JSString>>('text'.toJS).toDart;
  String? header(String name) =>
      headers.callMethod<JSString?>('get'.toJS, name.toJS)?.toDart;
  return mapUserscriptWebResponse(
    statusCode: statusCode,
    responseUrl: responseUrl,
    responseType: responseType,
    location: header('location'),
    contentType: header('content-type'),
    body: body.toDart,
  );
}
