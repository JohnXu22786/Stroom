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
  return UserscriptHttpResponse(
    statusCode: response.statusCode ?? 0,
    responseUrl: Uri.parse(url),
    location: response.headers.value('location'),
    contentType: response.headers.value(Headers.contentTypeHeader),
    body: response.data,
  );
}
