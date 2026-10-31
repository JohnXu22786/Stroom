/// Anki Grave — deleted objects pending sync (graves table).
///
/// ## Version reference
/// - AnkiDroid target release: **2.24.0** (May 2026)
///
/// ## Field mapping
/// | DB column | Dart field | Meaning            |
/// |-----------|------------|--------------------|
/// | usn       | usn        | update seq number  |
/// | oid       | oid        | original object id |
/// | type      | type       | 0=card, 1=note, 2=deck |

class Grave {
  int usn;
  int oid;
  int type; // 0=card, 1=note, 2=deck

  Grave({required this.usn, required this.oid, required this.type});

  Map<String, dynamic> toMap() => {'usn': usn, 'oid': oid, 'type': type};

  factory Grave.fromMap(Map<String, dynamic> m) =>
      Grave(usn: m['usn'] as int, oid: m['oid'] as int, type: m['type'] as int);
}
