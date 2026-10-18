import 'package:flutter/foundation.dart' show immutable;
import 'package:mime/mime.dart';

import 'io_type.dart';

/// Identifies a temporary file created by one task-flow block in one
/// execution. The reference is persisted with the result so cleanup can prove
/// ownership before deleting anything.
@immutable
class FlowTemporaryArtifact {
  final String executionId;
  final String blockId;
  final String reference;

  const FlowTemporaryArtifact({
    required this.executionId,
    required this.blockId,
    required this.reference,
  });

  Map<String, dynamic> toMap() => {
        'executionId': executionId,
        'blockId': blockId,
        'reference': reference,
      };

  factory FlowTemporaryArtifact.fromMap(Map<String, dynamic> map) =>
      FlowTemporaryArtifact(
        executionId: map['executionId'] as String,
        blockId: map['blockId'] as String,
        reference: map['reference'] as String,
      );
}

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
  final String? fileName;

  /// Media metadata from an upstream block. For shared containers such as MP4,
  /// this preserves the track kind that filename/header MIME cannot establish.
  final String? mimeType;

  /// Present only when [fileReference] is owned by a temporary flow step.
  final FlowTemporaryArtifact? temporaryArtifact;

  const FlowPayload.text(this.text, {this.type = IOType.text})
      : fileReference = null,
        fileName = null,
        mimeType = null,
        temporaryArtifact = null;

  const FlowPayload.file({
    required this.fileReference,
    required this.type,
    this.text = '',
    this.fileName,
    this.mimeType,
    this.temporaryArtifact,
  });

  factory FlowPayload.fromValue(
    String value,
    IOType type, {
    String? mimeType,
    String? fileName,
    FlowTemporaryArtifact? temporaryArtifact,
  }) =>
      isFileType(type)
          ? FlowPayload.file(
              fileReference: value,
              type: type,
              mimeType: mimeType,
              fileName: fileName,
              temporaryArtifact: temporaryArtifact)
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
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (temporaryArtifact != null)
          'temporaryArtifact': temporaryArtifact!.toMap(),
      };

  FlowPayload withTemporaryArtifact(FlowTemporaryArtifact? artifact) =>
      FlowPayload.file(
        fileReference: fileReference!,
        type: type,
        text: text,
        fileName: fileName,
        mimeType: mimeType,
        temporaryArtifact: artifact,
      );

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
            fileName: map['fileName'] as String?,
            mimeType: map['mimeType'] as String?,
            temporaryArtifact: map['temporaryArtifact'] is Map
                ? FlowTemporaryArtifact.fromMap(
                    Map<String, dynamic>.from(map['temporaryArtifact'] as Map))
                : null,
          );
  }
}

/// Preserve verified track metadata only within the detected container family.
/// Shared container magic cannot distinguish audio from video; strongly
/// different headers, such as PNG, WAV or MP3, still take precedence.
String flowFileMimeType(String reference,
    {List<int>? headerBytes, String? mimeType}) {
  final detected = lookupMimeType(reference, headerBytes: headerBytes) ??
      'application/octet-stream';
  String normalized(String mime) => mime.split(';').first.trim().toLowerCase();
  String? containerFamily(String mime) => switch (normalized(mime)) {
        'audio/mp4' ||
        'audio/x-m4a' ||
        'video/mp4' ||
        'audio/quicktime' ||
        'video/quicktime' =>
          'iso',
        'audio/webm' ||
        'audio/weba' ||
        'video/webm' ||
        'audio/x-matroska' ||
        'video/x-matroska' =>
          'ebml',
        'audio/x-msvideo' || 'video/x-msvideo' => 'avi',
        'audio/x-flv' || 'video/x-flv' => 'flv',
        'audio/ogg' || 'video/ogg' || 'application/ogg' => 'ogg',
        'audio/x-mpeg-program-stream' || 'video/mpeg' => 'mpeg',
        _ => null,
      };
  final family = containerFamily(detected);
  if (family != null &&
      mimeType != null &&
      containerFamily(mimeType) == family &&
      (flowMimeType(mimeType) == IOType.audio ||
          flowMimeType(mimeType) == IOType.video)) {
    final supplied = normalized(mimeType);
    return supplied == 'audio/x-m4a' ? 'audio/mp4' : supplied;
  }
  if (family == 'iso') {
    final named = lookupMimeType(reference);
    if (named != null &&
        containerFamily(named) == 'iso' &&
        flowMimeType(named) == IOType.audio) {
      return 'audio/mp4';
    }
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
