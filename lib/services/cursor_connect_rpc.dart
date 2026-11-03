import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class CursorConnectRpcException implements Exception {
  final String code;
  const CursorConnectRpcException(this.code);
}

class CursorAgentDelta {
  final String? text;
  final String? reasoning;
  final Map<String, int>? usage;
  final bool turnEnded;
  final int? requestContextId;
  final String? execId;
  final int? mcpStateId;
  final String? mcpServerIdentifier;
  final int? keyValueId;
  final bool? keyValueSet;
  final bool? keyValueGet;
  final Uint8List? keyValueBlobId;
  final Uint8List? requestMetadata;
  final String? unsupportedAction;

  const CursorAgentDelta({
    this.text,
    this.reasoning,
    this.usage,
    this.turnEnded = false,
    this.requestContextId,
    this.execId,
    this.mcpStateId,
    this.mcpServerIdentifier,
    this.keyValueId,
    this.keyValueSet,
    this.keyValueGet,
    this.keyValueBlobId,
    this.requestMetadata,
    this.unsupportedAction,
  });
}

class CursorConnectFrameDecoder {
  Uint8List _pending = Uint8List(0);

  void finish() {
    if (_pending.isNotEmpty) {
      throw const CursorConnectRpcException('truncated_frame');
    }
  }

  List<CursorAgentDelta> add(List<int> bytes) {
    _pending = Uint8List.fromList([..._pending, ...bytes]);
    final deltas = <CursorAgentDelta>[];
    var offset = 0;
    while (_pending.length - offset >= 5) {
      final flags = _pending[offset];
      final length = ByteData.sublistView(
        _pending,
        offset + 1,
        offset + 5,
      ).getUint32(0, Endian.big);
      if (length > 16 * 1024 * 1024) {
        throw const CursorConnectRpcException('invalid_frame');
      }
      if (_pending.length - offset - 5 < length) break;
      final raw = _pending.sublist(offset + 5, offset + 5 + length);
      offset += 5 + length;
      if ((flags & 0x02) != 0) {
        final trailerBytes = (flags & 0x01) != 0
            ? GZipDecoder().decodeBytes(raw)
            : raw;
        final trailer = _decodeJsonObject(trailerBytes);
        final nestedError = trailer['error'];
        final error = nestedError is Map
            ? Map<String, dynamic>.from(nestedError)
            : const <String, dynamic>{};
        final code = error['code'] ?? trailer['code'];
        if ((nestedError is Map && nestedError.isNotEmpty) ||
            (code != null && code != 'ok')) {
          throw CursorConnectRpcException(
            'upstream_${code?.toString().isNotEmpty == true ? code : 'error'}',
          );
        }
        continue;
      }
      final payload = (flags & 0x01) != 0
          ? GZipDecoder().decodeBytes(raw)
          : raw;
      deltas.addAll(decodeAgentServerMessage(payload));
    }
    _pending = Uint8List.fromList(_pending.sublist(offset));
    return deltas;
  }

  static Uri decodeAgentRunEndpoint(
    List<int> response, {
    bool ghostMode = true,
  }) {
    final topLevel = _fields(response);
    final config = topLevel
        .where((field) => field.number == 27 && field.bytes != null)
        .firstOrNull;
    if (config?.bytes == null) {
      throw const CursorConnectRpcException('invalid_agent_endpoint');
    }
    final endpointFields = _fields(config!.bytes!);
    final agentUrl = _stringValue(endpointFields, ghostMode ? 1 : 2);
    if (agentUrl == null) {
      throw const CursorConnectRpcException('invalid_agent_endpoint');
    }
    final uri = Uri.tryParse(agentUrl);
    final host = uri?.host.toLowerCase() ?? '';
    final allowedHost =
        host == 'api5.cursor.sh' || host.endsWith('.api5.cursor.sh');
    if (uri == null ||
        uri.scheme != 'https' ||
        !allowedHost ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const CursorConnectRpcException('invalid_agent_endpoint');
    }
    return uri.replace(
      path: '/agent.v1.AgentService/Run',
      query: null,
      fragment: null,
    );
  }

  static Uint8List encodeRequest({
    required String modelId,
    required String conversationId,
    required Map<String, dynamic> body,
    Map<String, Uint8List>? blobStore,
  }) {
    final messages = body['messages'];
    if (messages is! Iterable) {
      throw const CursorConnectRpcException('invalid_request');
    }
    final tools = body['tools'];
    if (tools is Iterable && tools.isNotEmpty) {
      throw const CursorConnectRpcException('unsupported_tools');
    }
    final systemText = <String>[];
    final turns = <String>[];
    final images = <Uint8List>[];
    var onlyUserTurn = true;
    var turnCount = 0;
    String? singleUserText;
    for (final raw in messages) {
      if (raw is! Map || raw['role'] is! String) {
        throw const CursorConnectRpcException('invalid_request');
      }
      final role = (raw['role'] as String).toLowerCase();
      if (!const {'system', 'user', 'assistant', 'tool'}.contains(role)) {
        throw const CursorConnectRpcException('invalid_request');
      }
      if (role != 'system') turnCount++;
      if (role != 'system' && role != 'user') onlyUserTurn = false;
      if (raw['tool_calls'] is Iterable &&
          (raw['tool_calls'] as Iterable).isNotEmpty) {
        throw const CursorConnectRpcException('unsupported_tools');
      }
      final content = _messageText(
        raw['content'],
        images: role == 'user' ? images : null,
      );
      if (content.isEmpty) continue;
      if (role == 'system') {
        systemText.add(content);
      } else if (role == 'user') {
        singleUserText = content;
        turns.add('User: $content');
      } else if (role == 'assistant') {
        turns.add('Assistant: $content');
      } else if (role == 'tool') {
        final toolCallId = raw['tool_call_id'] is String
            ? raw['tool_call_id'] as String
            : '(unknown)';
        turns.add('Tool result ($toolCallId): $content');
      } else {
        turns.add('$role: $content');
      }
    }
    if (images.length > 12) {
      throw const CursorConnectRpcException('unsupported_images');
    }
    final turnText = onlyUserTurn && turnCount == 1
        ? singleUserText ?? ''
        : turns.join('\n\n');
    final prompt = [
      if (systemText.isNotEmpty) systemText.join('\n\n'),
      if (turnText.isNotEmpty) turnText,
    ].join('\n\n');
    if (prompt.trim().isEmpty && images.isEmpty) {
      throw const CursorConnectRpcException('invalid_request');
    }

    // AgentRunRequest -> ConversationAction -> UserMessageAction.
    final selectedImages = <Uint8List>[];
    for (final image in images) {
      final uuid = const Uuid().v4();
      final mimeType = _imageMimeType(image);
      final extension = switch (mimeType) {
        'image/jpeg' => 'jpg',
        'image/gif' => 'gif',
        'image/webp' => 'webp',
        _ => 'png',
      };
      final imageBytes = _imageBytes(image);
      final blobId = Uint8List.fromList(sha256.convert(imageBytes).bytes);
      if (blobStore != null) {
        final blobIdHex = blobId
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
        blobStore[blobIdHex] = imageBytes;
      }
      selectedImages.add(
        _message(1, [
          _string(2, uuid),
          _string(3, 'attachment-$uuid.$extension'),
          _string(7, mimeType),
          _message(9, [_bytes(1, blobId), _bytes(2, imageBytes)]),
        ]),
      );
    }
    final rootPromptParts = <Uint8List>[];
    if (systemText.isNotEmpty && blobStore != null) {
      final rootPromptBytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({'role': 'system', 'content': systemText.join('\n\n')}),
        ),
      );
      final rootPromptDigest = Uint8List.fromList(
        sha256.convert(rootPromptBytes).bytes,
      );
      final digestHex = rootPromptDigest
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      blobStore[digestHex] = rootPromptBytes;
      rootPromptParts.add(_bytes(1, rootPromptDigest));
    }
    final userMessage = _message(1, [
      _string(1, prompt),
      _string(2, const Uuid().v4()),
      _message(3, [_message(1, selectedImages)]),
      _varint(4, 1), // UserMessage.mode
    ]);
    final action = _message(2, [
      _message(1, [
        _message(1, [userMessage]),
      ]),
    ]);
    final requested = _resolveRequestedModel(modelId, body['reasoning_effort']);
    final details = _message(3, [
      _string(1, requested.modelId),
      _string(3, requested.modelId),
      _string(4, requested.modelId),
    ]);
    final emptyTools = _message(4, const []);
    final requestedModel = _message(9, [
      _string(1, requested.modelId),
      for (final parameter in requested.parameters)
        _message(3, [_string(1, parameter.$1), _string(2, parameter.$2)]),
    ]);
    final request = _message(1, [
      _message(1, rootPromptParts), // ConversationStateStructure
      action,
      details,
      emptyTools,
      _string(5, conversationId),
      requestedModel,
      _varint(12, 1), // no workspace context is exposed to this chat caller
      _string(16, conversationId),
    ]);
    return _frame(request);
  }

  static ({String modelId, List<(String, String)> parameters})
  _resolveRequestedModel(String modelId, Object? reasoningEffort) {
    var id = modelId.trim();
    final parameters = <(String, String)>[];
    if (id == 'auto') return (modelId: 'default', parameters: parameters);
    for (final level in ['cost', 'balance', 'intelligence']) {
      if (id == 'auto-$level') {
        return (modelId: 'default', parameters: [('optimization', level)]);
      }
    }
    final grok47 = RegExp(
      r'^cursor-grok-4\.7-(low|medium|high|xhigh)(-fast)?-(256k|500k)$',
    ).firstMatch(id);
    if (grok47 != null) {
      return (
        modelId: 'grok-4.7',
        parameters: [
          ('context', grok47[3]!),
          ('effort', grok47[1]!),
          ('fast', '${grok47[2] != null}'),
        ],
      );
    }
    if (id.endsWith('-1m')) {
      final legacy = id.substring(0, id.length - 3);
      final gpt = RegExp(
        r'^(gpt-5\.6-(?:sol|terra|luna))-(none|low|medium|high|xhigh|max)(-fast)?$',
      ).firstMatch(legacy);
      if (gpt != null) {
        return (
          modelId: gpt[1]!,
          parameters: [
            ('context', '1m'),
            ('reasoning', gpt[2]!),
            ('fast', '${gpt[3] != null}'),
          ],
        );
      }
      const claudeFamilies = <String, (String, bool, bool)>{
        'claude-fable-5-1': ('claude-fable-5-1', false, false),
        'claude-opus-5': ('claude-opus-5', true, false),
        'claude-opus-4-8': ('claude-opus-4-8', true, false),
        'claude-sonnet-5': ('claude-sonnet-5', false, false),
        'claude-4.6-sonnet': ('claude-sonnet-4-6', false, true),
      };
      for (final entry in claudeFamilies.entries) {
        if (!legacy.startsWith('${entry.key}-')) continue;
        var variant = legacy.substring(entry.key.length + 1);
        final fast = variant.endsWith('-fast');
        if (fast) variant = variant.substring(0, variant.length - 5);
        final trailingThinking =
            entry.value.$3 && variant.endsWith('-thinking');
        final leadingThinking =
            !entry.value.$3 && variant.startsWith('thinking-');
        if (trailingThinking) {
          variant = variant.substring(0, variant.length - 9);
        }
        if (leadingThinking) variant = variant.substring(9);
        if (!['low', 'medium', 'high', 'xhigh', 'max'].contains(variant) ||
            (fast && !entry.value.$2)) {
          break;
        }
        return (
          modelId: entry.value.$1,
          parameters: [
            ('thinking', '${trailingThinking || leadingThinking}'),
            ('context', '1m'),
            ('effort', variant),
            if (entry.value.$2) ('fast', '$fast'),
          ],
        );
      }
    }
    if (id.startsWith('composer-') && id.endsWith('-fast')) {
      id = id.substring(0, id.length - 5);
      parameters.add(('fast', 'true'));
    } else {
      final grokPrefix = id.startsWith('cursor-grok-')
          ? 'cursor-grok-'
          : id.startsWith('grok-')
          ? 'grok-'
          : null;
      if (grokPrefix != null) {
        final fast = id.endsWith('-fast');
        if (fast) id = id.substring(0, id.length - 5);
        for (final level in ['low', 'medium', 'high', 'xhigh', 'max']) {
          if (id.endsWith('-$level') &&
              id.length > grokPrefix.length + level.length + 1) {
            id = id.substring(0, id.length - level.length - 1);
            parameters.add(('effort', level));
            break;
          }
        }
        if (fast) parameters.add(('fast', 'true'));
      } else {
        final prefix = id.startsWith('claude-')
            ? 'claude-'
            : id.startsWith('gpt-')
            ? 'gpt-'
            : null;
        if (prefix != null) {
          for (final level in ['low', 'medium', 'high', 'xhigh', 'max']) {
            if (id.endsWith('-$level') &&
                id.length > prefix.length + level.length + 1) {
              id = id.substring(0, id.length - level.length - 1);
              parameters.add((
                prefix == 'gpt-' ? 'reasoning' : 'effort',
                level,
              ));
              break;
            }
          }
        }
      }
    }
    final effort = reasoningEffort is String ? reasoningEffort : null;
    if (effort != null &&
        !parameters.any((p) => p.$1 == 'effort' || p.$1 == 'reasoning')) {
      final param = id.startsWith('gpt-') ? 'reasoning' : 'effort';
      if (['low', 'medium', 'high', 'xhigh', 'max'].contains(effort) &&
          (id.startsWith('gpt-') ||
              id.startsWith('claude-') ||
              id.startsWith('grok-') ||
              id.startsWith('cursor-grok-'))) {
        parameters.add((param, effort));
      }
    }
    return (modelId: id, parameters: parameters);
  }

  static Uint8List encodeRequestContextAck(int id, String execId) => _frame(
    _message(2, [
      _varint(1, id),
      _string(15, execId),
      _message(10, [
        _message(1, [_message(1, const [])]),
      ]),
    ]),
  );

  static Uint8List encodeMcpStateAck({
    required int id,
    required String execId,
    required String serverIdentifier,
  }) => _frame(
    _message(2, [
      _varint(1, id),
      _string(15, execId),
      _message(36, [
        _message(1, [
          _message(1, [
            _string(1, serverIdentifier),
            _string(2, serverIdentifier),
            _string(7, 'ready'),
          ]),
        ]),
      ]),
    ]),
  );

  static Uint8List encodeKeyValueAck({
    required int id,
    required bool set,
    Uint8List? blobData,
    Uint8List? requestMetadata,
  }) {
    final payload = <Uint8List>[
      if (id != 0) _varint(1, id),
      _message(
        set ? 3 : 2,
        set ? const [] : [_bytes(1, blobData ?? Uint8List(0))],
      ),
      if (requestMetadata != null && requestMetadata.isNotEmpty)
        _bytes(4, requestMetadata),
    ];
    return _frame(_message(3, payload));
  }

  static List<CursorAgentDelta> decodeAgentServerMessage(List<int> payload) {
    final output = <CursorAgentDelta>[];
    for (final top in _fields(payload)) {
      if (top.number == 1 && top.bytes != null) {
        for (final update in _fields(top.bytes!)) {
          if (update.number == 1 && update.bytes != null) {
            output.add(CursorAgentDelta(text: _nestedText(update.bytes!)));
          } else if (update.number == 4 && update.bytes != null) {
            output.add(CursorAgentDelta(reasoning: _nestedText(update.bytes!)));
          } else if (update.number == 7) {
            // The source protocol uses field 7 for partial tool-call activity.
            // Stroom cannot resume these provider-owned tools, so reject the
            // action before a later KV checkpoint can look like turn-end.
            output.add(const CursorAgentDelta(unsupportedAction: 'tools'));
          } else if (update.number == 14 && update.bytes != null) {
            final usage = _fields(update.bytes!);
            final input = _integer(usage, 1);
            final tokens = _integer(usage, 2);
            output.add(
              CursorAgentDelta(
                turnEnded: true,
                usage: input == null && tokens == null
                    ? null
                    : {
                        'prompt_tokens': ?input,
                        'completion_tokens': ?tokens,
                        if (input != null || tokens != null)
                          'total_tokens': (input ?? 0) + (tokens ?? 0),
                      },
              ),
            );
          } else if (update.number == 2 || update.number == 3) {
            output.add(const CursorAgentDelta(unsupportedAction: 'tools'));
          }
        }
      } else if (top.number == 2 && top.bytes != null) {
        final fields = _fields(top.bytes!);
        final id = _integer(fields, 1) ?? 0;
        final execId = _stringValue(fields, 15) ?? '';
        if (fields.any((field) => field.number == 10)) {
          output.add(CursorAgentDelta(requestContextId: id, execId: execId));
        } else if (fields.any((field) => field.number == 36)) {
          final stateArgs = fields.firstWhere((field) => field.number == 36);
          final serverIdentifier = stateArgs.bytes == null
              ? null
              : _fields(stateArgs.bytes!)
                    .where((field) => field.number == 1 && field.bytes != null)
                    .map((field) => utf8.decode(field.bytes!))
                    .firstWhere(
                      (value) => value.trim().isNotEmpty,
                      orElse: () => 'stroom',
                    );
          output.add(
            CursorAgentDelta(
              mcpStateId: id,
              execId: execId,
              mcpServerIdentifier: serverIdentifier ?? 'stroom',
            ),
          );
        } else {
          final actionField = fields
              .where(
                (field) =>
                    field.number != 1 &&
                    field.number != 15 &&
                    field.number != 19 &&
                    field.number != 57,
              )
              .firstOrNull;
          if (actionField != null) {
            output.add(
              CursorAgentDelta(unsupportedAction: 'exec_${actionField.number}'),
            );
          }
        }
      } else if (top.number == 4 && top.bytes != null) {
        final fields = _fields(top.bytes!);
        final id = _integer(fields, 1) ?? 0;
        final set = fields.any((field) => field.number == 3);
        final get = fields.any((field) => field.number == 2);
        if (set || get) {
          final getArgs = fields
              .where((field) => field.number == 2 && field.bytes != null)
              .firstOrNull;
          output.add(
            CursorAgentDelta(
              keyValueId: id,
              keyValueSet: set,
              keyValueGet: get,
              keyValueBlobId: getArgs == null
                  ? null
                  : _bytesValue(_fields(getArgs.bytes!), 1),
              requestMetadata: _bytesValue(fields, 4),
            ),
          );
        }
      }
    }
    return output;
  }

  static Uint8List encodeSseChunk({
    required String id,
    required String model,
    String? text,
    String? reasoning,
    Map<String, int>? usage,
    bool done = false,
  }) {
    final chunk = <String, dynamic>{
      'id': id,
      'object': 'chat.completion.chunk',
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'model': model,
      'choices': [
        {
          'index': 0,
          'delta': {
            if (text != null && text.isNotEmpty) 'content': text,
            if (reasoning != null && reasoning.isNotEmpty)
              'reasoning_content': reasoning,
          },
          'finish_reason': done ? 'stop' : null,
        },
      ],
      'usage': ?usage,
    };
    return Uint8List.fromList(utf8.encode('data: ${jsonEncode(chunk)}\n\n'));
  }

  /// Composer models return private thinking followed by their visible reply in
  /// a dedicated sentinel format. Only return the suffix after the final end
  /// marker; never pass the prefix through Stroom's reasoning channel.
  static String visibleComposerReply(String thinking) {
    final end = thinking.lastIndexOf('</think>');
    if (end < 0) return '';
    var visible = thinking.substring(end + '</think>'.length);
    final open = RegExp(r'^\s*<[｜|]\s*final\s*[｜|]>', caseSensitive: false);
    final close = RegExp(r'<[｜|]\s*/\s*final\s*[｜|]>$', caseSensitive: false);
    if (open.hasMatch(visible)) {
      visible = visible.replaceFirst(open, '');
    } else if (RegExp(r'^\s*<(?![｜|/])').hasMatch(visible) ||
        RegExp(r'^\s*<[｜|][^>]*$').hasMatch(visible)) {
      return '';
    }
    return visible.replaceFirst(close, '');
  }

  static Map<String, dynamic> _decodeJsonObject(List<int> bytes) {
    try {
      final value = jsonDecode(utf8.decode(bytes));
      return value is Map ? Map<String, dynamic>.from(value) : const {};
    } catch (_) {
      throw const CursorConnectRpcException('invalid_trailer');
    }
  }

  static String _messageText(Object? raw, {List<Uint8List>? images}) {
    if (raw is String) return raw;
    if (raw == null) return '';
    if (raw is Iterable) {
      final parts = <String>[];
      for (final item in raw) {
        if (item is! Map) {
          throw const CursorConnectRpcException('unsupported_content');
        }
        if (item['type'] == 'text') {
          if (item['text'] is! String) {
            throw const CursorConnectRpcException('unsupported_content');
          }
          parts.add(item['text'] as String);
        } else if (item['type'] == 'image' ||
            item['type'] == 'image_url' ||
            item['image_url'] != null) {
          if (images == null) {
            throw const CursorConnectRpcException('unsupported_images');
          }
          final imageUrl = item['image_url'];
          final reference = imageUrl is Map ? imageUrl['url'] : imageUrl;
          if (reference is! String) {
            throw const CursorConnectRpcException('unsupported_images');
          }
          final match = RegExp(
            r'^data:(image/(?:jpeg|jpg|png|gif|webp));base64,([A-Za-z0-9+/]+={0,2})$',
            caseSensitive: false,
          ).firstMatch(reference);
          if (match == null) {
            throw const CursorConnectRpcException('unsupported_images');
          }
          try {
            final decoded = base64Decode(match.group(2)!);
            final normalizedMime = match.group(1)!.toLowerCase() == 'image/jpg'
                ? 'image/jpeg'
                : match.group(1)!.toLowerCase();
            if (decoded.isEmpty || decoded.length > 1024 * 1024) {
              throw const CursorConnectRpcException('unsupported_images');
            }
            // Carry MIME alongside bytes until SelectedImage protobuf encoding.
            images.add(_imageEnvelope(normalizedMime, decoded));
          } on CursorConnectRpcException {
            rethrow;
          } catch (_) {
            throw const CursorConnectRpcException('unsupported_images');
          }
        } else {
          throw const CursorConnectRpcException('unsupported_content');
        }
      }
      return parts.join('\n');
    }
    throw const CursorConnectRpcException('unsupported_content');
  }

  static Uint8List _imageEnvelope(String mimeType, Uint8List bytes) {
    final mimeBytes = utf8.encode('$mimeType\u0000');
    return Uint8List.fromList([...mimeBytes, ...bytes]);
  }

  static String _imageMimeType(Uint8List image) {
    final separator = image.indexOf(0);
    if (separator <= 0) {
      throw const CursorConnectRpcException('unsupported_images');
    }
    return utf8.decode(image.sublist(0, separator));
  }

  static Uint8List _imageBytes(Uint8List image) {
    final separator = image.indexOf(0);
    if (separator <= 0) {
      throw const CursorConnectRpcException('unsupported_images');
    }
    return Uint8List.fromList(image.sublist(separator + 1));
  }

  static String _nestedText(List<int> bytes) =>
      _stringValue(_fields(bytes), 1) ?? '';

  static int? _integer(List<_ProtoField> fields, int number) =>
      fields.where((field) => field.number == number).firstOrNull?.value;

  static String? _stringValue(List<_ProtoField> fields, int number) {
    final bytes = _bytesValue(fields, number);
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } catch (_) {
      throw const CursorConnectRpcException('invalid_protobuf');
    }
  }

  static Uint8List? _bytesValue(List<_ProtoField> fields, int number) =>
      fields.where((field) => field.number == number).firstOrNull?.bytes;

  static List<_ProtoField> _fields(List<int> input) {
    final bytes = Uint8List.fromList(input);
    final fields = <_ProtoField>[];
    var offset = 0;
    while (offset < bytes.length) {
      final tag = _readVarint(bytes, offset);
      offset = tag.$2;
      final number = tag.$1 >> 3;
      final wire = tag.$1 & 7;
      if (number == 0) {
        throw const CursorConnectRpcException('invalid_protobuf');
      }
      if (wire == 0) {
        final value = _readVarint(bytes, offset);
        fields.add(_ProtoField(number, value: value.$1));
        offset = value.$2;
      } else if (wire == 2) {
        final length = _readVarint(bytes, offset);
        offset = length.$2;
        final end = offset + length.$1;
        if (end > bytes.length) {
          throw const CursorConnectRpcException('invalid_protobuf');
        }
        fields.add(_ProtoField(number, bytes: bytes.sublist(offset, end)));
        offset = end;
      } else if (wire == 1) {
        offset += 8;
        if (offset > bytes.length) {
          throw const CursorConnectRpcException('invalid_protobuf');
        }
      } else if (wire == 5) {
        offset += 4;
        if (offset > bytes.length) {
          throw const CursorConnectRpcException('invalid_protobuf');
        }
      } else {
        throw const CursorConnectRpcException('invalid_protobuf');
      }
    }
    return fields;
  }

  static (int, int) _readVarint(Uint8List bytes, int offset) {
    var value = 0;
    var shift = 0;
    while (offset < bytes.length && shift < 64) {
      final byte = bytes[offset++];
      value |= (byte & 0x7f) << shift;
      if (byte < 0x80) return (value, offset);
      shift += 7;
    }
    throw const CursorConnectRpcException('invalid_protobuf');
  }

  static Uint8List _message(int number, List<Uint8List> parts) =>
      _bytes(number, Uint8List.fromList(parts.expand((part) => part).toList()));

  static Uint8List _string(int number, String value) =>
      _bytes(number, Uint8List.fromList(utf8.encode(value)));

  static Uint8List _varint(int number, int value) => Uint8List.fromList([
    ..._encodeVarint((number << 3)),
    ..._encodeVarint(value),
  ]);

  static Uint8List _bytes(int number, List<int> value) => Uint8List.fromList([
    ..._encodeVarint((number << 3) | 2),
    ..._encodeVarint(value.length),
    ...value,
  ]);

  static Uint8List _frame(List<int> payload) => Uint8List.fromList([
    0,
    (payload.length >> 24) & 0xff,
    (payload.length >> 16) & 0xff,
    (payload.length >> 8) & 0xff,
    payload.length & 0xff,
    ...payload,
  ]);

  static List<int> _encodeVarint(int value) {
    final bytes = <int>[];
    while (value >= 0x80) {
      bytes.add((value & 0x7f) | 0x80);
      value >>= 7;
    }
    bytes.add(value);
    return bytes;
  }
}

/// Emits only newly visible Composer reply text as thinking deltas arrive.
class CursorComposerReplyDecoder {
  final StringBuffer _thinking = StringBuffer();
  var _emittedLength = 0;

  String add(String delta) {
    _thinking.write(delta);
    final visible = CursorConnectFrameDecoder.visibleComposerReply(
      _thinking.toString(),
    );
    if (visible.length <= _emittedLength) return '';
    final result = visible.substring(_emittedLength);
    _emittedLength = visible.length;
    return result;
  }

  String finish() {
    final visible = CursorConnectFrameDecoder.visibleComposerReply(
      _thinking.toString(),
    );
    if (visible.length <= _emittedLength) return '';
    final result = visible.substring(_emittedLength);
    _emittedLength = visible.length;
    return result;
  }
}

class _ProtoField {
  final int number;
  final int? value;
  final Uint8List? bytes;

  const _ProtoField(this.number, {this.value, this.bytes});
}
