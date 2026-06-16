/// 从 URL 推断标题
String inferTitleFromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return uri.host;
  } catch (_) {
    return url.length > 50 ? '${url.substring(0, 50)}...' : url;
  }
}
