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
}

class UserscriptHttpException implements Exception {
  final int statusCode;

  const UserscriptHttpException(this.statusCode);
}
