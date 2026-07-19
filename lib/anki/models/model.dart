/// Represents a note type (model) in the Anki system.
///
/// Note types define the fields and card templates for a type of note.
/// Examples: Basic, Basic (and reversed), Cloze, etc.
class AnkiModel {
  /// Unique model ID
  int id;

  /// Model name
  String name;

  /// Field names
  List<String> fieldNames;

  /// Card template definitions (name, question template, answer template)
  List<CardTemplate> templates;

  /// Whether this is a cloze model
  bool isCloze;

  /// CSS styling
  String css;

  /// Last modification time
  int modified;

  AnkiModel({
    required this.id,
    required this.name,
    this.fieldNames = const ['Front', 'Back'],
    this.templates = const [],
    this.isCloze = false,
    this.css = '',
    this.modified = 0,
  });

  /// Creates the default "Basic" model.
  factory AnkiModel.createBasic() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AnkiModel(
      id: now,
      name: 'Basic',
      fieldNames: ['Front', 'Back'],
      templates: [
        CardTemplate(
          name: 'Card 1',
          questionTemplate: '{{Front}}',
          answerTemplate: '{{FrontSide}}\n\n<hr id="answer">\n\n{{Back}}',
        ),
      ],
      css:
          '.card {\n  font-family: arial;\n  font-size: 20px;\n  text-align: center;\n  color: black;\n  background-color: white;\n}\n',
    );
  }

  /// Creates a "Basic (and reversed)" model.
  factory AnkiModel.createBasicReversed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return AnkiModel(
      id: now,
      name: 'Basic (and reversed card)',
      fieldNames: ['Front', 'Back'],
      templates: [
        CardTemplate(
          name: 'Card 1',
          questionTemplate: '{{Front}}',
          answerTemplate: '{{FrontSide}}\n\n<hr id="answer">\n\n{{Back}}',
        ),
        CardTemplate(
          name: 'Card 2',
          questionTemplate: '{{Back}}',
          answerTemplate: '{{FrontSide}}\n\n<hr id="answer">\n\n{{Front}}',
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fieldNames': fieldNames,
        'templates': templates.map((t) => t.toJson()).toList(),
        'isCloze': isCloze,
        'css': css,
        'modified': modified,
      };

  factory AnkiModel.fromJson(Map<String, dynamic> json) => AnkiModel(
        id: json['id'] as int,
        name: json['name'] as String,
        fieldNames:
            (json['fieldNames'] as List<dynamic>?)?.cast<String>() ?? [],
        templates: (json['templates'] as List<dynamic>?)
                ?.map((t) => CardTemplate.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        isCloze: json['isCloze'] as bool? ?? false,
        css: json['css'] as String? ?? '',
        modified: json['modified'] as int? ?? 0,
      );
}

/// A card template within a model.
class CardTemplate {
  /// Template name
  String name;

  /// Question template (with {{Field}} markers)
  String questionTemplate;

  /// Answer template (with {{Field}} markers)
  String answerTemplate;

  CardTemplate({
    required this.name,
    required this.questionTemplate,
    required this.answerTemplate,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'questionTemplate': questionTemplate,
        'answerTemplate': answerTemplate,
      };

  factory CardTemplate.fromJson(Map<String, dynamic> json) => CardTemplate(
        name: json['name'] as String,
        questionTemplate: json['questionTemplate'] as String,
        answerTemplate: json['answerTemplate'] as String,
      );
}
