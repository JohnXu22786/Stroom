import 'package:dio/dio.dart';

import 'userscript_http_response.dart';

Future<UserscriptHttpResponse> fetchUserscriptHttp(String url) async {
  Response<String> response;
  try {
    response = await Dio(BaseOptions(
      responseType: ResponseType.plain,
      followRedirects: false,
      validateStatus: (status) => status != null && status < 400,
    )).get<String>(url);
  } on DioException catch (error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) throw UserscriptHttpException(statusCode);
    rethrow;
  }
  return mapUserscriptDioResponse(response, Uri.parse(url));
}

UserscriptHttpResponse mapUserscriptDioResponse(
  Response<String> response,
  Uri requestUri,
) {
  return UserscriptHttpResponse(
    statusCode: response.statusCode ?? 0,
    responseUrl: requestUri,
    location: response.headers.value('location'),
    contentType: response.headers.value(Headers.contentTypeHeader),
    body: response.data,
  );
}
