/// AnkiDroid review log — exact 1:1 mapping of the revlog table.
class AnkiRevlog {
  int id; // PRIMARY KEY — microsecond timestamp
  int cid; // cards.id
  int usn; // update sequence number
  int ease; // rating: 1=again, 2=hard, 3=good, 4=easy
  int ivl; // new interval (days)
  int lastIvl; // previous interval (days)
  int factor; // ease factor after review (2500 = 250%)
  int time; // review duration (milliseconds)
  int type; // 0=learning, 1=review, 2=relearning, 3=filtered

  AnkiRevlog({
    int? id,
    required this.cid,
    this.usn = -1,
    required this.ease,
    required this.ivl,
    this.lastIvl = 0,
    this.factor = 2500,
    this.time = 0,
    this.type = 1,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
        'id': id,
        'cid': cid,
        'usn': usn,
        'ease': ease,
        'ivl': ivl,
        'lastIvl': lastIvl,
        'factor': factor,
        'time': time,
        'type': type,
      };

  factory AnkiRevlog.fromMap(Map<String, dynamic> m) => AnkiRevlog(
        id: m['id'] as int?,
        cid: m['cid'] as int,
        usn: m['usn'] as int? ?? -1,
        ease: m['ease'] as int,
        ivl: m['ivl'] as int,
        lastIvl: m['lastIvl'] as int? ?? 0,
        factor: m['factor'] as int? ?? 2500,
        time: m['time'] as int? ?? 0,
        type: m['type'] as int? ?? 1,
      );

  @override
  String toString() => 'AnkiRevlog(cid=$cid, ease=$ease, ivl=$ivl)';
}
