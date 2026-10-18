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
  static const int maxMediaArchiveBytes = 128 * 1024 * 1024;
  static const Duration _timeout = Duration(seconds: 45);

  final Uri syncRoot;
  final http.Client _client;
  final bool _ownsClient;
  final String _sessionKey;
  String? _hostKey;
  bool _closed = false;

  AnkiSyncProtocolClient._({
    required this.syncRoot,
    required http.Client client,
    required bool ownsClient,
    required String sessionKey,
    String? hostKey,
  })  : _client = client,
        _ownsClient = ownsClient,
        _sessionKey = sessionKey,
        _hostKey = hostKey;

  factory AnkiSyncProtocolClient.ankiWeb({
    http.Client? client,
    String? hostKey,
  }) =>
      AnkiSyncProtocolClient._(
        syncRoot: ankiWebSyncRoot,
        client: client ?? http.Client(),
        ownsClient: client == null,
        sessionKey: _newSessionKey(),
        hostKey: hostKey,
      );

  factory AnkiSyncProtocolClient.selfHosted({
    required String endpoint,
    String certificate = '',
    http.Client? client,
    String? hostKey,
  }) {
    final root = _selfHostedRoot(endpoint);
    if (client != null) {
      return AnkiSyncProtocolClient._(
        syncRoot: root,
        client: client,
        ownsClient: false,
        sessionKey: _newSessionKey(),
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
    return '${syncRoot.toString()}#$keyHash';
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

  /// One-way collection replacement. Callers must show an explicit
  /// destructive-action confirmation and retain a local backup beforehand.
  Future<void> uploadCollection(List<int> collectionBytes) async {
    _requireAuthenticated();
    final response = await _send('upload', collectionBytes);
    if (utf8.decode(response, allowMalformed: true).trim() != 'OK') {
      throw const AnkiSyncException('服务器没有接受 collection 上传');
    }
  }

  /// Downloads the remote collection bytes. The caller must validate them,
  /// back up the local collection, and only then replace the local database.
  Future<List<int>> downloadCollection() async {
    _requireAuthenticated();
    return _send('download', utf8.encode('{}'));
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
      {'files': filenames},
      maxResponseBytes: maxMediaArchiveBytes,
    );
  }

  Future<List<int>> _send(
    String method,
    List<int> payload, {
    String? hostKey,
    bool compress = true,
    int? maxResponseBytes,
  }) async {
    if (_closed) throw const AnkiSyncException('同步连接已关闭');
    final request = http.MultipartRequest('POST', _endpointFor(method))
      ..fields['c'] = compress ? '1' : '0'
      ..fields['k'] = hostKey ?? _hostKey ?? ''
      ..fields['s'] = _sessionKey;
    request.files.add(
      http.MultipartFile.fromBytes(
        'data',
        compress ? gzip.encode(payload) : payload,
        filename: 'data',
      ),
    );

    try {
      final streamed = await _client.send(request).timeout(_timeout);
      if (streamed.statusCode != HttpStatus.ok) {
        await streamed.stream.listen((_) {}).cancel();
        throw AnkiSyncException(_safeHttpError(streamed.statusCode));
      }
      if (maxResponseBytes != null) {
        return await _readResponseWithLimit(streamed, maxResponseBytes);
      }
      final response = await http.Response.fromStream(streamed).timeout(
        _timeout,
      );
      return response.bodyBytes;
    } on AnkiSyncException {
      rethrow;
    } on TimeoutException {
      throw const AnkiSyncException('连接超时，请检查网络和服务器地址');
    } on HandshakeException {
      throw const AnkiSyncException('TLS 证书验证失败');
    } on SocketException {
      throw const AnkiSyncException('无法连接到同步服务器');
    } catch (_) {
      // Never include request/response bodies here; authentication responses
      // may contain information that should not be placed in logs or UI.
      throw const AnkiSyncException('同步请求失败，请检查服务器和网络');
    }
  }

  Future<List<int>> _readResponseWithLimit(
    http.StreamedResponse response,
    int maxBytes,
  ) async {
    final declaredLength = response.contentLength;
    if (declaredLength != null && declaredLength > maxBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const AnkiSyncException('媒体 ZIP 压缩数据超过 128 MB');
    }

    final output = BytesBuilder(copy: false);
    final iterator = StreamIterator<List<int>>(response.stream);
    final deadline = DateTime.now().add(_timeout);
    var length = 0;
    try {
      while (true) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining.inMicroseconds <= 0) {
          throw TimeoutException('Media ZIP response timed out', _timeout);
        }
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (chunk.length > maxBytes - length) {
          throw const AnkiSyncException('媒体 ZIP 压缩数据超过 128 MB');
        }
        length += chunk.length;
        output.add(chunk);
      }
      return output.takeBytes();
    } finally {
      await iterator.cancel();
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

  factory AnkiRemoteMeta.fromJson(Map<String, dynamic> json) => AnkiRemoteMeta(
        modified: _asInt(json['mod']),
        schema: _asInt(json['scm']),
        usn: _asInt(json['usn']),
        serverTime: _asInt(json['ts']),
        message: json['msg'] as String? ?? '',
        shouldContinue: json['cont'] as bool? ?? true,
        hostNumber: _asInt(json['hostNum']),
        isEmpty: json['empty'] as bool? ?? false,
        mediaUsn: _asInt(json['media_usn']),
      );
}

int _asInt(Object? value) => value is num ? value.toInt() : 0;

class AnkiSyncException implements Exception {
  final String message;
  const AnkiSyncException(this.message);

  @override
  String toString() => message;
}
