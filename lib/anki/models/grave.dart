/// Deleted objects pending sync — exact 1:1 mapping of the graves table.
class AnkiGrave {
  int usn; // update sequence number
  int oid; // original object id
  int type; // 1=note, 2=card, 3=deck

  AnkiGrave({required this.usn, required this.oid, required this.type});

  Map<String, dynamic> toMap() => {'usn': usn, 'oid': oid, 'type': type};

  factory AnkiGrave.fromMap(Map<String, dynamic> m) => AnkiGrave(
        usn: m['usn'] as int,
        oid: m['oid'] as int,
        type: m['type'] as int,
      );
}
