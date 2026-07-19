/// Anki note type (model) — JSON shape matches Anki's col blob.
class AnkiModel {
  int id;
  String name;
  int type; // 0=normal, 1=cloze
  int mod;
  int usn;
  int sortf; // sort field index
  int did; // default deck id
  List<ModelField> flds;
  List<ModelTemplate> tmpls;
  String css;
  List<dynamic> req; // [[ord, "all"|"any", [field ords...]], ...]
  List<String> tags;
  String latexPre;
  String latexPost;
  late String latex;

  AnkiModel({
    required this.id,
    required this.name,
    this.type = 0,
    this.mod = 0,
    this.usn = -1,
    this.sortf = 0,
    this.did = 1,
    List<ModelField>? flds,
    List<ModelTemplate>? tmpls,
    this.css =
        '.card {\n  font-family: arial;\n  font-size: 20px;\n  text-align: center;\n  color: black;\n  background-color: white;\n}\n',
    List<dynamic>? req,
    List<String>? tags,
    this.latexPre =
        r'\documentclass[12pt]{article}\usepackage{amsmath}\usepackage{amssymb}\usepackage[utf8]{inputenc}\usepackage{pgfpages}\pagestyle{empty}\setlength{\parindent}{0pt}\begin{document}',
    this.latexPost = r'\end{document}',
    this.latex = 'dvipng',
  })  : flds = flds ?? [],
        tmpls = tmpls ?? [],
        req = req ?? [],
        tags = tags ?? [];

  factory AnkiModel.createBasic() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return AnkiModel(
      id: now,
      name: 'Basic',
      flds: [
        ModelField(name: 'Front', ord: 0, font: 'Arial', size: 20),
        ModelField(name: 'Back', ord: 1, font: 'Arial', size: 20),
      ],
      tmpls: [
        ModelTemplate(
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
      sortf: 0,
    );
  }

  /// Creates a "Cloze" model.
  factory AnkiModel.createCloze() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return AnkiModel(
      id: now + 1,
      name: 'Cloze',
      type: 1, // cloze
      flds: [
        ModelField(name: 'Text', ord: 0, font: 'Arial', size: 20),
        ModelField(name: 'Extra', ord: 1, font: 'Arial', size: 20),
      ],
      tmpls: [
        ModelTemplate(
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
      sortf: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'mod': mod,
        'usn': usn,
        'sortf': sortf,
        'did': did,
        'flds': flds.map((f) => f.toJson()).toList(),
        'tmpls': tmpls.map((t) => t.toJson()).toList(),
        'css': css,
        'req': req,
        'tags': tags,
        'latexPre': latexPre,
        'latexPost': latexPost,
        'latex': latex,
      };

  factory AnkiModel.fromJson(Map<String, dynamic> j) => AnkiModel(
        id: j['id'] as int,
        name: j['name'] as String,
        type: j['type'] as int? ?? 0,
        mod: j['mod'] as int? ?? 0,
        usn: j['usn'] as int? ?? -1,
        sortf: j['sortf'] as int? ?? 0,
        did: j['did'] as int? ?? 1,
        flds: (j['flds'] as List?)
                ?.map((f) => ModelField.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [],
        tmpls: (j['tmpls'] as List?)
                ?.map((t) => ModelTemplate.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        css: j['css'] as String? ?? '',
        req: j['req'] as List<dynamic>? ?? [],
        tags: (j['tags'] as List?)?.cast<String>() ?? [],
        latexPre: j['latexPre'] as String? ?? '',
        latexPost: j['latexPost'] as String? ?? '',
      );
}

class ModelField {
  String name;
  int ord;
  String font;
  int size;
  bool sticky;
  bool rtl;
  List<String> media;

  ModelField({
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

  factory ModelField.fromJson(Map<String, dynamic> j) => ModelField(
        name: j['name'] as String,
        ord: j['ord'] as int? ?? 0,
        font: j['font'] as String? ?? 'Arial',
        size: j['size'] as int? ?? 20,
        sticky: j['sticky'] as bool? ?? false,
        rtl: j['rtl'] as bool? ?? false,
        media: (j['media'] as List?)?.cast<String>() ?? [],
      );
}

class ModelTemplate {
  String name;
  int ord;
  String qfmt;
  String afmt;
  String bqfmt;
  String bafmt;
  int? did; // deck override

  ModelTemplate({
    required this.name,
    this.ord = 0,
    this.qfmt = '',
    this.afmt = '',
    this.bqfmt = '',
    this.bafmt = '',
    this.did,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'ord': ord,
        'qfmt': qfmt,
        'afmt': afmt,
        if (bqfmt.isNotEmpty) 'bqfmt': bqfmt,
        if (bafmt.isNotEmpty) 'bafmt': bafmt,
        if (did != null) 'did': did,
      };

  factory ModelTemplate.fromJson(Map<String, dynamic> j) => ModelTemplate(
        name: j['name'] as String,
        ord: j['ord'] as int? ?? 0,
        qfmt: j['qfmt'] as String? ?? '',
        afmt: j['afmt'] as String? ?? '',
        bqfmt: j['bqfmt'] as String? ?? '',
        bafmt: j['bafmt'] as String? ?? '',
        did: j['did'] as int?,
      );
}
