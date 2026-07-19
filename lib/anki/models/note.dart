/// Represents a note (fact) in the Anki system.
///
/// Notes are the raw data from which cards are generated.
/// A note belongs to a model (note type) which defines its fields and card templates.
/// Each note can generate one or more cards.
class AnkiNote {
  /// Unique note ID (millisecond timestamp at creation)
  int id;

  /// Globally unique identifier (used for syncing)
  String guid;

  /// Model ID (note type ID)
  int modelId;

  /// Last modification time (epoch seconds)
  int modified;

  /// Update sequence number (used for syncing, -1 = local changes)
  int usn;

  /// Tags (space-separated string internally, exposed as list)
  List<String> tags;

  /// Field values (each element is the text of one field)
  List<String> fields;

  /// Sort field (first field text, for sorting)
  String sortField;

  /// Checksum (for duplicate detection)
  int csum;

  /// Flags
  int flags;

  /// Extra data (JSON string)
  String data;

  AnkiNote({
    required this.id,
    required this.modelId,
    this.guid = '',
    this.modified = 0,
    this.usn = -1,
    List<String>? tags,
    required this.fields,
    this.sortField = '',
    this.csum = 0,
    this.flags = 0,
    this.data = '',
  }) : tags = tags ?? [];

  /// Creates a new note with a unique ID and auto-generated GUID.
  factory AnkiNote.createNew({
    required int modelId,
    required List<String> fields,
    List<String> tags = const [],
  }) {
    _idCounter++;
    final now = DateTime.now().microsecondsSinceEpoch;
    return AnkiNote(
      id: now + _idCounter,
      modelId: modelId,
      guid: _generateGuid(),
      modified: now ~/ 1000,
      fields: fields,
      sortField: fields.isNotEmpty ? fields.first : '',
      tags: List.from(tags),
    );
  }

  static int _idCounter = 0;

  /// Generates a simple GUID.
  static String _generateGuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = (now * 7 + 13) % 100000;
    return '${now}_$random';
  }

  /// Adds a tag to this note.
  void addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
      tags.add(trimmed);
    }
  }

  /// Removes a tag from this note.
  void removeTag(String tag) {
    tags.remove(tag);
  }

  /// Returns whether this note has the specified tag.
  bool hasTag(String tag) => tags.contains(tag);

  // --- JSON Serialization ---

  Map<String, dynamic> toJson() => {
        'id': id,
        'guid': guid,
        'modelId': modelId,
        'modified': modified,
        'usn': usn,
        'tags': tags.join(' '),
        'fields': fields.join(String.fromCharCode(0x1f)),
        'sortField': sortField,
        'csum': csum,
        'flags': flags,
        'data': data,
      };

  factory AnkiNote.fromJson(Map<String, dynamic> json) {
    final fieldsStr = json['fields'] as String? ?? '';
    final tagsStr = json['tags'] as String? ?? '';
    return AnkiNote(
      id: json['id'] as int,
      modelId: json['modelId'] as int,
      guid: json['guid'] as String? ?? '',
      modified: json['modified'] as int? ?? 0,
      usn: json['usn'] as int? ?? -1,
      tags: tagsStr.isEmpty
          ? []
          : tagsStr.split(' ').where((t) => t.isNotEmpty).toList(),
      fields:
          fieldsStr.isEmpty ? [] : fieldsStr.split(String.fromCharCode(0x1f)),
      sortField: json['sortField'] as String? ?? '',
      csum: json['csum'] as int? ?? 0,
      flags: json['flags'] as int? ?? 0,
      data: json['data'] as String? ?? '',
    );
  }

  @override
  String toString() => 'AnkiNote(id=$id, modelId=$modelId, fields=$fields)';
}
