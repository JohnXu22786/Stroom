import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../utils/file_record.dart';
import '../utils/audio_utils.dart'
    show detectAudioFormat, normalizeAudioFormat, normalizeAsrUploadFormat;

/// Local media tools that operate only on attachments in their owning chat.
class ChatMediaToolService {
  static const String mediaListToolName = 'stroom_media_list';
  static const String ocrToolName = 'stroom_ocr';
  static const String asrToolName = 'stroom_asr';

  static List<Attachment> attachmentsFromMessages(
    Iterable<ChatMessage> messages,
  ) =>
      [
        for (final message in messages) ...message.attachments,
      ];

  static const List<ToolDefinition> toolDefinitions = [
    ToolDefinition(
      name: mediaListToolName,
      description:
          'List visible images and audio files saved in the Stroom library. '
          'Use a returned record ID with stroom_ocr or stroom_asr.',
      parameters: {
        'type': 'object',
        'properties': {
          'media_type': {
            'type': 'string',
            'enum': ['all', 'image', 'audio'],
            'description': 'Which library media to list; defaults to all.',
          },
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 50,
            'description': 'Maximum records to return; defaults to 20.',
          },
        },
        'required': <String>[],
      },
    ),
    ToolDefinition(
      name: ocrToolName,
      description:
          'Extract text from an image attached in this conversation or an '
          'image in the Stroom library. Use image_id for a library image; '
          'otherwise attachment_index selects a chat attachment. If both are '
          'omitted, use the newest image attachment.',
      parameters: {
        'type': 'object',
        'properties': {
          'image_id': {
            'type': 'string',
            'description': 'Opaque record ID from stroom_media_list.',
          },
          'attachment_index': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Optional zero-based index among image attachments '
                'in this conversation; defaults to the newest image.',
          },
        },
        'required': <String>[],
      },
    ),
    ToolDefinition(
      name: asrToolName,
      description:
          'Transcribe audio attached in this conversation or an audio file '
          'in the Stroom library. Use audio_id for a library file; otherwise '
          'attachment_index selects a chat attachment. If both are omitted, '
          'use the newest audio attachment.',
      parameters: {
        'type': 'object',
        'properties': {
          'audio_id': {
            'type': 'string',
            'description': 'Opaque record ID from stroom_media_list.',
          },
          'attachment_index': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Optional zero-based index among audio attachments '
                'in this conversation; defaults to the newest audio.',
          },
        },
        'required': <String>[],
      },
    ),
    ToolDefinition(
      name: 'stroom_tts',
      description: 'Generate speech from text using the configured Stroom TTS '
          'provider and save the audio to the Stroom audio library.',
      parameters: {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'minLength': 1,
            'description': 'Text to speak.',
          },
          'title': {
            'type': 'string',
            'description': 'Optional name for the saved audio file.',
          },
        },
        'required': ['text'],
      },
    ),
  ];

  /// Resolve only a typed attachment from the current conversation. The
  /// returned list is in chronological order, matching the tool description.
  static Attachment? selectAttachment(
    List<Attachment> attachments, {
    required String fileType,
    required Object? index,
  }) {
    final matching = attachments.where((item) => item.fileType == fileType);
    if (matching.isEmpty) return null;
    if (index == null) return matching.last;
    if (index is! int || index < 0 || index >= matching.length) return null;
    return matching.elementAt(index);
  }

  static String imageFormat(Attachment attachment, {String? mimeType}) {
    final extension =
        p.extension(attachment.fileName).replaceFirst('.', '').toLowerCase();
    final mimeFormat =
        switch ((mimeType ?? attachment.mimeType).toLowerCase()) {
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/bmp' => 'bmp',
      'image/jpeg' || 'image/jpg' => 'jpeg',
      _ => '',
    };
    if (mimeType != null && mimeFormat.isNotEmpty) return mimeFormat;
    return switch (extension) {
      'jpg' || 'jpeg' => 'jpeg',
      'png' || 'gif' || 'webp' || 'bmp' => extension,
      _ => mimeFormat,
    };
  }

  static String audioFormat(Attachment attachment, Uint8List bytes) {
    final detected = normalizeAudioFormat(detectAudioFormat(bytes));
    final extension =
        p.extension(attachment.fileName).replaceFirst('.', '').toLowerCase();
    final format = detected == 'pcm' ? extension : detected;
    return normalizeAsrUploadFormat(format);
  }

  static String formatMediaList(
    List<FileRecord> records, {
    required String type,
    int limit = 20,
  }) {
    final boundedLimit = limit.clamp(1, 50);
    final ordered = [...records]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jsonEncode([
      for (final record in ordered.take(boundedLimit))
        {
          'id': record.id,
          'name': record.name,
          'type': type,
          'format': record.format,
          'size': record.size,
          'folder': record.folder,
          'created_at': record.createdAt.toIso8601String(),
        },
    ]);
  }

  static T? findRecordById<T extends FileRecord>(List<T> records, Object? id) {
    if (id is! String || id.trim().isEmpty) return null;
    for (final record in records) {
      if (record.id == id.trim()) return record;
    }
    return null;
  }

  static Future<String> handleLibraryList(
    Map<String, dynamic> args, {
    required Future<List<FileRecord>> Function() loadImages,
    required Future<List<FileRecord>> Function() loadAudio,
  }) async {
    final mediaType = args['media_type'] ?? 'all';
    if (mediaType is! String ||
        !{'all', 'image', 'audio'}.contains(mediaType)) {
      return 'Error: media_type must be all, image, or audio.';
    }
    final rawLimit = args['limit'];
    final limit = rawLimit ?? 20;
    if (limit is! int || limit < 1 || limit > 50) {
      return 'Error: limit must be an integer from 1 to 50.';
    }
    final records = <Map<String, dynamic>>[];
    if (mediaType == 'all' || mediaType == 'image') {
      records.addAll(
        jsonDecode(
          formatMediaList(await loadImages(), type: 'image', limit: 50),
        ).cast<Map<String, dynamic>>(),
      );
    }
    if (mediaType == 'all' || mediaType == 'audio') {
      records.addAll(
        jsonDecode(
          formatMediaList(await loadAudio(), type: 'audio', limit: 50),
        ).cast<Map<String, dynamic>>(),
      );
    }
    records.sort(
      (a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );
    return jsonEncode(records.take(limit).toList());
  }

  static Future<String> handleOcr(
    Map<String, dynamic> args, {
    required List<Attachment> attachments,
    required Future<String> Function(Attachment) recognize,
    Future<String> Function(String imageId)? recognizeLibraryImage,
  }) async {
    final imageId = args['image_id'];
    if (imageId != null) {
      if (imageId is! String || imageId.trim().isEmpty) {
        return 'Error: image_id must be a library record ID.';
      }
      if (args['attachment_index'] != null) {
        return 'Error: provide image_id or attachment_index, not both.';
      }
      final recognizeLibrary = recognizeLibraryImage;
      if (recognizeLibrary == null) {
        return 'Error: Stroom library image access is unavailable.';
      }
      return recognizeLibrary(imageId.trim());
    }
    final index = args['attachment_index'];
    final attachment = selectAttachment(
      attachments,
      fileType: 'image',
      index: index,
    );
    if (attachment == null) {
      return index == null
          ? 'Error: this conversation has no image attachment to read.'
          : 'Error: attachment_index does not identify an image in this conversation.';
    }
    return recognize(attachment);
  }

  static Future<String> handleAsr(
    Map<String, dynamic> args, {
    required List<Attachment> attachments,
    required Future<String> Function(Attachment) transcribe,
    Future<String> Function(String audioId)? transcribeLibraryAudio,
  }) async {
    final audioId = args['audio_id'];
    if (audioId != null) {
      if (audioId is! String || audioId.trim().isEmpty) {
        return 'Error: audio_id must be a library record ID.';
      }
      if (args['attachment_index'] != null) {
        return 'Error: provide audio_id or attachment_index, not both.';
      }
      final transcribeLibrary = transcribeLibraryAudio;
      if (transcribeLibrary == null) {
        return 'Error: Stroom library audio access is unavailable.';
      }
      return transcribeLibrary(audioId.trim());
    }
    final index = args['attachment_index'];
    final attachment = selectAttachment(
      attachments,
      fileType: 'audio',
      index: index,
    );
    if (attachment == null) {
      return index == null
          ? 'Error: this conversation has no audio attachment to transcribe.'
          : 'Error: attachment_index does not identify audio in this conversation.';
    }
    return transcribe(attachment);
  }

  static Future<String> handleTts(
    Map<String, dynamic> args, {
    required Future<String?> Function(String text, String title) synthesize,
  }) async {
    final text = args['text'];
    if (text is! String || text.trim().isEmpty) {
      return 'Error: text must contain something to speak.';
    }
    final titleRaw = args['title'];
    final title = titleRaw is String ? titleRaw.trim() : '';
    final result = await synthesize(text.trim(), title);
    return result ??
        'Error: speech generation did not complete. Check the TTS provider and try again.';
  }
}
