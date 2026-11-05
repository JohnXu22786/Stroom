# Active streaming Markdown parsing

## Current cost

The live stream stores text in a canonical `StringBuffer` per active section. At
each throttled update, `textChunks` materializes that active section as a
`String`. The chat page replaces the active `TextSegment`; its `MarkdownWidget`
then reparses the complete active section.

The locked `markdown_widget` 2.3.2+8 implementation confirms this behavior:

- `MarkdownWidgetState.didUpdateWidget` clears its widget list and calls
  `updateState` for every data update.
- `updateState` invokes `MarkdownGenerator.buildWidgets(widget.data)`.
- `MarkdownGenerator.buildWidgets` splits the whole string into lines,
  constructs a new `markdown.Document`, and calls `parseLines` for all lines.

The locked `markdown` 7.3.1 implementation has no resumable document parser:
`Document.parseLines` converts every line and calls `parseLineList`, which
creates a new `BlockParser`, parses all blocks, parses inline content, and
filters footnotes. `BlockParser` owns mutable line position, buffered lines,
block syntax state, and blank-line state for one complete parse.

The plain-text delta path from PR #1417 avoids the Markdown widget entirely
when its syntax scanner can prove the active section is plain text. It does not
change the Markdown rendering path described above.

## Why a renderer-only suffix cache is unsafe

There is no stable block boundary available from the current parser API. A
blank line does not prove that earlier output is final: setext headings can
reinterpret a preceding paragraph; list continuation can absorb following
lines; reference definitions and footnotes affect nodes elsewhere in the
document; and an open fence, HTML block, table, or inline delimiter can span
updates. The project's custom math syntax also recognizes expressions only
once their closing delimiter arrives. Parsing a guessed prefix independently
can therefore differ from parsing the full document.

Keeping the existing `MarkdownWidget` for an active tail while separately
rendering a cached prefix would also need a single persistent `Document` (and
AST/widget invalidation) so later definitions and references can update earlier
blocks. The current `markdown_widget` API exposes neither that document nor an
incremental append/update operation. Reimplementing block-boundary detection
in Stroom would duplicate CommonMark parser state and risk semantic drift.

## Smallest safe next step

Add a resumable document/session API to `markdown` and a widget update API to
`markdown_widget`, or maintain a Stroom-owned fork that provides both. The
session must retain parser state across line appends, invalidate from the
earliest affected block when cross-document definitions change, and expose
stable AST/widget identities for unchanged blocks. The widget API should
update only those changed nodes while preserving current Markdown config,
custom syntax/generators, TOC, search, and selection behavior.

Before enabling that path, add equivalence coverage comparing incremental and
full-document output at arbitrary chunk boundaries for open fences, nested and
lazy lists, setext headings, HTML, tables, link references, footnotes, inline
constructs, and custom math. Until that parser contract exists, full reparsing
of active Markdown is the smallest safe behavior; reducing its frequency alone
would not remove the repeated growing snapshots or establish semantic
correctness.
