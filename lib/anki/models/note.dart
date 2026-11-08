import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' show Element, Node;
import 'package:html/parser.dart' show parseFragment;

/// Anki Note — exact 1:1 mapping of the upstream Rust `Note` struct
/// (ankitects/anki rslib/src/notes/mod.rs).
///
/// Field naming follows the upstream Rust source / protobuf definition
/// (`notes.proto`), NOT the DB column short names.
///
/// ## Version reference
/// - AnkiDroid target release: **2.24.0** (May 2026)
/// - Upstream anki commit tracked at proto import time
/// - Upstream Rust workspace: `rslib/src/notes/mod.rs`
///
/// ## Key differences from DB storage
/// - `fields` is a `List<String>` (in-memory); DB stores as 0x1f-separated string in `flds`.
/// - `tags` is a `List<String>` (in-memory); DB stores as space-separated string.
/// - `sort_field` is `String?` (in-memory); DB stores as required `sfld`.
/// - `checksum` is `int?` (in-memory); DB stores as required `csum`.

/// In-memory Note matching the upstream Rust `Note` struct.
class Note {
  int id; // PRIMARY KEY — microsecond timestamp
  String guid; // globally unique id (for syncing)
  int notetype_id; // model id / note type id (was: mid)
  int mtime; // last modified epoch seconds (was: mod)
  int usn; // update sequence number
  List<String> tags; // tag list (was: space-separated String)
  List<String> fields; // field values list (was: 0x1f-separated String in flds)
  String? sort_field; // first non-empty sort field (was: String sfld)
  int? checksum; // checksum for duplicate detection (was: int csum)
  int flags; // flags
  String custom_data; // JSON string (was: data)

  Note({
    int? id,
    this.guid = '',
    required this.notetype_id,
    this.mtime = 0,
    this.usn = -1,
    List<String>? tags,
    required this.fields,
    this.sort_field,
    this.checksum,
    this.flags = 0,
    this.custom_data = '',
  })  : id = id ?? _nextId(),
        tags = tags ?? [];

  /// Creates a new note from a notetype id and field values.
  factory Note.createNew({
    required int notetype_id,
    required List<String> fields,
    List<String>? tags,
  }) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final sf = fields.isNotEmpty ? fields.first : '';
    return Note(
      id: now,
      guid: _guid(),
      notetype_id: notetype_id,
      mtime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      tags: tags ?? [],
      fields: fields,
      sort_field: sf,
    );
  }

  /// Creates a new note from a notetype id and field values string (0x1f-separated).
  factory Note.createNewFromFlds({
    required int notetype_id,
    required String flds,
    String tagsStr = '',
  }) {
    final fields =
        flds.isEmpty ? <String>[] : flds.split(String.fromCharCode(0x1f));
    return Note.createNew(
      notetype_id: notetype_id,
      fields: fields,
      tags: tagsStr.trim().isEmpty
          ? <String>[]
          : tagsStr.trim().split(' ').where((t) => t.isNotEmpty).toList(),
    );
  }

  /// Fields as a 0x1f-separated string for DB storage.
  String get fldsForDb => fields.join(String.fromCharCode(0x1f));

  /// Tags as a space-padded string for DB storage (e.g. " tag1 tag2 ").
  String get tagsForDb {
    if (tags.isEmpty) return '';
    return ' ${tags.join(' ')} ';
  }

  /// Sort field value for DB storage (derived from fields[0] if not set).
  String get sfldForDb =>
      Note.stripHtml(sort_field ?? (fields.isNotEmpty ? fields.first : ''));

  /// Checksum for DB storage, always derived from the first field.
  int get csumForDb =>
      checksum ?? Note.computeChecksum(fields.isNotEmpty ? fields.first : '');

  // ── Tag helpers ───────────────────────────────────────────────────────

  bool hasTag(String t) => tags.contains(t);

  void addTag(String t) {
    if (!tags.contains(t)) {
      tags.add(t);
    }
  }

  void removeTag(String t) {
    tags.remove(t);
  }

  // ── Serialization ─────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'guid': guid,
        'mid': notetype_id,
        'mod': mtime,
        'usn': usn,
        'tags': tagsForDb,
        'flds': fldsForDb,
        'sfld': sfldForDb,
        'csum': csumForDb,
        'flags': flags,
        'data': custom_data,
      };

  factory Note.fromMap(Map<String, dynamic> m) {
    final fldsStr = m['flds'] as String? ?? '';
    final fields =
        fldsStr.isEmpty ? <String>[] : fldsStr.split(String.fromCharCode(0x1f));
    final tagsStr = m['tags'] as String? ?? '';
    final tags = tagsStr.trim().isEmpty
        ? <String>[]
        : tagsStr.trim().split(' ').where((t) => t.isNotEmpty).toList();
    return Note(
      id: m['id'] as int,
      guid: m['guid'] as String? ?? '',
      notetype_id: m['mid'] as int,
      mtime: m['mod'] as int? ?? 0,
      usn: m['usn'] as int? ?? -1,
      tags: tags,
      fields: fields,
      sort_field: m['sfld']?.toString(),
      checksum: m['csum'] as int?,
      flags: m['flags'] as int? ?? 0,
      custom_data: m['data'] as String? ?? '',
    );
  }

  static int _counter = 0;
  static int _nextId() {
    _counter++;
    return DateTime.now().microsecondsSinceEpoch + _counter;
  }

  static String _guid() => '${DateTime.now().microsecondsSinceEpoch}_$_counter';

  /// Compute the checksum for a field value (SHA1 truncated to u32).
  static int computeChecksum(String text) {
    final plainText = stripHtml(text);
    return int.parse(
      sha1.convert(utf8.encode(plainText)).toString().substring(0, 8),
      radix: 16,
    );
  }

  static final RegExp _ankiMediaTag = RegExp(
    r'''<\b(?:img|audio|video|object|source)\b(?:[^>"']|"[^"]*"|'[^']*')*>''',
    caseSensitive: false,
  );
  static final RegExp _htmlMarkup = RegExp(
    r'<!--.*?-->|<style\b.*?</style>|<script\b.*?</script>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _ankiSoundReference = RegExp(r'\[sound:([^\]]+)\]');
  static final RegExp _ankiCssUrl = RegExp(
    r'''url\(\s*(?:"([^"]*)"|'([^']*)'|([^)]*?))\s*\)''',
    caseSensitive: false,
  );

  /// Strip Anki field markup before storing the sort field/checksum.
  static String stripHtml(String value) {
    final withMediaFilenames = value.replaceAllMapped(_ankiMediaTag, (match) {
      final tag = match.group(0)!;
      final fragment = parseFragment(tag);
      Element? mediaElement;
      for (final node in fragment.nodes) {
        if (node is Element) {
          mediaElement = node;
          break;
        }
      }
      final source = mediaElement?.attributes['src'];
      final data = mediaElement?.attributes['data'];
      final filename = source?.isNotEmpty == true
          ? source
          : data?.isNotEmpty == true
              ? data
              : null;
      if (filename == null) return tag;

      // Attribute values are already entity-decoded by the HTML parser. Escape
      // them before reinserting so the final fragment parse decodes once.
      return ' ${const HtmlEscape(HtmlEscapeMode.element).convert(filename)} ';
    });
    final withoutTags = withMediaFilenames.replaceAll(_htmlMarkup, '');
    return parseFragment(withoutTags).text?.replaceAll('\u00a0', ' ') ?? '';
  }

  /// Rename references to media files whose server names were made safe for
  /// the local filesystem. Only media attributes and Anki sound references
  /// are changed; ordinary text and unrelated attributes are preserved.
  static String rewriteMediaReferences(
    String value,
    Map<String, String> replacements,
  ) {
    if (replacements.isEmpty) return value;

    final withCssReferences = rewriteCssMediaReferences(value, replacements);
    var changed = withCssReferences != value;
    final withSoundReferences = withCssReferences.replaceAllMapped(
      _ankiSoundReference,
      (match) {
        final oldFilename = match.group(1)!;
        final newFilename = replacements[oldFilename];
        if (newFilename == null || newFilename == oldFilename) {
          return match.group(0)!;
        }
        changed = true;
        return '[sound:$newFilename]';
      },
    );

    final fragment = parseFragment(withSoundReferences);
    void rewriteNode(Node node) {
      if (node is Element &&
          const {
            'img',
            'audio',
            'video',
            'object',
            'source',
          }.contains(node.localName)) {
        for (final attribute in const ['src', 'data']) {
          final oldFilename = node.attributes[attribute];
          final newFilename =
              oldFilename == null ? null : replacements[oldFilename];
          if (newFilename != null && newFilename != oldFilename) {
            node.attributes[attribute] = newFilename;
            changed = true;
          }
        }
      }
      for (final child in node.nodes.toList()) {
        rewriteNode(child);
      }
    }

    for (final node in fragment.nodes.toList()) {
      rewriteNode(node);
    }
    return changed ? fragment.outerHtml : value;
  }

  /// Rewrite exact local media references inside CSS `url()` values.
  static String rewriteCssMediaReferences(
    String value,
    Map<String, String> replacements,
  ) {
    if (replacements.isEmpty) return value;
    return value.replaceAllMapped(_ankiCssUrl, (match) {
      final quote = match.group(1) != null
          ? '"'
          : match.group(2) != null
              ? "'"
              : '';
      final oldFilename = match.group(1) ?? match.group(2) ?? match.group(3);
      final newFilename =
          oldFilename == null ? null : replacements[oldFilename];
      if (newFilename == null || newFilename == oldFilename) {
        return match.group(0)!;
      }
      return 'url($quote$newFilename$quote)';
    });
  }

  @override
  String toString() => 'Note(id=$id, notetype_id=$notetype_id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Note && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
