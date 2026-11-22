import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

const _zcodeMaxFrameBytes = 16 * 1024 * 1024;
const _zcodeMaxHelloBytes = 64 * 1024;
const _zcodeMaxModels = 128;
const _zcodeMaxMessages = 256;
const _zcodeMaxTools = 128;
const _zcodeMaxImages = 20;
const _zcodeMaxImageBytes = 10 * 1024 * 1024;
const _zcodeStartupTimeout = Duration(seconds: 10);
const _zcodeRequestTimeout = Duration(minutes: 10);
const _zcodeImageFetchTimeout = Duration(seconds: 15);
const _zcodeMaxImageRedirects = 3;

class ZcodeCliException implements Exception {
  final String code;
  final String message;

  const ZcodeCliException(this.code, this.message);

  @override
  String toString() => message;
}

/// Fixed shell-free launch policy: `zcode app-server`, or the bundled runtime
/// at `~/.zcode/server/{node,zcode-server.cjs}` when both files are present.
class ZcodeCliLaunch {
  final String executable;
  final List<String> arguments;
  final bool runInShell;

  const ZcodeCliLaunch({
    required this.executable,
    this.arguments = const ['app-server'],
    this.runInShell = false,
  });

  static List<String>? windowsNpmShimCommand({
    required String shimPath,
    required String shimContents,
    required String nodePath,
  }) {
    final match = RegExp(
      r'"%(?:dp0|basedir)%\\(node_modules\\@zai\\zcode\\[^"\r\n]+\.js)"',
      caseSensitive: false,
    ).firstMatch(shimContents);
    if (match == null) return null;
    final scriptPath = match.group(1)!;
    if (scriptPath.split(RegExp(r'[\\/]')).any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      return null;
    }
    final script = scriptPath.replaceAll('/', r'\');
    final slash = math.max(
      shimPath.lastIndexOf(r'\'),
      shimPath.lastIndexOf('/'),
    );
    final directory = slash < 0 ? '' : shimPath.substring(0, slash);
    return [nodePath, '$directory\\$script'];
  }

  static bool needsWindowsResolution(String executable) {
    final normalized = executable.toLowerCase();
    return normalized == 'zcode' || normalized.endsWith('.cmd');
  }
}

abstract interface class ZcodeCliProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  void writeStdin(List<int> bytes);
  Future<void> closeStdin();
  Future<void> terminate({bool force = false});
}

abstract interface class ZcodeCliProcessLauncher {
  Future<ZcodeCliProcess> start(
    ZcodeCliLaunch launch, {
    required String workingDirectory,
  });
}

class IoZcodeCliProcessLauncher implements ZcodeCliProcessLauncher {
  const IoZcodeCliProcessLauncher();

  @override
  Future<ZcodeCliProcess> start(
    ZcodeCliLaunch launch, {
    required String workingDirectory,
  }) async {
    var target = launch;
    final bundled = await _resolveBundledRuntime();
    if (bundled != null && launch.executable == 'zcode') target = bundled;
    if (Platform.isWindows &&
        ZcodeCliLaunch.needsWindowsResolution(target.executable)) {
      target = await _resolveWindowsLaunch(target);
    }
    final process = await Process.start(
      target.executable,
      target.arguments,
      workingDirectory: workingDirectory,
      runInShell: false,
      mode: ProcessStartMode.normal,
    );
    return _IoZcodeCliProcess(process);
  }

  Future<ZcodeCliLaunch?> _resolveBundledRuntime() async {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null || home.isEmpty) return null;
    final root = Directory(p.join(home, '.zcode', 'server'));
    final node = File(
      p.join(root.path, Platform.isWindows ? 'node.exe' : 'node'),
    );
    final entry = File(p.join(root.path, 'zcode-server.cjs'));
    if (!await node.exists() || !await entry.exists()) return null;
    return ZcodeCliLaunch(executable: node.path, arguments: [entry.path]);
  }

  Future<ZcodeCliLaunch> _resolveWindowsLaunch(ZcodeCliLaunch requested) async {
    final candidates = <String>[];
    if (requested.executable.toLowerCase().endsWith('.cmd')) {
      candidates.add(requested.executable);
    } else {
      try {
        final result = await Process.run(
          'where.exe',
          [requested.executable],
          runInShell: false,
        );
        candidates.addAll(
          (result.stdout as String)
              .split(RegExp(r'\r?\n'))
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty),
        );
      } on ProcessException {
        // Let Process.start return the normal missing-binary error below.
      }
    }
    for (final candidate in candidates) {
      if (candidate.toLowerCase().endsWith('.exe')) {
        return ZcodeCliLaunch(executable: candidate);
      }
      if (!candidate.toLowerCase().endsWith('.cmd')) continue;
      try {
        final shim = await File(candidate).readAsString();
        final separator = math.max(
          candidate.lastIndexOf(r'\'),
          candidate.lastIndexOf('/'),
        );
        final nodeBesideShim = File(
          '${candidate.substring(0, separator)}\\node.exe',
        );
        final nodePaths = <String>[
          if (await nodeBesideShim.exists()) nodeBesideShim.path,
        ];
        final nodeResult = await Process.run(
            'where.exe',
            [
              'node.exe',
            ],
            runInShell: false);
        nodePaths.addAll(
          (nodeResult.stdout as String)
              .split(RegExp(r'\r?\n'))
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty),
        );
        for (final node in nodePaths) {
          final command = ZcodeCliLaunch.windowsNpmShimCommand(
            shimPath: candidate,
            shimContents: shim,
            nodePath: node,
          );
          if (command != null) {
            return ZcodeCliLaunch(
              executable: command.first,
              arguments: [...command.skip(1), 'app-server'],
            );
          }
        }
      } on Object {
        continue;
      }
    }
    return requested;
  }
}

class _IoZcodeCliProcess implements ZcodeCliProcess {
  final Process _process;

  const _IoZcodeCliProcess(this._process);

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void writeStdin(List<int> bytes) => _process.stdin.add(bytes);

  @override
  Future<void> closeStdin() => _process.stdin.close();

  @override
  Future<void> terminate({bool force = false}) async {
    _process.kill(force ? ProcessSignal.sigkill : ProcessSignal.sigterm);
  }
}

enum ZcodeServerStatus {
  ready,
  binaryMissing,
  serverUnavailable,
  modelServiceNotReady,
  signedOut,
  noEnabledCodingPlanModel,
  unknownProtocolError,
}

class ZcodeServerStatusResult {
  final ZcodeServerStatus status;
  final String code;

  const ZcodeServerStatusResult(this.status, this.code);
}

class ZcodeModel {
  final String id;
  final String displayName;
  final int contextLength;
  final int maxOutputTokens;
  final bool supportsVision;

  const ZcodeModel({
    required this.id,
    required this.displayName,
    required this.contextLength,
    required this.maxOutputTokens,
    this.supportsVision = false,
  });
}

const zcodePinnedModels = <ZcodeModel>[
  ZcodeModel(
    id: 'glm-5.3-flash',
    displayName: 'GLM 5.3 Flash',
    contextLength: 1000000,
    maxOutputTokens: 131072,
    supportsVision: true,
  ),
  ZcodeModel(
    id: 'glm-5.3',
    displayName: 'GLM 5.3',
    contextLength: 1000000,
    maxOutputTokens: 131072,
  ),
  ZcodeModel(
    id: 'glm-5.3-max',
    displayName: 'GLM 5.3 Max',
    contextLength: 1000000,
    maxOutputTokens: 131072,
  ),
  ZcodeModel(
    id: 'glm-5.2',
    displayName: 'GLM 5.2',
    contextLength: 1000000,
    maxOutputTokens: 131072,
  ),
  ZcodeModel(
    id: 'glm-5.1',
    displayName: 'GLM 5.1',
    contextLength: 204800,
    maxOutputTokens: 131072,
  ),
  ZcodeModel(
    id: 'glm-5',
    displayName: 'GLM 5',
    contextLength: 200000,
    maxOutputTokens: 131072,
  ),
  ZcodeModel(
    id: 'glm-5-turbo',
    displayName: 'GLM 5 Turbo',
    contextLength: 200000,
    maxOutputTokens: 131072,
  ),
  ZcodeModel(
    id: 'glm-4.7-flash',
    displayName: 'GLM 4.7 Flash',
    contextLength: 200000,
    maxOutputTokens: 131072,
  ),
  ZcodeModel(
    id: 'glm-4.7',
    displayName: 'GLM 4.7',
    contextLength: 200000,
    maxOutputTokens: 131072,
  ),
  ZcodeModel(
    id: 'glm-4.6v',
    displayName: 'GLM 4.6V (Vision)',
    contextLength: 128000,
    maxOutputTokens: 32768,
    supportsVision: true,
  ),
  ZcodeModel(
    id: 'glm-4.6',
    displayName: 'GLM 4.6',
    contextLength: 200000,
    maxOutputTokens: 32768,
  ),
  ZcodeModel(
    id: 'glm-4.5v',
    displayName: 'GLM 4.5V (Vision)',
    contextLength: 16000,
    maxOutputTokens: 32768,
    supportsVision: true,
  ),
  ZcodeModel(
    id: 'glm-4.5',
    displayName: 'GLM 4.5',
    contextLength: 128000,
    maxOutputTokens: 32768,
  ),
  ZcodeModel(
    id: 'glm-4.5-air',
    displayName: 'GLM 4.5 Air',
    contextLength: 128000,
    maxOutputTokens: 32768,
  ),
];

const zcodePinnedModelIds = <String>[
  'glm-5.3-flash',
  'glm-5.3',
  'glm-5.3-max',
  'glm-5.2',
  'glm-5.1',
  'glm-5',
  'glm-5-turbo',
  'glm-4.7-flash',
  'glm-4.7',
  'glm-4.6v',
  'glm-4.6',
  'glm-4.5v',
  'glm-4.5',
  'glm-4.5-air',
];

class ZcodeModelSelection {
  final String providerId;
  final String modelId;
  final int? maxOutputTokens;
  final String? reasoningLevel;

  const ZcodeModelSelection({
    required this.providerId,
    required this.modelId,
    this.maxOutputTokens,
    this.reasoningLevel,
  });
}

ZcodeModelSelection resolveZcodeModelSelection(
  Object? view,
  String modelId, {
  String? providerId,
}) {
  final root = _asMap(view);
  final providers = root['providers'];
  if (providers is! List || providers.length > _zcodeMaxModels) {
    throw const ZcodeCliException(
      'protocol_error',
      'ZCode model service returned an invalid model list.',
    );
  }
  if (providers.any((provider) => provider is! Map)) {
    throw const ZcodeCliException(
      'protocol_error',
      'ZCode model service returned an invalid provider list.',
    );
  }
  final candidateProviders = providerId == null
      ? const ['account:zai-individual-coding-plan', 'builtin:zai-coding-plan']
      : [providerId];
  for (final wantedProvider in candidateProviders) {
    final provider = providers.whereType<Map>().cast<Map>().firstWhere(
          (entry) => entry['providerId'] == wantedProvider,
          orElse: () => const {},
        );
    if (provider.isEmpty) continue;
    final models = provider['models'];
    if (models is! List || models.length > _zcodeMaxModels) {
      throw const ZcodeCliException(
        'protocol_error',
        'ZCode model service returned an invalid model list.',
      );
    }
    for (final rawModel in models) {
      if (rawModel is! Map) {
        throw const ZcodeCliException(
          'protocol_error',
          'ZCode model service returned an invalid model entry.',
        );
      }
      final nativeModelId = rawModel['modelId'];
      if (nativeModelId is! String ||
          nativeModelId.toLowerCase() != modelId.toLowerCase()) {
        continue;
      }
      if (rawModel['config'] != null && rawModel['config'] is! Map) {
        throw const ZcodeCliException(
          'protocol_error',
          'ZCode model service returned an invalid model configuration.',
        );
      }
      final config = _asMap(rawModel['config']);
      if (config['enabled'] == false) continue;
      final options = _asMap(config['optionSpecs']);
      final tokenSpec = _asMap(options['maxOutputTokens']);
      final maxTokens = tokenSpec['max'];
      final reasoningSpec = _asMap(options['reasoningLevel']);
      final rawLevels = reasoningSpec['values'];
      final levels = rawLevels is List
          ? rawLevels.whereType<String>().toList(growable: false)
          : const <String>[];
      return ZcodeModelSelection(
        providerId: wantedProvider,
        modelId: nativeModelId,
        maxOutputTokens: maxTokens is num && maxTokens > 0
            ? math.min(maxTokens.toInt(), 131072).toInt()
            : null,
        reasoningLevel: levels.contains('high') ? 'high' : levels.firstOrNull,
      );
    }
  }
  throw const ZcodeCliException(
    'model_unavailable',
    'No enabled ZCode Coding Plan model matches the selected model.',
  );
}

int? resolveZcodeMaxOutputTokens(Object? view, String modelId) {
  int? resolved;
  for (final providerId in const [
    'account:zai-individual-coding-plan',
    'builtin:zai-coding-plan',
  ]) {
    try {
      resolved = resolveZcodeModelSelection(
        view,
        modelId,
        providerId: providerId,
      ).maxOutputTokens;
      if (resolved != null) return resolved;
    } on ZcodeCliException catch (error) {
      if (error.code != 'model_unavailable') rethrow;
      continue;
    }
  }
  return null;
}

class ZcodeSocketDecodedValue {
  final Object? value;
  final int offset;

  const ZcodeSocketDecodedValue(this.value, this.offset);
}

class ZcodeSocketFrame {
  final int type;
  final int sequence;
  final int correlationId;
  final Object? header;
  final Object? payload;

  const ZcodeSocketFrame({
    required this.type,
    required this.sequence,
    required this.correlationId,
    required this.header,
    required this.payload,
  });
}

class ZcodeSocketProtocol {
  const ZcodeSocketProtocol._();

  static Uint8List encodeValue(Object? value) {
    if (value == null) return _jsonValue(null);
    if (value is String) {
      final bytes = utf8.encode(value);
      return _join([
        Uint8List.fromList([1]),
        _encodeVql(bytes.length),
        bytes,
      ]);
    }
    if (value is Uint8List) {
      return _join([
        Uint8List.fromList([2]),
        _encodeVql(value.length),
        value,
      ]);
    }
    if (value is List) {
      return _join([
        Uint8List.fromList([4]),
        _encodeVql(value.length),
        ...value.map(encodeValue),
      ]);
    }
    if (value is int && value >= 0) {
      return _join([
        Uint8List.fromList([6]),
        _encodeVql(value),
      ]);
    }
    if (value is num && value >= 0 && value == value.roundToDouble()) {
      return _join([
        Uint8List.fromList([6]),
        _encodeVql(value.toInt()),
      ]);
    }
    return _jsonValue(value);
  }

  static Uint8List _jsonValue(Object? value) {
    final bytes = utf8.encode(jsonEncode(value));
    return _join([
      Uint8List.fromList([5]),
      _encodeVql(bytes.length),
      bytes,
    ]);
  }

  static ZcodeSocketDecodedValue decodeValue(Uint8List data, [int offset = 0]) {
    if (offset >= data.length) throw const FormatException('Truncated value');
    final type = data[offset++];
    if (type == 0) return ZcodeSocketDecodedValue(null, offset);
    if (type == 1 || type == 2 || type == 5) {
      final length = _decodeVql(data, offset);
      if (length.value > _zcodeMaxFrameBytes ||
          length.offset + length.value > data.length) {
        throw const FormatException('Invalid serialized value length');
      }
      final bytes = data.sublist(length.offset, length.offset + length.value);
      if (type == 2) {
        return ZcodeSocketDecodedValue(bytes, length.offset + length.value);
      }
      if (type == 1) {
        return ZcodeSocketDecodedValue(
          utf8.decode(bytes, allowMalformed: false),
          length.offset + length.value,
        );
      }
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      return ZcodeSocketDecodedValue(decoded, length.offset + length.value);
    }
    if (type == 4) {
      final length = _decodeVql(data, offset);
      if (length.value > _zcodeMaxModels) {
        throw const FormatException('Serialized array exceeds limit');
      }
      final values = <Object?>[];
      var cursor = length.offset;
      for (var index = 0; index < length.value; index++) {
        final decoded = decodeValue(data, cursor);
        values.add(decoded.value);
        cursor = decoded.offset;
      }
      return ZcodeSocketDecodedValue(values, cursor);
    }
    if (type == 6) {
      final decoded = _decodeVql(data, offset);
      return ZcodeSocketDecodedValue(decoded.value, decoded.offset);
    }
    throw FormatException('Unknown serialized value type $type');
  }

  static Uint8List encodeCall(
    int requestId,
    String channel,
    String method,
    List<Object?> arguments,
  ) {
    if (requestId < 1 || requestId > 0x7fffffff) {
      throw ArgumentError.value(requestId, 'requestId');
    }
    if (channel.isEmpty ||
        method.isEmpty ||
        arguments.length > _zcodeMaxModels) {
      throw ArgumentError('Invalid ZCode RPC call');
    }
    final payload = _join([
      encodeValue([100, requestId, channel, method]),
      encodeValue(arguments),
    ]);
    if (payload.length > _zcodeMaxFrameBytes) {
      throw ArgumentError('ZCode frame exceeds the configured safety limit');
    }
    final frame = Uint8List(13 + payload.length);
    final header = ByteData.sublistView(frame);
    header.setUint8(0, 1);
    header.setUint32(1, 0);
    header.setUint32(5, 0);
    header.setUint32(9, payload.length);
    frame.setRange(13, frame.length, payload);
    return frame;
  }

  static ZcodeSocketFrame decodeFrame(Uint8List frame) {
    if (frame.length < 13) {
      throw const FormatException('Truncated frame header');
    }
    final header = ByteData.sublistView(frame);
    final type = header.getUint8(0);
    final sequence = header.getUint32(1);
    final correlation = header.getUint32(5);
    final size = header.getUint32(9);
    if (size > _zcodeMaxFrameBytes || size != frame.length - 13) {
      throw const FormatException('Invalid frame length');
    }
    if (type != 1) throw FormatException('Unexpected frame type $type');
    final body = Uint8List.sublistView(frame, 13);
    final decodedHeader = decodeValue(body);
    final decodedPayload = decodeValue(body, decodedHeader.offset);
    if (decodedPayload.offset != body.length) {
      throw const FormatException('Trailing frame payload data');
    }
    return ZcodeSocketFrame(
      type: type,
      sequence: sequence,
      correlationId: correlation,
      header: decodedHeader.value,
      payload: decodedPayload.value,
    );
  }

  static Uint8List _encodeVql(int value) {
    if (value < 0 || value > _zcodeMaxFrameBytes) {
      throw ArgumentError.value(value, 'value');
    }
    var remaining = value;
    final result = <int>[];
    do {
      var part = remaining & 0x7f;
      remaining >>= 7;
      if (remaining > 0) part |= 0x80;
      result.add(part);
    } while (remaining > 0);
    return Uint8List.fromList(result);
  }

  static ({int value, int offset}) _decodeVql(Uint8List data, int offset) {
    var result = 0;
    var multiplier = 1;
    var cursor = offset;
    for (var index = 0; index < 8; index++) {
      if (cursor >= data.length) throw const FormatException('Truncated VQL');
      final byte = data[cursor++];
      result += (byte & 0x7f) * multiplier;
      if ((byte & 0x80) == 0) {
        if (result > _zcodeMaxFrameBytes) {
          throw const FormatException('VQL exceeds safety limit');
        }
        return (value: result, offset: cursor);
      }
      multiplier <<= 7;
    }
    throw const FormatException('Invalid VQL');
  }

  static Uint8List _join(Iterable<List<int>> parts) {
    final builder = BytesBuilder(copy: false);
    for (final part in parts) {
      builder.add(part);
    }
    return builder.takeBytes();
  }
}

class ZcodeContentPart {
  final String? text;
  final ZcodeImageInput? image;

  const ZcodeContentPart.text(this.text) : image = null;
  const ZcodeContentPart.image(this.image) : text = null;
}

class ZcodeChatMessage {
  final String role;
  final String content;
  final List<ZcodeContentPart> contentParts;
  final List<ZcodeImageInput> images;
  final List<ZcodeToolCall> toolCalls;
  final String? toolCallId;
  final String? toolName;

  const ZcodeChatMessage({
    required this.role,
    required this.content,
    this.contentParts = const [],
    this.images = const [],
    this.toolCalls = const [],
    this.toolCallId,
    this.toolName,
  });
}

class ZcodeImageInput {
  final String dataUrl;
  final String mediaType;

  const ZcodeImageInput(this.dataUrl, this.mediaType);
}

class ZcodeFetchedImage {
  final Uint8List bytes;
  final String mediaType;

  const ZcodeFetchedImage(this.bytes, this.mediaType);
}

typedef ZcodeRemoteImageFetcher = Future<ZcodeFetchedImage> Function(
  Uri uri,
  CancelToken? cancelToken,
);
typedef ZcodeImageAddressLookup = Future<List<InternetAddress>> Function(
    String host);

class ZcodeToolCall {
  final String id;
  final String name;
  final Object? arguments;

  const ZcodeToolCall(this.id, this.name, this.arguments);
}

class ZcodeFunctionTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  const ZcodeFunctionTool(this.name, this.description, this.inputSchema);
}

class ZcodeChatRequest {
  final List<ZcodeChatMessage> messages;
  final List<ZcodeFunctionTool> tools;
  final int? maxOutputTokens;

  const ZcodeChatRequest({
    required this.messages,
    required this.tools,
    this.maxOutputTokens,
  });

  factory ZcodeChatRequest.fromChatCompletionsBody(
    Map<String, dynamic> body, {
    bool modelSupportsVision = false,
  }) {
    const allowedBodyKeys = {
      'model',
      'messages',
      'tools',
      'tool_choice',
      'max_tokens',
      'max_completion_tokens',
      'stream',
      'temperature',
      'top_p',
      'frequency_penalty',
      'presence_penalty',
    };
    if (body.keys.any((key) => !allowedBodyKeys.contains(key))) {
      throw const ZcodeCliException(
        'invalid_request',
        'ZCode request contains unsupported fields.',
      );
    }
    if (body.keys.any(
      (key) => const {'audio', 'video', 'modalities'}.contains(key),
    )) {
      throw const ZcodeCliException(
        'unsupported_media',
        'ZCode supports text and model-approved image input only.',
      );
    }
    final rawMessages = body['messages'];
    if (rawMessages is! List ||
        rawMessages.isEmpty ||
        rawMessages.length > _zcodeMaxMessages) {
      throw const ZcodeCliException(
        'invalid_request',
        'Invalid ZCode message history.',
      );
    }
    final messages = <ZcodeChatMessage>[];
    final toolNames = <String, String>{};
    var imageCount = 0;
    for (final rawMessage in rawMessages) {
      if (rawMessage is! Map) {
        throw const ZcodeCliException(
          'unsupported_message',
          'Unsupported ZCode message.',
        );
      }
      final message = Map<String, dynamic>.from(rawMessage);
      const allowedMessageKeys = {
        'role',
        'content',
        'name',
        'tool_calls',
        'tool_call_id',
      };
      if (message.keys.any((key) => !allowedMessageKeys.contains(key))) {
        throw const ZcodeCliException(
          'unsupported_message',
          'ZCode message contains unsupported fields.',
        );
      }
      final role = message['role'];
      if (role is! String ||
          !const {
            'system',
            'developer',
            'user',
            'assistant',
            'tool',
          }.contains(role)) {
        throw const ZcodeCliException(
          'unsupported_message',
          'Unsupported ZCode message role.',
        );
      }
      final content = _content(message['content'], role, modelSupportsVision);
      imageCount += content.images.length;
      if (imageCount > _zcodeMaxImages) {
        throw const ZcodeCliException(
          'unsupported_media',
          'Too many ZCode images.',
        );
      }
      final calls = <ZcodeToolCall>[];
      final rawCalls = message['tool_calls'];
      if (rawCalls != null) {
        if (role != 'assistant' ||
            rawCalls is! List ||
            rawCalls.length > _zcodeMaxTools) {
          throw const ZcodeCliException(
            'unsupported_tool',
            'Unsupported ZCode tool call.',
          );
        }
        for (final rawCall in rawCalls) {
          if (rawCall is! Map || rawCall['type'] != 'function') {
            throw const ZcodeCliException(
              'unsupported_tool',
              'Unsupported ZCode tool call.',
            );
          }
          final fn = _asMap(rawCall['function']);
          final id = rawCall['id'];
          final name = fn['name'];
          final arguments = fn['arguments'];
          if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
            throw const ZcodeCliException(
              'unsupported_tool',
              'Invalid ZCode tool call.',
            );
          }
          Object? parsed;
          try {
            parsed = arguments is String ? jsonDecode(arguments) : arguments;
          } catch (_) {
            throw const ZcodeCliException(
              'unsupported_tool',
              'Invalid ZCode tool arguments.',
            );
          }
          parsed ??= const <String, dynamic>{};
          if (parsed is! Map) {
            throw const ZcodeCliException(
              'unsupported_tool',
              'ZCode function arguments must be a JSON object.',
            );
          }
          toolNames[id] = name;
          calls.add(ZcodeToolCall(id, name, parsed));
        }
      }
      if (role == 'tool') {
        final id = message['tool_call_id'];
        final explicitName = message['name'];
        final name = explicitName is String ? explicitName : toolNames[id];
        if (id is! String ||
            name is! String ||
            !toolNames.containsKey(id) ||
            toolNames[id] != name) {
          throw const ZcodeCliException(
            'unsupported_tool',
            'Tool result has no matching call.',
          );
        }
        messages.add(
          ZcodeChatMessage(
            role: role,
            content: content.text,
            contentParts: content.parts,
            toolCallId: id,
            toolName: name,
          ),
        );
      } else {
        messages.add(
          ZcodeChatMessage(
            role: role == 'developer' ? 'system' : role,
            content: content.text,
            contentParts: content.parts,
            images: content.images,
            toolCalls: calls,
          ),
        );
      }
    }
    final rawTools = body['tools'];
    if (rawTools != null && rawTools is! List) {
      throw const ZcodeCliException(
        'unsupported_tool',
        'Unsupported ZCode tool schema.',
      );
    }
    final tools = <ZcodeFunctionTool>[];
    for (final rawTool in (rawTools as List? ?? const [])) {
      if (rawTool is! Map || rawTool['type'] != 'function') {
        throw const ZcodeCliException(
          'unsupported_tool',
          'Only function tools are supported.',
        );
      }
      final fn = _asMap(rawTool['function']);
      final name = fn['name'];
      final schema = fn['parameters'];
      if (name is! String ||
          name.isEmpty ||
          (schema != null && schema is! Map)) {
        throw const ZcodeCliException(
          'unsupported_tool',
          'Invalid ZCode function tool.',
        );
      }
      tools.add(
        ZcodeFunctionTool(
          name,
          fn['description'] is String ? fn['description'] as String : '',
          schema is Map
              ? Map<String, dynamic>.from(schema)
              : const {'type': 'object'},
        ),
      );
      if (tools.length > _zcodeMaxTools) {
        throw const ZcodeCliException(
          'unsupported_tool',
          'Too many ZCode tools.',
        );
      }
    }
    final rawTokens = body['max_completion_tokens'] ?? body['max_tokens'];
    if (body['stream'] != null && body['stream'] is! bool) {
      throw const ZcodeCliException(
        'invalid_request',
        'Invalid ZCode stream option.',
      );
    }
    int? maxTokens;
    if (rawTokens != null) {
      if (rawTokens is! int || rawTokens < 1 || rawTokens > 131072) {
        throw const ZcodeCliException(
          'invalid_token_limit',
          'Invalid ZCode output token limit.',
        );
      }
      maxTokens = rawTokens;
    }
    final toolChoice = body['tool_choice'];
    if (toolChoice != null && toolChoice != 'auto' && toolChoice != 'none') {
      throw const ZcodeCliException(
        'unsupported_tool',
        'Unsupported ZCode tool selection mode.',
      );
    }
    return ZcodeChatRequest(
      messages: List.unmodifiable(messages),
      tools: toolChoice == 'none' ? const [] : List.unmodifiable(tools),
      maxOutputTokens: maxTokens,
    );
  }

  Future<ZcodeChatRequest> resolveRemoteImages({
    required ZcodeRemoteImageFetcher fetcher,
    CancelToken? cancelToken,
  }) async {
    final resolvedMessages = <ZcodeChatMessage>[];
    for (final message in messages) {
      final images = <ZcodeImageInput>[];
      final contentParts = <ZcodeContentPart>[];
      for (final part in message.contentParts) {
        final image = part.image;
        if (image == null) {
          contentParts.add(part);
          continue;
        }
        if (cancelToken?.isCancelled ?? false) {
          throw const ZcodeCliException(
            'cancelled',
            'ZCode request was canceled.',
          );
        }
        late final ZcodeImageInput resolvedImage;
        if (image.dataUrl.toLowerCase().startsWith('data:')) {
          resolvedImage = image;
        } else {
          final uri = _validatePublicImageUri(image.dataUrl);
          final fetched = await fetcher(uri, cancelToken);
          if (cancelToken?.isCancelled ?? false) {
            throw const ZcodeCliException(
              'cancelled',
              'ZCode request was canceled.',
            );
          }
          final mediaType = _normalizeZcodeImageMediaType(fetched.mediaType);
          if (fetched.bytes.isEmpty ||
              fetched.bytes.length > _zcodeMaxImageBytes) {
            throw const ZcodeCliException(
              'unsupported_media',
              'ZCode image exceeds the size limit.',
            );
          }
          resolvedImage = ZcodeImageInput(
            'data:$mediaType;base64,${base64Encode(fetched.bytes)}',
            mediaType,
          );
        }
        images.add(resolvedImage);
        contentParts.add(ZcodeContentPart.image(resolvedImage));
      }
      resolvedMessages.add(
        ZcodeChatMessage(
          role: message.role,
          content: message.content,
          contentParts: List.unmodifiable(contentParts),
          images: List.unmodifiable(images),
          toolCalls: message.toolCalls,
          toolCallId: message.toolCallId,
          toolName: message.toolName,
        ),
      );
    }
    return ZcodeChatRequest(
      messages: List.unmodifiable(resolvedMessages),
      tools: tools,
      maxOutputTokens: maxOutputTokens,
    );
  }
}

Uri _validatePublicImageUri(String reference) {
  final uri = Uri.tryParse(reference);
  final host = uri?.host.toLowerCase() ?? '';
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal') ||
      host == 'metadata.google.internal' ||
      !_isPublicIpLiteral(host)) {
    throw const ZcodeCliException(
      'unsupported_media',
      'Image URL is invalid or points to a blocked address.',
    );
  }
  return uri;
}

bool _isPublicIpLiteral(String host) {
  final address = InternetAddress.tryParse(host);
  if (address == null) return true;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    final a = bytes[0];
    final b = bytes[1];
    final c = bytes[2];
    return a != 0 &&
        a != 10 &&
        a != 127 &&
        a < 224 &&
        !(a == 100 && b >= 64 && b <= 127) &&
        !(a == 169 && b == 254) &&
        !(a == 172 && b >= 16 && b <= 31) &&
        !(a == 192 && (b == 0 || b == 168)) &&
        !(a == 198 && (b == 18 || b == 19 || b == 51 && c == 100)) &&
        !(a == 203 && b == 0 && c == 113);
  }
  if (bytes.every((byte) => byte == 0) ||
      bytes.take(15).every((byte) => byte == 0) && bytes.last == 1 ||
      bytes[0] & 0xfe == 0xfc ||
      bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80 ||
      bytes[0] & 0xe0 != 0x20 ||
      bytes[0] == 0x20 &&
          bytes[1] == 0x01 &&
          bytes[2] == 0x0d &&
          bytes[3] == 0xb8) {
    return false;
  }
  return true;
}

String _normalizeZcodeImageMediaType(String mediaType) {
  final normalized = mediaType.split(';').first.trim().toLowerCase();
  if (!const {
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/gif',
    'image/webp',
  }.contains(normalized)) {
    throw const ZcodeCliException(
      'unsupported_media',
      'Unsupported ZCode image format.',
    );
  }
  return normalized == 'image/jpg' ? 'image/jpeg' : normalized;
}

Future<List<InternetAddress>> _resolvePublicImageAddresses(
  Uri uri, {
  required ZcodeImageAddressLookup lookup,
  required Duration timeout,
  CancelToken? cancelToken,
}) async {
  final literal = InternetAddress.tryParse(uri.host);
  final addresses = literal == null
      ? await _lookupImageHost(
          uri.host,
          lookup: lookup,
          timeout: timeout,
          cancelToken: cancelToken,
        )
      : [literal];
  if (addresses.isEmpty ||
      addresses.any((address) => !_isPublicIpLiteral(address.address))) {
    throw const ZcodeCliException(
      'unsupported_media',
      'Image URL points to a blocked address.',
    );
  }
  return addresses;
}

Future<List<InternetAddress>> _lookupImageHost(
  String host, {
  required ZcodeImageAddressLookup lookup,
  required Duration timeout,
  CancelToken? cancelToken,
}) {
  final timedLookup = lookup(host).timeout(
    timeout,
    onTimeout: () => throw const ZcodeCliException(
      'image_dns_timeout',
      'Image URL host lookup timed out.',
    ),
  );
  if (cancelToken == null) return timedLookup;
  if (cancelToken.isCancelled) {
    throw const ZcodeCliException('cancelled', 'ZCode request was canceled.');
  }
  return Future.any([
    timedLookup,
    cancelToken.whenCancel.then<List<InternetAddress>>(
      (_) => throw const ZcodeCliException(
        'cancelled',
        'ZCode request was canceled.',
      ),
    ),
  ]);
}

Dio _dioPinnedToImageAddresses(Uri uri, List<InternetAddress> addresses) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: _zcodeImageFetchTimeout,
      receiveTimeout: _zcodeImageFetchTimeout,
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (_) => 'DIRECT';
      client.connectionFactory = (requestUri, proxyHost, proxyPort) {
        if (proxyHost != null ||
            proxyPort != null ||
            requestUri.host != uri.host ||
            requestUri.port != uri.port) {
          throw const SocketException('Unexpected image connection target.');
        }
        return Socket.startConnect(addresses.first, requestUri.port);
      };
      return client;
    },
  );
  return dio;
}

Future<ZcodeFetchedImage> _fetchPublicZcodeImage(
  Uri initialUri,
  CancelToken? cancelToken, {
  required ZcodeImageAddressLookup addressLookup,
  required Duration dnsTimeout,
}) async {
  var uri = initialUri;
  try {
    for (var hop = 0; hop <= _zcodeMaxImageRedirects; hop++) {
      uri = _validatePublicImageUri(uri.toString());
      final addresses = await _resolvePublicImageAddresses(
        uri,
        lookup: addressLookup,
        timeout: dnsTimeout,
        cancelToken: cancelToken,
      );
      final dio = _dioPinnedToImageAddresses(uri, addresses);
      try {
        final response = await dio.get<ResponseBody>(
          uri.toString(),
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            maxRedirects: 0,
            validateStatus: (status) => status != null,
          ),
        );
        Future<void> discardResponseBody() async {
          final body = response.data;
          if (body != null) {
            await body.stream.listen((_) {}).cancel();
          }
        }

        final status = response.statusCode ?? 0;
        if (status >= 300 && status < 400) {
          final location = response.headers.value('location');
          if (location == null || hop == _zcodeMaxImageRedirects) {
            await discardResponseBody();
            throw const ZcodeCliException(
              'unsupported_media',
              'Image URL has too many redirects.',
            );
          }
          await discardResponseBody();
          uri = uri.resolve(location);
          continue;
        }
        if (status != 200 || response.data == null) {
          await discardResponseBody();
          throw const ZcodeCliException(
            'unsupported_media',
            'Could not fetch the image URL.',
          );
        }
        late final String mediaType;
        try {
          mediaType = _normalizeZcodeImageMediaType(
            response.headers.value('content-type') ?? '',
          );
        } on ZcodeCliException {
          await discardResponseBody();
          rethrow;
        }
        final contentLength = int.tryParse(
          response.headers.value('content-length') ?? '',
        );
        if (contentLength != null && contentLength > _zcodeMaxImageBytes) {
          await discardResponseBody();
          throw const ZcodeCliException(
            'unsupported_media',
            'ZCode image exceeds the size limit.',
          );
        }
        final bytes = BytesBuilder(copy: false);
        var length = 0;
        await for (final chunk in response.data!.stream.timeout(
          _zcodeImageFetchTimeout,
        )) {
          length += chunk.length;
          if (length > _zcodeMaxImageBytes) {
            throw const ZcodeCliException(
              'unsupported_media',
              'ZCode image exceeds the size limit.',
            );
          }
          bytes.add(chunk);
        }
        return ZcodeFetchedImage(
          Uint8List.fromList(bytes.takeBytes()),
          mediaType,
        );
      } finally {
        dio.close(force: true);
      }
    }
    throw const ZcodeCliException(
      'unsupported_media',
      'Image URL has too many redirects.',
    );
  } on ZcodeCliException {
    rethrow;
  } on DioException {
    if (cancelToken?.isCancelled ?? false) {
      throw const ZcodeCliException(
        'cancelled',
        'ZCode request was canceled.',
      );
    }
    throw const ZcodeCliException(
      'unsupported_media',
      'Could not fetch the image URL.',
    );
  } on SocketException {
    if (cancelToken?.isCancelled ?? false) {
      throw const ZcodeCliException(
        'cancelled',
        'ZCode request was canceled.',
      );
    }
    throw const ZcodeCliException(
      'unsupported_media',
      'Image URL host could not be resolved.',
    );
  }
}

({String text, List<ZcodeImageInput> images, List<ZcodeContentPart> parts})
    _content(
  Object? value,
  String role,
  bool vision,
) {
  if (value == null) {
    return (text: '', images: const [], parts: const []);
  }
  if (value is String) {
    return (
      text: value,
      images: const [],
      parts: value.isEmpty ? const [] : [ZcodeContentPart.text(value)],
    );
  }
  if (value is! List) {
    throw const ZcodeCliException(
      'unsupported_media',
      'Unsupported ZCode content.',
    );
  }
  final text = StringBuffer();
  final images = <ZcodeImageInput>[];
  final parts = <ZcodeContentPart>[];
  for (final part in value) {
    if (part is String) {
      text.write(part);
      parts.add(ZcodeContentPart.text(part));
    } else if (part is Map &&
        const {'text', 'input_text', 'output_text'}.contains(part['type']) &&
        part['text'] is String) {
      text.write(part['text']);
      parts.add(ZcodeContentPart.text(part['text'] as String));
    } else if (part is Map && part['type'] == 'image_url' && role == 'user') {
      final url = _asMap(part['image_url'])['url'];
      if (url is! String || url.isEmpty) {
        throw const ZcodeCliException(
          'unsupported_media',
          'ZCode image URL is missing.',
        );
      }
      if (!vision) {
        throw const ZcodeCliException(
          'unsupported_media',
          'The selected ZCode model does not support image input.',
        );
      }
      if (!url.toLowerCase().startsWith('data:')) {
        _validatePublicImageUri(url);
        final image = ZcodeImageInput(url, '');
        images.add(image);
        parts.add(ZcodeContentPart.image(image));
        continue;
      }
      final match = RegExp(
        r'^data:(image/(?:png|jpeg|jpg|gif|webp));base64,([A-Za-z0-9+/=]+)$',
        caseSensitive: false,
      ).firstMatch(url);
      if (match == null) {
        throw const ZcodeCliException(
          'unsupported_media',
          'Unsupported ZCode image format.',
        );
      }
      if (match.group(2)!.length > ((_zcodeMaxImageBytes + 2) ~/ 3) * 4) {
        throw const ZcodeCliException(
          'unsupported_media',
          'ZCode image exceeds the size limit.',
        );
      }
      try {
        if (base64Decode(match.group(2)!).length > _zcodeMaxImageBytes) {
          throw const FormatException();
        }
      } catch (_) {
        throw const ZcodeCliException(
          'unsupported_media',
          'Invalid ZCode image data.',
        );
      }
      final mediaType = match.group(1)!.toLowerCase();
      final image = ZcodeImageInput(
        url,
        mediaType == 'image/jpg' ? 'image/jpeg' : mediaType,
      );
      images.add(image);
      parts.add(ZcodeContentPart.image(image));
    } else {
      throw const ZcodeCliException(
        'unsupported_media',
        'ZCode supports text and model-approved image input only.',
      );
    }
  }
  return (
    text: text.toString(),
    images: List.unmodifiable(images),
    parts: List.unmodifiable(parts),
  );
}

class ZcodeCliResponse {
  final int statusCode;
  final Map<String, List<String>> headers;
  final Object body;

  const ZcodeCliResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
}

class ZcodeAppServerClient {
  final ZcodeCliProcessLauncher launcher;
  final ZcodeCliLaunch launch;
  final Duration startupTimeout;
  final Duration requestTimeout;
  ZcodeCliProcess? _process;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  final List<int> _buffer = [];
  final Map<int, Completer<Object?>> _pending = {};
  Completer<void>? _initialized;
  Completer<void>? _helloReady;
  int _nextRequestId = 1;
  bool _helloDone = false;
  bool _closed = false;
  Future<void>? _closeFuture;

  ZcodeAppServerClient({
    required this.launcher,
    required this.launch,
    this.startupTimeout = _zcodeStartupTimeout,
    this.requestTimeout = _zcodeRequestTimeout,
  });

  Future<void> start(String workspacePath) async {
    if (_closed) {
      throw const ZcodeCliException(
        'cancelled',
        'ZCode request was canceled.',
      );
    }
    final directory = Directory(workspacePath);
    final process =
        await launcher.start(launch, workingDirectory: directory.path);
    if (_closed) {
      await _terminateProcess(process);
      throw const ZcodeCliException(
        'cancelled',
        'ZCode request was canceled.',
      );
    }
    _process = process;
    _helloReady = Completer<void>();
    _initialized = Completer<void>();
    _stdoutSubscription = process.stdout.listen(
      _onStdout,
      onError: _onError,
      onDone: _onDone,
    );
    // Drain stderr without retaining it: local CLI output may contain secrets.
    _stderrSubscription = process.stderr.listen((_) {}, onError: (_) {});
    unawaited(process.exitCode.then((_) => _onDone(), onError: _onError));
    await Future.wait([
      _withTimeout(_helloReady!.future, startupTimeout, 'hello_timeout'),
      _withTimeout(_initialized!.future, startupTimeout, 'startup_timeout'),
    ]);
  }

  Future<Object?> call(
    String channel,
    String method,
    List<Object?> arguments,
  ) async {
    final process = _process;
    final initialized = _initialized;
    if (process == null || _closed || initialized == null) {
      throw const ZcodeCliException(
        'server_unavailable',
        'ZCode app-server is unavailable.',
      );
    }
    await _withTimeout(
      initialized.future,
      startupTimeout,
      'startup_timeout',
    );
    if (_closed || process != _process) {
      throw const ZcodeCliException(
        'server_unavailable',
        'ZCode app-server is unavailable.',
      );
    }
    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    process.writeStdin(
      ZcodeSocketProtocol.encodeCall(id, channel, method, arguments),
    );
    return _withTimeout(
      completer.future,
      requestTimeout,
      'request_timeout',
    ).whenComplete(() {
      _pending.remove(id);
    });
  }

  void _onStdout(List<int> data) {
    if (_closed) return;
    if (_buffer.length + data.length >
        _zcodeMaxFrameBytes + _zcodeMaxHelloBytes + 13) {
      _fail(
        const ZcodeCliException(
          'protocol_error',
          'ZCode protocol frame exceeds safety limit.',
        ),
      );
      return;
    }
    _buffer.addAll(data);
    if (!_helloDone) {
      final newline = _buffer.indexOf(10);
      if (newline < 0) {
        if (_buffer.length > _zcodeMaxHelloBytes) {
          _fail(
            const ZcodeCliException(
              'protocol_error',
              'ZCode hello line exceeds safety limit.',
            ),
          );
        }
        return;
      }
      if (newline > _zcodeMaxHelloBytes) {
        _fail(
          const ZcodeCliException(
            'protocol_error',
            'ZCode hello line exceeds safety limit.',
          ),
        );
        return;
      }
      try {
        final helloBytes = _buffer.sublist(0, newline);
        final hello = jsonDecode(utf8.decode(helloBytes));
        if (_asMap(hello)['type'] != 'zcode-hello') {
          throw const FormatException('Unexpected hello');
        }
        _buffer.removeRange(0, newline + 1);
        _process!.writeStdin(
          utf8.encode(
            '${jsonEncode({
                  'type': 'zcode-hello-ack',
                  'version': 'stroom',
                  'clientId': 'stroom-$pid'
                })}\n',
          ),
        );
        _helloDone = true;
        _helloReady?.complete();
      } catch (_) {
        _fail(
          const ZcodeCliException(
            'protocol_error',
            'ZCode app-server hello is invalid.',
          ),
        );
        return;
      }
    }
    while (_buffer.length >= 13) {
      final header = ByteData.sublistView(Uint8List.fromList(_buffer), 0, 13);
      final frameType = header.getUint8(0);
      final frameLength = header.getUint32(9);
      if (frameLength > _zcodeMaxFrameBytes) {
        _fail(
          const ZcodeCliException(
            'protocol_error',
            'ZCode protocol frame exceeds safety limit.',
          ),
        );
        return;
      }
      final total = frameLength + 13;
      if (_buffer.length < total) return;
      final frame = Uint8List.fromList(_buffer.sublist(0, total));
      _buffer.removeRange(0, total);
      if (frameType != 1) continue;
      try {
        _handleFrame(ZcodeSocketProtocol.decodeFrame(frame));
      } catch (_) {
        _fail(
          const ZcodeCliException(
            'protocol_error',
            'ZCode app-server sent an invalid frame.',
          ),
        );
        return;
      }
    }
  }

  void _handleFrame(ZcodeSocketFrame frame) {
    if (frame.header is! List || (frame.header as List).isEmpty) {
      throw const FormatException('Invalid message header');
    }
    final header = frame.header as List;
    final kind = header[0];
    if (kind == 200) {
      final initialized = _initialized;
      if (initialized != null && !initialized.isCompleted) {
        initialized.complete();
      }
      return;
    }
    if (![201, 202, 203].contains(kind) ||
        header.length < 2 ||
        header[1] is! int) {
      throw const FormatException('Invalid response ID');
    }
    final id = header[1] as int;
    final pending = _pending[id];
    if (pending == null || pending.isCompleted) return;
    if (kind == 201) {
      pending.complete(frame.payload);
    } else {
      pending.completeError(
        ZcodeCliException(
          'rpc_error',
          kind == 203
              ? 'ZCode app-server canceled the request.'
              : 'ZCode app-server request failed.',
        ),
      );
    }
  }

  void _onError(Object error) => _fail(
        const ZcodeCliException(
          'server_unavailable',
          'ZCode app-server disconnected.',
        ),
      );

  void _onDone() => _fail(
        const ZcodeCliException(
          'server_unavailable',
          'ZCode app-server disconnected.',
        ),
      );

  void _fail(Object error) {
    if (!(_helloReady?.isCompleted ?? true)) _helloReady!.completeError(error);
    if (!(_initialized?.isCompleted ?? true)) {
      _initialized!.completeError(error);
    }
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  Future<T> _withTimeout<T>(
    Future<T> future,
    Duration timeout,
    String code,
  ) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      throw ZcodeCliException(code, 'ZCode app-server request timed out.');
    }
  }

  Future<void> close() {
    final closing = _closeFuture;
    if (closing != null) return closing;
    _closed = true;
    return _closeFuture = _closeProcess();
  }

  Future<void> _closeProcess() async {
    final process = _process;
    _process = null;
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _fail(const ZcodeCliException('cancelled', 'ZCode request was canceled.'));
    if (process != null) await _terminateProcess(process);
  }

  Future<void> _terminateProcess(ZcodeCliProcess process) async {
    try {
      await process.closeStdin();
    } catch (_) {}
    await process.terminate();
    try {
      await process.exitCode.timeout(const Duration(seconds: 1));
    } on TimeoutException {
      await process.terminate(force: true);
      try {
        await process.exitCode.timeout(const Duration(seconds: 1));
      } catch (_) {}
    } catch (_) {}
  }
}

class ZcodeCliService {
  final ZcodeCliProcessLauncher _launcher;
  final bool Function() _supportsLocalProcess;
  final ZcodeCliLaunch? _launch;
  final ZcodeRemoteImageFetcher _imageFetcher;

  ZcodeCliService({
    ZcodeCliProcessLauncher? launcher,
    bool Function()? supportsLocalProcess,
    ZcodeCliLaunch? launch,
    ZcodeRemoteImageFetcher? imageFetcher,
    ZcodeImageAddressLookup? imageAddressLookup,
    Duration imageDnsTimeout = _zcodeImageFetchTimeout,
  })  : _launcher = launcher ?? const IoZcodeCliProcessLauncher(),
        _supportsLocalProcess = supportsLocalProcess ??
            (() => !kIsWeb && !Platform.isAndroid && !Platform.isIOS),
        _launch = launch,
        _imageFetcher = imageFetcher ??
            ((uri, cancelToken) => _fetchPublicZcodeImage(uri, cancelToken,
                addressLookup: imageAddressLookup ?? InternetAddress.lookup,
                dnsTimeout: imageDnsTimeout));

  Future<ZcodeServerStatusResult> status() async {
    if (!_supportsLocalProcess()) {
      return const ZcodeServerStatusResult(
        ZcodeServerStatus.serverUnavailable,
        'desktop_only',
      );
    }
    final workspace = await _privateWorkspace();
    final client = _client();
    try {
      await client.start(workspace.path);
      final initialize = _asMap(
        await client.call('zcode-agent', 'initialize', [
          {
            'workspacePath': workspace.path,
            'workspaceIdentity': workspace.path,
          },
        ]),
      );
      if (initialize['available'] != true) {
        return const ZcodeServerStatusResult(
          ZcodeServerStatus.modelServiceNotReady,
          'model_service_not_ready',
        );
      }
      final view = await client.call('model-selection', 'getView', const []);
      final providers = _asMap(view)['providers'];
      if (providers is! List) {
        return const ZcodeServerStatusResult(
          ZcodeServerStatus.unknownProtocolError,
          'protocol_error',
        );
      }
      if (providers.isEmpty) {
        return const ZcodeServerStatusResult(
          ZcodeServerStatus.modelServiceNotReady,
          'model_service_not_ready',
        );
      }
      final accountSignedOut = providers.whereType<Map>().any(
            (provider) =>
                provider['providerId'] ==
                    'account:zai-individual-coding-plan' &&
                (provider['authenticated'] == false ||
                    provider['signedIn'] == false ||
                    provider['status'] == 'signed-out' ||
                    provider['status'] == 'signed_out'),
          );
      final available = _availableModels(view);
      if (available.isEmpty) {
        if (accountSignedOut) {
          return const ZcodeServerStatusResult(
            ZcodeServerStatus.signedOut,
            'signed_out',
          );
        }
        return const ZcodeServerStatusResult(
          ZcodeServerStatus.noEnabledCodingPlanModel,
          'model_unavailable',
        );
      }
      return const ZcodeServerStatusResult(ZcodeServerStatus.ready, 'ready');
    } on ProcessException catch (error) {
      return ZcodeServerStatusResult(
        error.errorCode == 2 || error.errorCode == -2
            ? ZcodeServerStatus.binaryMissing
            : ZcodeServerStatus.serverUnavailable,
        error.errorCode == 2 || error.errorCode == -2
            ? 'binary_missing'
            : 'server_unavailable',
      );
    } on ZcodeCliException catch (error) {
      return ZcodeServerStatusResult(
        error.code == 'startup_timeout' || error.code == 'hello_timeout'
            ? ZcodeServerStatus.serverUnavailable
            : error.code == 'protocol_error'
                ? ZcodeServerStatus.unknownProtocolError
                : ZcodeServerStatus.serverUnavailable,
        error.code,
      );
    } catch (_) {
      return const ZcodeServerStatusResult(
        ZcodeServerStatus.unknownProtocolError,
        'protocol_error',
      );
    } finally {
      await client.close();
      await _deleteWorkspace(workspace);
    }
  }

  Future<List<ZcodeModel>> discoverModels({Object? view}) async {
    if (!_supportsLocalProcess()) {
      throw const ZcodeCliException(
        'desktop_only',
        'ZCode is available only in the Stroom desktop app.',
      );
    }
    final modelView = view ?? await _readView();
    return _availableModels(modelView);
  }

  Future<Object?> _readView() async {
    final workspace = await _privateWorkspace();
    final client = _client();
    try {
      await client.start(workspace.path);
      final initialized = _asMap(
        await client.call('zcode-agent', 'initialize', [
          {
            'workspacePath': workspace.path,
            'workspaceIdentity': workspace.path,
          },
        ]),
      );
      if (initialized['available'] != true) {
        throw const ZcodeCliException(
          'model_service_not_ready',
          'ZCode model service is not ready.',
        );
      }
      return await client.call('model-selection', 'getView', const []);
    } finally {
      await client.close();
      await _deleteWorkspace(workspace);
    }
  }

  List<ZcodeModel> _availableModels(Object? view) {
    final result = <ZcodeModel>[];
    for (final source in const [
      'account:zai-individual-coding-plan',
      'builtin:zai-coding-plan',
    ]) {
      for (final model in zcodePinnedModels) {
        try {
          resolveZcodeModelSelection(view, model.id, providerId: source);
          if (result.every((item) => item.id != model.id)) result.add(model);
        } on ZcodeCliException catch (error) {
          if (error.code != 'model_unavailable') rethrow;
          continue;
        }
      }
    }
    return result.take(_zcodeMaxModels).toList(growable: false);
  }

  Future<ZcodeModelSelection> _waitForModelSelection(
    ZcodeAppServerClient client,
    String modelId, {
    CancelToken? cancelToken,
  }) async {
    final deadline = DateTime.now().add(_zcodeStartupTimeout);
    while (true) {
      if (cancelToken?.isCancelled ?? false) {
        throw const ZcodeCliException(
          'cancelled',
          'ZCode request was canceled.',
        );
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw const ZcodeCliException(
          'model_unavailable',
          'No enabled ZCode Coding Plan model matches the selected model.',
        );
      }
      final view =
          await client.call('model-selection', 'getView', const []).timeout(
        remaining,
        onTimeout: () => throw const ZcodeCliException(
          'model_service_not_ready',
          'ZCode model service did not become ready.',
        ),
      );
      try {
        return resolveZcodeModelSelection(view, modelId);
      } on ZcodeCliException catch (error) {
        if (error.code != 'model_unavailable' ||
            DateTime.now().isAfter(deadline)) {
          rethrow;
        }
      }
      final delay = deadline.difference(DateTime.now());
      if (delay <= Duration.zero) {
        throw const ZcodeCliException(
          'model_unavailable',
          'No enabled ZCode Coding Plan model matches the selected model.',
        );
      }
      final pollDelay = delay < const Duration(milliseconds: 250)
          ? delay
          : const Duration(milliseconds: 250);
      if (cancelToken == null) {
        await Future<void>.delayed(pollDelay);
      } else {
        await Future.any<void>([
          Future<void>.delayed(pollDelay),
          cancelToken.whenCancel.then<void>(
            (_) => throw const ZcodeCliException(
              'cancelled',
              'ZCode request was canceled.',
            ),
          ),
        ]);
      }
    }
  }

  Future<ZcodeCliResponse> request({
    required String modelId,
    required Map<String, dynamic> body,
    bool stream = false,
    CancelToken? cancelToken,
    Future<void> Function()? onRequestSent,
  }) async {
    if (!_supportsLocalProcess()) {
      throw const ZcodeCliException(
        'desktop_only',
        'ZCode is available only in the Stroom desktop app.',
      );
    }
    if (cancelToken?.isCancelled ?? false) {
      throw const ZcodeCliException(
        'cancelled',
        'ZCode request was canceled.',
      );
    }
    final model =
        zcodePinnedModels.where((item) => item.id == modelId).firstOrNull;
    if (model == null) {
      throw const ZcodeCliException('invalid_model', 'Unknown ZCode model.');
    }
    final parsedRequest = ZcodeChatRequest.fromChatCompletionsBody(
      body,
      modelSupportsVision: model.supportsVision,
    );
    final request = await parsedRequest.resolveRemoteImages(
      fetcher: _imageFetcher,
      cancelToken: cancelToken,
    );
    final workspace = await _privateWorkspace();
    final client = _client();
    if (cancelToken != null) {
      unawaited(
        cancelToken.whenCancel.then<void>(
          (_) => unawaited(client.close()),
          onError: (_) {},
        ),
      );
    }
    try {
      await client.start(workspace.path);
      final initialized = _asMap(
        await client.call('zcode-agent', 'initialize', [
          {
            'workspacePath': workspace.path,
            'workspaceIdentity': workspace.path,
          },
        ]),
      );
      if (initialized['available'] != true) {
        throw const ZcodeCliException(
          'model_service_not_ready',
          'ZCode model service is not ready.',
        );
      }
      final selected = await _waitForModelSelection(
        client,
        modelId,
        cancelToken: cancelToken,
      );
      final maxTokens = selected.maxOutputTokens ?? model.maxOutputTokens;
      final outputTokens = math
          .min(
            request.maxOutputTokens ?? maxTokens,
            maxTokens,
          )
          .toInt();
      final generationArguments = [
        {
          'workspacePath': workspace.path,
          'workspaceIdentity': workspace.path,
          'selection': {
            'providerId': selected.providerId,
            'modelId': selected.modelId,
            if (selected.reasoningLevel != null)
              'options': {'reasoningLevel': selected.reasoningLevel},
          },
          'messages': [
            for (final message in request.messages) _messageMap(message),
          ],
          'tools': [
            for (final tool in request.tools)
              {
                'name': tool.name,
                'description': tool.description,
                'inputSchema': tool.inputSchema,
              },
          ],
          'maxOutputTokens': outputTokens,
          'querySource': 'stroom',
          'requestTimeoutMs': _zcodeRequestTimeout.inMilliseconds,
        },
      ];
      try {
        ZcodeSocketProtocol.encodeCall(
          1,
          'zcode-agent',
          'generateWorkspaceText',
          generationArguments,
        );
      } on ArgumentError {
        throw const ZcodeCliException(
          'invalid_request',
          'ZCode request exceeds the maximum safe size.',
        );
      }
      await onRequestSent?.call();
      final result = _asMap(
        await client.call(
          'zcode-agent',
          'generateWorkspaceText',
          generationArguments,
        ),
      );
      final completion = _completion(modelId, result);
      final output = stream ? _streamCompletion(completion) : completion;
      return ZcodeCliResponse(
        statusCode: 200,
        headers: {
          'content-type': [
            stream ? 'text/event-stream; charset=utf-8' : 'application/json',
          ],
        },
        body: output,
      );
    } finally {
      await client.close();
      await _deleteWorkspace(workspace);
    }
  }

  Map<String, Object?> _messageMap(ZcodeChatMessage message) => {
        'role': message.role,
        'content': [
          for (final part in message.contentParts)
            if (part.text != null)
              {'type': 'text', 'text': part.text}
            else if (part.image != null)
              {
                'type': 'image',
                'dataUrl': part.image!.dataUrl,
                'mediaType': part.image!.mediaType,
              },
        ],
        if (message.toolCalls.isNotEmpty)
          'toolCalls': [
            for (final call in message.toolCalls)
              {'id': call.id, 'name': call.name, 'input': call.arguments},
          ],
        if (message.toolCallId != null) 'toolCallId': message.toolCallId,
        if (message.toolName != null) 'toolName': message.toolName,
      };

  Object _completion(String model, Map<String, dynamic> result) {
    final rawCalls = result['toolCalls'];
    final toolCalls = <Map<String, dynamic>>[];
    if (rawCalls is List) {
      if (rawCalls.length > _zcodeMaxTools) {
        throw const ZcodeCliException(
          'protocol_error',
          'ZCode returned too many tool calls.',
        );
      }
      for (final rawCall in rawCalls) {
        if (rawCall is! Map ||
            rawCall['id'] is! String ||
            rawCall['name'] is! String) {
          throw const ZcodeCliException(
            'protocol_error',
            'ZCode returned an invalid tool call.',
          );
        }
        toolCalls.add({
          'id': rawCall['id'],
          'type': 'function',
          'function': {
            'name': rawCall['name'],
            'arguments': jsonEncode(
              rawCall['input'] is Map
                  ? rawCall['input']
                  : const <String, dynamic>{},
            ),
          },
        });
      }
    }
    final usage = _asMap(result['usage']);
    final promptTokens = _safeTokenCount(usage['inputTokens']);
    final completionTokens = _safeTokenCount(usage['outputTokens']);
    final text = result['text'];
    return {
      'id': 'chatcmpl-zcode-${DateTime.now().microsecondsSinceEpoch}',
      'object': 'chat.completion',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': text is String ? text : '',
            if (toolCalls.isNotEmpty) 'tool_calls': toolCalls,
          },
          'finish_reason': toolCalls.isNotEmpty
              ? 'tool_calls'
              : result['finishReason'] == 'length' ||
                      result['finishReason'] == 'max-tokens'
                  ? 'length'
                  : 'stop',
        },
      ],
      'usage': {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': _safeTokenCount(
          usage['totalTokens'],
          fallback: promptTokens + completionTokens,
        ),
      },
    };
  }

  Stream<List<int>> _streamCompletion(Object body) {
    final response = _asMap(body);
    final choices = response['choices'] as List;
    final choice = _asMap(choices.first);
    final message = _asMap(choice['message']);
    final rawCalls = message['tool_calls'] is List
        ? message['tool_calls'] as List
        : const [];
    final calls = [
      for (var index = 0; index < rawCalls.length; index++)
        {...Map<String, dynamic>.from(rawCalls[index] as Map), 'index': index},
    ];
    final base = {
      'id': response['id'],
      'object': 'chat.completion.chunk',
      'created': response['created'],
      'model': response['model'],
    };
    final chunks = [
      {
        ...base,
        'choices': [
          {
            'index': 0,
            'delta': {
              'role': 'assistant',
              'content': message['content'],
              if (calls.isNotEmpty) 'tool_calls': calls,
            },
            'finish_reason': null,
          },
        ],
      },
      {
        ...base,
        'choices': [
          {'index': 0, 'delta': {}, 'finish_reason': choice['finish_reason']},
        ],
        'usage': response['usage'],
      },
    ];
    final encoded =
        '${chunks.map((chunk) => 'data: ${jsonEncode(chunk)}\n\n').join()}data: [DONE]\n\n';
    return Stream<List<int>>.value(utf8.encode(encoded));
  }

  ZcodeAppServerClient _client() => ZcodeAppServerClient(
        launcher: _launcher,
        launch: _launch ?? const ZcodeCliLaunch(executable: 'zcode'),
      );

  Future<Directory> _privateWorkspace() async {
    final root = await Directory.systemTemp.createTemp('stroom-zcode-');
    await root.create(recursive: true);
    return root;
  }

  Future<void> _deleteWorkspace(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {}
  }
}

Map<String, dynamic> _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _safeTokenCount(Object? value, {int fallback = 0}) =>
    value is num && value >= 0 && value <= 0x7fffffff
        ? value.toInt()
        : fallback;
