# AnkiDroid Alignment Version

This Dart implementation of the Anki flashcard system is aligned with:

- **AnkiDroid release:** [2.24.0](https://github.com/ankidroid/Anki-Android/releases/tag/v2.24.0) (May 2026)
- **Upstream Anki (ankitects/anki):** `main` branch at [commit c1fc45928dfa3fd12050c2bf254c2e3f33463830](https://github.com/ankitects/anki/tree/c1fc45928dfa3fd12050c2bf254c2e3f33463830) (approximate, tracked at proto import time)
- **Anki database schema version:** 11
- **Scheduler:** V3 (compatible with upstream Anki scheduler)

## Model Mapping

The Dart model classes in `lib/anki/models/` follow the upstream Rust struct definitions in `ankitects/anki/rslib/src/`:

| Dart class | Upstream Rust source | Protobuf definition |
|---|---|---|
| `Card` | `rslib/src/card/mod.rs` | `anki/cards.proto` |
| `Note` | `rslib/src/notes/mod.rs` | `anki/notes.proto` |
| `Deck` | `rslib/src/decks/mod.rs` | `anki/decks.proto` |
| `RevlogEntry` | `rslib/src/revlog/mod.rs` | `anki/stats.proto` |
| `Grave` | — (table only) | — |
| `Notetype` | `rslib/src/notetype/` | `anki/notetypes.proto` |

## Upgrade Path

When updating to a newer AnkiDroid release:

1. Check the [AnkiDroid releases page](https://github.com/ankidroid/Anki-Android/releases)
2. Update the version reference at the top of this file
3. Sync protobuf definitions from `ankitects/anki` if needed
4. Update model classes to match any new fields in the Rust structs / protobufs

## Excluded Features

- **AnkiWeb server sync** — this implementation does not include server-side sync functionality.
  Client-side sync code exists in `lib/anki/sync/` and `anki_source/` for local compatibility.
- **FSRS full implementation** — FSRS-related fields (`memory_state`, `desired_retention`, `decay`)
  are defined on the model but FSRS scheduling is not yet implemented.
