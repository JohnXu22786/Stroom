# ASR long-audio resource benchmark

The harness writes generated zero-filled, mono, 16 kHz, signed 16-bit WAV files
in bounded blocks. Run every mode in a fresh Flutter test process so Linux
`VmHWM` starts from the same process baseline:

```sh
export PATH="/workspace/flutter-sdk/bin:$PATH"
ASR_BENCH_MODE=eager-allocation-control ASR_BENCH_MINUTES=10 ASR_BENCH_FILE_COUNT=1 flutter test --no-pub tests/utils/audio_asr_resource_benchmark_test.dart --reporter expanded
ASR_BENCH_MODE=lazy-segmented ASR_BENCH_MINUTES=10 ASR_BENCH_FILE_COUNT=1 flutter test --no-pub tests/utils/audio_asr_resource_benchmark_test.dart --reporter expanded
ASR_BENCH_MODE=eager-allocation-control ASR_BENCH_MINUTES=30 ASR_BENCH_FILE_COUNT=1 flutter test --no-pub tests/utils/audio_asr_resource_benchmark_test.dart --reporter expanded
ASR_BENCH_MODE=lazy-segmented ASR_BENCH_MINUTES=30 ASR_BENCH_FILE_COUNT=1 flutter test --no-pub tests/utils/audio_asr_resource_benchmark_test.dart --reporter expanded
ASR_BENCH_MODE=eager-allocation-control ASR_BENCH_MINUTES=60 ASR_BENCH_FILE_COUNT=1 flutter test --no-pub tests/utils/audio_asr_resource_benchmark_test.dart --reporter expanded
ASR_BENCH_MODE=lazy-segmented ASR_BENCH_MINUTES=60 ASR_BENCH_FILE_COUNT=1 flutter test --no-pub tests/utils/audio_asr_resource_benchmark_test.dart --reporter expanded
ASR_BENCH_MODE=eager-allocation-control ASR_BENCH_MINUTES=10 ASR_BENCH_FILE_COUNT=5 flutter test --no-pub tests/utils/audio_asr_resource_benchmark_test.dart --reporter expanded
ASR_BENCH_MODE=lazy-segmented ASR_BENCH_MINUTES=10 ASR_BENCH_FILE_COUNT=5 flutter test --no-pub tests/utils/audio_asr_resource_benchmark_test.dart --reporter expanded
```

Both modes read the same files and use the same current `AudioChunker.planAsync`
frame planner. `eager-allocation-control` models eager ownership by retaining
the source plus two byte snapshots and every materialized chunk across the
scenario. `lazy-segmented` processes one file at a time and materializes then
releases one chunk at a time, yielding between chunks. This controlled pair
isolates source/chunk retention and materialization responsiveness while
holding the planner constant. The harness also stages each generated input
through `AsrRetryAudioStore` before planning, so `retryAudioStageMs` includes
the content digest and persisted-byte verification. Its in-memory adapter
keeps only the active staged file and avoids measuring native filesystem or
browser IndexedDB latency. Provider calls remain outside this harness and are
covered by scheduler tests. WAV generation is completed before the 10 ms
timer starts, so `maxEventLoopTimerGapMs` covers source reads, retry-audio
staging, planning, and materialization but excludes benchmark input setup;
`inputBuildMs` reports that setup separately.

The pre-implementation baseline was recorded before edits using the original
synchronous `AudioChunker.split` path. It retained the source, two full handoff
snapshots, and every split output. Its raw results are historical context, not
a direct paired delta against the current staging-inclusive controlled comparison:

| Scenario | Historical peak RSS | Chunking time | Max 10 ms timer gap |
| --- | ---: | ---: | ---: |
| 10 min × 1 | 311.0 MiB | 140 ms | 186 ms |
| 30 min × 1 | 584.7 MiB | 378 ms | 476 ms |
| 60 min × 1 | 992.6 MiB | 1,136 ms | 1,291 ms |
| 10 min × 5 | 544.1 MiB | 562 ms | 259 ms |

The following controlled eager-versus-lazy measurements were captured before
retry-audio staging was included in the harness. Keep them as historical
chunk-only context, not as the current staging-inclusive comparison.

| Scenario | Peak RSS: eager control → lazy | Max timer gap: eager → lazy | Chunk work: eager → lazy | Elapsed: eager → lazy |
| --- | ---: | ---: | ---: | ---: |
| 10 min × 1 | 216.6 → 180.5 MiB (−17%) | 38 → 16 ms | 128 → 131 ms | 186 → 160 ms |
| 30 min × 1 | 419.0 → 290.8 MiB (−31%) | 97 → 47 ms | 330 → 526 ms | 468 → 636 ms |
| 60 min × 1 | 683.1 → 428.7 MiB (−37%) | 220 → 65 ms | 688 → 678 ms | 953 → 804 ms |
| 10 min × 5 | 547.9 → 215.0 MiB (−61%) | 41 → 23 ms | 547 → 601 ms | 789 → 717 ms |

The eager control retains three complete source byte arrays per file plus all
chunk buffers, so its peak grows with every staged file. The lazy path retains
one active source and one materialized chunk on the main isolate. Native
planning temporarily transfers a full source copy to its worker isolate, so
the process can hold both isolate copies while planning. Peak RSS varies by scenario: the
single 60-minute file used 428.7 MiB, while the five-file batch used 215.0 MiB,
about half despite similar total audio duration. In this run, the lazy
30-minute case used less peak RSS and had a smaller timer gap but took longer
overall, which shows the time measurements vary by scenario. Timer gaps
in this native control are a responsiveness proxy during source reads and
chunk planning/materialization; the Web planner, preprocessing, and codecs
have separate yielding regressions.

After retry verification reads were changed to return a distinct byte buffer,
the same eight scenarios were rerun in fresh processes with staging enabled.
`Peak RSS` is `VmHWM`; `chunk work` is
planning plus materialization; `retry stage` includes save plus integrity
verification; and `elapsed` includes source reads, retry staging, and chunk
work. The hash worker temporarily receives a source copy on native platforms;
Web hashing instead processes bounded chunks and yields to the event loop.
Native silence planning transfers one active WAV payload to its worker through
`TransferableTypedData`, and that in-flight payload is included in the peak RSS.
All scenarios retained exact PCM-byte and frame coverage, with 10/30/60 chunks
for single-file runs and 50 chunks for the five-file run.

| Scenario | Peak RSS: eager → lazy | Max timer gap: eager → lazy | Retry stage: eager → lazy | Chunk work: eager → lazy | Elapsed: eager → lazy |
| --- | ---: | ---: | ---: | ---: | ---: |
| 10 min × 1 | 330.2 → 283.9 MiB | 42 → 22 ms | 666 → 491 ms | 154 → 131 ms | 867 → 649 ms |
| 30 min × 1 | 572.6 → 471.5 MiB | 70 → 37 ms | 1,460 → 1,388 ms | 303 → 311 ms | 1,858 → 1,750 ms |
| 60 min × 1 | 803.7 → 692.5 MiB | 141 → 60 ms | 2,779 → 2,869 ms | 594 → 602 ms | 3,552 → 3,548 ms |
| 10 min × 5 | 655.2 → 333.4 MiB | 34 → 25 ms | 2,442 → 2,285 ms | 495 → 551 ms | 3,081 → 2,914 ms |

These values are a fresh rerun on 2026-10-27 after the ADPCM pass-through
metadata correction. Peak RSS is the process `VmHWM`, rounded to one decimal
MiB. Each eager and lazy scenario ran in a separate test process. The 60-minute
single-file pair used nearly the same elapsed time; the 30-minute lazy run used
slightly more chunk work. Across all four cases, PCM bytes and frames matched
exactly. The five-file lazy run used about 49% less peak RSS and had a smaller
maximum timer gap than its eager control.

The in-memory adapter measures digest CPU and the store's byte verification,
including a distinct readback copy to model the full audio buffer returned by
native file reads, but not durable storage transport. These latest values
replace the prior staging-inclusive table after the native worker handoff
changed to `TransferableTypedData`. Results still vary across runs. In the
five-file case, lazy processing used about 49% less peak RSS and had a smaller
maximum timer gap, with similar elapsed time. The focused storage regression
verifies that timer callbacks run during large-audio staging and reload rather
than waiting for a full synchronous digest on the UI isolate.

On non-Linux hosts `VmHWM` is reported as `-1`. RSS and timing values vary by
runtime and machine; exact frame and PCM-byte coverage are the deterministic
checks.
