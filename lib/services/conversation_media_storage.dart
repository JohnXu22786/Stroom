import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/stroom_conversation.dart';
import 'attachment_storage.dart';

typedef ConversationMediaWriter = Future<String> Function(
  String fileName,
  Uint8List bytes, {
  String? stableId,
});
typedef ConversationMediaReader = Future<Uint8List?> Function(String path);

/// Removes inline media bytes from captured protocol JSON while retaining
/// metadata and marking the position where the media reference was removed.
Map<String, dynamic> sanitizeConversationMediaJson(
  Map<String, dynamic> value,
) =>
    _sanitizeExtensionMap(value);

/// Moves inline provider media out of a neutral message before repository
/// persistence. Source protocol metadata remains, with byte payloads replaced
/// by a stable M2 reference.
Future<StroomMessage> externalizeConversationMedia(
  StroomMessage message, {
  ConversationMediaWriter? saveFile,
}) async {
  final writer = saveFile ?? AttachmentStorage.saveFile;
  final content = <StroomContentPart>[];
  var index = 0;
  for (final part in message.content) {
    final candidate = _inlineMedia(part);
    if (candidate == null) {
      content.add(
        StroomContentPart(
          type: part.type,
          data: _sanitizeExtensionMap(part.data),
          extraFields: _sanitizeExtensions(part.extraFields),
        ),
      );
      continue;
    }
    final path = await writer(
      _mediaFileName(part, candidate.mimeType),
      candidate.bytes,
      stableId: '${message.id}_$index',
    );
    index++;
    final source = part.data['source'];
    content.add(
      StroomContentPart(
        type: part.type,
        data: {
          for (final entry in part.data.entries)
            if (!{'inlineData', 'data', 'base64Data'}.contains(entry.key) &&
                entry.key != 'source' &&
                !_isInlineDataUrl(entry.value))
              entry.key: _sanitizeInlineMetadata(entry.value),
          'reference': path,
          'storagePath': path,
          'mimeType': candidate.mimeType,
          'size': candidate.bytes.length,
          'hash': AttachmentStorage.computeHash(candidate.bytes),
          'sha256': sha256.convert(candidate.bytes).toString(),
          if (source is Map) 'source': _stripInlinePayloads(source),
        },
        extraFields: _sanitizeExtensions(part.extraFields),
      ),
    );
  }
  return StroomMessage(
    id: message.id,
    role: message.role,
    sequence: message.sequence,
    createdAt: message.createdAt,
    content: content,
    status: message.status,
    finishReason: message.finishReason,
    usage: message.usage,
    extensions: _sanitizeExtensions(message.extensions),
    extraFields: _sanitizeExtensionMap(message.extraFields),
    diagnostics: message.diagnostics == null
        ? null
        : StroomMessageDiagnostics.fromMap({
            if (message.diagnostics!.rawRequest != null)
              'rawRequest':
                  _sanitizeExtensionMap(message.diagnostics!.rawRequest!),
            if (message.diagnostics!.rawResponse != null)
              'rawResponse':
                  _sanitizeExtensionMap(message.diagnostics!.rawResponse!),
          }),
  );
}

/// Resolves local M2 references in an outbound Chat/Task Flow request map.
/// Provider URLs and already encoded data URLs are left untouched.
Future<List<Map<String, dynamic>>> resolveConversationMediaReferences(
  List<Map<String, dynamic>> messages, {
  ConversationMediaReader? readFile,
}) async {
  final reader = readFile ?? AttachmentStorage.readFile;
  final output = <Map<String, dynamic>>[];
  for (final message in messages) {
    output.add(await _resolveMap(message, reader));
  }
  return output;
}

Future<Map<String, dynamic>> _resolveMap(
  Map source,
  ConversationMediaReader reader,
) async {
  final mimeType = _string(source['mimeType'] ?? source['mime_type']);
  final output = <String, dynamic>{};
  for (final entry in source.entries) {
    final key = '${entry.key}';
    final value = entry.value;
    if (key == 'fileData' &&
        value is Map &&
        value['fileUri'] is String &&
        _isLocalMediaPath(value['fileUri'] as String)) {
      final path = value['fileUri'] as String;
      final bytes = await reader(path);
      if (bytes == null) {
        throw StateError('Conversation media is unavailable: $path');
      }
      output['inlineData'] = {
        'mimeType': _string(value['mimeType']).isNotEmpty
            ? value['mimeType']
            : _mimeFromPath(path),
        'data': base64Encode(bytes),
      };
      continue;
    }
    if (value is Map) {
      output[key] = await _resolveMap(value, reader);
    } else if (value is List) {
      output[key] = [
        for (final child in value)
          if (child is Map) await _resolveMap(child, reader) else child,
      ];
    } else if (value is String &&
        _isLocalMediaPath(value) &&
        const {
          'reference',
          'storagePath',
          'url',
          'file_data',
          'file_url',
          'file_uri',
          'fileUri',
          'data',
          'image_url',
          'audio_url',
          'video_url',
        }.contains(key)) {
      final bytes = await reader(value);
      if (bytes == null) {
        throw StateError('Conversation media is unavailable: $value');
      }
      final effectiveMime = mimeType.isEmpty ? _mimeFromPath(value) : mimeType;
      output[key] = switch (key) {
        'fileUri' => value,
        'data' => base64Encode(bytes),
        _ => 'data:$effectiveMime;base64,${base64Encode(bytes)}',
      };
    } else {
      output[key] = value;
    }
  }
  return output;
}

_InlineMedia? _inlineMedia(StroomContentPart part) {
  if (!const {'image', 'audio', 'video', 'file', 'media'}.contains(part.type)) {
    return null;
  }
  final inlineData = part.data['inlineData'];
  if (inlineData is Map && inlineData['data'] is String) {
    final bytes = _decodeBase64(inlineData['data'] as String);
    if (bytes != null) {
      return _InlineMedia(
        bytes,
        _string(inlineData['mimeType'] ?? part.data['mimeType']),
      );
    }
  }
  final reference = part.data['reference'];
  if (reference is String) {
    final inlineReference = _inlineFromUrl(reference);
    if (inlineReference != null) return inlineReference;
  }
  final imageUrl = part.data['imageUrl'] ?? part.data['audioUrl'];
  if (imageUrl is String) {
    final inlineUrl = _inlineFromUrl(imageUrl);
    if (inlineUrl != null) return inlineUrl;
  } else if (imageUrl is Map && imageUrl['url'] is String) {
    final inlineUrl = _inlineFromUrl(imageUrl['url'] as String);
    if (inlineUrl != null) return inlineUrl;
  }
  final source = part.data['source'];
  if (source is Map) return _inlineFromSource(source);
  return null;
}

_InlineMedia? _inlineFromSource(Map source) {
  for (final key in const [
    'inlineData',
    'input_audio',
    'output_audio',
    'audio',
    'file',
    'document',
    'source',
  ]) {
    final value = source[key];
    if (value is Map) {
      final mimeType = _string(
        value['mimeType'] ??
            value['mime_type'] ??
            value['media_type'] ??
            source['mime_type'],
      );
      final resolvedMimeType = mimeType.isNotEmpty
          ? mimeType
          : _audioMimeFromFormat(_string(value['format']));
      final rawData = value['data'];
      if (rawData is String) {
        _InlineMedia? inline;
        if (rawData.startsWith('data:')) {
          inline = _inlineFromUrl(rawData);
        } else if (value['type'] == 'base64' ||
            resolvedMimeType.isNotEmpty ||
            value['format'] is String) {
          final bytes = _decodeBase64(rawData);
          if (bytes != null) inline = _InlineMedia(bytes, resolvedMimeType);
        }
        if (inline != null) return inline;
      }
      final fileData = value['file_data'];
      if (fileData is String) {
        final inline = _inlineFromUrl(fileData);
        if (inline != null) return inline;
      }
      if (value['url'] is String) {
        final inline = _inlineFromUrl(value['url'] as String);
        if (inline != null) return inline;
      }
    }
  }
  for (final key in const ['image_url', 'audio_url', 'video_url']) {
    final value = source[key];
    final url = value is Map ? value['url'] : value;
    if (url is String) {
      final inline = _inlineFromUrl(url);
      if (inline != null) return inline;
    }
  }
  return null;
}

_InlineMedia? _inlineFromUrl(String value) {
  final match = RegExp(
    r'^data:([^;,]+)(?:;[^,]+)*;base64,(.*)$',
    dotAll: true,
  ).firstMatch(value);
  if (match == null) return null;
  final bytes = _decodeBase64(match.group(2)!);
  return bytes == null ? null : _InlineMedia(bytes, match.group(1)!);
}

Uint8List? _decodeBase64(String value) {
  try {
    final decoded = base64Decode(value);
    if (decoded.isEmpty) return null;
    return Uint8List.fromList(decoded);
  } on FormatException {
    return null;
  }
}

Map<String, dynamic> _stripInlinePayloads(Map value, {String? parentKey}) {
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = '${entry.key}';
    final child = entry.value;
    if (child is Map) {
      result[key] = _stripInlinePayloads(child, parentKey: key);
    } else if (child is List) {
      result[key] = _sanitizeInlineList(
        key,
        child,
        (map) => _stripInlinePayloads(map, parentKey: key),
      );
    } else if (child is String &&
        _isInlineExtensionPayload(key, child, value, parentKey: parentKey)) {
      result['stroomMediaReference'] = true;
    } else {
      result[key] = _sanitizeExtensionValue(child);
    }
  }
  return result;
}

dynamic _sanitizeInlineMetadata(Object? value) {
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = '${entry.key}';
      if (_isInlineDataUrl(entry.value)) {
        result['stroomMediaReference'] = true;
      } else {
        result[key] = _sanitizeInlineMetadata(entry.value);
      }
    }
    return result;
  }
  if (value is List) {
    return value.map(_sanitizeInlineMetadata).toList();
  }
  return value;
}

bool _isInlineDataUrl(Object? value) =>
    value is String && value.startsWith('data:') && value.contains(';base64,');

Map<String, dynamic> _sanitizeExtensions(Map<String, dynamic> extensions) => {
      for (final extension in extensions.entries)
        extension.key: _sanitizeExtensionValue(extension.value),
    };

Object? _sanitizeExtensionValue(Object? value) {
  if (value is Map) return _sanitizeExtensionMap(value);
  if (value is List) {
    return [for (final item in value) _sanitizeExtensionValue(item)];
  }
  if (value is String &&
      (value.trimLeft().startsWith('{') || value.trimLeft().startsWith('['))) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return jsonEncode(_sanitizeExtensionMap(decoded));
      if (decoded is List) {
        return jsonEncode([
          for (final item in decoded) _sanitizeExtensionValue(item),
        ]);
      }
    } on FormatException {
      // Arbitrary extension strings are preserved as-is.
    }
  }
  return value;
}

Map<String, dynamic> _sanitizeExtensionMap(Map value, {String? parentKey}) {
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = '${entry.key}';
    final child = entry.value;
    if (child is Map) {
      result[key] = _sanitizeExtensionMap(child, parentKey: key);
    } else if (child is List) {
      result[key] = _sanitizeInlineList(
        key,
        child,
        (map) => _sanitizeExtensionMap(map, parentKey: key),
      );
    } else if (child is String &&
        _isInlineExtensionPayload(key, child, value, parentKey: parentKey)) {
      result['stroomMediaReference'] = true;
    } else {
      result[key] = _sanitizeExtensionValue(child);
    }
  }
  return result;
}

List<Object?> _sanitizeInlineList(
  String key,
  List values,
  Map<String, dynamic> Function(Map) sanitizeMap,
) =>
    [
      for (final item in values)
        if (item is Map)
          sanitizeMap(item)
        else if (key == 'images' &&
            item is String &&
            (_isInlineDataUrl(item) || _decodeBase64(item) != null))
          {'stroomMediaReference': true}
        else
          item,
    ];

bool _isInlineExtensionPayload(
  String key,
  String value,
  Map parent, {
  String? parentKey,
}) =>
    (key == 'data' &&
        (parent.containsKey('mimeType') ||
            parent.containsKey('mime_type') ||
            parent.containsKey('media_type') ||
            parent.containsKey('format') ||
            parent['type'] == 'base64')) ||
    ({'url', 'file_data', 'imageUrl', 'audioUrl', 'videoUrl'}.contains(key) &&
        value.startsWith('data:')) ||
    (key == 'result' &&
        parent['type'] == 'image_generation_call' &&
        _decodeBase64(value) != null) ||
    (key == 'partial_image_b64' &&
        parent['type'] == 'response.image_generation_call.partial_image' &&
        _decodeBase64(value) != null) ||
    (key == 'delta' &&
        const {
          'response.output_audio.delta',
          'response.audio.delta',
        }.contains(parent['type']) &&
        _decodeBase64(value) != null) ||
    (key == 'data' &&
        const {'audio', 'input_audio', 'output_audio'}.contains(parentKey) &&
        _decodeBase64(value) != null);

String _audioMimeFromFormat(String? format) => switch (format?.toLowerCase()) {
      'mp3' || 'mpeg' => 'audio/mpeg',
      'wav' || 'wave' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'pcm' || 'pcm16' => 'audio/pcm',
      _ => '',
    };

String _mediaFileName(StroomContentPart part, String mimeType) {
  final explicit = part.data['fileName'];
  if (explicit is String && explicit.isNotEmpty) return explicit;
  final extension = switch (mimeType.toLowerCase()) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'audio/mpeg' => 'mp3',
    'audio/wav' || 'audio/x-wav' => 'wav',
    'audio/ogg' => 'ogg',
    'video/mp4' => 'mp4',
    'application/pdf' => 'pdf',
    _ => 'bin',
  };
  return '${part.type}.$extension';
}

String _mimeFromPath(String path) {
  final extension = path.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'ogg' => 'audio/ogg',
    'mp4' => 'video/mp4',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

bool _isLocalMediaPath(String value) =>
    value.startsWith('attachments/') || value.startsWith('temp_edited/');

String _string(Object? value) => value is String ? value : '';

class _InlineMedia {
  final Uint8List bytes;
  final String mimeType;

  const _InlineMedia(this.bytes, this.mimeType);
}
