import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_connector_http_client.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_ai_studio_webview_session_bridge.dart';
import 'package:stroom/services/llm_credential_store.dart';

void main() {
  final bridge = LlmAiStudioWebViewSessionBridge.instance;
  late _FakeWebViewDriver driver;

  setUp(() {
    bridge.resetForTest();
    driver = _FakeWebViewDriver();
  });

  tearDown(() => bridge.resetForTest());

  test(
    'default connector path uses the registered in-app AI Studio session',
    () async {
      bridge.attach(
        pageUrl: 'https://aistudio.google.com/app/prompts/new_chat',
        driver: driver,
      );
      final accounts = LlmAccountConnectorService(
        preferences: _MemoryPreferences(),
        credentialStore: _MemoryCredentials(),
      );
      final account = await accounts.saveAccount(
        LlmAccount(
          id: 'aistudio-webview',
          connectorType: 'aistudio',
          authType: 'relay',
          displayName: 'AI Studio session',
        ),
      );
      final client = LlmConnectorHttpClient(accountService: accounts);

      final response = await client.request(
        account: account,
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      );

      expect(driver.requests, hasLength(1));
      expect(
        driver.requests.single.uri.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent',
      );
      expect(
        driver.requests.single.headers.keys,
        containsAll(['Accept', 'Content-Type']),
      );
      expect(driver.requests.single.headers, isNot(contains('Authorization')));
      expect(response.statusCode, 200);
      expect(response.body, {'candidates': []});

      final secondAccount = await accounts.saveAccount(
        LlmAccount(
          id: 'aistudio-webview-second',
          connectorType: 'aistudio',
          authType: 'relay',
          displayName: 'Second AI Studio session',
        ),
      );
      await expectLater(
        client.request(
          account: secondAccount,
          modelId: 'gemini-3.1-pro',
          body: const {'contents': []},
        ),
        throwsA(isA<LlmConnectorTransportUnavailable>()),
      );
      expect(driver.requests, hasLength(1));
    },
  );

  test(
    'production WebView driver fetches in page without exporting session',
    () async {
      final controller = _FakeInAppWebViewController();
      final webViewDriver = LlmAiStudioInAppWebViewDriver(controller);
      final request = LlmPreparedNativeRequest(
        uri: Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent',
        ),
        method: 'POST',
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: const {'contents': []},
      );

      final response = await webViewDriver.execute(
        request,
        requestId: 'request-1',
      );

      expect(response.statusCode, 200);
      expect(utf8.decode(response.body!), '{"candidates":[]}');
      expect(controller.arguments['url'], request.uri.toString());
      expect(controller.arguments['body'], '{"contents":[]}');
      expect(controller.functionBody, contains("credentials: 'include'"));
      expect(controller.functionBody, contains("redirect: 'manual'"));
      expect(controller.functionBody, contains("cache: 'no-store'"));
      expect(controller.functionBody, isNot(contains('document.cookie')));
      expect(controller.functionBody, isNot(contains('localStorage')));
      expect(controller.removedHandlerName, controller.handlerName);
    },
  );

  test(
    'production WebView driver streams and aborts on consumer cancel',
    () async {
      final controller = _FakeInAppWebViewController()
        ..pauseStreamAfterStart = true;
      final webViewDriver = LlmAiStudioInAppWebViewDriver(controller);
      final request = LlmPreparedNativeRequest(
        uri: Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:streamGenerateContent?alt=sse',
        ),
        method: 'POST',
        headers: const {
          'Accept': 'text/event-stream',
          'Content-Type': 'application/json',
        },
        body: const {'contents': []},
      );

      final response = await webViewDriver.execute(
        request,
        requestId: 'stream-request',
      );
      final receivedChunk = Completer<void>();
      final chunks = <List<int>>[];
      final subscription = response.stream!.listen((chunk) {
        chunks.add(List<int>.from(chunk));
        if (!receivedChunk.isCompleted) receivedChunk.complete();
      });
      await controller.emitChunk('data: {"candidates":[]}\n\n');
      await receivedChunk.future;
      await subscription.cancel();

      expect(utf8.decode(chunks.single), 'data: {"candidates":[]}\n\n');
      expect(
        controller.evaluatedJavascript,
        contains('["stream-request"]?.abort()'),
      );
      expect(controller.removedHandlerName, controller.handlerName);
    },
  );

  test(
    'requires HTTPS AI Studio origin and rejects an off-host request',
    () async {
      expect(
        bridge.attach(
          pageUrl: 'http://aistudio.google.com/app',
          driver: driver,
        ),
        isNull,
      );
      expect(
        bridge.attach(
          pageUrl: 'https://accounts.google.com/signin',
          driver: driver,
        ),
        isNull,
      );
      expect(
        () => bridge.execute(
          'test-account',
          LlmPreparedNativeRequest(
            uri: Uri.parse('https://evil.example.test/generate'),
            method: 'POST',
            headers: const {'Content-Type': 'application/json'},
            body: const {'contents': []},
          ),
        ),
        throwsA(isA<LlmAiStudioWebViewBridgeException>()),
      );
      expect(driver.requests, isEmpty);
    },
  );

  test('maps an expired browser session to a safe re-login error', () async {
    bridge.attach(pageUrl: 'https://aistudio.google.com/', driver: driver);
    driver.response = LlmAiStudioWebViewResponse(statusCode: 401, headers: {});
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
    );
    final account = await accounts.saveAccount(
      LlmAccount(
        id: 'aistudio-expired',
        connectorType: 'aistudio',
        authType: 'relay',
        displayName: 'AI Studio session',
      ),
    );

    await expectLater(
      LlmConnectorHttpClient(accountService: accounts).request(
        account: account,
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      ),
      throwsA(
        isA<LlmConnectorAuthenticationRequired>().having(
          (error) => error.toString(),
          'safe message',
          isNot(contains('private')),
        ),
      ),
    );
  });

  test('maps WebView fetch failures to a generic request error', () async {
    final controller = _FakeInAppWebViewController()
      ..errorType = 'network_error';
    bridge.attach(
      pageUrl: 'https://aistudio.google.com/',
      driver: LlmAiStudioInAppWebViewDriver(controller),
    );
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
    );
    final account = await accounts.saveAccount(
      LlmAccount(
        id: 'aistudio-network-error',
        connectorType: 'aistudio',
        authType: 'relay',
        displayName: 'AI Studio session',
      ),
    );

    await expectLater(
      LlmConnectorHttpClient(accountService: accounts).request(
        account: account,
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      ),
      throwsA(isA<LlmConnectorHttpException>()),
    );
  });

  test('does not treat a Google API 403 as an expired browser session',
      () async {
    bridge.attach(pageUrl: 'https://aistudio.google.com/', driver: driver);
    driver.response = LlmAiStudioWebViewResponse(
      statusCode: 403,
      headers: const {},
    );
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
    );
    final account = await accounts.saveAccount(
      LlmAccount(
        id: 'aistudio-forbidden',
        connectorType: 'aistudio',
        authType: 'relay',
        displayName: 'AI Studio session',
      ),
    );

    await expectLater(
      LlmConnectorHttpClient(accountService: accounts).request(
        account: account,
        modelId: 'gemini-3.1-pro',
        body: const {'contents': []},
      ),
      throwsA(
        isA<LlmConnectorHttpException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test(
    'rejects API keys, cookies, and credentials at the bridge boundary',
    () async {
      bridge.attach(pageUrl: 'https://aistudio.google.com/', driver: driver);

      await expectLater(
        bridge.execute(
          'aistudio-account',
          LlmPreparedNativeRequest(
            uri: Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro:generateContent',
            ),
            method: 'POST',
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': 'must-not-cross-the-bridge',
            },
            body: const {'contents': []},
          ),
        ),
        throwsA(isA<LlmAiStudioWebViewBridgeException>()),
      );
      expect(driver.requests, isEmpty);
    },
  );

  test('streams response bytes and propagates consumer cancellation', () async {
    final source = StreamController<List<int>>();
    var sourceCancelled = false;
    source.onCancel = () {
      sourceCancelled = true;
    };
    driver.response = LlmAiStudioWebViewResponse(
      statusCode: 200,
      headers: const {
        'content-type': ['text/event-stream'],
      },
      stream: source.stream,
    );
    bridge.attach(pageUrl: 'https://aistudio.google.com/', driver: driver);
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
    );
    final account = await accounts.saveAccount(
      LlmAccount(
        id: 'aistudio-stream',
        connectorType: 'aistudio',
        authType: 'relay',
        displayName: 'AI Studio session',
      ),
    );
    final response =
        await LlmConnectorHttpClient(accountService: accounts).request(
      account: account,
      modelId: 'gemini-3.1-pro',
      body: const {'contents': []},
      stream: true,
    );
    final receivedChunk = Completer<void>();
    final chunks = <List<int>>[];
    final subscription = (response.body as Stream<List<int>>).listen((chunk) {
      chunks.add(List<int>.from(chunk));
      if (!receivedChunk.isCompleted) receivedChunk.complete();
    });
    source.add([1]);
    await receivedChunk.future;

    await subscription.cancel();

    expect(chunks, [
      [1],
    ]);
    expect(sourceCancelled, isTrue);
    await response.completedObservation;
  });

  test('maps an in-flight WebView cancellation to request cancellation',
      () async {
    final source = StreamController<List<int>>();
    driver.response = LlmAiStudioWebViewResponse(
      statusCode: 200,
      headers: const {
        'content-type': ['text/event-stream'],
      },
      stream: source.stream,
    );
    bridge.attach(pageUrl: 'https://aistudio.google.com/', driver: driver);
    final accounts = LlmAccountConnectorService(
      preferences: _MemoryPreferences(),
      credentialStore: _MemoryCredentials(),
    );
    final account = await accounts.saveAccount(
      LlmAccount(
        id: 'aistudio-stream-cancelled',
        connectorType: 'aistudio',
        authType: 'relay',
        displayName: 'AI Studio session',
      ),
    );
    final response = await LlmConnectorHttpClient(
      accountService: accounts,
    ).request(
      account: account,
      modelId: 'gemini-3.1-pro',
      body: const {'contents': []},
      stream: true,
    );
    final error = Completer<Object>();
    final subscription = (response.body as Stream<List<int>>).listen(
      (_) {},
      onError: (Object value) => error.complete(value),
    );
    source.addError(const LlmAiStudioWebViewRequestCancelled());

    expect(await error.future, isA<LlmConnectorRequestCancelled>());
    await subscription.cancel();
    await response.completedObservation;
  });
}

class _FakeWebViewDriver implements LlmAiStudioWebViewDriver {
  final List<LlmPreparedNativeRequest> requests = [];
  LlmAiStudioWebViewResponse response = LlmAiStudioWebViewResponse(
    statusCode: 200,
    headers: const {
      'content-type': ['application/json'],
    },
    body: Uint8List.fromList(utf8.encode('{"candidates":[]}')),
  );
  int disposeCalls = 0;

  @override
  Future<LlmAiStudioWebViewResponse> execute(
    LlmPreparedNativeRequest request, {
    required String requestId,
    CancelToken? cancelToken,
  }) async {
    requests.add(request);
    return response;
  }

  @override
  void dispose() {
    disposeCalls++;
  }
}

class _FakeInAppWebViewController extends Fake
    implements InAppWebViewController {
  JavaScriptHandlerCallback? callback;
  Map<String, dynamic> arguments = const {};
  String functionBody = '';
  String? handlerName;
  String? removedHandlerName;
  String? evaluatedJavascript;
  bool pauseStreamAfterStart = false;
  String? errorType;
  Completer<CallAsyncJavaScriptResult?>? pendingCallResult;

  @override
  Future<WebUri?> getUrl() async => WebUri('https://aistudio.google.com/');

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    evaluatedJavascript = source;
    final pending = pendingCallResult;
    if (pending != null && !pending.isCompleted) {
      pending.complete(CallAsyncJavaScriptResult(value: true));
    }
    return null;
  }

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {
    this.handlerName = handlerName;
    this.callback = callback;
  }

  @override
  JavaScriptHandlerCallback? removeJavaScriptHandler({
    required String handlerName,
  }) {
    removedHandlerName = handlerName;
    final removed = callback;
    callback = null;
    return removed;
  }

  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript({
    required String functionBody,
    Map<String, dynamic> arguments = const <String, dynamic>{},
    ContentWorld? contentWorld,
  }) async {
    this.functionBody = functionBody;
    this.arguments = arguments;
    final error = errorType;
    if (error != null) {
      await callback!([arguments['requestId'], error]);
      return CallAsyncJavaScriptResult(value: false);
    }
    if (arguments['stream'] == true) {
      await callback!([
        arguments['requestId'],
        'start',
        200,
        'text/event-stream',
      ]);
      if (pauseStreamAfterStart) {
        pendingCallResult = Completer<CallAsyncJavaScriptResult?>();
        return pendingCallResult!.future;
      }
      await emitChunk('data: {"candidates":[]}\n\n');
      await callback!([arguments['requestId'], 'end']);
      return CallAsyncJavaScriptResult(value: true);
    }
    await callback!([
      arguments['requestId'],
      'complete',
      200,
      'application/json',
      '{"candidates":[]}',
    ]);
    return CallAsyncJavaScriptResult(value: true);
  }

  Future<void> emitChunk(String chunk) async {
    await callback!([arguments['requestId'], 'chunk', chunk]);
  }
}

class _MemoryPreferences implements LlmAccountPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

class _MemoryCredentials implements LlmCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String secret) async {
    values[reference] = secret;
  }
}
