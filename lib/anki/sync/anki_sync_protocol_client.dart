import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Anki's supported legacy multipart protocol. Version 10 remains accepted by
/// current Anki sync servers and maps collection schema 11 to schema 11.
/// Keeping this adapter separate from the old JSON/sync-v1 engine prevents
/// requests for one destination from being sent with another protocol.
class AnkiSyncProtocolClient {
  static final Uri ankiWebSyncRoot = Uri.parse(
    'https://sync.ankiweb.net/sync/',
  );
  static const int protocolVersion = 10;
  static const int maxCollectionDownloadBytes = 512 * 1024 * 1024;
  static const int maxInMemoryCollectionBytes = 64 * 1024 * 1024;
  static const int maxMediaArchiveBytes = 128 * 1024 * 1024;
  static const Duration _timeout = Duration(seconds: 45);

  final Uri _configuredSyncRoot;
  Uri? _redirectedSyncRoot;
  final http.Client _client;
  final bool _ownsClient;
  final bool _allowAnkiWebMetaRedirect;
  final String _sessionKey;
  final Duration _requestTimeout;
  String? _hostKey;
  bool _closed = false;

  Uri get syncRoot => _redirectedSyncRoot ?? _configuredSyncRoot;

  AnkiSyncProtocolClient._({
    required Uri syncRoot,
    required http.Client client,
    required bool ownsClient,
    required String sessionKey,
    required Duration requestTimeout,
    required bool allowAnkiWebMetaRedirect,
    String? hostKey,
  })  : _configuredSyncRoot = syncRoot,
        _client = client,
        _ownsClient = ownsClient,
        _allowAnkiWebMetaRedirect = allowAnkiWebMetaRedirect,
        _sessionKey = sessionKey,
        _requestTimeout = requestTimeout,
        _hostKey = hostKey;

  factory AnkiSyncProtocolClient.ankiWeb({
    http.Client? client,
    String? hostKey,
    Duration requestTimeout = _timeout,
  }) =>
      AnkiSyncProtocolClient._(
        syncRoot: ankiWebSyncRoot,
        client: client ?? http.Client(),
        ownsClient: client == null,
        sessionKey: _newSessionKey(),
        requestTimeout: requestTimeout,
        allowAnkiWebMetaRedirect: true,
        hostKey: hostKey,
      );

  factory AnkiSyncProtocolClient.selfHosted({
    required String endpoint,
    String certificate = '',
    http.Client? client,
    String? hostKey,
    Duration requestTimeout = _timeout,
  }) {
    final root = _selfHostedRoot(endpoint);
    if (client != null) {
      return AnkiSyncProtocolClient._(
        syncRoot: root,
        client: client,
        ownsClient: false,
        sessionKey: _newSessionKey(),
        requestTimeout: requestTimeout,
        allowAnkiWebMetaRedirect: false,
        hostKey: hostKey,
      );
    }

    final context = SecurityContext(withTrustedRoots: true);
    if (certificate.trim().isNotEmpty) {
      context.setTrustedCertificatesBytes(utf8.encode(certificate.trim()));
    }
    return AnkiSyncProtocolClient._(
      syncRoot: root,
      client: IOClient(HttpClient(context: context)),
      ownsClient: true,
      sessionKey: _newSessionKey(),
      requestTimeout: requestTimeout,
      allowAnkiWebMetaRedirect: false,
      hostKey: hostKey,
    );
  }

  String? get hostKey => _hostKey;
  bool get isAuthenticated => _hostKey?.isNotEmpty == true;

  /// Stable local marker for the authenticated account and server. The host
  /// key is hashed so credentials are never stored in the collection file.
  String get destinationIdentity {
    _requireAuthenticated();
    final keyHash = sha256.convert(utf8.encode(_hostKey!));
    return '${_configuredSyncRoot.toString()}#$keyHash';
  }

  /// Exchange account credentials for an Anki sync host key.
  /// Passwords are used only to build this request and are never retained.
  Future<String> login(String username, String password) async {
    final response = await _send(
      'hostKey',
      utf8.encode(jsonEncode({'u': username.trim(), 'p': password})),
      hostKey: '',
    );
    final decoded = _decodeJson(response, '登录响应无法解析');
    final key = decoded['key'];
    if (key is! String || key.isEmpty) {
      throw const AnkiSyncException('服务器响应中没有同步密钥');
    }
    _hostKey = key;
    return key;
  }

  /// Read-only collection metadata exchange. This does not change either
  /// collection and is safe to use to verify connectivity after login.
  Future<AnkiRemoteMeta> checkStatus() async {
    _requireAuthenticated();
    final response = await _send(
      'meta',
      utf8.encode(jsonEncode({'v': protocolVersion, 'cv': 'stroom:0.4.47'})),
    );
    final json = _decodeJson(response, '同步状态响应无法解析');
    return AnkiRemoteMeta.fromJson(json);
  }

  /// One-way collection replacement. Gzip is staged on disk so large local
  /// collections do not need to exist in memory alongside a compressed copy.
  Future<void> uploadCollectionFile(File collectionFile) async {
    _requireAuthenticated();
    Directory? stagingDirectory;
    try {
      stagingDirectory = await collectionFile.parent.createTemp(
        '.anki-sync-upload-',
      );
      final compressedFile = File('${stagingDirectory.path}/collection.gz');
      await collectionFile
          .openRead()
          .transform(gzip.encoder)
          .pipe(compressedFile.openWrite());

      final response = await _send(
        'upload',
        const <int>[],
        precompressedPayloadFile: compressedFile,
      );
      if (utf8.decode(response, allowMalformed: true).trim() != 'OK') {
        throw const AnkiSyncException('服务器没有接受 collection 上传');
      }
    } on AnkiSyncException {
      rethrow;
    } catch (_) {
      throw const AnkiSyncException('无法读取本地 collection 上传文件');
    } finally {
      if (stagingDirectory != null && await stagingDirectory.exists()) {
        try {
          await stagingDirectory.delete(recursive: true);
        } catch (_) {
          throw const AnkiSyncException('无法清理 collection 上传暂存文件');
        }
      }
    }
  }

  /// Downloads the remote collection bytes. The caller must validate them,
  /// back up the local collection, and only then replace the local database.
  /// This compatibility helper is limited to small collections; full syncs
  /// should use [downloadCollectionToFile] to avoid buffering the collection.
  Future<List<int>> downloadCollection() async {
    _requireAuthenticated();
    return _send(
      'download',
      utf8.encode('{}'),
      maxResponseBytes: maxInMemoryCollectionBytes,
      maxResponseExceededMessage: 'collection 内存下载超过 64 MB',
    );
  }

  /// Streams a full collection to disk with a bounded response size.
  Future<void> downloadCollectionToFile(File destination) async {
    _requireAuthenticated();
    await _send(
      'download',
      utf8.encode('{}'),
      maxResponseBytes: maxCollectionDownloadBytes,
      responseFile: destination,
      maxResponseExceededMessage: 'collection 下载超过 512 MB',
    );
  }

  /// Send a JSON request to a collection or media sync endpoint. Media
  /// endpoints return `{data, err}` envelopes; callers can request that they
  /// be unwrapped by [requestMediaJson].
  Future<dynamic> requestJson(String method, Object payload) async {
    _requireAuthenticated();
    final bytes = await _send(method, utf8.encode(jsonEncode(payload)));
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const AnkiSyncException('同步服务器响应无法解析');
    }
  }

  Future<dynamic> requestMediaJson(String method, Object payload) async {
    final envelope = await requestJson('../msync/$method', payload);
    if (envelope is! Map<String, dynamic>) {
      throw const AnkiSyncException('媒体同步服务器响应无法解析');
    }
    final error = envelope['err'];
    if (error is String && error.isNotEmpty) {
      throw const AnkiSyncException('媒体同步服务器拒绝了请求');
    }
    final data = envelope['data'];
    if (data == null) throw const AnkiSyncException('媒体同步服务器响应无法解析');
    return data;
  }

  Future<List<int>> requestMediaData(
    String method,
    Object payload, {
    int? maxResponseBytes,
  }) async {
    _requireAuthenticated();
    return _send(
      '../msync/$method',
      utf8.encode(jsonEncode(payload)),
      maxResponseBytes: maxResponseBytes,
    );
  }

  /// Media upload requests carry an already-compressed ZIP archive, so the
  /// multipart wrapper must use `c=0` and must not gzip the ZIP a second time.
  Future<Map<String, dynamic>> uploadMediaZip(List<int> zipBytes) async {
    _requireAuthenticated();
    final bytes = await _send(
      '../msync/uploadChanges',
      zipBytes,
      compress: false,
    );
    final envelope = _decodeJson(bytes, '媒体上传响应无法解析');
    final error = envelope['err'];
    if (error is String && error.isNotEmpty) {
      throw const AnkiSyncException('媒体同步服务器拒绝了上传');
    }
    final data = envelope['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is List && data.length == 2 && data[0] is num && data[1] is num) {
      // Anki's v10 server serializes MediaUploadResponse as a two-value tuple.
      return {
        'processed': (data[0] as num).toInt(),
        'currentUsn': (data[1] as num).toInt(),
      };
    }
    throw const AnkiSyncException('媒体上传响应无法解析');
  }

  Future<List<int>> downloadMediaZip(List<String> filenames) async {
    return requestMediaData(
        'downloadFiles',
        {
          'files': filenames,
        },
        maxResponseBytes: maxMediaArchiveBytes);
  }

  Future<List<int>> _send(
    String method,
    List<int> payload, {
    String? hostKey,
    bool compress = true,
    File? precompressedPayloadFile,
    bool allowMetaRedirect = true,
    int? maxResponseBytes,
    File? responseFile,
    String maxResponseExceededMessage = '媒体 ZIP 压缩数据超过 128 MB',
  }) async {
    if (_closed) throw const AnkiSyncException('同步连接已关闭');
    final abortRequest = Completer<void>();
    var requestTimedOut = false;
    Timer? requestTimer;
    void resetRequestTimer() {
      requestTimer?.cancel();
      requestTimer = Timer(_requestTimeout, () {
        requestTimedOut = true;
        if (!abortRequest.isCompleted) abortRequest.complete();
      });
    }

    final request = _ProgressAwareMultipartRequest(
      _endpointFor(method),
      abortTrigger: abortRequest.future,
      onProgress: resetRequestTimer,
    )
      ..followRedirects = false
      ..fields['c'] = compress ? '1' : '0'
      ..fields['k'] = hostKey ?? _hostKey ?? ''
      ..fields['s'] = _sessionKey;
    final requestBytes = precompressedPayloadFile == null
        ? (compress ? gzip.encode(payload) : payload)
        : null;
    final requestLength = precompressedPayloadFile == null
        ? requestBytes!.length
        : await precompressedPayloadFile.length();
    request.files.add(
      http.MultipartFile(
        'data',
        precompressedPayloadFile?.openRead() ?? _chunkedBytes(requestBytes!),
        requestLength,
        filename: 'data',
      ),
    );

    try {
      resetRequestTimer();
      final streamed = await Future.any<http.StreamedResponse>([
        _client.send(request),
        abortRequest.future.then<http.StreamedResponse>((_) {
          throw TimeoutException('HTTP request timed out', _requestTimeout);
        }),
      ]);
      requestTimer?.cancel();
      if (streamed.statusCode != HttpStatus.ok) {
        await streamed.stream.listen((_) {}).cancel();
        if (streamed.statusCode == HttpStatus.permanentRedirect &&
            method == 'meta' &&
            allowMetaRedirect &&
            _allowAnkiWebMetaRedirect) {
          final redirectedRoot = _validatedAnkiWebRedirectRoot(
            streamed.headers['location'],
          );
          if (redirectedRoot == null) {
            throw const AnkiSyncException('AnkiWeb 同步重定向地址无效');
          }
          _redirectedSyncRoot = redirectedRoot;
          return await _send(
            method,
            payload,
            hostKey: hostKey,
            compress: compress,
            precompressedPayloadFile: precompressedPayloadFile,
            allowMetaRedirect: false,
            maxResponseBytes: maxResponseBytes,
            responseFile: responseFile,
            maxResponseExceededMessage: maxResponseExceededMessage,
          );
        }
        throw AnkiSyncException(_safeHttpError(streamed.statusCode));
      }
      return await _readResponse(
        streamed,
        maxBytes: maxResponseBytes,
        outputFile: responseFile,
        maxBytesExceededMessage: maxResponseExceededMessage,
      );
    } on AnkiSyncException {
      rethrow;
    } on TimeoutException {
      throw const AnkiSyncException('连接超时，请检查网络和服务器地址');
    } on http.RequestAbortedException {
      if (requestTimedOut) {
        throw const AnkiSyncException('连接超时，请检查网络和服务器地址');
      }
      throw const AnkiSyncException('同步请求失败，请检查服务器和网络');
    } on HandshakeException {
      throw const AnkiSyncException('TLS 证书验证失败');
    } on SocketException {
      throw const AnkiSyncException('无法连接到同步服务器');
    } catch (_) {
      // Never include request/response bodies here; authentication responses
      // may contain information that should not be placed in logs or UI.
      throw const AnkiSyncException('同步请求失败，请检查服务器和网络');
    } finally {
      requestTimer?.cancel();
    }
  }

  static Stream<List<int>> _chunkedBytes(List<int> bytes) async* {
    const chunkSize = 64 * 1024;
    for (var start = 0; start < bytes.length; start += chunkSize) {
      final end = min(start + chunkSize, bytes.length);
      yield bytes.sublist(start, end);
    }
  }

  Future<List<int>> _readResponse(
    http.StreamedResponse response, {
    int? maxBytes,
    File? outputFile,
    String maxBytesExceededMessage = '媒体 ZIP 压缩数据超过 128 MB',
  }) async {
    final declaredLength = response.contentLength;
    if (maxBytes != null &&
        declaredLength != null &&
        declaredLength > maxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw AnkiSyncException(maxBytesExceededMessage);
    }

    final output = outputFile == null ? BytesBuilder(copy: false) : null;
    final fileSink = outputFile?.openWrite();
    final completed = Completer<void>();
    StreamSubscription<List<int>>? subscription;
    Timer? timeout;
    var responseEnded = false;
    var length = 0;

    void resetResponseTimeout() {
      timeout?.cancel();
      timeout = Timer(
        _requestTimeout,
        () => completed.completeError(
          TimeoutException('HTTP response timed out', _requestTimeout),
        ),
      );
    }

    try {
      // Bound stalled responses while allowing large media files to stream for
      // longer than the connection timeout as long as bytes keep arriving.
      resetResponseTimeout();
      subscription = response.stream.listen(
        (chunk) {
          if (completed.isCompleted) return;
          if (maxBytes != null && chunk.length > maxBytes - length) {
            completed.completeError(AnkiSyncException(maxBytesExceededMessage));
            return;
          }
          length += chunk.length;
          if (fileSink == null) {
            output!.add(chunk);
          } else {
            fileSink.add(chunk);
          }
          if (chunk.isNotEmpty) resetResponseTimeout();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completed.isCompleted) {
            completed.completeError(error, stackTrace);
          }
        },
        onDone: () {
          responseEnded = true;
          if (!completed.isCompleted) completed.complete();
        },
        cancelOnError: true,
      );

      await completed.future;
      await fileSink?.flush();
      return output?.takeBytes() ?? const <int>[];
    } finally {
      timeout?.cancel();
      if (!responseEnded) await subscription?.cancel();
      await fileSink?.close();
    }
  }

  Uri _endpointFor(String method) {
    final isMediaEndpoint = method.startsWith('../msync/');
    final endpointName =
        isMediaEndpoint ? method.substring('../msync/'.length) : method;
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(endpointName)) {
      throw const AnkiSyncException('同步请求路径无效');
    }

    final endpoint = syncRoot.resolve(method);
    final endpointRoot =
        isMediaEndpoint ? syncRoot.resolve('../msync/') : syncRoot;
    if (endpoint.origin != syncRoot.origin ||
        !endpoint.path.startsWith(endpointRoot.path)) {
      throw const AnkiSyncException('同步请求路径无效');
    }
    return endpoint;
  }

  static Uri? _validatedAnkiWebRedirectRoot(String? location) {
    if (location == null || location.trim().isEmpty) return null;
    final uri = Uri.tryParse(location.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port != 443 ||
        !RegExp(r'^sync(?:[0-9]+)?\.ankiweb\.net$')
            .hasMatch(uri.host.toLowerCase()) ||
        !const ['', '/', '/sync', '/sync/'].contains(uri.path)) {
      return null;
    }
    return uri.replace(path: '/sync/');
  }

  Map<String, dynamic> _decodeJson(List<int> bytes, String message) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Return a generic message instead of rendering raw server content.
    }
    throw AnkiSyncException(message);
  }

  void _requireAuthenticated() {
    if (!isAuthenticated) throw const AnkiSyncException('请先登录同步账户');
  }

  void close() {
    _closed = true;
    if (_ownsClient) _client.close();
  }

  static Uri _selfHostedRoot(String endpoint) {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const AnkiSyncException('请输入有效的 HTTP 或 HTTPS 服务器地址');
    }
    final host = uri.host.toLowerCase();
    final address = InternetAddress.tryParse(host);
    final isLoopback = host == 'localhost' ||
        host.endsWith('.localhost') ||
        address?.isLoopback == true;
    if (uri.scheme == 'http' && !isLoopback) {
      throw const AnkiSyncException('自建远程服务器必须使用 HTTPS');
    }
    var path = uri.path;
    if (path.endsWith('/sync/')) {
      // already a collection sync root
    } else if (path.endsWith('/sync')) {
      path = '$path/';
    } else {
      if (!path.endsWith('/')) path = '$path/';
      path = '${path}sync/';
    }
    return uri.replace(
      userInfo: '',
      path: path,
      queryParameters: const <String, String>{},
      fragment: '',
    );
  }

  static String _safeHttpError(int statusCode) {
    switch (statusCode) {
      case 400:
      case 401:
      case 403:
        return '登录失败或服务器拒绝了请求 (HTTP $statusCode)';
      case 404:
        return '找不到同步接口，请检查服务器地址 (HTTP 404)';
      default:
        return '同步服务器返回 HTTP $statusCode';
    }
  }

  static String _newSessionKey() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(20, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }
}

class AnkiRemoteMeta {
  final int modified;
  final int schema;
  final int usn;
  final int serverTime;
  final String message;
  final bool shouldContinue;
  final int hostNumber;
  final bool isEmpty;
  final int mediaUsn;

  const AnkiRemoteMeta({
    required this.modified,
    required this.schema,
    required this.usn,
    required this.serverTime,
    required this.message,
    required this.shouldContinue,
    required this.hostNumber,
    required this.isEmpty,
    required this.mediaUsn,
  });

  factory AnkiRemoteMeta.fromJson(Map<String, dynamic> json) {
    return AnkiRemoteMeta(
      modified: _requiredInt(json, 'mod'),
      schema: _requiredInt(json, 'scm'),
      usn: _requiredInt(json, 'usn'),
      serverTime: _requiredInt(json, 'ts'),
      message: _requiredString(json, 'msg'),
      shouldContinue: _requiredBool(json, 'cont'),
      hostNumber: _requiredInt(json, 'hostNum'),
      isEmpty: _requiredBool(json, 'empty'),
      mediaUsn: _requiredInt(json, 'media_usn'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) return value;
  throw const AnkiSyncException('同步状态响应无效');
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String) return value;
  throw const AnkiSyncException('同步状态响应无效');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) return value;
  throw const AnkiSyncException('同步状态响应无效');
}

class AnkiSyncException implements Exception {
  final String message;
  const AnkiSyncException(this.message);

  @override
  String toString() => message;
}

class _ProgressAwareMultipartRequest extends http.MultipartRequest
    with http.Abortable {
  @override
  final Future<void>? abortTrigger;
  final void Function() onProgress;

  _ProgressAwareMultipartRequest(
    Uri url, {
    required this.abortTrigger,
    required this.onProgress,
  }) : super('POST', url);

  @override
  http.ByteStream finalize() {
    final body = super.finalize();
    return http.ByteStream(
      body.map((chunk) {
        onProgress();
        return chunk;
      }),
    );
  }
}
