import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:stroom/utils/asr_evaluation.dart';

/// Offline by default. Provider access requires ASR_EVAL_ENABLE_PROVIDER=true
/// and endpoint/key values supplied in the current process environment.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
        'Usage: flutter pub run tool/asr_evaluate.dart <manifest.json>');
    exitCode = 64;
    return;
  }
  final environment = Platform.environment;
  final useProvider = isAsrProviderEvaluationEnabled(environment);
  final endpoint = environment['ASR_EVAL_ENDPOINT'] ?? '';
  final apiKey = environment['ASR_EVAL_API_KEY'] ?? '';
  final model = environment['ASR_EVAL_MODEL'] ?? 'whisper-1';
  if (useProvider && (endpoint.isEmpty || apiKey.isEmpty)) {
    stderr.writeln(
      'Provider evaluation requires ASR_EVAL_ENDPOINT and ASR_EVAL_API_KEY.',
    );
    exitCode = 64;
    return;
  }

  final manifestFile = File(arguments.single).absolute;
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final cases = manifest['cases'] as List<dynamic>? ?? const [];
  final rows = <Map<String, Object?>>[];
  final dio = useProvider
      ? Dio(BaseOptions(
          headers: {'Authorization': 'Bearer $apiKey'},
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ))
      : null;
  try {
    for (final rawCase in cases) {
      final item = rawCase as Map<String, dynamic>;
      final provenance = item['provenance'];
      if (!isAsrSampleProvenanceValid(provenance)) {
        throw const FormatException(
          'Each case needs source, license, and attribution provenance.',
        );
      }
      final audioPath = item['audio'] as String?;
      final audioSeconds = (item['audioSeconds'] as num?)?.toDouble();
      final reference = item['reference'] as String?;
      if (audioPath == null ||
          audioSeconds == null ||
          audioSeconds <= 0 ||
          reference == null) {
        throw const FormatException(
          'Each case needs audio, positive audioSeconds, and reference text.',
        );
      }
      final file = File(audioPath);
      final resolvedFile = file.isAbsolute
          ? file
          : File(
              '${manifestFile.parent.path}${Platform.pathSeparator}$audioPath');
      final bytes = await resolvedFile.readAsBytes();
      final watch = Stopwatch()..start();
      final providerResult = useProvider
          ? await _requestProvider(
              dio: dio!,
              endpoint: endpoint,
              model: model,
              audioBytes: Uint8List.fromList(bytes),
              filename: resolvedFile.uri.pathSegments.last,
              language: item['language'] as String?,
              includeSegments: item['referenceSegments'] is List,
            )
          : null;
      watch.stop();
      final transcript = providerResult?.$1 ??
          (useProvider ? null : item['transcript'] as String?);
      if (transcript == null) {
        throw const FormatException(
          'Offline cases need transcript; provider mode supplies it.',
        );
      }
      final metrics = scoreAsrText(reference, transcript);
      final refSegments = _segments(item['referenceSegments']);
      final transcriptSegments = _segments(item['transcriptSegments']);
      final latencyMs =
          useProvider ? watch.elapsedMilliseconds : item['latencyMs'] as int?;
      final residentBytes =
          useProvider ? ProcessInfo.currentRss : item['residentBytes'] as int?;
      final report = <String, Object?>{
        'id': item['id'],
        'language': item['language'],
        'conditions': item['conditions'],
        'provenance': provenance,
        'textMetrics': metrics.toJson(),
        'subtitleOffsetMeanAbsoluteSeconds': meanSubtitleOffsetSeconds(
          reference: refSegments,
          hypothesis: asrTranscriptSegmentsForEvaluation(
            providerEnabled: useProvider,
            providerSegments: providerResult?.$2,
            capturedTranscriptSegments: transcriptSegments,
          ),
        ),
        'audioSeconds': audioSeconds,
        'latencyMs': latencyMs,
        'rtf': latencyMs == null
            ? null
            : realTimeFactor(elapsedMs: latencyMs, audioSeconds: audioSeconds),
        'residentBytes': residentBytes,
        'audioBytes': bytes.length,
        'transcriptSource': useProvider ? 'provider' : 'manifest',
      };
      rows.add(report);
    }
  } finally {
    dio?.close(force: true);
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'providerEnabled': useProvider,
    'model': useProvider ? model : null,
    'networkByDefault': false,
    'cases': rows,
  }));
}

Future<(String, List<({double? start, double? end})>?)> _requestProvider({
  required Dio dio,
  required String endpoint,
  required String model,
  required Uint8List audioBytes,
  required String filename,
  required String? language,
  required bool includeSegments,
}) async {
  try {
    final response = await dio.post<Map<String, dynamic>>(
      endpoint,
      data: FormData.fromMap({
        'model': model,
        'response_format': includeSegments ? 'verbose_json' : 'json',
        if (language != null && language.isNotEmpty) 'language': language,
        'file': MultipartFile.fromBytes(audioBytes, filename: filename),
      }),
    );
    final data = response.data;
    final text = data?['text'];
    if (text is! String) {
      throw const FormatException('Provider response has no transcript text.');
    }
    final rawSegments = data?['segments'];
    final segments = rawSegments is List
        ? rawSegments.map((raw) {
            final segment = raw as Map<String, dynamic>;
            return (
              start: (segment['start'] as num?)?.toDouble(),
              end: (segment['end'] as num?)?.toDouble(),
            );
          }).toList()
        : null;
    return (text, segments);
  } on DioException {
    throw const FormatException(
      'Provider request failed; credentials and response details were omitted.',
    );
  }
}

List<({double? start, double? end})>? _segments(Object? raw) {
  if (raw is! List) return null;
  return raw.map((entry) {
    final segment = entry as Map<String, dynamic>;
    return (
      start: (segment['startSeconds'] as num?)?.toDouble(),
      end: (segment['endSeconds'] as num?)?.toDouble(),
    );
  }).toList();
}
