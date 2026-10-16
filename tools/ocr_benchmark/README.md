# OCR recognition quality benchmark

This directory contains 24 deterministic, synthetic PNG pages and their
golden transcriptions. The set covers Chinese and English text, dense small
text, rotated pages, multi-column reading order, tables, formulas, blank
pages, and low-contrast text. The fixtures contain no private source material.

The checked-in PNG hashes make the evaluation inputs verifiable without an
image library or network access:

    python3 tools/ocr_benchmark/evaluate.py --verify-fixtures
    python3 -m unittest discover -s tools/ocr_benchmark -p 'test_*.py' -v

The evaluator does not call a model. It consumes one JSON file of predictions,
plus the exact model identifier and non-secret recognition settings:

    {
      "run": {
        "model_id": "provider/model-version",
        "output_format": "markdown",
        "settings": {
          "temperature": 0,
          "top_p": 1,
          "max_tokens": 2048
        }
      },
      "predictions": [
        {
          "fixture_id": "mixed-zh-en-01",
          "text": "会议记录 / Meeting Notes",
          "elapsed_ms": 850,
          "returned_tokens": 42
        }
      ]
    }

Include one prediction per fixture for a complete run. A missing fixture or
null text counts as an omitted page. An empty string on a non-blank fixture
also counts as omitted; an empty string on a blank fixture is a returned
prediction. For elapsed-time and token metrics, run each fixture as a separate
OCR request and record that request's measurements on its fixture row. Do not
copy one joint-request total to multiple rows; if only run-level measurements
are available, leave the per-fixture fields null so those metrics remain
pending. `output_format` is one of `plain_text`, `markdown`, `table`, or
`latex` and is recorded in the report; if omitted it defaults to `plain_text`.

Run one evaluation or compare a candidate with a baseline using the same
manifest:

    python3 tools/ocr_benchmark/evaluate.py \
      --predictions /path/to/candidate.json \
      --baseline /path/to/baseline.json \
      --output /path/to/comparison.json

The report includes CER, omitted-page rate, reading-order score, table and
formula fidelity, total and mean elapsed time, and total and mean returned
tokens. A comparison labels each measured change as improved, unchanged, or a
regression. It uses no pass threshold or universal accuracy promise.

Normalization and metric definitions:

- Text is Unicode NFC; CRLF and CR become LF; consecutive whitespace is
  collapsed to one space and leading/trailing whitespace is removed.
- CER is code-point Levenshtein edit distance divided by the total normalized
  golden-text code points across pages. For `markdown` and `table` output, the
  evaluator removes headings, list/blockquote markers, annotated table pipes
  and separator rows, links, and inline emphasis/code markup before scoring.
  For `plain_text`, rows with the annotated column shape have table pipes
  normalized even when cell text differs; label-style prose and inline math are
  preserved.
  Intraword underscores are preserved as text rather than stripped as emphasis.
  It applies table-pipe normalization to both the golden and returned text. For
  `markdown`, `table`, and `latex`, it removes paired inline/display math
  delimiters while preserving unmatched and escaped dollar signs used as
  currency, and normalizes notation commands such as `\int`, `\theta`,
  `\alpha`, `\frac`, and `\sqrt`. Unicode punctuation
  immediately after inline math does not retain delimiters. For all formats,
  annotated formula spans are compacted for CER and superscript digit runs are
  normalized as one exponent. Compound fraction operands and exponent/subscript
  groups retain parentheses. This
  compares recognized content separately from the requested output syntax.
  Missing text is
  evaluated as an empty transcription and therefore contributes deletions.
- Page omission counts missing prediction rows, null text, or empty text for a
  non-empty golden page, divided by all fixtures.
- Reading-order score is the proportion of expected anchor pairs appearing in
  golden order within the normalized prediction. Anchors are unique fragments
  recorded for multi-column fixtures. A missing anchor is an incorrect pair;
  an empty or whitespace-only returned string scores zero. A missing prediction
  row or null text leaves this metric pending.
- Table fidelity compares the annotated rows and cells in sequence. It ignores
  optional outer Markdown pipes and a valid Markdown formatting row, while
  preserving annotated hyphen-only data rows and empty cells. For `plain_text`,
  it also accepts tab-separated table rows. An unframed pipe row must match an
  annotated row or have neighboring table context; a compact row with the wrong
  number of cells remains visible as an extra row. One-sided-pipe rows need an
  annotated match or neighboring table context; one-sided absolute-value
  equations such as `|x| = 2` remain formula text unless annotated as table
  rows. Labeled prose such as `Set relation: x | y` is not counted as a row. It
  remains a text check, not semantic table parsing. Escaped `\|` characters
  remain literal cell content.
  An exact annotated formula line is excluded from
  table comparison when removing it leaves the annotated rows intact. Formula
  fidelity compares the
  annotated formula as a complete span after whitespace compaction and Unicode
  superscript normalization; surrounding prose is allowed, but adjacent math
  operators, including spelled forms such as `plus` and `minus`, are not. For
  `markdown`, `table`, and `latex`, it
  also removes paired math delimiters, preserves unmatched currency dollar signs,
  and normalizes common notation such as `\int`, `\pi`, `\frac`, and `\sqrt`.
  It unwraps `\mathrm`, `\mathit`, `\operatorname`, and `\text` arguments while
  preserving font selectors such as `\mathbb` and `\mathbf`.
  Unmatched `\(`, `\)`, `\[`, `\]`, or `$` delimiters remain literal and fail
  formula fidelity when adjacent to the annotated formula.
  Escaped LaTeX text symbols such as `\%`, `\_`, and `\$` are scored as
  their literal characters.
  Paired math delimiters may touch CJK text; whitespace directly between CJK
  text and an annotated formula is ignored. Compound fraction operands and
  compound exponent/subscript groups retain grouping. It does not perform
  symbolic equivalence. Empty or whitespace-only returned text is a failed
  match. If any eligible page has a missing prediction row or null text, the
  metric value is null and its pending count is reported.
- Elapsed time is supplied in milliseconds per fixture. Returned tokens means
  provider-reported completion/output tokens per fixture. If any fixture lacks
  either measurement, that metric's total and mean are null and the missing
  page count is reported. A finite aggregate is required; overflow is reported
  as an evaluation error.

The deterministic self-tests and fixture checks validate the evaluator and
input set; they do not measure OCR model quality.

## Re-rendering fixtures

The PNGs are already checked in, so evaluation does not need Pillow or fonts.
To regenerate them, install the pinned optional rendering dependency and
provide the same Noto Sans CJK font file whose SHA-256 is recorded in
manifest.json:

    python3 -m pip install -r tools/ocr_benchmark/requirements.txt
    python3 tools/ocr_benchmark/generate_fixtures.py \
      --font /path/to/NotoSansCJK-Regular.ttc

The generator uses only the synthetic case definitions in
generate_fixtures.py; it does not read network or private data. Re-run the
fixture checks after regeneration:

    python3 tools/ocr_benchmark/evaluate.py --verify-fixtures

## Live benchmark status

**Pending.** This source-only task environment did not expose an authorized OCR
model configuration, so no live model requests or model scores were produced.
Provide a sanitized prediction file with the exact model identifier and
non-secret recognition settings to run the evaluator. The tool rejects
credential-like model IDs, setting names, and setting values, and never writes
prediction transcripts into its report.
