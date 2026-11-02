import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'devin_cli_acp_permissions_stub.dart'
    if (dart.library.ffi) 'devin_cli_acp_permissions_ffi.dart'
    as permissions;

/// The only Devin CLI commands Stroom starts for this account mode.
///
/// The executable must have an explicit account approval and a pinned content
/// digest. Account settings cannot supply a shell fragment or CLI argument.
class DevinCliAcpLaunch {
  static const fixedExecutable = 'devin';
  static const acpArguments = ['acp'];
  static const loginArguments = ['auth', 'login'];
  static const statusArguments = ['auth', 'status'];
  static const logoutArguments = ['auth', 'logout'];

  final String executablePath;
  final String executableSha256;
  final List<String> arguments;
  final Map<String, String> environment;
  final bool includeParentEnvironment;
  String get executable => executablePath;

  DevinCliAcpLaunch._(
    this.executablePath,
    this.executableSha256,
    this.arguments,
    this.environment,
  ) : includeParentEnvironment = false;

  static const executablePathKey = 'devinCliExecutablePath';
  static const executableSha256Key = 'devinCliExecutableSha256';

  factory DevinCliAcpLaunch.forAccount({
    required String homePath,
    required String executablePath,
    required String executableSha256,
    required Map<String, String> parentEnvironment,
    String? temporaryDirectory,
  }) => DevinCliAcpLaunch._(
    executablePath,
    executableSha256,
    List.unmodifiable(acpArguments),
    _isolatedEnvironment(
      homePath,
      parentEnvironment,
      temporaryDirectory: temporaryDirectory,
    ),
  );

  factory DevinCliAcpLaunch.forLogin({
    required String homePath,
    required String executablePath,
    required String executableSha256,
    required Map<String, String> parentEnvironment,
  }) => DevinCliAcpLaunch._(
    executablePath,
    executableSha256,
    List.unmodifiable(loginArguments),
    _isolatedEnvironment(homePath, parentEnvironment),
  );

  factory DevinCliAcpLaunch.forLogout({
    required String homePath,
    required String executablePath,
    required String executableSha256,
    required Map<String, String> parentEnvironment,
  }) => DevinCliAcpLaunch._(
    executablePath,
    executableSha256,
    List.unmodifiable(logoutArguments),
    _isolatedEnvironment(homePath, parentEnvironment),
  );

  factory DevinCliAcpLaunch.forStatus({
    required String homePath,
    required String executablePath,
    required String executableSha256,
    required Map<String, String> parentEnvironment,
  }) => DevinCliAcpLaunch._(
    executablePath,
    executableSha256,
    List.unmodifiable(statusArguments),
    _isolatedEnvironment(homePath, parentEnvironment),
  );

  static Map<String, String> _isolatedEnvironment(
    String homePath,
    Map<String, String> parentEnvironment, {
    String? temporaryDirectory,
  }) {
    final home = p.normalize(p.absolute(homePath));
    final config = p.join(home, '.config');
    final data = p.join(home, '.local', 'share');
    final cache = p.join(home, '.cache');
    final temp = p.normalize(
      p.absolute(temporaryDirectory ?? p.join(home, 'tmp')),
    );
    return Map.unmodifiable({
      if (parentEnvironment['PATH'] case final path? when path.isNotEmpty)
        'PATH': path,
      'HOME': home,
      'XDG_CONFIG_HOME': config,
      'XDG_DATA_HOME': data,
      'XDG_CACHE_HOME': cache,
      'TMPDIR': temp,
      'TMP': temp,
      'TEMP': temp,
      if (Platform.isWindows) ...{
        'USERPROFILE': home,
        'APPDATA': p.join(home, 'AppData', 'Roaming'),
        'LOCALAPPDATA': p.join(home, 'AppData', 'Local'),
        'SystemRoot': ?parentEnvironment['SystemRoot'],
      },
    });
  }

  /// Copies the approved CLI into a private directory and verifies the copy
  /// itself before it is launched, closing the verify-then-open path race.
  Future<({Directory directory, String executablePath})>
  prepareApprovedExecutableCopy() async {
    final currentApproval = await approveExecutablePath(executablePath);
    if (currentApproval.path != executablePath ||
        currentApproval.sha256 != executableSha256.toLowerCase()) {
      throw const DevinCliAcpExecutableApprovalException();
    }

    final directory = await Directory.systemTemp.createTemp(
      'stroom-devin-cli-executable-',
    );
    try {
      await permissions.restrictDirectory(directory.path);
      final copy = File(p.join(directory.path, p.basename(executablePath)));
      await File(executablePath).copy(copy.path);
      await permissions.restrictExecutable(copy.path);
      final copiedApproval = await approveExecutablePath(copy.path);
      if (copiedApproval.sha256 != executableSha256.toLowerCase()) {
        throw const DevinCliAcpExecutableApprovalException();
      }
      return (directory: directory, executablePath: copy.path);
    } catch (_) {
      try {
        await directory.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  /// Captures an explicitly user-approved local executable and pins its
  /// canonical path and content digest for subsequent launches.
  static Future<({String path, String sha256})> approveExecutablePath(
    String path,
  ) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty || !p.isAbsolute(trimmedPath)) {
      throw const FileSystemException(
        'Select an absolute Devin CLI executable path.',
      );
    }
    final file = File(trimmedPath);
    final canonicalPath = await file.resolveSymbolicLinks();
    final expectedFileName = Platform.isWindows
        ? '$fixedExecutable.exe'
        : fixedExecutable;
    if (p.basename(canonicalPath).toLowerCase() !=
        expectedFileName.toLowerCase()) {
      throw const FileSystemException(
        'The selected executable must be named devin.',
      );
    }
    final canonicalFile = File(canonicalPath);
    final stat = await canonicalFile.stat();
    if (stat.type != FileSystemEntityType.file ||
        (!Platform.isWindows && (stat.mode & 0x49) == 0)) {
      throw const FileSystemException('The Devin CLI path is not executable.');
    }
    final digest = await sha256.bind(canonicalFile.openRead()).first;
    return (path: canonicalPath, sha256: digest.toString());
  }

  static Future<void> verifyExecutableApproval(
    String path,
    String expectedSha256,
  ) async {
    try {
      final approval = await approveExecutablePath(path);
      if (approval.path == path &&
          approval.sha256 == expectedSha256.toLowerCase()) {
        return;
      }
    } on FileSystemException {
      throw const DevinCliAcpExecutableApprovalException();
    }
    throw const DevinCliAcpExecutableApprovalException();
  }
}

class DevinCliAcpExecutableApprovalException implements Exception {
  const DevinCliAcpExecutableApprovalException();
}

/// Isolated, account-scoped storage for the official CLI's login state.
class DevinCliAcpHome {
  static String pathForAccount({
    required String supportDirectory,
    required String accountId,
  }) {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    final safeId = base64Url.encode(utf8.encode(accountId)).replaceAll('=', '');
    final root = p.normalize(p.absolute(supportDirectory));
    final result = p.normalize(p.join(root, 'devin_cli_acp', safeId));
    if (!p.isWithin(root, result)) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    return result;
  }

  static Future<void> restrictDirectory(String path) =>
      permissions.restrictDirectory(path);

  static Future<Directory> createTemporaryDirectory(String homePath) async {
    final directory = Directory(p.join(homePath, 'tmp'));
    await directory.create(recursive: true);
    await permissions.restrictDirectory(directory.path);
    return directory;
  }

  static Future<Directory> createForAccount(String accountId) async {
    if (Platform.isAndroid || Platform.isIOS || kIsWeb) {
      throw UnsupportedError(
        'Devin CLI ACP requires a desktop platform with local process support.',
      );
    }
    final support = await getApplicationSupportDirectory();
    final path = pathForAccount(
      supportDirectory: support.path,
      accountId: accountId,
    );
    final directory = Directory(path);
    await directory.create(recursive: true);
    await permissions.restrictDirectory(directory.path);
    await createTemporaryDirectory(directory.path);
    return directory;
  }
}

/// Strict JSON-RPC helpers for ACP's newline-delimited stdio transport.
abstract final class DevinCliAcpJsonRpc {
  static const protocolVersion = 1;
  static const maxFrameBytes = 1024 * 1024;

  static String encodeRequest({
    required Object id,
    required String method,
    Map<String, Object?>? params,
  }) {
    if (id is! int && id is! String) {
      throw ArgumentError.value(id, 'id');
    }
    if (method.isEmpty || method.trim() != method) {
      throw ArgumentError.value(method, 'method');
    }
    return _encodeFrame({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': ?params,
    });
  }

  static String encodeNotification({
    required String method,
    Map<String, Object?>? params,
  }) {
    if (method.isEmpty || method.trim() != method) {
      throw ArgumentError.value(method, 'method');
    }
    return _encodeFrame({
      'jsonrpc': '2.0',
      'method': method,
      'params': ?params,
    });
  }

  static String encodeErrorResponse({
    required Object id,
    required int code,
    required String message,
  }) => _encodeFrame({
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  });

  static String _encodeFrame(Map<String, Object?> message) {
    final encoded = jsonEncode(message);
    if (utf8.encode(encoded).length > maxFrameBytes) {
      throw const FormatException('ACP frame exceeds the size limit.');
    }
    return '$encoded\n';
  }

  /// Decodes newline-delimited ACP frames while bounding raw input bytes,
  /// before a line splitter could buffer an oversized unterminated frame.
  static Stream<String> decodeLines(Stream<List<int>> source) async* {
    final frame = <int>[];
    await for (final chunk in source) {
      for (final byte in chunk) {
        if (byte == 0x0a) {
          final hasCarriageReturn = frame.isNotEmpty && frame.last == 0x0d;
          if (frame.length - (hasCarriageReturn ? 1 : 0) > maxFrameBytes) {
            throw const FormatException(
              'ACP frame exceeds the supported limit.',
            );
          }
          if (hasCarriageReturn) frame.removeLast();
          yield utf8.decode(frame);
          frame.clear();
        } else {
          final trailingCarriageReturn =
              byte == 0x0d && frame.length == maxFrameBytes;
          if (frame.length >= maxFrameBytes && !trailingCarriageReturn) {
            throw const FormatException(
              'ACP frame exceeds the supported limit.',
            );
          }
          frame.add(byte);
        }
      }
    }
    if (frame.length > maxFrameBytes) {
      throw const FormatException('ACP frame exceeds the supported limit.');
    }
    if (frame.isNotEmpty) yield utf8.decode(frame);
  }

  static Map<String, dynamic> decodeMessage(String frame) {
    if (utf8.encode(frame).length > maxFrameBytes) {
      throw const FormatException('ACP frame exceeds the supported limit.');
    }
    final decoded = jsonDecode(frame);
    if (decoded is! Map<String, dynamic> || decoded['jsonrpc'] != '2.0') {
      throw const FormatException('Invalid ACP JSON-RPC frame.');
    }
    final hasMethod = decoded['method'] is String;
    final hasResult = decoded.containsKey('result');
    final hasError = decoded.containsKey('error');
    if (hasMethod == (hasResult || hasError) ||
        hasResult && hasError ||
        (hasMethod && (decoded['method'] as String).isEmpty)) {
      throw const FormatException('Invalid ACP JSON-RPC frame.');
    }
    if (decoded.containsKey('id') &&
        decoded['id'] != null &&
        decoded['id'] is! int &&
        decoded['id'] is! String) {
      throw const FormatException('Invalid ACP JSON-RPC id.');
    }
    return decoded;
  }

  static void validateNegotiatedVersion(Object? value) {
    if (value != protocolVersion) {
      throw DevinCliAcpUnsupportedProtocolVersion();
    }
  }
}

class DevinCliAcpUnsupportedProtocolVersion extends UnsupportedError {
  DevinCliAcpUnsupportedProtocolVersion()
    : super('The Devin CLI ACP version is not supported.');
}
