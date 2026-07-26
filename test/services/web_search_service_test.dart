import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/web_search_service.dart';
import 'package:stroom/models/tool_call.dart';

void main() {
  // ====================================================================
  // Tool definition tests (no HTTP needed)
  // ====================================================================

  group('WebSearchService - tool definition', () {
    test('has correct tool definition structure', () {
      final defs = WebSearchService.toolDefinitions;
      expect(defs.length, equals(1));

      final webSearchDef = defs.first;
      expect(webSearchDef.name, equals('web_search'));
      expect(webSearchDef.description, isNotEmpty);

      final params = webSearchDef.parameters;
      expect(params['type'], equals('object'));

      final properties = params['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('query'), isTrue);
      expect(properties.containsKey('source'), isTrue);
      expect(properties.containsKey('count'), isTrue);

      // Required should include query
      final required = params['required'] as List;
      expect(required, contains('query'));
    });

    test('source parameter has enum values for google/bing/baidu', () {
      final defs = WebSearchService.toolDefinitions;
      final webSearchDef = defs.first;
      final properties =
          webSearchDef.parameters['properties'] as Map<String, dynamic>;
      final sourceProperty = properties['source'] as Map<String, dynamic>;

      expect(sourceProperty['type'], equals('string'));
      expect(sourceProperty['enum'], contains('google'));
      expect(sourceProperty['enum'], contains('bing'));
      expect(sourceProperty['enum'], contains('baidu'));
    });
  });

  // ====================================================================
  // Search result parsing tests (unit-testable without HTTP)
  // ====================================================================

  group('WebSearchService - source validation', () {
    test('valid source "google" is accepted', () {
      expect(WebSearchService.isValidSource('google'), isTrue);
    });

    test('valid source "bing" is accepted', () {
      expect(WebSearchService.isValidSource('bing'), isTrue);
    });

    test('valid source "baidu" is accepted', () {
      expect(WebSearchService.isValidSource('baidu'), isTrue);
    });

    test('invalid source returns error', () {
      expect(WebSearchService.isValidSource('yahoo'), isFalse);
    });

    test('empty source defaults to google', () {
      expect(WebSearchService.isValidSource(''), isTrue);
    });

    test('null source defaults to google', () {
      expect(WebSearchService.isValidSource(null), isTrue);
    });
  });

  group('WebSearchService - URL construction', () {
    test('google URL is constructed correctly', () {
      final url = WebSearchService.buildSearchUrl('test query', 'google');
      expect(url, contains('google.com/search'));
      expect(url, contains('q='));
      expect(url, contains('test'));
      expect(url, contains('query'));
      expect(url, isNot(contains('bing')));
      expect(url, isNot(contains('baidu')));
    });

    test('bing URL is constructed correctly', () {
      final url = WebSearchService.buildSearchUrl('test query', 'bing');
      expect(url, contains('www.bing.com/search'));
      expect(url, contains('q='));
      expect(url, contains('test'));
      expect(url, contains('query'));
    });

    test('baidu URL is constructed correctly', () {
      final url = WebSearchService.buildSearchUrl('test query', 'baidu');
      expect(url, contains('baidu.com/s'));
      expect(url, contains('wd='));
      expect(url, contains('test'));
      expect(url, contains('query'));
    });

    test('default source is used when null provided', () {
      final url = WebSearchService.buildSearchUrl('test', null);
      expect(url, contains('google.com'));
    });
  });

  group('WebSearchService - URL cleaning', () {
    test('cleanUrlForTest passes through direct https URL unchanged', () {
      final cleaned =
          WebSearchService.cleanUrlForTest('https://example.com/page');
      expect(cleaned, equals('https://example.com/page'));
    });

    test('cleanUrlForTest extracts URL from Google /url?q= redirect', () {
      final cleaned = WebSearchService.cleanUrlForTest(
        '/url?q=https://example.com/page&sa=U&ved=2ahUKEwjR',
      );
      expect(cleaned, equals('https://example.com/page'));
    });

    test('cleanUrlForTest decodes HTML entities', () {
      final cleaned = WebSearchService.cleanUrlForTest(
        'https://example.com/?a=1&amp;b=2',
      );
      expect(cleaned, equals('https://example.com/?a=1&b=2'));
    });

    test('cleanUrlForTest returns empty for non-http URLs', () {
      final cleaned = WebSearchService.cleanUrlForTest('ftp://example.com');
      expect(cleaned, isEmpty);
    });

    test('cleanUrlForTest returns empty for empty input', () {
      final cleaned = WebSearchService.cleanUrlForTest('');
      expect(cleaned, isEmpty);
    });
  });

  group('WebSearchService - HTML parsing', () {
    test(
        'parseGoogleResults extracts results from HTML (with /url?q= redirects)',
        () {
      final html = '''
<html>
<body>
<div id="search">
<div class="MjjYud">
  <div>
    <h3><a href="/url?q=https://example.com/page1&sa=U&ved=2ahUKEwjR">Example Title 1</a></h3>
    <div><span>This is the snippet for page 1</span></div>
  </div>
</div>
<div class="MjjYud">
  <div>
    <h3><a href="/url?q=https://example.com/page2&sa=U&ved=2ahUKEwjR">Example Title 2</a></h3>
    <div><span>This is the snippet for page 2</span></div>
  </div>
</div>
</div>
</body>
</html>
''';
      final results = WebSearchService.parseGoogleResults(html, maxResults: 10);
      expect(results.length, equals(2));
      expect(results[0].title, contains('Example Title 1'));
      expect(results[0].url, contains('example.com/page1'));
      expect(results[0].snippet, contains('snippet for page 1'));
    });

    test('parseGoogleResults also handles direct https URLs', () {
      final html = '''
<html><body><div id="search">
<div class="MjjYud"><div><h3><a href="https://example.com/1">Direct Title</a></h3></div></div>
</div></body></html>
''';
      final results = WebSearchService.parseGoogleResults(html, maxResults: 10);
      expect(results.length, equals(1));
      expect(results[0].url, contains('example.com/1'));
    });

    test('parseGoogleResults respects maxResults', () {
      final html = '''
<html><body><div id="search">
<div class="MjjYud"><div><h3><a href="/url?q=https://example.com/1">Title 1</a></h3></div></div>
<div class="MjjYud"><div><h3><a href="/url?q=https://example.com/2">Title 2</a></h3></div></div>
<div class="MjjYud"><div><h3><a href="/url?q=https://example.com/3">Title 3</a></h3></div></div>
</div></body></html>
''';
      final results = WebSearchService.parseGoogleResults(html, maxResults: 2);
      expect(results.length, equals(2));
    });

    test('parseGoogleResults returns empty list when no results found', () {
      final html = '<html><body>No results here</body></html>';
      final results = WebSearchService.parseGoogleResults(html, maxResults: 10);
      expect(results, isEmpty);
    });

    test('parseBingResults extracts results from HTML', () {
      final html = '''
<html><body>
<ul id="b_results">
<li class="b_algo"><h2><a href="https://bing.example.com/1">Bing Title 1</a></h2><p>Snippet 1</p></li>
<li class="b_algo"><h2><a href="https://bing.example.com/2">Bing Title 2</a></h2><p>Snippet 2</p></li>
</ul>
</body></html>
''';
      final results = WebSearchService.parseBingResults(html, maxResults: 10);
      expect(results.length, equals(2));
      expect(results[0].title, contains('Bing Title 1'));
      expect(results[0].url, contains('bing.example.com/1'));
    });

    test('parseBingResults returns empty list when no results', () {
      final html = '<html><body><ul id="b_results"></ul></body></html>';
      final results = WebSearchService.parseBingResults(html, maxResults: 10);
      expect(results, isEmpty);
    });

    test('parseBaiduResults extracts results from HTML', () {
      final html = '''
<html><body>
<div id="content_left">
<div class="result">
<h3><a href="https://baidu.example.com/1">Baidu Title 1</a></h3>
<div class="c-abstract">Abstract 1</div>
</div>
<div class="result">
<h3><a href="https://baidu.example.com/2">Baidu Title 2</a></h3>
<div class="c-abstract">Abstract 2</div>
</div>
</div>
</body></html>
''';
      final results = WebSearchService.parseBaiduResults(html, maxResults: 10);
      expect(results.length, equals(2));
      expect(results[0].title, contains('Baidu Title 1'));
      expect(results[0].url, contains('baidu.example.com/1'));
    });

    test('parseBaiduResults returns empty list when no results', () {
      final html = '<html><body><div id="content_left"></div></body></html>';
      final results = WebSearchService.parseBaiduResults(html, maxResults: 10);
      expect(results, isEmpty);
    });
  });

  group('WebSearchService - result formatting', () {
    test('formatResults returns formatted string with results', () {
      final results = [
        SearchResult(
          title: 'Title 1',
          url: 'https://example.com/1',
          snippet: 'Snippet 1',
        ),
        SearchResult(
          title: 'Title 2',
          url: 'https://example.com/2',
          snippet: 'Snippet 2',
        ),
      ];
      final formatted = WebSearchService.formatResults(results, 'google');
      expect(formatted, contains('Title 1'));
      expect(formatted, contains('example.com/1'));
      expect(formatted, contains('Snippet 1'));
      expect(formatted, contains('Title 2'));
      expect(formatted, contains('---')); // separator between results
    });

    test('formatResults returns "no results" message when empty', () {
      final formatted = WebSearchService.formatResults([], 'google');
      expect(formatted, contains('未找到'));
    });
  });

  group('WebSearchService - error handling', () {
    test('empty query returns error message', () async {
      final result = await WebSearchService.handleWebSearch({
        'query': '',
        'source': 'google',
      });
      expect(result, contains('不能为空'));
    });

    test('invalid source returns error message', () async {
      final result = await WebSearchService.handleWebSearch({
        'query': 'test',
        'source': 'invalid_source',
      });
      expect(result, contains('不支持'));
      expect(result, contains('google'));
      expect(result, contains('bing'));
      expect(result, contains('baidu'));
    });
  });
}
