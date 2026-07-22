/// Anki NoteType (model) — JSON shape matches Anki's col blob.
///
/// In the upstream code, "model" is referred to as "note type" or "notetype"
/// (`rslib/src/notetype/`). The class name `Notetype` follows the upstream
/// Rust / protobuf naming (`notetypes.proto`).
///
/// ## Version reference
/// - AnkiDroid target release: **2.24.0** (May 2026)
/// - Upstream anki commit tracked at proto import time

/// Note type (model) matching Anki's col blob JSON format.
class Notetype {
  int id;
  String name;
  int type; // 0=normal, 1=cloze
  int mtime; // last modified (was: mod)
  int usn;
  int sortFieldIndex; // sort field index (was: sortf)
  int defaultDeckId; // default deck id (was: did)
  List<NoteField> fields; // (was: flds)
  List<NoteTemplate> templates; // (was: tmpls)
  String css;
  List<dynamic> req; // [[ord, "all"|"any", [field ords...]], ...]
  List<String> tags;
  String latexPre;
  String latexPost;
  String latex;

  Notetype({
    required this.id,
    required this.name,
    this.type = 0,
    this.mtime = 0,
    this.usn = -1,
    this.sortFieldIndex = 0,
    this.defaultDeckId = 1,
    List<NoteField>? fields,
    List<NoteTemplate>? templates,
    this.css =
        '.card {\n  font-family: arial;\n  font-size: 20px;\n  text-align: center;\n  color: black;\n  background-color: white;\n}\n',
    List<dynamic>? req,
    List<String>? tags,
    this.latexPre =
        r'\documentclass[12pt]{article}\usepackage{amsmath}\usepackage{amssymb}\usepackage[utf8]{inputenc}\usepackage{pgfpages}\pagestyle{empty}\setlength{\parindent}{0pt}\begin{document}',
    this.latexPost = r'\end{document}',
    this.latex = 'dvipng',
  })  : fields = fields ?? [],
        templates = templates ?? [],
        req = req ?? [],
        tags = tags ?? [];

  factory Notetype.createBasic() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return Notetype(
      id: now,
      name: 'Basic',
      fields: [
        NoteField(name: 'Front', ord: 0, font: 'Arial', size: 20),
        NoteField(name: 'Back', ord: 1, font: 'Arial', size: 20),
      ],
      templates: [
        NoteTemplate(
          name: 'Card 1',
          ord: 0,
          qfmt: '{{Front}}',
          afmt: '{{FrontSide}}\n\n<hr id="answer">\n\n{{Back}}',
        ),
      ],
      req: [
        0,
        0,
        [0]
      ], // ord 0, all, field 0
      sortFieldIndex: 0,
    );
  }

  /// Creates a "Cloze" note type.
  factory Notetype.createCloze() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return Notetype(
      id: now + 1,
      name: 'Cloze',
      type: 1, // cloze
      fields: [
        NoteField(name: 'Text', ord: 0, font: 'Arial', size: 20),
        NoteField(name: 'Extra', ord: 1, font: 'Arial', size: 20),
      ],
      templates: [
        NoteTemplate(
          name: 'Cloze',
          ord: 0,
          qfmt: '{{cloze:Text}}',
          afmt: '{{cloze:Text}}\n\n<hr id="answer">\n\n{{Extra}}',
        ),
      ],
      req: [
        0,
        0,
        [0]
      ],
      sortFieldIndex: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'mod': mtime,
        'usn': usn,
        'sortf': sortFieldIndex,
        'did': defaultDeckId,
        'flds': fields.map((f) => f.toJson()).toList(),
        'tmpls': templates.map((t) => t.toJson()).toList(),
        'css': css,
        'req': req,
        'tags': tags,
        'latexPre': latexPre,
        'latexPost': latexPost,
        'latex': latex,
      };

  factory Notetype.fromJson(Map<String, dynamic> j) => Notetype(
        id: j['id'] as int,
        name: j['name'] as String,
        type: j['type'] as int? ?? 0,
        mtime: j['mod'] as int? ?? 0,
        usn: j['usn'] as int? ?? -1,
        sortFieldIndex: j['sortf'] as int? ?? 0,
        defaultDeckId: j['did'] as int? ?? 1,
        fields: (j['flds'] as List?)
                ?.map((f) => NoteField.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [],
        templates: (j['tmpls'] as List?)
                ?.map((t) => NoteTemplate.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        css: j['css'] as String? ?? '',
        req: j['req'] as List<dynamic>? ?? [],
        tags: (j['tags'] as List?)?.cast<String>() ?? [],
        latexPre: j['latexPre'] as String? ?? '',
        latexPost: j['latexPost'] as String? ?? '',
      );
}

/// A field within a note type (was: ModelField).
class NoteField {
  String name;
  int ord;
  String font;
  int size;
  bool sticky;
  bool rtl;
  List<String> media;

  NoteField({
    required this.name,
    this.ord = 0,
    this.font = 'Arial',
    this.size = 20,
    this.sticky = false,
    this.rtl = false,
    List<String>? media,
  }) : media = media ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'ord': ord,
        'font': font,
        'size': size,
        'sticky': sticky,
        'rtl': rtl,
        'media': media,
      };

  factory NoteField.fromJson(Map<String, dynamic> j) => NoteField(
        name: j['name'] as String,
        ord: j['ord'] as int? ?? 0,
        font: j['font'] as String? ?? 'Arial',
        size: j['size'] as int? ?? 20,
        sticky: j['sticky'] as bool? ?? false,
        rtl: j['rtl'] as bool? ?? false,
        media: (j['media'] as List?)?.cast<String>() ?? [],
      );
}

/// A card template within a note type (was: ModelTemplate).
class NoteTemplate {
  String name;
  int ord;
  String qfmt;
  String afmt;
  String bqfmt;
  String bafmt;
  int? deckId; // deck override (was: did)

  NoteTemplate({
    required this.name,
    this.ord = 0,
    this.qfmt = '',
    this.afmt = '',
    this.bqfmt = '',
    this.bafmt = '',
    this.deckId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'ord': ord,
        'qfmt': qfmt,
        'afmt': afmt,
        if (bqfmt.isNotEmpty) 'bqfmt': bqfmt,
        if (bafmt.isNotEmpty) 'bafmt': bafmt,
        if (deckId != null) 'did': deckId,
      };

  factory NoteTemplate.fromJson(Map<String, dynamic> j) => NoteTemplate(
        name: j['name'] as String,
        ord: j['ord'] as int? ?? 0,
        qfmt: j['qfmt'] as String? ?? '',
        afmt: j['afmt'] as String? ?? '',
        bqfmt: j['bqfmt'] as String? ?? '',
        bafmt: j['bafmt'] as String? ?? '',
        deckId: j['did'] as int?,
      );
}
