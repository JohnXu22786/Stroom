# ASR evaluation and platform smoke baseline

This baseline separates deterministic scoring checks from model evaluation.
The text-metric tests use small hand-written examples only to check edit
distance and Unicode handling; their outputs are not model accuracy results.
No speech audio is checked in: the repository's existing media parser fixtures
have no recorded speech content, references, source, or redistribution terms.
The provenance inventory is [sample-provenance.json](../tests/fixtures/asr/sample-provenance.json).
Add a reference-audio sample only after its source, license, speech reference,
and redistributability have been verified. Until then, Chinese, English,
mixed-language, names/numbers, noise/silence, sentence-boundary, and long-audio
reference-audio coverage remains an explicit data gap.

## Offline evaluation

The evaluator accepts a JSON manifest with one case per audio sample:

```json
{
  "cases": [
    {
      "id": "licensed-sample-id",
      "audio": "audio/example.wav",
      "format": "wav",
      "audioSeconds": 2.4,
      "reference": "Reference transcript",
      "transcript": "Previously captured transcript",
      "transcriptSegments": [
        {"startSeconds": 0.1, "endSeconds": 2.3, "text": "Transcript segment"}
      ],
      "language": "en",
      "conditions": ["sentence-boundary"],
      "provenance": {
        "source": "source URL or archive identifier",
        "license": "license identifier",
        "attribution": "required attribution"
      },
      "referenceSegments": [
        {"startSeconds": 0.0, "endSeconds": 2.4}
      ]
    }
  ]
}
```

Every case must provide non-empty `source`, `license`, and `attribution`
strings in `provenance`. The CLI rejects a case before opening its audio file
or making a provider request when any field is missing or blank.

Run without provider access using `flutter pub run tool/asr_evaluate.dart
manifest.json`. Offline mode requires `transcript` and never constructs an ASR
service or sends network requests. It reports CER, whitespace-delimited WER,
subtitle boundary offset when both segment lists are available, RTF, per-case
latency, resident memory, audio size, and provenance metadata. In offline mode,
latency and resident memory are reported only when recorded values are present
in the manifest. Offline subtitle offsets use `transcriptSegments` when both
reference and captured transcript segment timings are provided. Reports
omit audio bytes, references, transcripts, endpoint, and credentials. CER
counts Unicode grapheme clusters and preserves punctuation; WER uses
whitespace-delimited tokens, so language-specific Chinese word segmentation
is not implied.

For a real-provider run, explicitly set
`ASR_EVAL_ENABLE_PROVIDER=true`, `ASR_EVAL_ENDPOINT`, and `ASR_EVAL_API_KEY` in
the invoking process, and optionally `ASR_EVAL_MODEL`. This mode sends audio
directly through the evaluator's Dio client and does not exercise the app's
`AsrService`. Do not commit these values or real transcripts. The provider path sends supplied audio unchanged,
with no preprocessing, chunking, or compression. A provider run measures
end-to-end client latency; it does not isolate server compute time. Resident memory is sampled
after each case and is not a peak-RSS measurement. Actual model metrics only
exist when a real transcript is supplied by the provider or a real captured
result is explicitly supplied in offline mode.

## Platform smoke matrix

| Platform | Available repeatable coverage | Device/platform smoke status |
| --- | --- | --- |
| Linux | ASR protocol, chunking, retry, lifecycle, and evaluator unit tests in Flutter CI | CI host only; no provider request by default |
| Web | Existing Flutter Web/Chrome suites cover shared app paths; ASR evaluator text tests are platform-independent | No browser microphone or real provider smoke in the baseline |
| Android | ASR service tests use mocked HTTP and run in the Flutter test suite | No Android emulator/device smoke recorded |
| iOS | ASR service tests use mocked HTTP and run in the Flutter test suite | No iOS simulator/device smoke recorded |
| macOS | ASR service tests use mocked HTTP and run in the Flutter test suite | No macOS host smoke recorded |
| Windows | ASR service tests use mocked HTTP and run in the Flutter test suite | No Windows host smoke recorded |

The current GitHub Actions functional jobs run on Ubuntu. Native device audio
capture, permission handling, and provider interoperability still require
separate platform smoke runs. Ordinary CI remains offline and deterministic.
