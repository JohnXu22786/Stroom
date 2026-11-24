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

bool isTrustedUserscriptUri(Uri candidate) {
  final host = candidate.host.toLowerCase();
  return candidate.scheme == 'https' &&
      candidate.port == 443 &&
      candidate.userInfo.isEmpty &&
      (host == 'greasyfork.org' ||
          host == 'www.greasyfork.org' ||
          host == 'update.greasyfork.org' ||
          host == 'raw.githubusercontent.com');
}

Uri validateUserscriptResponseUrl(String? responseUrl) {
  if (responseUrl == null || responseUrl.isEmpty) {
    throw const FormatException('redirectedUrl');
  }
  final uri = Uri.parse(responseUrl);
  if (!isTrustedUserscriptUri(uri)) {
    throw const FormatException('redirectedUrl');
  }
  return uri;
}

UserscriptHttpResponse mapUserscriptWebResponse({
  required int statusCode,
  required Uri responseUrl,
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
    responseUrl: responseUrl,
    location: location,
    contentType: contentType,
    body: body,
  );
}
