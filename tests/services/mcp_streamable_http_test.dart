import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/mcp.dart';
import 'package:stroom/services/mcp_client.dart';

/// 模拟一个远程 MCP 服务器，支持 streamable HTTP（POST）与 legacy SSE（GET）
/// 两种传输，供 McpClient 注入使用。
class FakeRemoteMcp {
  FakeRemoteMcp({required this.name, this.sessionId = 'sess-123'});

  final String name;
  final String sessionId;

  /// streamable HTTP 是否可用；false 时 POST 返回 405。
  bool streamable = true;

  /// legacy SSE 是否可用；false 时 GET 返回 405。
  bool legacy = true;

  /// 响应使用 application/json 裸 JSON 体（无 event/data 帧）。
  bool bareJson = false;

  /// initialize 响应拆成多个 data: 行（SSE 规范允许，需按 \n 拼接）。
  bool splitData = false;

  /// tools/call 返回 JSON-RPC error 帧。
  bool callError = false;

  /// tools/call 返回 isError: true 的结果。
  bool callIsError = false;

  /// legacy GET 立即关闭且不发 endpoint。
  bool legacyNoEndpoint = false;

  /// legacy endpoint POST 直接失败。
  bool failLegacyPost = false;

  /// 前 N 次 streamable POST 失败（405），随后成功（用于重连测试）。
  int failStreamableTimes = 0;
  int _streamableFailures = 0;

  /// 每次 POST 的请求头（streamable 与 legacy endpoint POST 都会记录）。
  final List<Map<String, String>> postRequestHeaders = [];

  /// 每次 POST 的 URL（streamable POST 与 legacy endpoint POST）。
  final List<String> postUrls = [];

  StreamController<String>? _legacyController;
  final List<StreamController<String>> _legacyControllers = [];

  /// 关闭第 [index] 次 legacy 连接对应的 GET 流（模拟服务器/网络断开）。
  void closeLegacyController(int index) {
    if (index >= 0 && index < _legacyControllers.length) {
      _legacyControllers[index].close();
    }
  }

  /// streamable POST 挂起（永不产出、永不关闭），用于 dispose 竞态测试。
  bool hangPost = false;

  Stream<String> postLines(
    String url,
    Map<String, String> headers,
    String body, {
    CancelToken? cancelToken,
    void Function(Map<String, List<String>> headers)? onResponseHeaders,
  }) async* {
    postRequestHeaders.add(headers);
    postUrls.add(url);

    if (_streamableFailures < failStreamableTimes) {
      _streamableFailures++;
      throw DioException(
        requestOptions: RequestOptions(path: url),
        response: Response(
            requestOptions: RequestOptions(path: url), statusCode: 405),
        type: DioExceptionType.badResponse,
      );
    }
    if (!streamable) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        response: Response(
            requestOptions: RequestOptions(path: url), statusCode: 405),
        type: DioExceptionType.badResponse,
      );
    }
    if (hangPost) {
      await Completer<void>().future; // 永不完成
      return;
    }
    if (onResponseHeaders != null) {
      onResponseHeaders({
        'mcp-session-id': [sessionId]
      });
    }
    final req = jsonDecode(body) as Map<String, dynamic>;
    final method = req['method'] as String?;
    final id = req['id'];
    if (method == 'initialize') {
      if (bareJson) {
        yield jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2024-11-05',
            'serverInfo': {'name': name},
          },
        });
      } else if (splitData) {
        yield 'event: message';
        yield 'data: {"jsonrpc":"2.0","id":"$id","result":{';
        yield 'data: "protocolVersion":"2024-11-05","serverInfo":{"name":"$name"}}}';
        yield '';
      } else {
        yield 'event: message';
        yield 'data: ${jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'protocolVersion': '2024-11-05',
                'serverInfo': {'name': name},
              },
            })}';
        yield '';
      }
    } else if (method == 'tools/list') {
      yield 'event: message';
      yield 'data: ${jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'result': {
              'tools': [
                {
                  'name': 'search',
                  'inputSchema': {'type': 'object'},
                },
              ],
            },
          })}';
      yield '';
    } else if (method == 'tools/call') {
      if (callError) {
        yield 'event: message';
        yield 'data: ${jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'error': {'code': -32603, 'message': 'Internal tool error'},
            })}';
        yield '';
      } else if (callIsError) {
        yield 'event: message';
        yield 'data: ${jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'content': [
                  {'type': 'text', 'text': 'tool reported failure'},
                ],
                'isError': true,
              },
            })}';
        yield '';
      } else {
        yield 'event: message';
        yield 'data: ${jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'content': [
                  {'type': 'text', 'text': 'hello'},
                ],
              },
            })}';
        yield '';
      }
    }
    // notifications/initialized 等通知：无响应，流直接结束。
  }

  Stream<String> sseConnect(
    String url,
    Map<String, String> headers, {
    CancelToken? cancelToken,
    void Function(Map<String, List<String>> headers)? onResponseHeaders,
  }) {
    if (!legacy) {
      return Stream.error(DioException(
        requestOptions: RequestOptions(path: url),
        response: Response(
            requestOptions: RequestOptions(path: url), statusCode: 405),
        type: DioExceptionType.badResponse,
      ));
    }
    if (legacyNoEndpoint) {
      // 干净关闭但从未发送 endpoint 事件（驱动 onDone 分支）
      return const Stream<String>.empty();
    }
    final controller = StreamController<String>();
    _legacyController = controller;
    _legacyControllers.add(controller);
    // 下一事件循环投递 endpoint 事件：确保 listener 已挂载。
    Future(() {
      if (controller.isClosed) return;
      controller.add('event: endpoint');
      controller.add('data: ${url.replaceAll('sse', 'messages')}');
      controller.add('');
    });
    return controller.stream;
  }

  Future<String> ssePost(
    String url,
    Map<String, String> headers,
    String body, {
    CancelToken? cancelToken,
  }) async {
    postRequestHeaders.add(headers);
    postUrls.add(url);
    if (failLegacyPost) {
      throw DioException(
        requestOptions: RequestOptions(path: url),
        response: Response(
            requestOptions: RequestOptions(path: url), statusCode: 500),
        type: DioExceptionType.badResponse,
      );
    }
    final req = jsonDecode(body) as Map<String, dynamic>;
    final method = req['method'] as String?;
    final id = req['id'];
    final c = _legacyController;
    if (c != null && !c.isClosed && method != 'notifications/initialized') {
      final result = method == 'tools/list'
          ? {
              'tools': [
                {
                  'name': 'search',
                  'inputSchema': {'type': 'object'}
                },
              ],
            }
          : method == 'tools/call'
              ? {
                  'content': [
                    {'type': 'text', 'text': 'hello'},
                  ],
                }
              : {
                  'protocolVersion': '2024-11-05',
                  'serverInfo': {'name': name},
                };
      c.add('event: message');
      c.add('data: ${jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'result': result
          })}');
      c.add('');
    }
    return '';
  }

  void dispose() {
    _legacyController?.close();
  }
}

void main() {
  group('McpClient.resolveRequestHeaders - 鉴权头解析', () {
    test('空/前缀占位头会被真实 key 填充（Exa/Zhipu 场景）', () {
      final exa = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Exa',
        url: 'https://mcp.exa.ai/mcp',
        headers: {'x-api-key': ''},
        apiKey: 'exa-key-1',
      ));
      expect(exa['x-api-key'], equals('exa-key-1'));

      final zhipu = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Zhipu',
        url: 'https://example.com/mcp',
        headers: {'Authorization': 'Bearer '},
        apiKey: 'zhipu-key',
      ));
      expect(zhipu['Authorization'], equals('Bearer zhipu-key'));
    });

    test('无任何请求头时回退为 Authorization: Bearer（Tavily 场景）', () {
      // 回归：Tavily 不接受 x-api-key，旧实现会错误地发送 x-api-key 头。
      final config = McpServerConfig.sse(
        name: 'Tavily',
        url: 'https://mcp.tavily.com/mcp/',
        apiKey: 'tvly-key',
      );
      final headers = McpClient.resolveRequestHeaders(config);
      expect(headers.containsKey('x-api-key'), isFalse,
          reason: 'Tavily 拒绝 x-api-key 鉴权，不得发送该头');
      expect(headers['Authorization'], equals('Bearer tvly-key'),
          reason: 'Tavily 接受 Authorization: Bearer 鉴权');
    });

    test('Authorization 已携带 key 时移除冗余的 x-api-key', () {
      final headers = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Custom',
        url: 'https://example.com/mcp',
        headers: {'Authorization': 'Bearer ', 'x-api-key': ''},
        apiKey: 'k1',
      ));
      expect(headers['Authorization'], equals('Bearer k1'));
      expect(headers.containsKey('x-api-key'), isFalse,
          reason: '同一凭据重复发送可能被服务器拒绝（Tavily 拒绝 x-api-key）');
    });

    test('过期的鉴权头会被 apiKey 字段刷新（换 key 场景）', () {
      final xapi = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Exa',
        url: 'https://mcp.exa.ai/mcp',
        headers: {'x-api-key': 'old-key'},
        apiKey: 'new-key',
      ));
      expect(xapi['x-api-key'], equals('new-key'),
          reason: 'apiKey 字段为最新用户输入，应覆盖过期的头部值');

      final auth = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Custom',
        url: 'https://example.com/mcp',
        headers: {'Authorization': 'Bearer old-key'},
        apiKey: 'new-key',
      ));
      expect(auth['Authorization'], equals('Bearer new-key'));
    });

    test('请求头已携带相同 key 时保持不变', () {
      final headers = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Exa',
        url: 'https://mcp.exa.ai/mcp',
        headers: {'x-api-key': 'same-key'},
        apiKey: 'same-key',
      ));
      expect(headers, equals({'x-api-key': 'same-key'}));
    });

    test('短 key 不会误命中非鉴权头值，仍会新增 Authorization 兜底', () {
      // 回归：旧实现用 contains 子串判断，key='1' 会被 User-Agent 里的
      // "App/1.0" 误命中，导致请求不带任何鉴权头。
      final headers = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Custom',
        url: 'https://example.com/mcp',
        headers: {'x-custom': 'App/1.0'},
        apiKey: '1',
      ));
      expect(headers['x-custom'], equals('App/1.0'));
      expect(headers['Authorization'], equals('Bearer 1'));
    });

    test('未配置 key 时请求头原样返回', () {
      final headers = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Exa',
        url: 'https://mcp.exa.ai/mcp',
        headers: {'x-api-key': 'plain'},
      ));
      expect(headers, equals({'x-api-key': 'plain'}));
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('非鉴权头不会被注入 apiKey（占位形态的自定义头保留原样）', () {
      // 回归：旧实现会把空/占位形态的任意请求头填成 apiKey，导致 key
      // 泄漏进用户从未指定承载凭据的自定义头。
      final headers = McpClient.resolveRequestHeaders(McpServerConfig.sse(
        name: 'Custom',
        url: 'https://example.com/mcp',
        headers: {'X-Request-Id': '', 'x-trace': 'Bearer '},
        apiKey: 'k1',
      ));
      expect(headers['X-Request-Id'], equals(''));
      expect(headers['x-trace'], equals('Bearer '));
      expect(headers['Authorization'], equals('Bearer k1'));
    });
  });

  group('McpClient streamable HTTP 传输', () {
    test('streamable HTTP POST 连接成功并发现/调用工具（Exa/Tavily 场景）', () async {
      final fake = FakeRemoteMcp(name: 'Exa');
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Exa',
          url: 'https://mcp.exa.ai/mcp',
          apiKey: 'exa-key',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      final connected = await client.connect();
      expect(connected, isTrue);
      expect(client.isConnected, isTrue);

      // streamable 模式的 initialize 必须 POST 到 config URL 本身
      // （legacy 模式才会 POST 到 endpoint URL）。
      expect(fake.postUrls.first, equals('https://mcp.exa.ai/mcp'),
          reason: 'streamable HTTP 直接 POST 到配置的 URL');
      // 无请求头配置时携带 Bearer 鉴权 + streamable 协议头。
      final initHeaders = fake.postRequestHeaders.first;
      expect(initHeaders['Authorization'], 'Bearer exa-key');
      expect(initHeaders['Accept'], 'application/json, text/event-stream');
      expect(initHeaders['MCP-Protocol-Version'], '2024-11-05');

      final tools = await client.listTools();
      expect(tools.map((t) => t.name), contains('search'));

      final result = await client.callTool('search', {'q': 'x'});
      expect(result, equals('hello'));
    });

    test('application/json 裸响应体（无 SSE 帧）也能正常连接', () async {
      final fake = FakeRemoteMcp(name: 'Exa')..bareJson = true;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Exa',
          url: 'https://mcp.exa.ai/mcp',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      expect(await client.connect(), isTrue);
      expect(client.isConnected, isTrue);
    });

    test('跨多个 data: 行的响应（SSE 规范拼接）能正常连接', () async {
      final fake = FakeRemoteMcp(name: 'Exa')..splitData = true;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Exa',
          url: 'https://mcp.exa.ai/mcp',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      expect(await client.connect(), isTrue);
      expect(client.isConnected, isTrue);
    });

    test('mcp-session-id 被捕获并在后续请求中回传', () async {
      final fake = FakeRemoteMcp(name: 'Tavily', sessionId: 'sess-42');
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Tavily',
          url: 'https://mcp.tavily.com/mcp/',
          apiKey: 'tvly-key',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      await client.connect();
      await client.listTools();

      final lastHeaders = fake.postRequestHeaders.last;
      expect(lastHeaders['Mcp-Session-Id'], equals('sess-42'),
          reason: 'streamable HTTP 协议要求回传 Mcp-Session-Id');
    });

    test('工具返回 JSON-RPC error 帧时 callTool 报错', () async {
      final fake = FakeRemoteMcp(name: 'Exa')..callError = true;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Exa',
          url: 'https://mcp.exa.ai/mcp',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      await client.connect();
      final result = await client.callTool('search', {'q': 'x'});
      expect(result, contains('Error:'),
          reason: 'JSON-RPC error 应通过 callTool 的 Error 前缀暴露');
      expect(result, contains('Internal tool error'));
    });

    test('工具返回 isError: true 结果时 callTool 报错', () async {
      final fake = FakeRemoteMcp(name: 'Exa')..callIsError = true;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Exa',
          url: 'https://mcp.exa.ai/mcp',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      await client.connect();
      final result = await client.callTool('search', {'q': 'x'});
      expect(result, contains('Error:'));
      expect(result, contains('tool reported failure'));
    });

    test('streamable POST 失败(405)时回退 legacy SSE GET 连接', () async {
      final fake = FakeRemoteMcp(name: 'Jina')
        ..streamable = false; // POST → 405，仅支持 legacy SSE GET
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Jina',
          url: 'https://mcp.jina.ai/sse',
          apiKey: 'jina-key',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      final connected = await client.connect();
      expect(connected, isTrue);
      expect(client.isConnected, isTrue);

      // 确实先尝试过 streamable POST（记录在 405 抛出之前）……
      expect(fake.postUrls, contains('https://mcp.jina.ai/sse'));
      // ……legacy 模式下工具 POST 发往 endpoint URL（而非 config URL）。
      await client.listTools();
      expect(fake.postUrls.any((u) => u.contains('messages')), isTrue,
          reason: 'legacy SSE 模式应将消息 POST 到 endpoint 事件给出的 URL');
    });

    test('重连后旧 GET 流关闭不影响新连接（旧订阅已拆除）', () async {
      final fake = FakeRemoteMcp(name: 'Jina')..streamable = false;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Jina',
          url: 'https://mcp.jina.ai/sse',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      // 连接 #1（legacy）
      expect(await client.connect(), isTrue);

      // POST 失败 → 断开，但旧 GET 流仍保持打开
      fake.failLegacyPost = true;
      final result = await client.callTool('search', {'q': 'x'});
      expect(result, contains('Error:'));
      expect(client.isConnected, isFalse);

      // 服务器恢复 → 重连（连接 #2）
      fake.failLegacyPost = false;
      expect(await client.connect(), isTrue);
      expect(client.isConnected, isTrue);

      // 旧连接 #1 的 GET 流此刻才关闭：不得把健康的新连接标记为断开
      fake.closeLegacyController(0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.isConnected, isTrue,
          reason: '重连后旧订阅必须被拆除，其 onDone 不得影响新连接');
    });

    test('legacy endpoint POST 失败后标记断开，再次 connect 可重连', () async {
      final fake = FakeRemoteMcp(name: 'Jina')
        ..streamable = false
        ..failLegacyPost = true;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Jina',
          url: 'https://mcp.jina.ai/sse',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      expect(await client.connect(), isTrue);

      final result = await client.callTool('search', {'q': 'x'});
      expect(result, contains('Error:'));
      expect(client.isConnected, isFalse,
          reason: 'legacy POST 传输失败应标记断开，下次调用才会重连');

      // 服务器恢复后重连成功
      fake.failLegacyPost = false;
      expect(await client.connect(), isTrue);
      expect(client.isConnected, isTrue);
    });

    test('两种传输都失败时 connect 返回 false', () async {
      final fake = FakeRemoteMcp(name: 'Down')
        ..streamable = false
        ..legacy = false;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Down',
          url: 'https://example.com/mcp',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      final connected = await client.connect();
      expect(connected, isFalse);
      expect(client.isConnected, isFalse);
    });

    test('legacy GET 流关闭但未发 endpoint 时 connect 失败', () async {
      final fake = FakeRemoteMcp(name: 'Broken')
        ..streamable = false
        ..legacyNoEndpoint = true;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Broken',
          url: 'https://example.com/sse',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      final connected = await client.connect();
      expect(connected, isFalse);
    });

    test('connect 中途 dispose() 不崩溃、不泄漏，且返回 false', () async {
      final fake = FakeRemoteMcp(name: 'Hang')..hangPost = true;
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Hang',
          url: 'https://example.com/mcp',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(fake.dispose);

      final connectFuture = client.connect();
      // 等待连接开始（POST 已发出但无响应）
      await Future<void>.delayed(const Duration(milliseconds: 50));
      client.dispose();

      final connected = await connectFuture;
      expect(connected, isFalse);
      expect(client.isDisposed, isTrue);
    });

    test('并发调用同一服务器的多个工具不会串扰（Future.wait 场景）', () async {
      final fake = FakeRemoteMcp(name: 'Exa');
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Exa',
          url: 'https://mcp.exa.ai/mcp',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      expect(await client.connect(), isTrue);

      // 聊天服务对同一轮的工具调用使用 Future.wait 并发执行
      final results = await Future.wait([
        client.callTool('search', {'q': 'a'}),
        client.callTool('search', {'q': 'b'}),
        client.callTool('search', {'q': 'c'}),
      ]);
      expect(results, everyElement(equals('hello')), reason: '并发请求的响应不得被跨请求拼坏');
    });

    test('首次连接失败后再次 connect 可以成功（重连）', () async {
      final fake = FakeRemoteMcp(name: 'Exa')
        ..failStreamableTimes = 1
        ..legacy = false; // 首次 streamable 也失败 → 整体失败
      final client = McpClient(
        config: McpServerConfig.sse(
          name: 'Exa',
          url: 'https://mcp.exa.ai/mcp',
          apiKey: 'k',
        ),
        postLines: fake.postLines,
        sseConnectFn: fake.sseConnect,
        ssePostFn: fake.ssePost,
      );
      addTearDown(() {
        client.dispose();
        fake.dispose();
      });

      expect(await client.connect(), isFalse);
      expect(await client.connect(), isTrue);
      expect(client.isConnected, isTrue);
    });
  });
}
