import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'userscript_http_response.dart';

@JS('fetch')
external JSPromise<JSAny?> _fetch(JSString input, JSAny? init);

Future<UserscriptHttpResponse> fetchUserscriptHttp(String url) async {
  final options = JSObject()
    ..setProperty('method'.toJS, 'GET'.toJS)
    ..setProperty('credentials'.toJS, 'omit'.toJS)
    ..setProperty('redirect'.toJS, 'manual'.toJS);
  final response = (await _fetch(url.toJS, options).toDart) as JSObject;
  final responseType = response['type']?.dartify() as String?;
  final statusCode = (response['status']?.dartify() as num?)?.toInt() ?? 0;
  final responseUrl = response['url']?.dartify() as String?;
  if (responseType == 'opaqueredirect') {
    throw const FormatException('redirectedUrl');
  }
  final headers = response['headers'] as JSObject;
  final body =
      await response.callMethod<JSPromise<JSString>>('text'.toJS).toDart;
  String? header(String name) =>
      headers.callMethod<JSString?>('get'.toJS, name.toJS)?.toDart;
  if (statusCode >= 400) throw UserscriptHttpException(statusCode);
  return mapUserscriptWebResponse(
    statusCode: statusCode,
    requestUrl: url,
    responseUrl: responseUrl,
    responseType: responseType,
    location: header('location'),
    contentType: header('content-type'),
    body: body.toDart,
  );
}
