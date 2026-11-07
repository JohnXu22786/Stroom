import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:stroom/providers/locale_provider.dart';

String sseClientWebConnectionFailureMessage({
  required int? statusCode,
  required String? statusText,
  Locale? locale,
}) {
  final strings = appLocalizationsForLocale(locale);
  if (statusCode != null && statusCode != 0) {
    if ((statusText ?? '').isNotEmpty) {
      return strings.sseConnectionFailedWithStatus(statusCode, statusText!);
    }
    return strings.sseConnectionFailedWithoutStatusText(statusCode);
  }
  return strings.sseConnectionUnavailable;
}

String sseClientWebHttpRequestFailureMessage({
  required int statusCode,
  required String? statusText,
  Locale? locale,
}) =>
    appLocalizationsForLocale(locale)
        .sseHttpRequestFailed(statusCode, statusText ?? '');

String sseClientWebRequestFailureMessage({Locale? locale}) =>
    appLocalizationsForLocale(locale).sseRequestFailed;

String sseClientWebNetworkFailureMessage({Locale? locale}) =>
    appLocalizationsForLocale(locale).sseNetworkRequestFailed;

String sseClientWebCancellationMessage({Locale? locale}) =>
    appLocalizationsForLocale(locale).sseRequestCancelled;

String _sseClientWebNetworkFailureWithStatus({
  required int statusCode,
  required String? statusText,
  required Locale? locale,
}) {
  final strings = appLocalizationsForLocale(locale);
  if ((statusText ?? '').isNotEmpty) {
    return strings.sseNetworkRequestFailedWithStatus(statusCode, statusText!);
  }
  return strings.sseNetworkRequestFailedWithoutStatusText(statusCode);
}

String _sseClientWebNetworkConnectionUnavailable(Locale? locale) =>
    appLocalizationsForLocale(locale).sseNetworkConnectionUnavailable;

/// Converts a failed browser XHR into the equivalent Dio transport error.
///
/// Keeping the conversion independent of `dart:html` lets the error
/// classification and Retry-After metadata be covered by platform-neutral
/// tests while the web client supplies the XHR response fields.
DioException createSseClientWebFailure({
  required String url,
  required int? statusCode,
  required String? statusText,
  required String? responseBody,
  Map<String, List<String>> responseHeaders = const {},
  Locale? locale,
}) {
  final requestOptions = RequestOptions(path: url);
  if (statusCode != null && statusCode >= 400) {
    return DioException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        data: responseBody,
        statusCode: statusCode,
        statusMessage: statusText,
        headers: Headers.fromMap(responseHeaders),
      ),
      type: DioExceptionType.badResponse,
    );
  }
  return DioException(
    requestOptions: requestOptions,
    message: statusCode != null && statusCode != 0
        ? _sseClientWebNetworkFailureWithStatus(
            statusCode: statusCode,
            statusText: statusText,
            locale: locale,
          )
        : _sseClientWebNetworkConnectionUnavailable(locale),
    type: DioExceptionType.connectionError,
  );
}
