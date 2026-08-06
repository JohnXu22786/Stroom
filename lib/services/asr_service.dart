import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../providers/chat_api_provider.dart';
import '../providers/provider_config.dart';
import '../utils/audio_codecs.dart';
import '../utils/audio_chunker.dart';
import '../utils/audio_utils.dart';
import '../utils/format_file_size.dart';
import 'app_log_service.dart';
import '../utils/http_utils.dart';

// Formati supportati dal Whisper API (OpenAI-compatible).
const _asrSupportedFormats = {
  'flac',
  'mp3',
  'mp4',
  'mpeg',
  'mpga',
  'm4a',
  'ogg',
  'opus',
  'wav',
  'webm',
};

// ============================================================================
// Audio Upload Method
// ============================================================================

/// How the audio data is sent to the transcription API.
///
/// Different OpenAI-compatible providers support different upload methods:
/// - [multipart]: Standard `multipart/form-data` with binary file field.
///   Works with all providers. Limited by each provider's file size cap.
/// - [base64Json]: Base64-encode the audio and send as JSON body.
///   Bypasses multipart size limits on some providers (e.g., OpenRouter).
/// - [url]: Pass a public HTTPS URL instead of file bytes. The provider
///   downloads the audio server-side. Supports the largest files (e.g.,
///   Together AI up to 1 GB, Groq up to 100 MB).
enum AudioUploadMethod {
  /// Standard multipart/form-data upload (most compatible).
  multipart,

  /// Base64-encoded audio in JSON body.
  base64Json,

  /// Pass a public URL for the provider to download.
  url,
}

// ============================================================================
// ASR Config
// ============================================================================

/// Configuration for an OpenAI-compatible Automatic Speech Recognition (ASR)
/// service using the Whisper API.
///
/// The user provides the full endpoint URL (e.g. https://api.openai.com/v1/audio/transcriptions),
/// which is used directly without appending any path.
///
/// [uploadMethod] selects the HTTP format used to send audio.
/// [maxFileSizeBytes] controls the maximum allowed audio file size for
/// file-based upload methods (multipart, base64Json). Does NOT apply to URL.
class AsrConfig {
  final String model;
  final String apiKey;
  final String host;
  final String? language;

  /// Type-specific config (language, responseFormat, temperature, etc.)
  final Map<String, dynamic> typeConfig;

  /// Custom parameters that the user defined
  final List<CustomParam> customParams;

  /// How to send the audio file to the API.
  final AudioUploadMethod uploadMethod;

  /// Maximum allowed audio file size in bytes.
  ///
  /// Files larger than this will be rejected before sending to the API.
  /// Defaults to 25 MB (26,214,400 bytes), matching OpenAI's audio API limit.
  /// Set to a higher value for providers that support larger files.
  /// Does NOT apply to [AudioUploadMethod.url].
  final int maxFileSizeBytes;

  /// Preprocessing method: 'none' or 'resampleMono'.
  /// 'resampleMono' resamples to 16kHz and mixes to mono for size reduction.
  final String preprocessing;

  /// Chunking method: 'none', 'silence', 'fixedDuration', or 'fixedSize'.
  final String chunking;

  /// Compression codec: 'none', 'adpcm' (wrapped in a WAV container),
  /// or 'flac'. 'opus'/'mp3' are not supported (experimental encoders
  /// produce undecodable output).
  final String compression;

  /// Fallback strategy when file exceeds [maxFileSizeBytes]:
  /// - 'none': reject immediately
  /// - 'specific': try base64 JSON (bypasses multipart size caps on some
  ///   providers; URL needs a public link, multipart doesn't help an
  ///   over-limit file)
  /// - 'generic': apply preprocessing → compression → chunking → re-upload
  /// - 'all': try specific first, then generic
  final String fallbackMethod;

  /// Default max file size for OpenAI-compatible audio APIs.
  static const int defaultMaxAudioFileSizeBytes = 25 * 1024 * 1024;

  const AsrConfig({
    this.model = 'whisper-1',
    required this.apiKey,
    required this.host,
    this.language,
    this.typeConfig = const {},
    this.customParams = const [],
    this.uploadMethod = AudioUploadMethod.multipart,
    this.maxFileSizeBytes = defaultMaxAudioFileSizeBytes,
    this.preprocessing = 'none',
    this.chunking = 'none',
    this.compression = 'none',
    this.fallbackMethod = 'none',
  });

  /// Returns the host without a trailing slash.
  String get normalizedHost {
    var h = host.trim();
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  /// The full transcription endpoint URL.
  String get transcribeUrl => normalizedHost;

  /// Get the effective language from typeConfig, falling back to the
  /// legacy `language` field for backward compatibility.
  String? get effectiveLanguage {
    if (typeConfig['enableLanguage'] == true &&
        typeConfig.containsKey('language')) {
      final lang = typeConfig['language'] as String?;
      if (lang != null && lang.isNotEmpty) return lang;
    }
    return language;
  }

  AsrConfig copyWith({
    String? model,
    String? apiKey,
    String? host,
    String? language,
    Map<String, dynamic>? typeConfig,
    List<CustomParam>? customParams,
    AudioUploadMethod? uploadMethod,
    int? maxFileSizeBytes,
    String? preprocessing,
    String? chunking,
    String? compression,
    String? fallbackMethod,
  }) =>
      AsrConfig(
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        host: host ?? this.host,
        language: language ?? this.language,
        typeConfig: typeConfig ?? this.typeConfig,
        customParams: customParams ?? this.customParams,
        uploadMethod: uploadMethod ?? this.uploadMethod,
        maxFileSizeBytes: maxFileSizeBytes ?? this.maxFileSizeBytes,
        preprocessing: preprocessing ?? this.preprocessing,
        chunking: chunking ?? this.chunking,
        compression: compression ?? this.compression,
        fallbackMethod: fallbackMethod ?? this.fallbackMethod,
      );
}

// ============================================================================
// ASR Result
// ============================================================================

/// The result of an ASR transcription operation.
class AsrResult {
  final String text;
  final int processingTimeMs;

  const AsrResult({required this.text, this.processingTimeMs = 0});
}

// ============================================================================
// ASR Service
// ============================================================================

/// An ASR service that uses an OpenAI-compatible audio/transcriptions API
/// to transcribe audio into text.
///
/// The API is called with a multipart/form-data POST request (standard OpenAI
/// STT convention) containing:
/// - `file`: the audio file data
/// - `model`: the Whisper model ID (default: whisper-1)
/// - `language` (optional): ISO language code
/// - `response_format`: json (default)
///
/// The response follows the standard OpenAI transcription format:
/// `{ "text": "transcribed text" }`.
class AsrService {
  final AsrConfig config;
  final Dio _dio;

  // ── Diagnostic capture (mirrors chat_api_provider pattern) ───────────
  /// The last request body sent to the API.
  Map<String, dynamic>? lastRequestBody;

  /// The last response data received from the API (or null on error).
  Map<String, dynamic>? lastResponseData;

  /// The last request headers sent.
  Map<String, String>? lastRequestHeaders;

  /// The last response headers received.
  Map<String, List<String>>? lastResponseHeaders;

  /// The last request URL.
  String? lastRequestUrl;

  /// The last HTTP response status code.
  int? lastResponseStatusCode;

  /// Mask API key for display, showing only first 8 chars and last 4 chars.
  static String _maskApiKey(String key) {
    if (key.isEmpty) return '****';
    if (key.length <= 4) return '${key.substring(0, 1)}***';
    if (key.length <= 16) return '${key.substring(0, 4)}****';
    return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
  }

  AsrService({required this.config, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                headers: {
                  if (config.apiKey.isNotEmpty)
                    'Authorization': 'Bearer ${config.apiKey}',
                  ...openRouterAppHeaders,
                },
                // No timeouts — ASR transcription may take a long time
              ),
            );

  /// Dio default headers, exposed for testing.
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

  /// Dio send timeout, exposed for diagnostic and testing.
  Duration? get sendTimeout => _dio.options.sendTimeout;

  /// Dio connect timeout, exposed for diagnostic and testing.
  Duration? get connectTimeout => _dio.options.connectTimeout;

  /// Dio receive timeout, exposed for diagnostic and testing.
  Duration? get receiveTimeout => _dio.options.receiveTimeout;

  /// Transcribe audio bytes into text.
  ///
  /// Supports [AudioUploadMethod.multipart] (default) and [AudioUploadMethod.base64Json].
  /// For [AudioUploadMethod.url], use [transcribeFromUrl] instead.
  ///
  /// [audioBytes] - The raw audio data (e.g., WAV, MP3, M4A, etc.).
  /// [audioFormat] - The audio file extension/format (e.g., 'wav', 'mp3', 'm4a').
  Future<AsrResult> transcribe({
    required Uint8List audioBytes,
    String audioFormat = 'wav',
  }) async {
    await AppLogService.info('AsrService',
        '开始转写: 格式=$audioFormat, 方式=${config.uploadMethod.name}, 大小=${audioBytes.length} 字节');
    if (config.host.isEmpty) {
      throw Exception('API 地址未配置');
    }
    if (audioBytes.isEmpty) {
      throw Exception('音频数据为空');
    }

    final fmt = audioFormat.toLowerCase();
    if (!_asrSupportedFormats.contains(fmt)) {
      throw Exception(
        '不支持的音频格式: $fmt。'
        'Whisper API 支持的格式: ${_asrSupportedFormats.join(", ")}。'
        '请将音频转换为 WAV/MP3 格式后重试。',
      );
    }

    var workingBytes = audioBytes;

    // ── Preprocessing (always applied if configured) ────────────────
    if (config.preprocessing == 'resampleMono' && fmt == 'wav') {
      try {
        final preprocessor = WavPreprocessor();
        workingBytes = preprocessor.process(workingBytes);
        await AppLogService.info('AsrService',
            '预处理完成: ${audioBytes.length} → ${workingBytes.length} 字节');
      } catch (e) {
        await AppLogService.warning('AsrService', '预处理失败: $e');
      }
    }

    // ── Check if file fits within limit ─────────────────────────────
    final exceedsLimit = workingBytes.length > config.maxFileSizeBytes &&
        config.uploadMethod != AudioUploadMethod.url;

    if (!exceedsLimit) {
      // ── File fits — send via primary method ───────────────────────
      return _applyCompressionAndSend(workingBytes, fmt);
    }

    // ── File exceeds limit — apply fallback strategy ────────────────
    await AppLogService.info('AsrService',
        '文件超限 (${formatFileSize(workingBytes.length)} > ${formatFileSize(config.maxFileSizeBytes)})，尝试兜底策略: ${config.fallbackMethod}');

    final fallback = config.fallbackMethod;

    // Step 1: Try specific fallback (base64) if configured
    if (fallback == 'specific' || fallback == 'all') {
      final specificMethod = _getSpecificFallback(config.uploadMethod);
      if (specificMethod == null) {
        await AppLogService.info('AsrService',
            '当前上传方式 (${config.uploadMethod.name}) 没有可用的特定兜底'
            '（URL 需要公网链接，multipart 不缓解超限）');
      } else {
        try {
          if (specificMethod == AudioUploadMethod.base64Json) {
            // NOTE: must await, not `return` — a bare `return future` would
            // deliver the error to the caller without entering this catch,
            // aborting the whole fallback chain.
            return await _sendViaBase64(workingBytes, fmt);
          }
        } catch (e) {
          await AppLogService.warning(
              'AsrService', '特定兜底 (${specificMethod.name}) 失败: $e');
        }
      }
    }

    // Step 2: Try generic fallback (compression → chunking → re-upload)
    if (fallback == 'generic' || fallback == 'all') {
      var actualFmt = fmt;

      // Apply compression if configured
      if (config.compression != 'none' && fmt == 'wav') {
        final result = _applyCompression(workingBytes, fmt);
        workingBytes = result.$1;
        actualFmt = result.$2;
      }

      // Apply chunking if configured. Chunking operates on raw PCM WAV only:
      // - compressed payloads (ADPCM-in-WAV, FLAC) must not be split at
      //   arbitrary byte offsets (block alignment / frame boundaries);
      // - non-WAV inputs (mp3 etc.) cannot be parsed by the chunker.
      if (config.chunking != 'none' &&
          workingBytes.length > config.maxFileSizeBytes &&
          config.compression == 'none' &&
          actualFmt == 'wav') {
        try {
          // await required: a bare `return future` would deliver the error to
          // the caller without entering this catch.
          return await _transcribeChunked(workingBytes, actualFmt);
        } on FormatException catch (e) {
          // Malformed/unparseable WAV — fall through to the rejection below.
          // Other failures (e.g. '切块转写全部失败') propagate as-is.
          unawaited(AppLogService.warning('AsrService', '切块失败: $e'));
        }
      }

      // If compression/chunking brought it under limit, send via primary
      if (workingBytes.length <= config.maxFileSizeBytes) {
        return _sendViaMethod(workingBytes, actualFmt, config.uploadMethod);
      }
    }

    // ── All fallbacks exhausted — reject ────────────────────────────
    if (fallback == 'none') {
      throw Exception(
        '文件大小超过限制: '
        '${formatFileSize(workingBytes.length)} > '
        '${formatFileSize(config.maxFileSizeBytes)}。'
        '当前兜底策略为“无”，超限文件被直接拒绝。',
      );
    }
    throw Exception(
      '文件大小超过限制且兜底策略未能解决: '
      '${formatFileSize(workingBytes.length)} > '
      '${formatFileSize(config.maxFileSizeBytes)}。'
      '压缩仅对 WAV 生效且压缩后仍可能超限；切块仅支持未压缩 WAV。'
      '请降低文件大小，或改用 Base64/URL 上传方式。',
    );
  }

  /// Apply compression to working bytes. Returns compressed bytes and the
  /// new audio format string (e.g., 'flac' instead of 'wav').
  ///
  /// Only codecs that produce a standalone decodable container are used:
  /// - 'adpcm': wrapped in a WAV container (WAVE_FORMAT_IMA_ADPCM).
  /// - 'flac': standalone FLAC file.
  /// 'opus'/'mp3' are experimental pure-Dart encoders whose output cannot
  /// be decoded by providers — they are skipped instead of uploading garbage.
  (Uint8List, String) _applyCompression(Uint8List workingBytes, String fmt) {
    if (config.compression == 'none' || fmt != 'wav') {
      return (workingBytes, fmt);
    }
    if (config.compression != 'adpcm' && config.compression != 'flac') {
      unawaited(AppLogService.warning(
          'AsrService', '不支持的压缩方式: ${config.compression}，跳过压缩'));
      return (workingBytes, fmt);
    }
    try {
      final info = parseWavHeader(workingBytes);
      var samples = readPcmSamplesFloat(workingBytes, info);
      // All built-in encoders are mono-only. Downmix multichannel audio
      // first, otherwise interleaved channels would be encoded as mono
      // and the audio would play back at Nx speed (garbage transcription).
      if (info.numChannels > 1) {
        final monoLen = samples.length ~/ info.numChannels;
        final mono = Float64List(monoLen);
        for (int i = 0; i < monoLen; i++) {
          double sum = 0;
          for (int ch = 0; ch < info.numChannels; ch++) {
            sum += samples[i * info.numChannels + ch];
          }
          mono[i] = sum / info.numChannels;
        }
        samples = mono;
      }
      final pcm = Int16List(samples.length);
      for (int i = 0; i < samples.length; i++) {
        pcm[i] = (samples[i] * 32767).round().clamp(-32768, 32767);
      }
      if (config.compression == 'adpcm') {
        final adpcm = encodeAdpcm(pcm, AdpcmConfig());
        // Raw IMA ADPCM nibbles cannot be uploaded directly — wrap them in
        // a WAV container so providers can decode them.
        return (adpcmToWav(adpcm, sampleRate: info.sampleRate), 'wav');
      }
      return (encodeFlac(pcm, sampleRate: info.sampleRate), 'flac');
    } catch (e) {
      unawaited(AppLogService.warning('AsrService', '压缩失败: $e'));
    }
    return (workingBytes, fmt);
  }

  /// Apply compression and send via primary method (for files within limit).
  Future<AsrResult> _applyCompressionAndSend(
      Uint8List workingBytes, String fmt) async {
    var actualFmt = fmt;
    if (config.compression != 'none' && fmt == 'wav') {
      final result = _applyCompression(workingBytes, fmt);
      workingBytes = result.$1;
      actualFmt = result.$2;
    }
    return _sendViaMethod(workingBytes, actualFmt, config.uploadMethod);
  }

  /// Get the specific fallback method that differs from primary.
  ///
  /// Only base64 is usable as a specific fallback:
  /// - URL upload requires a public URL, which a local file does not have
  ///   (use [transcribeFromUrl] instead).
  /// - Multipart does not help an over-limit file (same size limit).
  AudioUploadMethod? _getSpecificFallback(AudioUploadMethod primary) {
    switch (primary) {
      case AudioUploadMethod.multipart:
        // base64 bypasses multipart size caps on some providers (e.g. OpenRouter).
        return AudioUploadMethod.base64Json;
      case AudioUploadMethod.base64Json:
        return null;
      case AudioUploadMethod.url:
        return null;
    }
  }

  /// Send via base64 JSON method.
  Future<AsrResult> _sendViaBase64(Uint8List bytes, String fmt) async {
    return _sendViaMethod(bytes, fmt, AudioUploadMethod.base64Json);
  }

  /// Send audio via the specified upload method.
  Future<AsrResult> _sendViaMethod(
      Uint8List bytes, String fmt, AudioUploadMethod method) async {
    final stopwatch = Stopwatch()..start();
    final mimeTypeString = getMimeType(fmt);
    final mimeType = mimeTypeString.contains('/')
        ? DioMediaType.parse(mimeTypeString)
        : null;
    final fileName = 'audio.$fmt';
    final sharedParams = _buildSharedParams();

    try {
      final response = await _sendTranscriptionRequest(
        sharedParams: sharedParams,
        audioBytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        method: method,
      );

      stopwatch.stop();
      _captureResponseDiagnostics(response);
      final text = _extractText(response.data);

      await AppLogService.info('AsrService',
          '转写完成: ${stopwatch.elapsedMilliseconds}ms, 文本长度=${text.length}');
      return AsrResult(
        text: text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on DioException catch (e) {
      _captureDioExceptionDiagnostics(e);
      throwWrappedDioException(e);
    }
  }

  /// Transcribe audio from a public URL (supports [AudioUploadMethod.url]).
  ///
  /// The provider downloads the audio server-side, avoiding client-side
  /// file size limits entirely. Supported by Together AI (up to 1 GB),
  /// Groq (up to 100 MB), xAI (up to 500 MB), etc.
  Future<AsrResult> transcribeFromUrl(String audioUrl) async {
    await AppLogService.info('AsrService', '开始转写 (URL): $audioUrl');

    if (config.host.isEmpty) {
      throw Exception('API 地址未配置');
    }
    final trimmed = audioUrl.trim();
    if (trimmed.isEmpty) {
      throw Exception('音频链接为空');
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      throw Exception('无效的音频链接，必须以 http:// 或 https:// 开头');
    }

    final stopwatch = Stopwatch()..start();
    final sharedParams = _buildSharedParams();
    sharedParams['file'] = trimmed;

    // Capture diagnostics
    lastRequestBody = sharedParams;
    lastRequestUrl = config.transcribeUrl;
    lastRequestHeaders = {
      if (config.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${_maskApiKey(config.apiKey)}',
    };
    lastResponseData = null;
    lastResponseStatusCode = null;
    lastResponseHeaders = null;

    try {
      final response = await _dio.post(
        config.transcribeUrl,
        data: jsonEncode(sharedParams),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      stopwatch.stop();
      _captureResponseDiagnostics(response);
      final text = _extractText(response.data);

      await AppLogService.info('AsrService',
          '转写完成 (URL): ${stopwatch.elapsedMilliseconds}ms, 文本长度=${text.length}');
      return AsrResult(
        text: text,
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
    } on DioException catch (e) {
      _captureDioExceptionDiagnostics(e);
      throwWrappedDioException(e);
    }
  }

  // ── Internal ─────────────────────────────────────────────────────

  /// Build the shared request parameters (model, language, response_format,
  /// temperature, etc.) as a JSON-compatible map.
  Map<String, dynamic> _buildSharedParams() {
    final params = <String, dynamic>{
      'model': config.model,
    };

    final tc = config.typeConfig;

    // response_format
    if (tc['enableResponseFormat'] == true &&
        tc.containsKey('responseFormat')) {
      params['response_format'] = tc['responseFormat'] as String;
    } else {
      params['response_format'] = 'json';
    }

    // language
    final effectiveLang = config.effectiveLanguage;
    if (effectiveLang != null && effectiveLang.isNotEmpty) {
      params['language'] = effectiveLang;
    }

    // temperature
    if (tc['enableTemperature'] == true && tc.containsKey('temperature')) {
      params['temperature'] = (tc['temperature'] as num).toDouble();
    }

    // timestamp_granularities (only for verbose_json)
    if (tc['enableTimestampGranularities'] == true &&
        tc.containsKey('timestampGranularities')) {
      params['timestamp_granularities'] =
          tc['timestampGranularities'] as String;
    }

    // prompt
    if (tc['enablePrompt'] == true && tc.containsKey('prompt')) {
      final prompt = tc['prompt'] as String;
      if (prompt.trim().isNotEmpty) {
        params['prompt'] = prompt;
      }
    }

    // Custom parameters
    for (final param in config.customParams) {
      final name = param.paramName.trim();
      if (name.isEmpty) continue;
      final value = param.defaultValue.trim();
      if (value.isEmpty) continue;
      final parsed = _parseParamValue(value, param.type);
      params[name] = parsed is String ? parsed : parsed.toString();
    }

    return params;
  }

  /// Transcribe a large WAV file by chunking, transcribing each chunk,
  /// and concatenating results.
  Future<AsrResult> _transcribeChunked(
      Uint8List wavBytes, String audioFormat) async {
    // Map chunking config string to enum
    final chunkMethod = switch (config.chunking) {
      'silence' => AudioChunkMethod.silence,
      'fixedDuration' => AudioChunkMethod.fixedDuration,
      'fixedSize' => AudioChunkMethod.fixedSize,
      _ => throw Exception('未知的切块方式: ${config.chunking}'),
    };

    final chunker = AudioChunker(
      config: AudioChunkConfig(
        // Each chunk is re-wrapped with a 44-byte WAV header. The data cap
        // reserves it so the full chunk file stays within maxFileSizeBytes.
        // For base64 uploads the payload is additionally inflated by ~4/3:
        // cap = floor(L/4)*3 - 44 guarantees 4*ceil(file/3) <= L for any L.
        maxChunkBytes: config.uploadMethod == AudioUploadMethod.base64Json
            ? config.maxFileSizeBytes ~/ 4 * 3 - 44
            : config.maxFileSizeBytes - 44,
      ),
    );
    final chunks = chunker.chunk(wavBytes, chunkMethod);

    await AppLogService.info(
        'AsrService', '切块完成: ${chunks.length} 个片段 (共 ${wavBytes.length} 字节)');

    final texts = <String>[];
    final fmt = audioFormat; // 'wav'
    final mimeTypeString = getMimeType(fmt);
    final mimeType = mimeTypeString.contains('/')
        ? DioMediaType.parse(mimeTypeString)
        : null;
    final fileName = 'audio.$fmt';
    final sharedParams = _buildSharedParams();

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];

      // ── Prompt carrying: pass previous chunk's text as prompt ──
      final chunkParams = Map<String, dynamic>.from(sharedParams);
      if (i > 0 && texts.isNotEmpty) {
        // Use last ~100 chars of previous chunk's text as prompt for continuity
        final prevText = texts.last;
        final promptSuffix = prevText.length > 100
            ? prevText.substring(prevText.length - 100)
            : prevText;
        chunkParams['prompt'] = promptSuffix;
      }

      try {
        final response = await _sendTranscriptionRequest(
          sharedParams: chunkParams,
          audioBytes: chunk,
          fileName: fileName,
          mimeType: mimeType,
        );
        _captureResponseDiagnostics(response);
        final text = _extractText(response.data);
        if (text.isNotEmpty) {
          texts.add(text);
        }
        await AppLogService.info('AsrService', '切块 $i/${chunks.length} 转写完成');
      } on Exception catch (e) {
        // Keep response diagnostics for the last failed chunk so the error
        // detail dialog shows the actual API response.
        if (e is DioException) {
          _captureDioExceptionDiagnostics(e);
        }
        await AppLogService.warning(
            'AsrService', '切块 $i/${chunks.length} 转写失败: $e');
      }
    }

    // Chunks are strictly non-overlapping (see AudioChunker), so results
    // are concatenated directly. Overlap dedup would be wrong here: for
    // non-overlapping audio it can remove legitimate repeated text at
    // chunk boundaries.
    if (texts.isEmpty) {
      throw Exception(
          '切块转写全部失败（${chunks.length} 个片段均未成功），请检查网络或 API 配置后重试');
    }

    return AsrResult(
      text: texts.join(' '),
      processingTimeMs: 0,
    );
  }

  /// Send the transcription request using the specified [method].
  Future<Response<dynamic>> _sendTranscriptionRequest({
    required Map<String, dynamic> sharedParams,
    required Uint8List audioBytes,
    required String fileName,
    required DioMediaType? mimeType,
    AudioUploadMethod? method,
  }) async {
    final effectiveMethod = method ?? config.uploadMethod;
    final diagnosticFields = Map<String, dynamic>.from(sharedParams);

    switch (effectiveMethod) {
      case AudioUploadMethod.multipart:
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            audioBytes,
            filename: fileName,
            contentType: mimeType,
          ),
          ...sharedParams,
        });
        diagnosticFields['file'] =
            '$fileName (${audioBytes.length} bytes, ${mimeType?.mimeType ?? 'unknown'})';

        _captureDiagnostics(diagnosticFields);

        return _dio.post(
          config.transcribeUrl,
          data: formData,
        );

      case AudioUploadMethod.base64Json:
        final b64 = base64Encode(audioBytes);
        sharedParams['file'] = b64;
        diagnosticFields['file'] =
            '$fileName (base64, ${audioBytes.length} bytes)';

        _captureDiagnostics(diagnosticFields);

        return _dio.post(
          config.transcribeUrl,
          data: jsonEncode(sharedParams),
          options: Options(
            headers: {'Content-Type': 'application/json'},
          ),
        );

      case AudioUploadMethod.url:
        // Should not be reached — use transcribeFromUrl for URL method.
        throw Exception('URL 上传方式请使用 transcribeFromUrl() 方法，而不是 transcribe()');
    }
  }

  void _captureDiagnostics(Map<String, dynamic> diagnosticFields) {
    lastRequestBody = diagnosticFields;
    lastRequestUrl = config.transcribeUrl;
    lastRequestHeaders = {
      if (config.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${_maskApiKey(config.apiKey)}',
    };
    lastResponseData = null;
    lastResponseStatusCode = null;
    lastResponseHeaders = null;
  }

  void _captureResponseDiagnostics(Response<dynamic> response) {
    lastResponseStatusCode = response.statusCode;
    lastResponseData = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{'raw': '$response.data'};
    lastResponseHeaders = response.headers.map;
  }

  /// Capture response-level diagnostic fields from a [DioException].
  void _captureDioExceptionDiagnostics(DioException e) {
    if (e.response?.data is Map) {
      lastResponseData = Map<String, dynamic>.from(e.response!.data as Map);
    } else if (e.response?.data is String) {
      lastResponseData = <String, dynamic>{'raw': e.response!.data as String};
    } else {
      lastResponseData = null;
    }
    lastResponseStatusCode = e.response?.statusCode;
    lastResponseHeaders = e.response?.headers.map;
  }

  /// Parse a parameter value string into its proper type.
  static dynamic _parseParamValue(String value, String type) {
    switch (type) {
      case 'number':
        final numVal = num.tryParse(value);
        return numVal ?? value;
      case 'boolean':
        if (value.toLowerCase() == 'true') return true;
        if (value.toLowerCase() == 'false') return false;
        return value;
      case 'json':
        try {
          return jsonDecode(value);
        } catch (_) {
          return value;
        }
      case 'string':
      default:
        return value;
    }
  }

  /// Extract text from the standard OpenAI transcription response.
  String _extractText(dynamic responseData) {
    try {
      if (responseData is! Map<String, dynamic>) {
        throw Exception('API 返回格式异常');
      }
      final text = responseData['text'];
      if (text is! String || text.trim().isEmpty) {
        throw Exception('音频转写返回了空的文本');
      }
      return text;
    } catch (e) {
      throw Exception('解析音频转写结果失败: $e');
    }
  }
}

// ============================================================================
// Factory Functions
// ============================================================================

/// Create an [AsrService] from provider configuration fields.
AsrService createAsrServiceFromConfig({
  required String host,
  required String apiKey,
  String model = 'whisper-1',
  String? language,
  Map<String, dynamic> typeConfig = const {},
  List<CustomParam> customParams = const [],
  AudioUploadMethod uploadMethod = AudioUploadMethod.multipart,
  int maxFileSizeBytes = AsrConfig.defaultMaxAudioFileSizeBytes,
}) {
  return AsrService(
    config: AsrConfig(
      host: host,
      apiKey: apiKey,
      model: model,
      language: language,
      typeConfig: typeConfig,
      customParams: customParams,
      uploadMethod: uploadMethod,
      maxFileSizeBytes: maxFileSizeBytes,
    ),
  );
}
