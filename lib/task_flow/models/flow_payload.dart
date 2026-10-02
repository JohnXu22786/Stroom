import 'package:flutter/foundation.dart' show immutable;
import 'package:mime/mime.dart';

import 'io_type.dart';

/// Upper bound for image inputs before the chat attachment pipeline reads
/// their full bytes. Images above the document limit may be compressed, but
/// still need a bound on the initial allocation.
const int maxFlowImageInputBytes = 20 * 1024 * 1024;

/// A block's value with its media kind preserved across the flow chain.
/// File references are local paths (or WebFileStore keys), never chat text.
@immutable
class FlowPayload {
  final IOType type;
  final String text;
  final String? fileReference;

  /// Media metadata from an upstream block. For shared containers such as MP4,
  /// this preserves the track kind that filename/header MIME cannot establish.
  final String? mimeType;

  const FlowPayload.text(this.text, {this.type = IOType.text})
    : fileReference = null,
      mimeType = null;

  const FlowPayload.file({
    required this.fileReference,
    required this.type,
    this.text = '',
    this.mimeType,
  });

  factory FlowPayload.fromValue(
    String value,
    IOType type, {
    String? mimeType,
  }) => isFileType(type)
      ? FlowPayload.file(fileReference: value, type: type, mimeType: mimeType)
      : FlowPayload.text(value, type: type);

  bool get isFile => fileReference != null;
  String get value => fileReference ?? text;

  static bool isFileType(IOType type) => const [
    IOType.audio,
    IOType.image,
    IOType.video,
    IOType.file,
  ].contains(type);

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'text': text,
    if (fileReference != null) 'fileReference': fileReference,
    if (mimeType != null) 'mimeType': mimeType,
  };

  factory FlowPayload.fromMap(Map<String, dynamic> map) {
    final type = IOType.fromJson(map['type'] as String? ?? 'text');
    final text = map['text'] as String? ?? '';
    final reference = map['fileReference'] as String?;
    return reference == null
        ? FlowPayload.text(text, type: type)
        : FlowPayload.file(
            fileReference: reference,
            type: type,
            text: text,
            mimeType: map['mimeType'] as String?,
          );
  }
}

/// Use the chat composer's MIME lookup, preserving an MP4 container's audio
/// track metadata (or its explicit M4A filename). An `ftypisom` header identifies
/// the container, not whether it contains video. Strongly different headers,
/// such as PNG or MP3, still take precedence over filename/upstream metadata.
String flowFileMimeType(
  String reference, {
  List<int>? headerBytes,
  String? mimeType,
}) {
  final detected =
      lookupMimeType(reference, headerBytes: headerBytes) ??
      'application/octet-stream';
  bool isMp4(String? mime) => const {
    'audio/mp4',
    'audio/x-m4a',
    'video/mp4',
  }.contains(mime?.split(';').first.trim().toLowerCase());
  if (isMp4(detected)) {
    if (isMp4(mimeType)) {
      return flowMimeType(mimeType) == IOType.audio ? 'audio/mp4' : 'video/mp4';
    }
    final named = lookupMimeType(reference);
    if (isMp4(named) && flowMimeType(named) == IOType.audio) return 'audio/mp4';
  }
  return detected;
}

IOType flowFileType(String reference, {List<int>? headerBytes}) =>
    flowMimeType(flowFileMimeType(reference, headerBytes: headerBytes));

IOType flowMimeType(String? mimeType) {
  final mime = mimeType?.toLowerCase() ?? '';
  if (mime.startsWith('image/')) return IOType.image;
  if (mime.startsWith('audio/')) return IOType.audio;
  if (mime.startsWith('video/')) return IOType.video;
  return IOType.file;
}
