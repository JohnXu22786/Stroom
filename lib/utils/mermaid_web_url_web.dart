import 'dart:html' as html;

Uri get mermaidWebBaseUri =>
    Uri.parse(html.document.baseUri ?? html.window.location.href);
