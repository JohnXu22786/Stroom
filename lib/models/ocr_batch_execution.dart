/// Default cap for the UTF-8 encoded JSON sent to an OCR endpoint.
const defaultOcrRequestSizeBudgetBytes = 20 * 1024 * 1024;

/// How a selected set of images is submitted to the OCR model.
enum OcrBatchMode { joint, perImage }

/// Persisted result for one source image in a per-image OCR run.
enum OcrPageOutcomeStatus {
  pending,
  running,
  succeeded,
  incomplete,
  failed,
  cancelled,
}

class OcrPageOutcome {
  final int imageIndex;
  final OcrPageOutcomeStatus status;
  final String? text;
  final String? error;

  const OcrPageOutcome({
    required this.imageIndex,
    required this.status,
    this.text,
    this.error,
  });

  bool get canReuseResult =>
      status == OcrPageOutcomeStatus.succeeded && text != null;

  Map<String, dynamic> toMap() => {
    'imageIndex': imageIndex,
    'status': status.name,
    if (text != null) 'text': text,
    if (error != null) 'error': error,
  };

  static OcrPageOutcome? fromMap(dynamic value) {
    if (value is! Map) return null;
    final imageIndex = value['imageIndex'];
    final status = value['status'];
    if (imageIndex is! int || imageIndex < 0 || status is! String) return null;
    OcrPageOutcomeStatus? parsedStatus;
    for (final candidate in OcrPageOutcomeStatus.values) {
      if (candidate.name == status) {
        parsedStatus = candidate;
        break;
      }
    }
    if (parsedStatus == null) return null;
    return OcrPageOutcome(
      imageIndex: imageIndex,
      status: parsedStatus,
      text: value['text'] is String ? value['text'] as String : null,
      error: value['error'] is String ? value['error'] as String : null,
    );
  }
}
