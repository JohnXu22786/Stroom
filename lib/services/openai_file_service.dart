import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../l10n/app_localizations.dart';
import '../providers/chat_api_shared.dart';
import '../providers/locale_provider.dart';
import '../utils/http_utils.dart';

// ============================================================================
// Configuration
// ============================================================================

/// Default threshold: files smaller than or equal to this size use the simple
/// `POST /v1/files` upload; files larger use the multipart Uploads API.
///
/// This matches OpenAI's maximum file size for regular uploads.
const int kDefaultMultipartThresholdBytes = 512 * 1024 * 1024; // 512 MB

/// Default part size for multipart uploads. Each part is sent as a separate
/// HTTP request. OpenAI's maximum per-part size is 64 MB.
const int kDefaultPartSizeBytes = 64 * 1024 * 1024; // 64 MB

/// Configuration for uploading files to an OpenAI-compatible Files API.
class OpenAiFileUploadConfig {
  /// API key for authentication.
  final String apiKey;

  /// Base URL of the API (e.g., `https://api.openai.com/v1`).
  /// Must NOT include a trailing slash.
  final String baseUrl;

  /// Files smaller than or equal to this threshold (in bytes) use the simple
  /// `POST /v1/files` upload. Files larger use the multipart Uploads API.
  final int multipartThresholdBytes;

  /// Size of each part in the multipart upload (in bytes).
  /// Must be ≤ 64 MB (OpenAI limit).
  final int partSizeBytes;

  const OpenAiFileUploadConfig({
    required this.apiKey,
    required this.baseUrl,
    this.multipartThresholdBytes = kDefaultMultipartThresholdBytes,
    this.partSizeBytes = kDefaultPartSizeBytes,
  });

  /// The URL for simple file uploads (POST /v1/files).
  String get filesUrl => '${_normalizedBaseUrl}/files';

  /// The URL for creating a multipart upload (POST /v1/uploads).
  String get uploadsUrl => '${_normalizedBaseUrl}/uploads';

  /// Base URL without trailing slash.
  String get _normalizedBaseUrl {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  OpenAiFileUploadConfig copyWith({
    String? apiKey,
    String? baseUrl,
    int? multipartThresholdBytes,
    int? partSizeBytes,
  }) =>
      OpenAiFileUploadConfig(
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        multipartThresholdBytes:
            multipartThresholdBytes ?? this.multipartThresholdBytes,
        partSizeBytes: partSizeBytes ?? this.partSizeBytes,
      );
}

// ============================================================================
// Result
// ============================================================================

/// The result of a successful file upload, containing the file metadata
/// returned by the API.
class OpenAiFileResult {
  /// The file ID assigned by the API (e.g., `file-abc123`).
  final String id;

  /// The file size in bytes.
  final int bytes;

  /// The original filename.
  final String filename;

  /// The purpose of the file (e.g., `assistants`, `fine-tune`, `user_data`).
  final String purpose;

  const OpenAiFileResult({
    required this.id,
    required this.bytes,
    required this.filename,
    required this.purpose,
  });
}

// ============================================================================
// Service
// ============================================================================

/// Service for uploading files to an OpenAI-compatible Files API.
///
/// Supports two upload paths:
///
/// **Simple (regular) upload** — for files ≤ [multipartThresholdBytes]:
///   `POST /v1/files` with `multipart/form-data` body containing the file
///   and purpose. Single request, no progress reporting.
///
/// **Multipart upload** — for files > [multipartThresholdBytes]:
///   1. `POST /v1/uploads` — create an Upload (JSON body)
///   2. `POST /v1/uploads/{id}/parts` — add each part (multipart/form-data)
///   3. `POST /v1/uploads/{id}/complete` — complete the upload (JSON body)
///
/// Both paths return an [OpenAiFileResult] with the file ID that can be used
/// in other API calls (Assistants, Fine-tuning, etc.).
///
/// The threshold defaults to 512 MB (OpenAI's regular upload limit) and the
/// part size defaults to 64 MB (OpenAI's maximum part size). Both are
/// configurable via [OpenAiFileUploadConfig].
class OpenAiFileService {
  final OpenAiFileUploadConfig config;
  final Dio _dio;
  final AppLocalizations Function() _localizations;

  Never _throwDioException(DioException error) {
    throwWrappedDioException(
      error,
      messageBuilder: (statusCode, detail) {
        final strings = _localizations();
        return statusCode == null
            ? strings.fileUploadRequestFailed(detail)
            : strings.fileUploadRequestFailedStatus(statusCode, detail);
      },
    );
  }

  OpenAiFileService({
    required this.config,
    Dio? dio,
    AppLocalizations Function()? localizations,
  })  : _localizations =
            localizations ?? (() => appLocalizationsForLocale(null)),
        _dio = dio ??
            Dio(BaseOptions(
              headers: {
                if (config.apiKey.isNotEmpty)
                  'Authorization': 'Bearer ${config.apiKey}',
                ...openRouterAppHeaders,
              },
              // No default Content-Type — Dio auto-sets the correct type
              // (multipart/form-data or application/json) per request.
            ));

  /// Upload a file to the API.
  ///
  /// Automatically selects the simple or multipart upload path based on
  /// [bytes.length] relative to [config.multipartThresholdBytes].
  ///
  /// [onProgress] is called during multipart uploads with values from 0.0
  /// to 1.0. Not called during simple uploads.
  ///
  /// [cancelToken] can be used to cancel a multipart upload mid-flight.
  ///
  /// Throws [Exception] on validation errors or API failures.
  Future<OpenAiFileResult> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String purpose,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final strings = _localizations();
    // ── Input validation ────────────────────────────────────────────
    if (config.apiKey.isEmpty) {
      throw Exception(strings.fileUploadApiKeyMissing);
    }
    if (config.baseUrl.isEmpty) {
      throw Exception(strings.fileUploadApiUrlMissing);
    }
    if (bytes.isEmpty) {
      throw Exception(strings.fileUploadContentEmpty);
    }
    final trimmedFilename = filename.trim();
    if (trimmedFilename.isEmpty) {
      throw Exception(strings.fileUploadFilenameEmpty);
    }
    final trimmedMime = mimeType.trim();
    if (trimmedMime.isEmpty) {
      throw Exception(strings.fileUploadMimeTypeEmpty);
    }
    final trimmedPurpose = purpose.trim();
    if (trimmedPurpose.isEmpty) {
      throw Exception(strings.fileUploadPurposeEmpty);
    }

    // ── Select upload path ──────────────────────────────────────────
    if (bytes.length <= config.multipartThresholdBytes) {
      return _regularUpload(
        bytes,
        trimmedFilename,
        trimmedMime,
        trimmedPurpose,
      );
    } else {
      return _multipartUpload(
        bytes,
        trimmedFilename,
        trimmedMime,
        trimmedPurpose,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
  }

  // ── Simple (regular) upload ──────────────────────────────────────

  /// Upload a file via `POST /v1/files` (single multipart/form-data request).
  Future<OpenAiFileResult> _regularUpload(
    Uint8List bytes,
    String filename,
    String mimeType,
    String purpose,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
      'purpose': purpose,
    });

    try {
      final response = await _dio.post(
        config.filesUrl,
        data: formData,
      );
      return _parseFileResponse(
        response.data,
        bytes.length,
        filename,
        purpose,
      );
    } on DioException catch (e) {
      _throwDioException(e);
    }
  }

  // ── Multipart upload ─────────────────────────────────────────────

  /// Upload a file via the multipart Uploads API (create → parts → complete).
  Future<OpenAiFileResult> _multipartUpload(
    Uint8List bytes,
    String filename,
    String mimeType,
    String purpose, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // Step 1: Create the upload
    final uploadId = await _createUpload(
      bytes.length,
      filename,
      mimeType,
      purpose,
      cancelToken: cancelToken,
    );

    try {
      // Check cancellation before proceeding
      if (cancelToken?.isCancelled == true) {
        throw Exception(_localizations().fileUploadCanceled);
      }

      // Step 2: Split and upload parts
      final totalParts = (bytes.length / config.partSizeBytes).ceil();
      final partIds = <String>[];

      for (var offset = 0;
          offset < bytes.length;
          offset += config.partSizeBytes) {
        if (cancelToken?.isCancelled == true) {
          await _cancelUploadSafely(uploadId);
          throw Exception(_localizations().fileUploadCanceled);
        }

        final end = (offset + config.partSizeBytes > bytes.length)
            ? bytes.length
            : offset + config.partSizeBytes;
        final partBytes = bytes.sublist(offset, end);

        final partId =
            await _addPart(uploadId, partBytes, cancelToken: cancelToken);
        partIds.add(partId);

        // Report progress (0.0 to 1.0)
        onProgress?.call(partIds.length / totalParts);
      }

      // Step 3: Complete the upload
      final result = await _completeUpload(
        uploadId,
        partIds,
        filename,
        purpose,
        cancelToken: cancelToken,
      );
      onProgress?.call(1.0);
      return result;
    } catch (e) {
      // If anything fails after creation, try to cancel the upload
      // on the server so it doesn't linger (uploads expire after 1 hour).
      await _cancelUploadSafely(uploadId);
      rethrow;
    }
  }

  /// Step 1: Create an Upload object → returns `upload_id`.
  Future<String> _createUpload(
    int totalBytes,
    String filename,
    String mimeType,
    String purpose, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        config.uploadsUrl,
        data: jsonEncode({
          'bytes': totalBytes,
          'filename': filename,
          'mime_type': mimeType,
          'purpose': purpose,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
        cancelToken: cancelToken,
      );

      final data = response.data as Map<String, dynamic>;
      final uploadId = data['id'] as String?;
      if (uploadId == null || uploadId.isEmpty) {
        throw Exception(_localizations().fileUploadCreateMissingId);
      }
      return uploadId;
    } on DioException catch (e) {
      _throwDioException(e);
    }
  }

  /// Step 2: Add a part to the upload → returns `part_id`.
  ///
  /// Parts are sent as `multipart/form-data` with field name `data`,
  /// following the OpenAI Uploads API specification.
  Future<String> _addPart(String uploadId, List<int> partBytes,
      {CancelToken? cancelToken}) async {
    final partsUrl = '${config.uploadsUrl}/$uploadId/parts';

    final formData = FormData.fromMap({
      'data': MultipartFile.fromBytes(
        partBytes,
        filename: 'chunk',
        // contentType omitted — Dio infers from bytes
      ),
    });

    try {
      final response = await _dio.post(
        partsUrl,
        data: formData,
        cancelToken: cancelToken,
      );

      final data = response.data as Map<String, dynamic>;
      final partId = data['id'] as String?;
      if (partId == null || partId.isEmpty) {
        throw Exception(_localizations().fileUploadPartMissingId);
      }
      return partId;
    } on DioException catch (e) {
      _throwDioException(e);
    }
  }

  /// Step 3: Complete the upload → returns the final [OpenAiFileResult]
  /// with the file ID from the nested `file` object.
  Future<OpenAiFileResult> _completeUpload(
    String uploadId,
    List<String> partIds,
    String filename,
    String purpose, {
    CancelToken? cancelToken,
  }) async {
    final completeUrl = '${config.uploadsUrl}/$uploadId/complete';

    try {
      final response = await _dio.post(
        completeUrl,
        data: jsonEncode({
          'part_ids': partIds,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
        cancelToken: cancelToken,
      );

      final data = response.data as Map<String, dynamic>;
      final fileData = data['file'] as Map<String, dynamic>?;

      if (fileData == null) {
        // Fallback: some providers might return the file data at top level
        if (data['id'] is String &&
            (data['id'] as String).startsWith('file-')) {
          return OpenAiFileResult(
            id: data['id'] as String,
            bytes: (data['bytes'] as num?)?.toInt() ?? 0,
            filename: (data['filename'] as String?) ?? filename,
            purpose: purpose,
          );
        }
        throw Exception(_localizations().fileUploadCompleteMissingFile);
      }

      return OpenAiFileResult(
        id: fileData['id'] as String,
        bytes: (fileData['bytes'] as num?)?.toInt() ?? 0,
        filename: (fileData['filename'] as String?) ?? filename,
        purpose: (fileData['purpose'] as String?) ?? purpose,
      );
    } on DioException catch (e) {
      _throwDioException(e);
    }
  }

  /// Safely cancel an upload (best-effort). Errors from the cancel request
  /// are swallowed so they don't mask the original error.
  Future<void> _cancelUploadSafely(String uploadId) async {
    try {
      await _dio.post(
        '${config.uploadsUrl}/$uploadId/cancel',
      );
    } catch (_) {
      // Best-effort cancellation — the upload will expire after 1 hour anyway.
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Parse a file response from the API into an [OpenAiFileResult].
  OpenAiFileResult _parseFileResponse(
    dynamic responseData,
    int bytesLength,
    String filename,
    String purpose,
  ) {
    String? id;
    int bytes = bytesLength;
    String name = filename;
    String purp = purpose;

    try {
      if (responseData is Map<String, dynamic>) {
        id = responseData['id'] as String?;
        if (responseData['bytes'] is num) {
          bytes = (responseData['bytes'] as num).toInt();
        }
        name = (responseData['filename'] as String?) ?? filename;
        purp = (responseData['purpose'] as String?) ?? purpose;
      }
    } catch (e) {
      debugPrint('[OpenAiFileService] Error parsing file response: $e');
      // Fall through with defaults — the essential 'id' check below
      // will still fail if id couldn't be extracted.
    }

    if (id == null || id.isEmpty) {
      throw Exception(_localizations().fileUploadMissingFileId);
    }

    return OpenAiFileResult(
      id: id,
      bytes: bytes,
      filename: name,
      purpose: purp,
    );
  }
}
