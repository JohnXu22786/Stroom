/// Anki Deck — matching the upstream protobuf `Deck` message
/// (ankitects/anki rslib/src/decks/mod.rs, decks.proto).
///
/// ## Version reference
/// - AnkiDroid target release: **2.24.0** (May 2026)
/// - Upstream anki commit tracked at proto import time
///
/// ## Structure
/// The `Deck` struct uses a `Common` sub-object for shared state and a
/// `kind` field to distinguish Normal vs Filtered decks, matching the
/// upstream protobuf definition.

// ─── Deck kind ────────────────────────────────────────────────────────────

/// Whether a deck is Normal or Filtered.
enum DeckKind {
  normal,
  filtered,
}

// ─── DeckCommon (shared state) ────────────────────────────────────────────

/// Common deck properties matching `Deck.Common` in decks.proto.
class DeckCommon {
  bool studyCollapsed;
  bool browserCollapsed;
  int lastDayStudied;
  int newStudied;
  int reviewStudied;
  int millisecondsStudied;
  int learningStudied;

  DeckCommon({
    this.studyCollapsed = false,
    this.browserCollapsed = false,
    this.lastDayStudied = 0,
    this.newStudied = 0,
    this.reviewStudied = 0,
    this.millisecondsStudied = 0,
    this.learningStudied = 0,
  });

  Map<String, dynamic> toJson() => {
        'studyCollapsed': studyCollapsed,
        'browserCollapsed': browserCollapsed,
        'lastDayStudied': lastDayStudied,
        'newStudied': newStudied,
        'reviewStudied': reviewStudied,
        'millisecondsStudied': millisecondsStudied,
        'learningStudied': learningStudied,
      };

  factory DeckCommon.fromJson(Map<String, dynamic> j) => DeckCommon(
        studyCollapsed: j['studyCollapsed'] as bool? ?? false,
        browserCollapsed: j['browserCollapsed'] as bool? ?? false,
        lastDayStudied: j['lastDayStudied'] as int? ?? 0,
        newStudied: j['newStudied'] as int? ?? 0,
        reviewStudied: j['reviewStudied'] as int? ?? 0,
        millisecondsStudied: j['millisecondsStudied'] as int? ?? 0,
        learningStudied: j['learningStudied'] as int? ?? 0,
      );
}

// ─── Normal deck info ─────────────────────────────────────────────────────

/// Normal deck properties matching `Deck.Normal` in decks.proto.
class NormalDeckInfo {
  int configId;
  int extendNew;
  int extendReview;
  String description;
  bool markdownDescription;
  int? reviewLimit;
  int? newLimit;
  double? desiredRetention;

  NormalDeckInfo({
    this.configId = 1,
    this.extendNew = 0,
    this.extendReview = 0,
    this.description = '',
    this.markdownDescription = false,
    this.reviewLimit,
    this.newLimit,
    this.desiredRetention,
  });

  Map<String, dynamic> toJson() => {
        'configId': configId,
        'extendNew': extendNew,
        'extendReview': extendReview,
        'description': description,
        'markdownDescription': markdownDescription,
        if (reviewLimit != null) 'reviewLimit': reviewLimit,
        if (newLimit != null) 'newLimit': newLimit,
        if (desiredRetention != null) 'desiredRetention': desiredRetention,
      };

  factory NormalDeckInfo.fromJson(Map<String, dynamic> j) => NormalDeckInfo(
        configId: j['configId'] as int? ?? 1,
        extendNew: j['extendNew'] as int? ?? 0,
        extendReview: j['extendReview'] as int? ?? 0,
        description: j['description'] as String? ?? '',
        markdownDescription: j['markdownDescription'] as bool? ?? false,
        reviewLimit: j['reviewLimit'] as int?,
        newLimit: j['newLimit'] as int?,
        desiredRetention: (j['desiredRetention'] as num?)?.toDouble(),
      );
}

// ─── Deck ─────────────────────────────────────────────────────────────────

/// In-memory Deck matching the upstream protobuf `Deck` message.
///
/// ## Field mapping
///
/// | Protobuf field   | Dart field         | Legacy field |
/// |------------------|--------------------|--------------|
/// | id               | id                 | id           |
/// | name             | name               | name         |
/// | mtime_secs       | mtimeSecs          | mod          |
/// | usn              | usn                | usn          |
/// | common           | common             | collapsed*   |
/// | normal/filtered  | kind               | dyn          |
/// | normal.config_id | normalInfo.configId | conf         |
class Deck {
  int id;
  String name;
  int mtimeSecs; // last modified epoch seconds (was: mod)
  int usn; // update sequence number
  int creationDate; // creation date epoch seconds (was: crt)
  DeckCommon common;
  DeckKind kind;
  NormalDeckInfo? normalInfo; // populated when kind == normal

  Deck({
    required this.id,
    required this.name,
    this.mtimeSecs = 0,
    this.usn = -1,
    this.creationDate = 0,
    DeckCommon? common,
    this.kind = DeckKind.normal,
    this.normalInfo,
  }) : common = common ?? DeckCommon();

  factory Deck.createNew({required String name, String description = ''}) {
    _idCounter++;
    final now = DateTime.now().microsecondsSinceEpoch;
    return Deck(
      id: now + _idCounter,
      name: name,
      mtimeSecs: now ~/ 1000,
      creationDate: now ~/ 1000,
      normalInfo: NormalDeckInfo(description: description),
    );
  }

  // ── Legacy compat accessors ───────────────────────────────────────────

  /// Legacy alias — returns true for filtered decks.
  @Deprecated('Use kind == DeckKind.filtered')
  bool get dyn => kind == DeckKind.filtered;

  /// Legacy alias — returns configId from normalInfo.
  @Deprecated('Use normalInfo.configId')
  int get conf => normalInfo?.configId ?? 1;

  /// Legacy alias — returns description from normalInfo.
  @Deprecated('Use normalInfo.description')
  String get desc => normalInfo?.description ?? '';

  /// Legacy alias — sets mtimeSecs.
  @Deprecated('Use mtimeSecs instead')
  int get mod => mtimeSecs;

  @Deprecated('Use mtimeSecs instead')
  set mod(int v) => mtimeSecs = v;

  /// Legacy alias for collapsed state.
  @Deprecated('Use common.studyCollapsed')
  bool get collapsed => common.studyCollapsed;

  @Deprecated('Use common.studyCollapsed')
  set collapsed(bool v) => common.studyCollapsed = v;

  /// Legacy alias for browser collapsed state.
  @Deprecated('Use common.browserCollapsed')
  bool get browserCollapsed => common.browserCollapsed;

  @Deprecated('Use common.browserCollapsed')
  set browserCollapsed(bool v) => common.browserCollapsed = v;

  // ── Name helpers ──────────────────────────────────────────────────────

  String? get parentName {
    final i = name.lastIndexOf('::');
    return i < 0 ? null : name.substring(0, i);
  }

  String get childName {
    final i = name.lastIndexOf('::');
    return i < 0 ? name : name.substring(i + 2);
  }

  bool isParentOf(String n) => n.startsWith('$name::');

  // ── Anki-compatible JSON (legacy schema11 format) ─────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': normalInfo?.description ?? '',
        'mod': mtimeSecs,
        'usn': usn,
        'dyn': kind == DeckKind.filtered ? 1 : 0,
        'conf': normalInfo?.configId ?? 1,
        'crt': creationDate,
        'lrnToday': [common.learningStudied, common.lastDayStudied],
        'revToday': [common.reviewStudied, common.lastDayStudied],
        'newToday': [common.newStudied, common.lastDayStudied],
        'timeToday': [common.millisecondsStudied, common.lastDayStudied],
        'collapsed': common.studyCollapsed,
        'browserCollapsed': common.browserCollapsed,
      };

  factory Deck.fromJson(Map<String, dynamic> j) {
    final lrnToday = (j['lrnToday'] as List?)?.cast<int>() ?? [0, 0];
    final revToday = (j['revToday'] as List?)?.cast<int>() ?? [0, 0];
    final newToday = (j['newToday'] as List?)?.cast<int>() ?? [0, 0];
    final timeToday = (j['timeToday'] as List?)?.cast<int>() ?? [0, 0];
    return Deck(
      id: j['id'] as int,
      name: j['name'] as String,
      mtimeSecs: j['mod'] as int? ?? 0,
      usn: j['usn'] as int? ?? -1,
      creationDate: j['crt'] as int? ?? 0,
      kind: (j['dyn'] as int? ?? 0) == 1 ? DeckKind.filtered : DeckKind.normal,
      normalInfo: NormalDeckInfo(
        configId: j['conf'] as int? ?? 1,
        description: j['desc'] as String? ?? '',
      ),
      common: DeckCommon(
        studyCollapsed: j['collapsed'] as bool? ?? false,
        browserCollapsed: j['browserCollapsed'] as bool? ?? false,
        learningStudied: lrnToday.isNotEmpty ? lrnToday[0] : 0,
        reviewStudied: revToday.isNotEmpty ? revToday[0] : 0,
        newStudied: newToday.isNotEmpty ? newToday[0] : 0,
        millisecondsStudied: timeToday.isNotEmpty ? timeToday[0] : 0,
        lastDayStudied: lrnToday.length > 1 ? lrnToday[1] : 0,
      ),
    );
  }

  static int _idCounter = 0;

  @override
  String toString() => 'Deck(id=$id, name=$name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Deck && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
