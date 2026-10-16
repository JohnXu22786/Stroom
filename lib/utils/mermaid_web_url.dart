import 'mermaid_web_url_stub.dart'
    if (dart.library.html) 'mermaid_web_url_web.dart' as platform;

/// Resolves a Mermaid web URL against Flutter's configured web base URI.
///
/// [baseUri] can be provided by tests; production uses the browser's
/// `document.baseURI` on web.
String resolveMermaidWebUrl(String url, {Uri? baseUri}) =>
    (baseUri ?? platform.mermaidWebBaseUri).resolve(url).toString();
