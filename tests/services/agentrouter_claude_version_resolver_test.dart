import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/agentrouter_claude_version_resolver.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final Future<String> Function() reply;
  var calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(await reply(), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('accepts newer registry version and caches resolved profile', () async {
    final adapter = _Adapter(() async => '{"version":"2.1.281"}');
    final resolver = AgentRouterClaudeVersionResolver(
      dio: Dio()..httpClientAdapter = adapter,
    );
    final result = await resolver.resolve();
    expect(result.clientVersion, '2.1.281');
    expect(result.billingVersion, '2.1.281.1e2');
    expect(result.userAgent, 'claude-cli/2.1.281 (external, cli)');
    await resolver.resolve();
    expect(adapter.calls, 1);
  });

  test('older and malformed versions use pinned fallback', () async {
    for (final body in ['{"version":"2.1.279"}', '{"version":"latest"}']) {
      final resolver = AgentRouterClaudeVersionResolver(
        dio: Dio()..httpClientAdapter = _Adapter(() async => body),
      );
      expect((await resolver.resolve()).clientVersion, '2.1.280');
    }
  });

  test('fallback response is cached to avoid repeated registry delays',
      () async {
    final adapter = _Adapter(() async => '{"version":"2.1.279"}');
    final resolver = AgentRouterClaudeVersionResolver(
      dio: Dio()..httpClientAdapter = adapter,
    );
    expect((await resolver.resolve()).clientVersion, '2.1.280');
    expect((await resolver.resolve()).clientVersion, '2.1.280');
    expect(adapter.calls, 1);
  });
}
