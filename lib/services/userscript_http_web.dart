import 'dart:html';

import 'userscript_http_response.dart';

Future<UserscriptHttpResponse> fetchUserscriptHttp(String url) async {
  final request = await HttpRequest.request(
    url,
    method: 'GET',
    withCredentials: false,
    responseType: 'text',
  );
  final statusCode = request.status ?? 0;
  if (statusCode >= 400) throw UserscriptHttpException(statusCode);
  final responseUrl = request.responseUrl;
  return UserscriptHttpResponse(
    statusCode: statusCode,
    responseUrl: responseUrl == null || responseUrl.isEmpty
        ? Uri.parse(url)
        : Uri.parse(responseUrl),
    location: request.getResponseHeader('location'),
    contentType: request.getResponseHeader('content-type'),
    body: request.responseText,
  );
}
