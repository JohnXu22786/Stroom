class UserscriptHttpResponse {
  final int statusCode;
  final Uri responseUrl;
  final String? location;
  final String? contentType;
  final String? body;

  const UserscriptHttpResponse({
    required this.statusCode,
    required this.responseUrl,
    required this.location,
    required this.contentType,
    required this.body,
  });

  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class UserscriptHttpException implements Exception {
  final int statusCode;

  const UserscriptHttpException(this.statusCode);
}

UserscriptHttpResponse mapUserscriptWebResponse({
  required int statusCode,
  required String requestUrl,
  String? responseUrl,
  String? location,
  String? contentType,
  String? body,
  String? responseType,
}) {
  if (responseType == 'opaqueredirect') {
    throw const FormatException('redirectedUrl');
  }
  return UserscriptHttpResponse(
    statusCode: statusCode,
    responseUrl: responseUrl == null || responseUrl.isEmpty
        ? Uri.parse(requestUrl)
        : Uri.parse(responseUrl),
    location: location,
    contentType: contentType,
    body: body,
  );
}
