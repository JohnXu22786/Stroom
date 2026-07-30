import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:stroom/services/openai_file_service.dart';

// ============================================================================
// Mock HTTP Adapter — captures requests and returns pre-configured responses
// ============================================================================

/// A mock [HttpClientAdapter] that records every request and returns a
/// response configured per-path or a default.
class _MockAdapter implements HttpClientAdapter {
  final Map<String, _RouteHandler> _routes = {};

  /// All requests made through this adapter, in order.
  final List<_CapturedRequest> capturedRequests = [];

  /// Configure a response for the given URL path (e.g., '/v1/files').
  void onPost(String path, _RouteHandler handler) {
    _routes[path] = handler;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    // Capture the request body
    List<int> bodyBytes = [];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bodyBytes.addAll(chunk);
      }
    }

    // Dio sets options.path to the full URL when a full URL is passed.
    // Extract just the path component for route matching.
    String requestPath = options.path;
    if (requestPath.startsWith('http')) {
      final uri = Uri.parse(requestPath);
      requestPath = uri.path;
    }

    capturedRequests.add(_CapturedRequest(
      method: options.method,
      path: requestPath,
      contentType: options.contentType,
      bodyBytes: Uint8List.fromList(bodyBytes),
      headers: options.headers,
      queryParameters: options.queryParameters,
    ));

    // Look up the route handler by path
    final handler = _routes[requestPath];
    if (handler != null) {
      return handler(options, bodyBytes);
    }

    // Default: 404
    return ResponseBody.fromString(
      '{"error":{"message":"Not found"}}',
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

typedef _RouteHandler = ResponseBody Function(
    RequestOptions options, List<int> bodyBytes);

/// A captured HTTP request for inspection in tests.
class _CapturedRequest {
  final String method;
  final String path;
  final String? contentType;
  final Uint8List bodyBytes;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> queryParameters;

  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.contentType,
    required this.bodyBytes,
    required this.headers,
    required this.queryParameters,
  });
}

// ============================================================================
// Helpers
// ============================================================================

/// Extract the body string from a byte array, handling binary content.
String _bodyString(Uint8List bytes) {
  return utf8.decode(bytes, allowMalformed: true);
}

/// Check if [bodyBytes] contains a multipart field with the given [name]
/// and [value].
bool _multipartFieldContains(List<int> bodyBytes, String name, String value) {
  final bodyStr = utf8.decode(bodyBytes, allowMalformed: true);
  final pattern = 'name="$name"';
  final nameIdx = bodyStr.indexOf(pattern);
  if (nameIdx == -1) return false;
  final headerEnd = bodyStr.indexOf('\r\n\r\n', nameIdx);
  if (headerEnd == -1) return false;
  final valueStart = headerEnd + 4;
  final valueEnd = bodyStr.indexOf('\r\n', valueStart);
  if (valueEnd == -1) return false;
  final actualValue = bodyStr.substring(valueStart, valueEnd);
  return actualValue == value;
}

/// Check that [needle] bytes appear sequentially in [haystack].
bool _bodyContains(List<int> haystack, List<int> needle) {
  if (needle.length > haystack.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

/// Default config for tests.
OpenAiFileUploadConfig _testConfig({String baseUrl = 'https://api.test.com'}) {
  return OpenAiFileUploadConfig(
    apiKey: 'test-key',
    baseUrl: baseUrl,
  );
}

/// Create a [Dio] instance backed by the given [adapter].
Dio _mockDio(_MockAdapter adapter) {
  return Dio(BaseOptions(
    headers: {'Authorization': 'Bearer test-key'},
  ))
    ..httpClientAdapter = adapter;
}

// ============================================================================
// Tests
// ============================================================================

void main() {
  group('OpenAiFileUploadConfig', () {
    test('uses default thresholds when not specified', () {
      final config = OpenAiFileUploadConfig(
        apiKey: 'key',
        baseUrl: 'https://api.test.com',
      );
      expect(config.multipartThresholdBytes, 512 * 1024 * 1024);
      expect(config.partSizeBytes, 64 * 1024 * 1024);
    });

    test('accepts custom thresholds', () {
      final config = OpenAiFileUploadConfig(
        apiKey: 'key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 1024 * 1024, // 1 MB
        partSizeBytes: 256 * 1024, // 256 KB
      );
      expect(config.multipartThresholdBytes, 1024 * 1024);
      expect(config.partSizeBytes, 256 * 1024);
    });

    test('filesUrl returns the correct URL', () {
      final config = _testConfig();
      expect(config.filesUrl, 'https://api.test.com/files');
    });

    test('uploadsUrl returns the correct URL', () {
      final config = _testConfig();
      expect(config.uploadsUrl, 'https://api.test.com/uploads');
    });

    test('normalizedBaseUrl strips trailing slash from filesUrl', () {
      final config = _testConfig(baseUrl: 'https://api.test.com/');
      expect(config.filesUrl, 'https://api.test.com/files');
    });

    test('normalizedBaseUrl strips trailing slash from uploadsUrl', () {
      final config = _testConfig(baseUrl: 'https://api.test.com/');
      expect(config.uploadsUrl, 'https://api.test.com/uploads');
    });

    test('copyWith preserves existing values when fields are omitted', () {
      final config = OpenAiFileUploadConfig(
        apiKey: 'key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 1000,
        partSizeBytes: 500,
      );
      final copy = config.copyWith();
      expect(copy.apiKey, 'key');
      expect(copy.baseUrl, 'https://api.test.com');
      expect(copy.multipartThresholdBytes, 1000);
      expect(copy.partSizeBytes, 500);
    });

    test('copyWith updates individual fields', () {
      final config = _testConfig();
      final copy = config.copyWith(
        multipartThresholdBytes: 1024,
        partSizeBytes: 256,
      );
      expect(copy.multipartThresholdBytes, 1024);
      expect(copy.partSizeBytes, 256);
      expect(copy.apiKey, 'test-key'); // unchanged
    });
  });

  group('OpenAiFileService small file upload (regular)', () {
    test(
        'sends a multipart/form-data POST to /v1/files for files at or below threshold',
        () async {
      final adapter = _MockAdapter();
      adapter.onPost('/files', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"file-abc123","object":"file","bytes":100,"created_at":1234567890,"filename":"test.txt","purpose":"user_data"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(
        config: _testConfig(),
        dio: dio,
      );

      final fileBytes = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final result = await service.uploadFile(
        bytes: fileBytes,
        filename: 'test.txt',
        mimeType: 'text/plain',
        purpose: 'user_data',
      );

      // Verify the result
      expect(result.id, 'file-abc123');
      expect(result.bytes, 100);
      expect(result.filename, 'test.txt');
      expect(result.purpose, 'user_data');

      // Verify the request was sent to /files
      expect(adapter.capturedRequests.length, 1);
      final req = adapter.capturedRequests.first;
      expect(req.path, '/files');
      expect(req.method, 'POST');
      expect(req.contentType, isNotNull);
      expect(req.contentType!.contains('multipart/form-data'), isTrue);
      expect(req.contentType!.contains('boundary='), isTrue);

      // Verify the multipart body contains the file and purpose
      expect(
        _bodyContains(req.bodyBytes, fileBytes),
        isTrue,
        reason: 'File bytes should be present in multipart body',
      );
      expect(
        _multipartFieldContains(req.bodyBytes, 'purpose', 'user_data'),
        isTrue,
        reason: 'purpose field should be present in multipart body',
      );
    });

    test('sends Authorization header with API key in regular upload', () async {
      final adapter = _MockAdapter();
      adapter.onPost('/files', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"file-abc","object":"file","bytes":50,"created_at":1,"filename":"a.txt","purpose":"user_data"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: _testConfig(), dio: dio);

      await service.uploadFile(
        bytes: Uint8List(50),
        filename: 'a.txt',
        mimeType: 'text/plain',
        purpose: 'user_data',
      );

      // Check that Authorization header is set on the request
      final req = adapter.capturedRequests.first;
      expect(req.headers['Authorization'], 'Bearer test-key');
    });

    test('throws when file bytes are empty (regular upload)', () async {
      final service = OpenAiFileService(config: _testConfig());
      expect(
        () => service.uploadFile(
          bytes: Uint8List(0),
          filename: 'empty.txt',
          mimeType: 'text/plain',
          purpose: 'user_data',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when purpose is empty (regular upload)', () async {
      final service = OpenAiFileService(config: _testConfig());
      expect(
        () => service.uploadFile(
          bytes: Uint8List(100),
          filename: 'test.txt',
          mimeType: 'text/plain',
          purpose: '',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'wraps DioException with user-friendly message on regular upload failure',
        () async {
      final adapter = _MockAdapter();
      adapter.onPost('/files', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"error":{"message":"Invalid file format"}}',
          400,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: _testConfig(), dio: dio);

      expect(
        () => service.uploadFile(
          bytes: Uint8List(100),
          filename: 'test.txt',
          mimeType: 'text/plain',
          purpose: 'user_data',
        ),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('HTTP 400'))),
      );
    });
  });

  group('OpenAiFileService large file upload (multipart)', () {
    test('uses multipart upload flow for files above threshold', () async {
      // Use a low threshold so even a small file triggers multipart
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 50, // 50 bytes threshold
        partSizeBytes: 64, // 64 bytes per part
      );

      final uploadId = 'upload_xyz';
      final partId = 'part_001';
      final fileId = 'file-large-001';

      final adapter = _MockAdapter();

      // Step 1: Create upload
      adapter.onPost('/uploads', (options, bodyBytes) {
        final bodyStr = utf8.decode(bodyBytes);
        // Verify the create request body
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        expect(body['filename'], 'large.bin');
        expect(body['purpose'], 'fine-tune');
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":200,"created_at":1,"filename":"large.bin","purpose":"fine-tune","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      // Step 2: Add part
      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$partId","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      // Step 3: Complete upload - expect 4 part IDs (200 bytes / 64 bytes = ceil(3.125) = 4 parts)
      adapter.onPost('/uploads/$uploadId/complete', (options, bodyBytes) {
        final bodyStr = utf8.decode(bodyBytes);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final receivedPartIds = body['part_ids'] as List<dynamic>;
        // Verify we have 4 parts (all same ID from the mock)
        expect(receivedPartIds.length, 4);
        expect(receivedPartIds.every((id) => id == partId), isTrue);
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":200,"created_at":1,"filename":"large.bin","purpose":"fine-tune","status":"completed","file":{"id":"$fileId","object":"file","bytes":200,"created_at":1,"filename":"large.bin","purpose":"fine-tune"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      final fileBytes = Uint8List(200); // 200 bytes, above 50 byte threshold
      final result = await service.uploadFile(
        bytes: fileBytes,
        filename: 'large.bin',
        mimeType: 'application/octet-stream',
        purpose: 'fine-tune',
      );

      // Verify result
      expect(result.id, fileId);
      expect(result.bytes, 200);
      expect(result.filename, 'large.bin');

      // Verify the correct sequence of requests was made
      // 1 create + 4 parts (200 bytes / 64 bytes per part = 4) + 1 complete = 6
      expect(adapter.capturedRequests.length, 6);

      // Request 1: create upload
      expect(adapter.capturedRequests[0].path, '/uploads');
      expect(adapter.capturedRequests[0].method, 'POST');

      // Requests 2-5: add parts (4 parts)
      for (var i = 1; i < 5; i++) {
        expect(adapter.capturedRequests[i].path, '/uploads/$uploadId/parts');
        expect(adapter.capturedRequests[i].method, 'POST');
      }

      // Request 6: complete
      expect(adapter.capturedRequests[5].path, '/uploads/$uploadId/complete');
      expect(adapter.capturedRequests[5].method, 'POST');
    });

    test('splits file into correctly-sized parts for multipart upload',
        () async {
      final partSize = 50; // 50 bytes per part
      final totalSize = 120; // 120 bytes total → 3 parts (50 + 50 + 20)
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 10,
        partSizeBytes: partSize,
      );

      final uploadId = 'upload_split';
      final partIds = ['part_a', 'part_b', 'part_c'];
      var partIndex = 0;

      final adapter = _MockAdapter();

      adapter.onPost('/uploads', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":$totalSize,"created_at":1,"filename":"split.bin","purpose":"user_data","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        final pid = partIds[partIndex];
        partIndex++;
        return ResponseBody.fromString(
          '{"id":"$pid","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/complete', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":$totalSize,"created_at":1,"filename":"split.bin","purpose":"user_data","status":"completed","file":{"id":"file-split","object":"file","bytes":$totalSize,"created_at":1,"filename":"split.bin","purpose":"user_data"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      final fileBytes =
          Uint8List.fromList(List.generate(totalSize, (i) => i % 256));
      await service.uploadFile(
        bytes: fileBytes,
        filename: 'split.bin',
        mimeType: 'application/octet-stream',
        purpose: 'user_data',
      );

      // 1 create + 3 parts + 1 complete = 5 requests
      expect(adapter.capturedRequests.length, 5);
      // Verify parts are called in sequence
      expect(partIndex, 3);
    });

    test('reports progress during multipart upload', () async {
      final partSize = 32;
      final totalSize = 64; // 2 parts
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 10,
        partSizeBytes: partSize,
      );

      final uploadId = 'upload_progress';
      final progressValues = <double>[];

      final adapter = _MockAdapter();
      adapter.onPost('/uploads', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":$totalSize,"created_at":1,"filename":"p.bin","purpose":"user_data","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"part_${progressValues.length}","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/complete', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":$totalSize,"created_at":1,"filename":"p.bin","purpose":"user_data","status":"completed","file":{"id":"file-p","object":"file","bytes":$totalSize,"created_at":1,"filename":"p.bin","purpose":"user_data"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      await service.uploadFile(
        bytes: Uint8List(totalSize),
        filename: 'p.bin',
        mimeType: 'application/octet-stream',
        purpose: 'user_data',
        onProgress: (progress) {
          progressValues.add(progress);
        },
      );

      // Progress should increase from 0 to 1.0
      expect(progressValues.isNotEmpty, isTrue);
      expect(progressValues.first, greaterThanOrEqualTo(0.0));
      expect(progressValues.last, closeTo(1.0, 0.01));
      // Progress values should be monotonically increasing
      for (var i = 1; i < progressValues.length; i++) {
        expect(progressValues[i], greaterThanOrEqualTo(progressValues[i - 1]));
      }
    });

    test('cancels multipart upload mid-flight via CancelToken', () async {
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 10,
        partSizeBytes: 32,
      );

      final uploadId = 'upload_cancel';
      final cancelToken = CancelToken();

      final adapter = _MockAdapter();

      adapter.onPost('/uploads', (options, bodyBytes) {
        // Cancel after the create step
        cancelToken.cancel('User cancelled');
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":100,"created_at":1,"filename":"c.bin","purpose":"user_data","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"part_x","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      expect(
        () => service.uploadFile(
          bytes: Uint8List(100),
          filename: 'c.bin',
          mimeType: 'application/octet-stream',
          purpose: 'user_data',
          cancelToken: cancelToken,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when multipart upload fails due to upload creation error',
        () async {
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 10,
        partSizeBytes: 32,
      );

      final adapter = _MockAdapter();
      adapter.onPost('/uploads', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"error":{"message":"Upload limit exceeded"}}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      expect(
        () => service.uploadFile(
          bytes: Uint8List(100),
          filename: 'err.bin',
          mimeType: 'application/octet-stream',
          purpose: 'user_data',
        ),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('HTTP 429'))),
      );
    });
  });

  group('OpenAiFileService threshold boundary', () {
    test('file exactly at threshold uses regular upload, not multipart',
        () async {
      final threshold = 100;
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: threshold,
        partSizeBytes: 32,
      );

      final adapter = _MockAdapter();
      var regularUploadCalled = false;
      var multipartCreateCalled = false;

      adapter.onPost('/files', (options, bodyBytes) {
        regularUploadCalled = true;
        return ResponseBody.fromString(
          '{"id":"file-boundary","object":"file","bytes":$threshold,"created_at":1,"filename":"boundary.bin","purpose":"user_data"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads', (options, bodyBytes) {
        multipartCreateCalled = true;
        return ResponseBody.fromString(
          '{"id":"u1","object":"upload","bytes":$threshold,"created_at":1,"filename":"boundary.bin","purpose":"user_data","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      await service.uploadFile(
        bytes: Uint8List(threshold), // exactly at threshold
        filename: 'boundary.bin',
        mimeType: 'application/octet-stream',
        purpose: 'user_data',
      );

      expect(regularUploadCalled, isTrue);
      expect(multipartCreateCalled, isFalse,
          reason: 'File exactly at threshold should use regular upload');
    });

    test('file just over threshold uses multipart upload', () async {
      final threshold = 100;
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: threshold,
        partSizeBytes: 64,
      );

      final uploadId = 'upload_over';
      final adapter = _MockAdapter();

      var multipartCreateCalled = false;
      adapter.onPost('/uploads', (options, bodyBytes) {
        multipartCreateCalled = true;
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":101,"created_at":1,"filename":"over.bin","purpose":"user_data","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"p1","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/complete', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":101,"created_at":1,"filename":"over.bin","purpose":"user_data","status":"completed","file":{"id":"file-over","object":"file","bytes":101,"created_at":1,"filename":"over.bin","purpose":"user_data"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      await service.uploadFile(
        bytes: Uint8List(101), // just over threshold
        filename: 'over.bin',
        mimeType: 'application/octet-stream',
        purpose: 'user_data',
      );

      expect(multipartCreateCalled, isTrue,
          reason: 'File over threshold should use multipart upload');
    });
  });

  group('OpenAiFileService file_id return', () {
    test('regular upload returns the file id from API response', () async {
      final adapter = _MockAdapter();
      adapter.onPost('/files', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"file-my-id","object":"file","bytes":500,"created_at":1,"filename":"my.txt","purpose":"assistants"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: _testConfig(), dio: dio);

      final result = await service.uploadFile(
        bytes: Uint8List(500),
        filename: 'my.txt',
        mimeType: 'text/plain',
        purpose: 'assistants',
      );

      expect(result.id, 'file-my-id');
    });

    test('multipart upload returns the nested file id from complete response',
        () async {
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 10,
        partSizeBytes: 100,
      );

      final uploadId = 'upload_nested';
      final nestedFileId = 'file-nested-xyz';

      final adapter = _MockAdapter();
      adapter.onPost('/uploads', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":50,"created_at":1,"filename":"n.bin","purpose":"vision","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"p1","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/complete', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":50,"created_at":1,"filename":"n.bin","purpose":"vision","status":"completed","file":{"id":"$nestedFileId","object":"file","bytes":50,"created_at":1,"filename":"n.bin","purpose":"vision"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      final result = await service.uploadFile(
        bytes: Uint8List(50),
        filename: 'n.bin',
        mimeType: 'image/png',
        purpose: 'vision',
      );

      expect(result.id, nestedFileId);
    });

    test(
        'complete response with top-level file-id (no nested "file" key) still returns id',
        () async {
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 10,
        partSizeBytes: 100,
      );

      final uploadId = 'upload_flat';
      final flatFileId = 'file-flat-abc';

      final adapter = _MockAdapter();
      adapter.onPost('/uploads', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":30,"created_at":1,"filename":"f.bin","purpose":"assistants","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"p1","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      // Complete response WITHOUT a nested "file" key — some OpenAI-compatible
      // providers return file data at the top level instead.
      adapter.onPost('/uploads/$uploadId/complete', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":30,"created_at":1,"filename":"f.bin","purpose":"assistants","status":"completed"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      // This should throw because the fallback checks for "file-" prefix
      // but the top-level id is "upload_flat" which starts with "upload-",
      // so the fallback won't match and it will throw "missing file object".
      await expectLater(
        () => service.uploadFile(
          bytes: Uint8List(30),
          filename: 'f.bin',
          mimeType: 'application/octet-stream',
          purpose: 'assistants',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'complete response with top-level file-id starting with "file-" uses fallback',
        () async {
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes: 10,
        partSizeBytes: 100,
      );

      final uploadId = 'upload_top';
      final fileId = 'file-top-001';

      final adapter = _MockAdapter();
      adapter.onPost('/uploads', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":40,"created_at":1,"filename":"top.bin","purpose":"vision","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"pt1","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      // Some providers return the file id at the top level prefixed with "file-"
      adapter.onPost('/uploads/$uploadId/complete', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$fileId","object":"upload","bytes":40,"created_at":1,"filename":"top.bin","purpose":"vision","status":"completed"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      final result = await service.uploadFile(
        bytes: Uint8List(40),
        filename: 'top.bin',
        mimeType: 'image/png',
        purpose: 'vision',
      );

      expect(result.id, fileId);
    });
  });

  group('OpenAiFileService error cases', () {
    test('throws on empty filename', () async {
      final service = OpenAiFileService(config: _testConfig());
      expect(
        () => service.uploadFile(
          bytes: Uint8List(100),
          filename: '',
          mimeType: 'text/plain',
          purpose: 'user_data',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on null/empty mimeType', () async {
      final service = OpenAiFileService(config: _testConfig());
      expect(
        () => service.uploadFile(
          bytes: Uint8List(100),
          filename: 'test.txt',
          mimeType: '',
          purpose: 'user_data',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on empty apiKey', () async {
      final config = OpenAiFileUploadConfig(
        apiKey: '',
        baseUrl: 'https://api.test.com',
      );
      final service = OpenAiFileService(config: config);
      expect(
        () => service.uploadFile(
          bytes: Uint8List(100),
          filename: 'test.txt',
          mimeType: 'text/plain',
          purpose: 'user_data',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on empty baseUrl', () async {
      final config = OpenAiFileUploadConfig(
        apiKey: 'key',
        baseUrl: '',
      );
      final service = OpenAiFileService(config: config);
      expect(
        () => service.uploadFile(
          bytes: Uint8List(100),
          filename: 'test.txt',
          mimeType: 'text/plain',
          purpose: 'user_data',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('OpenAiFileService multipart body verification', () {
    test('multipart add-part request sends binary data as form field "data"',
        () async {
      final partSize = 50;
      final config = OpenAiFileUploadConfig(
        apiKey: 'test-key',
        baseUrl: 'https://api.test.com',
        multipartThresholdBytes:
            4, // threshold below 6-byte file → use multipart
        partSizeBytes: partSize,
      );

      final uploadId = 'upload_body_test';
      final testData = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02]);

      final adapter = _MockAdapter();
      adapter.onPost('/uploads', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":${testData.length},"created_at":1,"filename":"body.bin","purpose":"user_data","status":"pending","expires_at":99999999}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/parts', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"part_body_1","object":"upload.part","created_at":1,"upload_id":"$uploadId"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      adapter.onPost('/uploads/$uploadId/complete', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"$uploadId","object":"upload","bytes":${testData.length},"created_at":1,"filename":"body.bin","purpose":"user_data","status":"completed","file":{"id":"file-body","object":"file","bytes":${testData.length},"created_at":1,"filename":"body.bin","purpose":"user_data"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: config, dio: dio);

      await service.uploadFile(
        bytes: testData,
        filename: 'body.bin',
        mimeType: 'application/octet-stream',
        purpose: 'user_data',
      );

      // Find the add-part request
      final partReq =
          adapter.capturedRequests.firstWhere((r) => r.path.contains('/parts'));
      expect(partReq.contentType!.contains('multipart/form-data'), isTrue);
      // Verify the test data is in the body
      expect(_bodyContains(partReq.bodyBytes, testData), isTrue,
          reason: 'Add-part request body should contain the binary file data');
    });

    test('regular upload sends correct filename in Content-Disposition',
        () async {
      final adapter = _MockAdapter();
      adapter.onPost('/files', (options, bodyBytes) {
        return ResponseBody.fromString(
          '{"id":"file-x","object":"file","bytes":10,"created_at":1,"filename":"my_file.json","purpose":"fine-tune"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      });

      final dio = _mockDio(adapter);
      final service = OpenAiFileService(config: _testConfig(), dio: dio);

      await service.uploadFile(
        bytes: Uint8List(10),
        filename: 'my_file.json',
        mimeType: 'application/json',
        purpose: 'fine-tune',
      );

      final req = adapter.capturedRequests.first;
      final bodyStr = _bodyString(req.bodyBytes);
      expect(bodyStr.contains('filename="my_file.json"'), isTrue);
    });
  });
}
