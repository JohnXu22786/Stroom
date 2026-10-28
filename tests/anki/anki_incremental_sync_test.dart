import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/database/note_dao.dart';
import 'package:stroom/anki/database/revlog_dao.dart';
import 'package:stroom/anki/models/card.dart' as anki;
import 'package:stroom/anki/models/deck.dart' as anki_deck;
import 'package:stroom/anki/models/model.dart';
import 'package:stroom/anki/models/note.dart';
import 'package:stroom/anki/models/revlog.dart';
import 'package:stroom/anki/providers/anki_actions.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/anki/sync/anki_incremental_sync.dart';
import 'package:stroom/anki/sync/anki_sync_protocol_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workDir;
  late AnkiDatabase collection;
  late _QueueHttpClient fakeHttp;
  late AnkiSyncProtocolClient client;

  setUpAll(() {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('stroom_anki_sync_test_');
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();
    await collection.col.load();
    fakeHttp = _QueueHttpClient();
    client = AnkiSyncProtocolClient.ankiWeb(
      client: fakeHttp,
      hostKey: 'fake-host-key',
    );
  });

  tearDown(() async {
    client.close();
    fakeHttp.close();
    await collection.close();
    await workDir.delete(recursive: true);
  });

  test('merges a normal collection session and commits local USNs', () async {
    final model = collection.col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = anki.Card.createNew(note_id: note.id, deck_id: 1);
    await collection.cards.insert(card);
    final originalCollectionMod =
        (await collection.db.query('col')).single['mod'];

    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    final result = await AnkiIncrementalSync.sync(collection, client);

    expect(result.collectionChanged, isTrue);
    expect(await collection.notes.get(note.id), isNotNull);
    expect((await collection.notes.get(note.id))!.usn, 0);
    expect((await collection.cards.get(card.id))!.usn, 0);
    final col = (await collection.db.query('col')).single;
    expect(col['usn'], 1);
    expect(col['ls'], greaterThan(0));
    expect(col['mod'], originalCollectionMod);

    final applyChunkRequest = fakeHttp.requests.singleWhere(
      (request) => request.url.path == '/sync/applyChunk',
    );
    final payload = _decodedRequestData(applyChunkRequest);
    final chunk = payload['chunk'] as Map<String, dynamic>;
    expect((chunk['notes'] as List).single[0], note.id);
    expect((chunk['notes'] as List).single[7], '');
    expect((chunk['notes'] as List).single[8], '');
    expect((chunk['cards'] as List).single[0], card.id);
    expect(fakeHttp.requests.last.url.path, '/sync/finish');

    final sanityRequest = fakeHttp.requests.singleWhere(
      (request) => request.url.path == '/sync/sanityCheck2',
    );
    expect(_decodedRequestData(sanityRequest)['client'], [
      [0, 0, 0],
      1, // cards
      1, // notes
      0, // revlog
      0, // graves
      1, // models
      1, // decks
      1, // deck configs
    ]);
  });

  test(
    'syncs when the remote USN advances within the same modification second',
    () async {
      await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
      await AnkiIncrementalSync.sync(collection, client);

      final local = (await collection.db.query('col')).single;
      final localModified = local['mod'] as int;
      final localUsn = local['usn'] as int;
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteModified: localModified,
        remoteUsn: localUsn + 1,
      );

      final requestCountBeforeSync = fakeHttp.requests.length;
      final result = await AnkiIncrementalSync.sync(collection, client);

      expect(result.collectionChanged, isTrue);
      expect(
        fakeHttp.requests
            .skip(requestCountBeforeSync)
            .map((request) => request.url.path),
        contains('/sync/start'),
      );
    },
  );

  test('rejects short remote note, card, and review tuples', () async {
    final model = collection.col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = anki.Card.createNew(note_id: note.id, deck_id: 1);
    await collection.cards.insert(card);
    final review = RevlogEntry(cid: card.id, button_chosen: 3, interval: 1);
    await collection.revlog.insert(review);

    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    final malformedTuples = <MapEntry<String, List<int>>>[
      MapEntry('notes', [note.id]),
      MapEntry('cards', [card.id]),
      MapEntry('revlog', [review.id]),
    ];
    for (final malformed in malformedTuples) {
      final before = (await collection.db.query('col')).single;
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteModified: (before['mod'] as int) - 1,
        remoteChunk: {
          'done': true,
          malformed.key: [malformed.value],
        },
      );

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncException>()),
      );

      expect(fakeHttp.requests.last.url.path, '/sync/abort');
      final after = (await collection.db.query('col')).single;
      expect(after['mod'], before['mod']);
      expect(after['usn'], before['usn']);
      fakeHttp.responses.clear();
    }
  });

  test('rejects nonnumeric remote note, card, and review IDs', () async {
    final model = collection.col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = anki.Card.createNew(note_id: note.id, deck_id: 1);
    await collection.cards.insert(card);
    await collection.revlog.insert(
      RevlogEntry(cid: card.id, button_chosen: 3, interval: 1),
    );

    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    final malformedTuples = <MapEntry<String, List<dynamic>>>[
      MapEntry('notes', [
        'invalid-note-id',
        'guid',
        model.id,
        1,
        0,
        '',
        'front\x1fback',
        '',
        '',
        0,
        '',
      ]),
      MapEntry('cards', [
        'invalid-card-id',
        note.id,
        1,
        0,
        1,
        0,
        0,
        0,
        1,
        0,
        2500,
        0,
        0,
        0,
        0,
        0,
        0,
        '',
      ]),
      MapEntry('revlog', [
        'invalid-review-id',
        card.id,
        0,
        3,
        1,
        0,
        2500,
        1000,
        0,
      ]),
    ];

    for (final malformed in malformedTuples) {
      final before = (await collection.db.query('col')).single;
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteModified: (before['mod'] as int) - 1,
        remoteChunk: {
          'done': true,
          malformed.key: [malformed.value],
        },
      );

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncException>()),
      );

      expect(fakeHttp.requests.last.url.path, '/sync/abort');
      final table = switch (malformed.key) {
        'notes' => 'notes',
        'cards' => 'cards',
        _ => 'revlog',
      };
      expect(await collection.db.query(table, where: 'id = 0'), isEmpty);
      final after = (await collection.db.query('col')).single;
      expect(after['mod'], before['mod']);
      expect(after['usn'], before['usn']);
      fakeHttp.responses.clear();
    }
  });

  test('rejects remote chunk collections that have the wrong type', () async {
    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    for (final key in ['cards', 'notes', 'revlog']) {
      final before = (await collection.db.query('col')).single;
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteModified: (before['mod'] as int) - 1,
        remoteChunk: {'done': true, key: 'not-an-array'},
      );

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncException>()),
      );

      expect(fakeHttp.requests.last.url.path, '/sync/abort');
      final after = (await collection.db.query('col')).single;
      expect(after['mod'], before['mod']);
      expect(after['usn'], before['usn']);
      fakeHttp.responses.clear();
    }
  });

  test('rejects chunk responses without a boolean done field', () async {
    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    for (final remoteChunk in [
      {'cards': [], 'notes': [], 'revlog': []},
      {'done': 'true', 'cards': [], 'notes': [], 'revlog': []},
    ]) {
      final before = (await collection.db.query('col')).single;
      final previousChunkRequests = fakeHttp.requests
          .where((request) => request.url.path == '/sync/chunk')
          .length;
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteModified: (before['mod'] as int) - 1,
        remoteChunk: remoteChunk,
      );

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncException>()),
      );

      expect(
        fakeHttp.requests
            .where((request) => request.url.path == '/sync/chunk')
            .length,
        previousChunkRequests + 1,
      );
      expect(fakeHttp.requests.last.url.path, '/sync/abort');
      final after = (await collection.db.query('col')).single;
      expect(after['mod'], before['mod']);
      expect(after['usn'], before['usn']);
      fakeHttp.responses.clear();
    }
  });

  test('aborts when required remote note strings are not strings', () async {
    final model = collection.col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);

    for (final index in [1, 5, 6, 10]) {
      final before = (await collection.db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      ))
          .single;
      final colBefore = (await collection.db.query('col')).single;
      final remoteTuple = <dynamic>[
        note.id,
        'remote-guid',
        model.id,
        note.mtime + 1,
        0,
        ' remote-tag ',
        'remote front\x1fremote back',
        '',
        '',
        0,
        '',
      ]..[index] = null;

      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteModified: (colBefore['mod'] as int) - 1,
        remoteChunk: {
          'done': true,
          'notes': [remoteTuple],
        },
      );

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncException>()),
      );

      expect(fakeHttp.requests.last.url.path, '/sync/abort');
      final after = (await collection.db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      ))
          .single;
      for (final field in ['guid', 'tags', 'flds', 'data', 'usn', 'mod']) {
        expect(after[field], before[field], reason: 'field $field changed');
      }
      final colAfter = (await collection.db.query('col')).single;
      expect(colAfter['mod'], colBefore['mod']);
      expect(colAfter['usn'], colBefore['usn']);
      fakeHttp.responses.clear();
    }
  });

  test(
    'sends Basic and Cloze requirement tuples in Anki schema shape',
    () async {
      collection.col.addModel(Notetype.createCloze());
      await collection.col.save();

      await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
      await AnkiIncrementalSync.sync(collection, client);

      final changesRequest = fakeHttp.requests.singleWhere(
        (request) => request.url.path == '/sync/applyChanges',
      );
      final changes = _decodedRequestData(changesRequest)['changes']
          as Map<String, dynamic>;
      final models = (changes['models'] as List).cast<Map<String, dynamic>>();
      final basic = models.singleWhere((model) => model['name'] == 'Basic');
      final cloze = models.singleWhere((model) => model['name'] == 'Cloze');

      expect(basic['req'], [
        [
          0,
          'all',
          [0],
        ],
      ]);
      expect(cloze['req'], [
        [
          0,
          'any',
          [0],
        ],
      ]);
    },
  );

  test(
    'requires a full transfer when unchanged collection schemas differ',
    () async {
      await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
      await AnkiIncrementalSync.sync(collection, client);

      final local = (await collection.db.query('col')).single;
      final requestCount = fakeHttp.requests.length;
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteModified: local['mod'] as int,
        remoteSchema: (local['scm'] as int) + 1,
      );

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncFullTransferRequired>()),
      );
      expect(fakeHttp.requests.length, requestCount + 1);
      expect(fakeHttp.requests.last.url.path, endsWith('/sync/meta'));
    },
  );

  test(
    'requires a full transfer when the server collection is empty',
    () async {
      final note = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['existing local note', 'back'],
      )..usn = 0;
      await collection.notes.insert(note);
      await collection.db.update(
        'notes',
        {'usn': 0},
        where: 'id = ?',
        whereArgs: [note.id],
      );
      final local = (await collection.db.query('col')).single;
      fakeHttp.responses.add(
        _json({
          'mod': local['mod'],
          'scm': local['scm'],
          'usn': local['usn'],
          'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'msg': '',
          'cont': true,
          'hostNum': 1,
          'empty': true,
          'media_usn': 0,
        }),
      );

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncFullTransferRequired>()),
      );
      expect(
        fakeHttp.requests.map((request) => request.url.path),
        ['/sync/meta'],
      );
    },
  );

  test('requires a full transfer before changing sync destinations', () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['destination switch', 'note'],
    );
    await collection.notes.insert(note);
    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    final otherHttp = _QueueHttpClient();
    final otherClient = AnkiSyncProtocolClient.selfHosted(
      endpoint: 'https://other-sync.example.invalid',
      client: otherHttp,
      hostKey: 'other-host-key',
    );
    try {
      await expectLater(
        AnkiIncrementalSync.sync(collection, otherClient),
        throwsA(isA<AnkiSyncFullTransferRequired>()),
      );
      expect(otherHttp.requests, isEmpty);
      expect((await collection.notes.get(note.id))!.usn, 0);
    } finally {
      otherClient.close();
      otherHttp.close();
    }
  });

  test('migrates legacy deck configs as pending sync changes', () async {
    await collection.db.delete('deck_config');
    await collection.close();

    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();
    await collection.col.load();

    final migratedConfigs = await collection.db.query('deck_config');
    expect(migratedConfigs, isNotEmpty);
    final migratedId = migratedConfigs.first['id'] as int;
    expect(migratedConfigs.first['usn'], -1);

    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    final changesRequest = fakeHttp.requests.singleWhere(
      (request) => request.url.path == '/sync/applyChanges',
    );
    final changes =
        _decodedRequestData(changesRequest)['changes'] as Map<String, dynamic>;
    final deckConfigs = (changes['decks'] as List)[1] as List;
    expect(
      deckConfigs.map((config) => (config as List).first),
      contains(migratedId),
    );
    expect((await collection.db.query('deck_config')).first['usn'], 0);
  });

  test('keeps a newer local deck config over an older server copy', () async {
    final localRow = (await collection.db.query('deck_config')).single;
    final localConfig =
        jsonDecode(localRow['config'] as String) as Map<String, dynamic>;
    localConfig['syncTestValue'] = 'local';
    final localMtime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await collection.db.update(
      'deck_config',
      {'config': jsonEncode(localConfig), 'mtime_secs': localMtime, 'usn': -1},
      where: 'id = ?',
      whereArgs: [localRow['id']],
    );

    final olderServerConfig = Map<String, dynamic>.from(localConfig)
      ..['syncTestValue'] = 'server';
    await _queueCollectionSync(
      fakeHttp,
      collection,
      sanityStatus: 'ok',
      remoteChanges: {
        'decks': [
          [],
          [
            [
              localRow['id'],
              localRow['name'],
              localMtime - 1,
              0,
              olderServerConfig,
            ],
          ],
        ],
      },
    );

    await AnkiIncrementalSync.sync(collection, client);

    final savedRow = (await collection.db.query('deck_config')).single;
    final savedConfig =
        jsonDecode(savedRow['config'] as String) as Map<String, dynamic>;
    expect(savedConfig['syncTestValue'], 'local');
    expect(savedRow['mtime_secs'], localMtime);

    final changesRequest = fakeHttp.requests.singleWhere(
      (request) => request.url.path == '/sync/applyChanges',
    );
    final changes =
        _decodedRequestData(changesRequest)['changes'] as Map<String, dynamic>;
    final sentDeckConfig =
        ((changes['decks'] as List)[1] as List).single as List<dynamic>;
    expect(
      (sentDeckConfig[4] as Map<String, dynamic>)['syncTestValue'],
      'local',
    );
  });

  test('aborts on a truncated remote deck config tuple', () async {
    final localRow = (await collection.db.query('deck_config')).single;
    final beforeUsn = (await collection.db.query('col')).single['usn'];
    await _queueCollectionSync(
      fakeHttp,
      collection,
      sanityStatus: 'ok',
      remoteChanges: {
        'decks': [
          [],
          [
            [
              localRow['id'],
              localRow['name'],
              (localRow['mtime_secs'] as int) + 1,
              0,
            ],
          ],
        ],
      },
    );

    await expectLater(
      AnkiIncrementalSync.sync(collection, client),
      throwsA(isA<AnkiSyncException>()),
    );

    expect(fakeHttp.requests.last.url.path, '/sync/abort');
    expect((await collection.db.query('col')).single['usn'], beforeUsn);
    expect(
      (await collection.db.query('deck_config')).single['config'],
      localRow['config'],
    );
  });

  test('aborts on a remote deck config that is not an object', () async {
    final localRow = (await collection.db.query('deck_config')).single;
    final beforeUsn = (await collection.db.query('col')).single['usn'];
    await _queueCollectionSync(
      fakeHttp,
      collection,
      sanityStatus: 'ok',
      remoteChanges: {
        'decks': [
          [],
          [
            [
              localRow['id'],
              localRow['name'],
              (localRow['mtime_secs'] as int) + 1,
              0,
              'not-an-object',
            ],
          ],
        ],
      },
    );

    await expectLater(
      AnkiIncrementalSync.sync(collection, client),
      throwsA(isA<AnkiSyncException>()),
    );

    expect(fakeHttp.requests.last.url.path, '/sync/abort');
    expect((await collection.db.query('col')).single['usn'], beforeUsn);
    expect(
      (await collection.db.query('deck_config')).single['config'],
      localRow['config'],
    );
  });

  test('saves in-place notetype list edits as pending sync changes', () async {
    final colRow = (await collection.db.query('col')).single;
    final models =
        jsonDecode(colRow['models'] as String) as Map<String, dynamic>;
    final modelJson = models.values.first as Map<String, dynamic>;
    modelJson
      ..['mod'] = 1
      ..['usn'] = 0;
    await collection.db.update(
        'col',
        {
          'models': jsonEncode(models),
        },
        where: 'id = 1');
    await collection.col.reload();

    final model = collection.col.modelList.first;
    model.tags.add('edited tag');
    ((model.req.single as List)[2] as List).add(1);
    await collection.col.save();

    expect(model.usn, -1);
    expect(model.mtime, greaterThan(1));
    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    final changesRequest = fakeHttp.requests.singleWhere(
      (request) => request.url.path == '/sync/applyChanges',
    );
    final changes =
        _decodedRequestData(changesRequest)['changes'] as Map<String, dynamic>;
    final sentModel =
        (changes['models'] as List).single as Map<String, dynamic>;
    expect(sentModel['id'], model.id);
    expect(sentModel['tags'], contains('edited tag'));
    expect(sentModel['req'], [
      [
        0,
        'all',
        [0, 1],
      ],
    ]);
  });

  test(
    'addCard seeds and persists a note type for an empty collection',
    () async {
      await collection.db.update('col', {'models': '{}'}, where: 'id = 1');
      await collection.col.reload();
      expect(collection.col.modelList, isEmpty);

      final container = ProviderContainer(
        overrides: [
          ankiColDaoProvider.overrideWith((ref) async => collection.col),
        ],
      );
      addTearDown(container.dispose);

      final noteId = await container
          .read(ankiActionsProvider)
          .addCard(1, 'new front', 'new back');

      final note = await collection.notes.get(noteId);
      expect(note, isNotNull);
      expect(collection.col.getModel(note!.notetype_id), isNotNull);
      expect(await collection.cards.listByNote(noteId), hasLength(1));
      expect(collection.col.getModel(note.notetype_id)!.name, 'Basic');
    },
  );

  test(
    'addCard falls back to an available note type when the placeholder is stale',
    () async {
      final availableModelId = collection.col.modelList.first.id;
      expect(availableModelId, isNot(1));

      final container = ProviderContainer(
        overrides: [
          ankiColDaoProvider.overrideWith((ref) async => collection.col),
        ],
      );
      addTearDown(container.dispose);

      final noteId = await container
          .read(ankiActionsProvider)
          .addCard(1, 'new front', 'new back', modelId: 1);

      expect(
        (await collection.notes.get(noteId))!.notetype_id,
        availableModelId,
      );
    },
  );

  test('decodes named and numeric HTML entities in note fields', () {
    expect(Note.stripHtml('<b>&copy; &#65; &amp;&nbsp;</b>'), '© A & ');
  });

  test('preserves comparison text while stripping note field markup', () {
    expect(Note.stripHtml('1 < 2 > 0'), '1 < 2 > 0');
  });

  test('preserves media filenames while stripping Anki field markup', () {
    expect(
      Note.stripHtml(
        'front<script>ignored</script><!-- comment -->'
        '<img src="card&amp;1.jpg">',
      ),
      'front card&1.jpg ',
    );
  });

  test('does not treat data-src as the media filename attribute', () {
    expect(
      Note.stripHtml('<img data-src="lazy.jpg" src="actual.jpg">'),
      ' actual.jpg ',
    );
    expect(Note.stripHtml('<img data-src="lazy.jpg">'), '');
  });

  test('does not match media attributes inside another quoted attribute', () {
    expect(
      Note.stripHtml('<img alt="say src=wrong.jpg" src="right.jpg">'),
      ' right.jpg ',
    );
  });

  test('note checksum uses the first field when sort field is customized', () {
    final note = Note(
      notetype_id: 1,
      fields: ['<b>&copy; &#65;</b>', 'custom sort value'],
      sort_field: 'custom sort value',
    );

    expect(note.sfldForDb, 'custom sort value');
    expect(note.csumForDb, Note.computeChecksum('© A'));
  });

  test('note DAO preserves leading zeros in sort fields', () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['001', 'back'],
    );

    await collection.notes.insert(note);

    expect(
      (await collection.db.query(
        'notes',
        columns: ['sfld'],
        where: 'id = ?',
        whereArgs: [note.id],
      ))
          .single['sfld'],
      '001',
    );
  });

  test('migrates integer-affinity sort fields back to text', () async {
    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['001', 'back'],
    );
    await collection.notes.insert(note);
    await collection.close();

    final legacyDatabase = await sqflite.openDatabase(
      '${workDir.path}/collection.anki2',
    );
    await legacyDatabase.execute('ALTER TABLE notes RENAME TO notes_before');
    await legacyDatabase.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY,
        guid TEXT NOT NULL,
        mid INTEGER NOT NULL,
        mod INTEGER NOT NULL,
        usn INTEGER NOT NULL,
        tags TEXT NOT NULL,
        flds TEXT NOT NULL,
        sfld INTEGER NOT NULL,
        csum INTEGER NOT NULL,
        flags INTEGER NOT NULL,
        data TEXT NOT NULL
      )
    ''');
    await legacyDatabase.execute('''
      INSERT INTO notes
      SELECT id, guid, mid, mod, usn, tags, flds, CAST(sfld AS INTEGER),
        csum, flags, data
      FROM notes_before
    ''');
    await legacyDatabase.execute('DROP TABLE notes_before');
    await legacyDatabase.close();

    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();
    final stored = (await collection.notes.get(note.id))!..fields[0] = '001';
    await collection.notes.update(stored);

    final sortField = (await collection.db.query(
      'notes',
      columns: ['sfld'],
      where: 'id = ?',
      whereArgs: [note.id],
    ))
        .single['sfld'];
    final column = (await collection.db.rawQuery(
      'PRAGMA table_info(notes)',
    ))
        .singleWhere((column) => column['name'] == 'sfld');
    expect(column['type'], 'TEXT');
    expect(sortField, '001');
  });

  test(
    'note DAO refreshes sort field and checksum when fields change',
    () async {
      final model = collection.col.modelList.first..sortFieldIndex = 1;
      await collection.col.save();
      final note = Note.createNew(
        notetype_id: model.id,
        fields: ['original front', 'original sort'],
      );

      await collection.notes.insert(note);
      var stored = (await collection.notes.get(note.id))!;
      expect(stored.sfldForDb, 'original sort');

      stored.fields[0] = 'edited front';
      stored.fields[1] = 'edited sort';
      await collection.notes.update(stored);

      stored = (await collection.notes.get(note.id))!;
      expect(stored.sfldForDb, 'edited sort');
      expect(stored.csumForDb, Note.computeChecksum('edited front'));
    },
  );

  test('legacy metadata migration checksums the first field', () async {
    final model = collection.col.modelList.first..sortFieldIndex = 1;
    await collection.col.save();
    final note = Note(
      id: 123456789,
      notetype_id: model.id,
      fields: ['<b>&copy; &#65;</b>', 'custom sort value'],
      sort_field: 'custom sort value',
    );
    await collection.notes.insert(note);
    await collection.db.update(
      'notes',
      {'sfld': '<b>&copy; &#65;</b>', 'csum': 0},
      where: 'id = ?',
      whereArgs: [note.id],
    );
    await _removeSyncMetadataMigrationMarker(workDir);

    await collection.close();
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();

    final migrated = (await collection.notes.get(note.id))!;
    expect(migrated.sfldForDb, 'custom sort value');
    expect(migrated.csumForDb, Note.computeChecksum('© A'));
  });

  test('database open can retry after sync metadata migration fails', () async {
    final retryPath = '${workDir.path}/failed_open_retry';
    await Directory(retryPath).create();
    final temporaryMarker = Directory(
      '$retryPath/collection.anki2.stroom-sync-metadata-migration.tmp',
    );
    await temporaryMarker.create();
    final retryDatabase = AnkiDatabase(basePath: retryPath);

    try {
      await expectLater(
        retryDatabase.open(),
        throwsA(isA<FileSystemException>()),
      );
      await temporaryMarker.delete();

      await retryDatabase.open();
      await retryDatabase.col.load();

      expect(retryDatabase.col.modelList, isNotEmpty);
    } finally {
      await retryDatabase.close();
    }
  });

  test('concurrent open callers wait for DAO initialization', () async {
    await collection.close();
    collection = AnkiDatabase(basePath: workDir.path);

    await Future.wait([collection.open(), collection.open()]);
    await collection.col.load();

    expect(collection.col.deckList, isNotEmpty);
  });

  test('deck config seeding retries after a partial failure', () async {
    final row = (await collection.db.query(
      'col',
      columns: ['dconf'],
      where: 'id = 1',
    ))
        .single;
    final configs = jsonDecode(row['dconf'] as String) as Map<String, dynamic>;
    configs['2'] = Map<String, dynamic>.from(configs['1'] as Map)
      ..['id'] = 2
      ..['name'] = 'Second';
    await collection.db.update(
        'col',
        {
          'dconf': jsonEncode(configs),
        },
        where: 'id = 1');
    await collection.db.delete('deck_config');
    await collection.db.execute('''
      CREATE TRIGGER fail_second_deck_config
      BEFORE INSERT ON deck_config WHEN NEW.id = 2
      BEGIN SELECT RAISE(FAIL, 'test-only insert failure'); END
    ''');

    await collection.close();
    collection = AnkiDatabase(basePath: workDir.path);
    await expectLater(collection.open(), throwsA(anything));

    final maintenanceDatabase = await sqflite.openDatabase(
      '${workDir.path}/collection.anki2',
      singleInstance: false,
    );
    await maintenanceDatabase.execute('DROP TRIGGER fail_second_deck_config');
    await maintenanceDatabase.close();

    await collection.open();
    final seededIds = (await collection.db.query('deck_config'))
        .map((config) => config['id'])
        .toSet();
    expect(seededIds, containsAll([1, 2]));
  });

  test('legacy metadata migration runs once for the same collection', () async {
    final model = collection.col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    const preservedLegacyMillis = 1700000000000;
    await collection.db.update(
      'notes',
      {
        'mod': preservedLegacyMillis,
        'usn': 7,
        'sfld': 'intentionally stale after migration',
        'csum': 0,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );

    await collection.close();
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();

    final row = (await collection.db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [note.id],
    ))
        .single;
    expect(row['mod'], preservedLegacyMillis);
    expect(row['usn'], 7);
    expect(row['sfld'], 'intentionally stale after migration');
    expect(row['csum'], 0);
  });

  test('migrates legacy Basic and Cloze requirement metadata', () async {
    final cloze = Notetype.createCloze();
    collection.col.addModel(cloze);
    final customAny = Notetype.createBasic()
      ..id = cloze.id + 1
      ..name = 'Custom any';
    customAny.templates.add(
      NoteTemplate(
        name: 'Card 2',
        ord: 1,
        qfmt: '{{Front}}',
        afmt: '{{Back}}',
      ),
    );
    customAny.templates.add(
      NoteTemplate(
        name: 'Card 3',
        ord: 2,
        qfmt: '{{Back}}',
        afmt: '{{Front}}',
      ),
    );
    collection.col.addModel(customAny);
    await collection.col.save();

    final basic = collection.col.modelList.firstWhere(
      (model) => model.type == 0,
    );
    final models = jsonDecode(
      (await collection.db.query('col', columns: ['models'])).single['models']
          as String,
    ) as Map<String, dynamic>;
    final basicJson = models[basic.id.toString()] as Map<String, dynamic>;
    basicJson
      ..['req'] = [
        0,
        0,
        [0],
      ]
      ..['usn'] = 0;
    final clozeJson = models[cloze.id.toString()] as Map<String, dynamic>;
    clozeJson
      ..['req'] = [
        [
          0,
          0,
          [0],
        ],
      ]
      ..['usn'] = 0;
    models[customAny.id.toString()] as Map<String, dynamic>
      ..['req'] = [
        [
          0,
          1,
          [0],
        ],
        [
          1,
          0,
          [1],
        ],
        [
          2,
          2,
          [1],
        ],
      ]
      ..['usn'] = 0;
    await collection.db.update(
        'col',
        {
          'models': jsonEncode(models),
        },
        where: 'id = 1');
    final created = ((await collection.db.query('col', columns: ['crt']))
            .single['crt'] as num)
        .toInt();
    final migrationMarker = File(
      '${workDir.path}${Platform.pathSeparator}'
      'collection.anki2.stroom-sync-metadata-migration',
    );
    await migrationMarker.writeAsString('2:$created');

    await collection.close();
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();
    await collection.col.load();

    final migratedBasic = collection.col.modelList.firstWhere(
      (model) => model.type == 0,
    );
    final migratedCloze = collection.col.modelList.firstWhere(
      (model) => model.type == 1,
    );
    final migratedCustomAny = collection.col.modelList.firstWhere(
      (model) => model.id == customAny.id,
    );
    expect(migratedBasic.req, [
      [
        0,
        'all',
        [0],
      ],
    ]);
    expect(migratedBasic.usn, -1);
    expect(migratedCloze.req, [
      [
        0,
        'any',
        [0],
      ],
    ]);
    expect(migratedCloze.usn, -1);
    expect(migratedCustomAny.req, [
      [
        0,
        'any',
        [0],
      ],
      [
        1,
        'all',
        [1],
      ],
      [
        2,
        'none',
        [1],
      ],
    ]);
    expect(migratedCustomAny.usn, -1);
  });

  test(
    'legacy metadata migration marker is scoped to collection creation',
    () async {
      final model = collection.col.modelList.first;
      final note = Note.createNew(
        notetype_id: model.id,
        fields: ['replacement front', 'replacement back'],
      );
      await collection.notes.insert(note);
      await collection.db.update(
        'notes',
        {'sfld': 'stale', 'csum': 0},
        where: 'id = ?',
        whereArgs: [note.id],
      );
      final originalCollectionCreated =
          ((await collection.db.query('col', columns: ['crt'])).single['crt']
                  as num)
              .toInt();
      await collection.db.update(
          'col',
          {
            'crt': originalCollectionCreated + 1,
          },
          where: 'id = 1');

      await collection.close();
      collection = AnkiDatabase(basePath: workDir.path);
      await collection.open();

      final row = (await collection.db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      ))
          .single;
      expect(row['sfld'], 'replacement front');
      expect(row['csum'], Note.computeChecksum('replacement front'));
    },
  );

  test('local deletes write Anki card and note grave types', () async {
    final model = collection.col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['front', 'back'],
    );
    await collection.notes.insert(note);
    final card = anki.Card.createNew(note_id: note.id, deck_id: 1);
    await collection.cards.insert(card);
    final review = RevlogEntry(cid: card.id, button_chosen: 3, interval: 1);
    await collection.revlog.insert(review);

    final noteDeletedDirectly = Note.createNew(
      notetype_id: model.id,
      fields: ['note delete', 'cascade'],
    );
    await collection.notes.insert(noteDeletedDirectly);
    final cardDeletedWithNote = anki.Card.createNew(
      note_id: noteDeletedDirectly.id,
      deck_id: 1,
    );
    await collection.cards.insert(cardDeletedWithNote);
    await collection.revlog.insert(
      RevlogEntry(cid: cardDeletedWithNote.id, button_chosen: 3, interval: 1),
    );

    await collection.cards.delete(card.id);
    await collection.notes.delete(note.id);
    await collection.notes.delete(noteDeletedDirectly.id);

    final graves = await collection.graves.all();
    expect(graves.map((grave) => (grave.oid, grave.type, grave.usn)).toSet(), {
      (card.id, 0, -1),
      (note.id, 1, -1),
      (cardDeletedWithNote.id, 0, -1),
      (noteDeletedDirectly.id, 1, -1),
    });
    final currentSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expect((await collection.notes.get(note.id)), isNull);
    expect((await collection.cards.get(cardDeletedWithNote.id)), isNull);
    expect(currentSeconds - note.mtime, lessThan(10));
    expect(await collection.revlog.listByCard(card.id), isEmpty);
    expect(await collection.revlog.listByCard(cardDeletedWithNote.id), isEmpty);
  });

  test('deleting a filtered deck returns cards to their home decks', () async {
    final homeDeck = collection.col.deckList.first;
    final filteredDeck = collection.col.addDeck('Filtered deck removal test')
      ..kind = anki_deck.DeckKind.filtered;
    await collection.col.save();

    final note = Note.createNew(
      notetype_id: collection.col.modelList.first.id,
      fields: ['filtered', 'deck removal'],
    );
    await collection.notes.insert(note);

    final reviewCard =
        anki.Card.createNew(note_id: note.id, deck_id: filteredDeck.id)
          ..ctype = anki.CardType.review
          ..queue = anki.CardQueue.review
          ..due = -100
          ..original_due = 42
          ..original_deck_id = homeDeck.id
          ..interval = 12
          ..reps = 4;
    final learningCard =
        anki.Card.createNew(note_id: note.id, deck_id: filteredDeck.id)
          ..ctype = anki.CardType.learn
          ..queue = anki.CardQueue.review
          ..due = -101
          ..original_due = 1700000000
          ..original_deck_id = homeDeck.id;
    final suspendedCard =
        anki.Card.createNew(note_id: note.id, deck_id: filteredDeck.id)
          ..ctype = anki.CardType.review
          ..queue = anki.CardQueue.suspended
          ..due = -102
          ..original_due = 43
          ..original_deck_id = homeDeck.id;
    final dayLearningReviewCard =
        anki.Card.createNew(note_id: note.id, deck_id: filteredDeck.id)
          ..ctype = anki.CardType.review
          ..queue = anki.CardQueue.review
          ..due = -103
          ..original_due = 1700000000
          ..original_deck_id = homeDeck.id;
    final newCardAtZeroDue =
        anki.Card.createNew(note_id: note.id, deck_id: filteredDeck.id)
          ..ctype = anki.CardType.new_
          ..queue = anki.CardQueue.new_
          ..due = -104
          ..original_due = 0
          ..original_deck_id = homeDeck.id;
    for (final card in [
      reviewCard,
      learningCard,
      suspendedCard,
      dayLearningReviewCard,
      newCardAtZeroDue,
    ]) {
      await collection.cards.insert(card);
      await collection.revlog.insert(
        RevlogEntry(cid: card.id, button_chosen: 3, interval: 1),
      );
    }

    await collection.col.removeDeck(filteredDeck.id);

    final restoredReview = (await collection.cards.get(reviewCard.id))!;
    expect(restoredReview.deck_id, homeDeck.id);
    expect(restoredReview.original_deck_id, 0);
    expect(restoredReview.original_due, 0);
    expect(restoredReview.due, 42);
    expect(restoredReview.queue, anki.CardQueue.review);
    expect(restoredReview.interval, 12);
    expect(restoredReview.reps, 4);

    final restoredLearning = (await collection.cards.get(learningCard.id))!;
    expect(restoredLearning.deck_id, homeDeck.id);
    expect(restoredLearning.due, 1700000000);
    expect(restoredLearning.queue, anki.CardQueue.learn);

    final restoredSuspended = (await collection.cards.get(suspendedCard.id))!;
    expect(restoredSuspended.deck_id, homeDeck.id);
    expect(restoredSuspended.due, 43);
    expect(restoredSuspended.queue, anki.CardQueue.suspended);

    final restoredDayLearningReview =
        (await collection.cards.get(dayLearningReviewCard.id))!;
    expect(restoredDayLearningReview.deck_id, homeDeck.id);
    expect(restoredDayLearningReview.due, 1700000000);
    expect(restoredDayLearningReview.queue, anki.CardQueue.dayLearn);

    final restoredNewCardAtZeroDue =
        (await collection.cards.get(newCardAtZeroDue.id))!;
    expect(restoredNewCardAtZeroDue.deck_id, homeDeck.id);
    expect(restoredNewCardAtZeroDue.due, 0);
    expect(restoredNewCardAtZeroDue.queue, anki.CardQueue.new_);

    expect(await collection.notes.get(note.id), isNotNull);
    for (final card in [
      reviewCard,
      learningCard,
      suspendedCard,
      dayLearningReviewCard,
      newCardAtZeroDue,
    ]) {
      expect(await collection.revlog.listByCard(card.id), hasLength(1));
    }
    final graves = await collection.graves.all();
    expect(
      graves.where(
        (grave) => [
          reviewCard.id,
          learningCard.id,
          suspendedCard.id,
        ].contains(grave.oid),
      ),
      isEmpty,
    );
    expect(
      graves.map((grave) => (grave.oid, grave.type)),
      contains((filteredDeck.id, 2)),
    );
    expect(collection.col.getDeck(filteredDeck.id), isNull);
  });

  test(
    'deleting a deck cascades cards and reviews but keeps shared notes',
    () async {
      final model = collection.col.modelList.first..sortFieldIndex = 1;
      await collection.col.save();
      final modelId = model.id;
      final deck = collection.col.addDeck('Deck cascade test');
      final sharedNote = Note.createNew(
        notetype_id: modelId,
        fields: ['shared', 'note'],
      );
      final removedNote = Note.createNew(
        notetype_id: modelId,
        fields: ['only in deck', 'note'],
      );
      await collection.notes.insert(sharedNote);
      await collection.notes.insert(removedNote);
      final removedCard = anki.Card.createNew(
        note_id: sharedNote.id,
        deck_id: deck.id,
      );
      final retainedCard = anki.Card.createNew(
        note_id: sharedNote.id,
        deck_id: 1,
      );
      final onlyCard = anki.Card.createNew(
        note_id: removedNote.id,
        deck_id: deck.id,
      );
      await collection.cards.insert(removedCard);
      await collection.cards.insert(retainedCard);
      await collection.cards.insert(onlyCard);
      await collection.revlog.insert(
        RevlogEntry(cid: removedCard.id, button_chosen: 3, interval: 1),
      );
      await collection.revlog.insert(
        RevlogEntry(cid: retainedCard.id, button_chosen: 3, interval: 1),
      );
      await collection.revlog.insert(
        RevlogEntry(cid: onlyCard.id, button_chosen: 3, interval: 1),
      );

      await collection.col.removeDeck(deck.id);

      expect(await collection.cards.get(removedCard.id), isNull);
      expect(await collection.cards.get(onlyCard.id), isNull);
      expect((await collection.cards.get(retainedCard.id))!.deck_id, 1);
      expect(await collection.notes.get(sharedNote.id), isNotNull);
      expect(await collection.notes.get(removedNote.id), isNull);
      expect(await collection.revlog.listByCard(removedCard.id), isEmpty);
      expect(await collection.revlog.listByCard(onlyCard.id), isEmpty);
      expect(await collection.revlog.listByCard(retainedCard.id), hasLength(1));

      final graves = await collection.graves.all();
      expect(
        graves.map((grave) => (grave.oid, grave.type, grave.usn)).toSet(),
        {
          (removedCard.id, 0, -1),
          (onlyCard.id, 0, -1),
          (removedNote.id, 1, -1),
          (deck.id, 2, -1),
        },
      );
      expect(collection.col.getDeck(deck.id), isNull);
    },
  );

  test(
    'deleting a home deck also deletes its cards in filtered decks',
    () async {
      final homeDeck = collection.col.deckList.first;
      final retainedDeck = collection.col.addDeck('Retained home deck');
      final filteredDeck = collection.col.addDeck('Filtered deck')
        ..kind = anki_deck.DeckKind.filtered;
      await collection.col.save();

      final doomedNote = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['doomed', 'filtered-only'],
      );
      final sharedNote = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['shared', 'note'],
      );
      final retainedNote = Note.createNew(
        notetype_id: collection.col.modelList.first.id,
        fields: ['retained', 'filtered'],
      );
      await collection.notes.insert(doomedNote);
      await collection.notes.insert(sharedNote);
      await collection.notes.insert(retainedNote);

      final deletedFilteredCard = anki.Card.createNew(
        note_id: doomedNote.id,
        deck_id: filteredDeck.id,
      )..original_deck_id = homeDeck.id;
      final deletedSharedFilteredCard = anki.Card.createNew(
        note_id: sharedNote.id,
        deck_id: filteredDeck.id,
      )..original_deck_id = homeDeck.id;
      final retainedSharedCard = anki.Card.createNew(
        note_id: sharedNote.id,
        deck_id: retainedDeck.id,
      );
      final retainedFilteredCard = anki.Card.createNew(
        note_id: retainedNote.id,
        deck_id: filteredDeck.id,
      )..original_deck_id = retainedDeck.id;
      final cards = [
        deletedFilteredCard,
        deletedSharedFilteredCard,
        retainedSharedCard,
        retainedFilteredCard,
      ];
      for (final card in cards) {
        await collection.cards.insert(card);
        await collection.revlog.insert(
          RevlogEntry(cid: card.id, button_chosen: 3, interval: 1),
        );
      }

      await collection.col.removeDeck(homeDeck.id);

      expect(await collection.cards.get(deletedFilteredCard.id), isNull);
      expect(await collection.cards.get(deletedSharedFilteredCard.id), isNull);
      expect(
        await collection.revlog.listByCard(deletedFilteredCard.id),
        isEmpty,
      );
      expect(
        await collection.revlog.listByCard(deletedSharedFilteredCard.id),
        isEmpty,
      );
      expect(await collection.notes.get(doomedNote.id), isNull);
      expect(await collection.notes.get(sharedNote.id), isNotNull);
      expect(await collection.cards.get(retainedSharedCard.id), isNotNull);
      expect(await collection.notes.get(retainedNote.id), isNotNull);

      final graves = await collection.graves.all();
      expect(
        graves.map((grave) => (grave.oid, grave.type, grave.usn)).toSet(),
        {
          (deletedFilteredCard.id, 0, -1),
          (deletedSharedFilteredCard.id, 0, -1),
          (doomedNote.id, 1, -1),
          (homeDeck.id, 2, -1),
        },
      );

      await collection.col.removeDeck(filteredDeck.id);
      final restoredCard = (await collection.cards.get(
        retainedFilteredCard.id,
      ))!;
      expect(restoredCard.deck_id, retainedDeck.id);
      expect(restoredCard.original_deck_id, 0);
    },
  );

  test('legacy metadata migration preserves modification times', () async {
    final model = collection.col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['legacy', 'note'],
    );
    await collection.notes.insert(note);
    const noteModifiedSecs = 1700000000;
    const collectionModifiedMs = 1700000000000;
    await collection.db.update(
      'notes',
      {'mod': noteModifiedSecs, 'usn': 4, 'sfld': '<b>legacy</b>', 'csum': 1},
      where: 'id = ?',
      whereArgs: [note.id],
    );
    await collection.db.update(
        'col',
        {
          'mod': collectionModifiedMs,
        },
        where: 'id = 1');
    final migrationMarker = File(
      '${workDir.path}/collection.anki2.stroom-sync-metadata-migration',
    );
    final created =
        (await collection.db.query('col', columns: ['crt'])).single['crt'];
    await migrationMarker.writeAsString('3:$created');

    await collection.close();
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();

    final migrated = (await collection.db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [note.id],
    ))
        .single;
    expect(migrated['mod'], noteModifiedSecs);
    expect(migrated['sfld'], 'legacy');
    expect(migrated['csum'], Note.computeChecksum('legacy'));
    expect(migrated['usn'], -1);
    expect(
      (await collection.db.query('col')).single['mod'],
      collectionModifiedMs ~/ 1000,
    );
  });

  test('legacy deck creation timestamps migrate to seconds and sync', () async {
    const legacyMigrationVersion = 1;
    const legacyDeckCreationMillis = 1700000000000;
    final collectionRow = (await collection.db.query(
      'col',
      columns: ['crt', 'decks'],
      where: 'id = 1',
    ))
        .single;
    final collectionCreated = (collectionRow['crt'] as num).toInt();
    final decks =
        jsonDecode(collectionRow['decks'] as String) as Map<String, dynamic>;
    final deckKey = decks.keys.single;
    final deckId = int.parse(deckKey);
    final legacyDeck = Map<String, dynamic>.from(decks[deckKey] as Map)
      ..['crt'] = legacyDeckCreationMillis
      ..['usn'] = 7;
    decks[deckKey] = legacyDeck;
    await collection.db.update(
        'col',
        {
          'decks': jsonEncode(decks),
        },
        where: 'id = 1');
    // Simulate an installation that already ran migration v1, which did not
    // normalize deck creation timestamps.
    await File(
      '${workDir.path}/collection.anki2.stroom-sync-metadata-migration',
    ).writeAsString('$legacyMigrationVersion:$collectionCreated');

    await collection.close();
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();

    final migratedDecks = jsonDecode(
      (await collection.db.query('col', columns: ['decks'])).single['decks']
          as String,
    ) as Map<String, dynamic>;
    final migratedDeck = migratedDecks[deckKey] as Map<String, dynamic>;
    expect(migratedDeck['crt'], legacyDeckCreationMillis ~/ 1000);
    expect(migratedDeck['usn'], -1);

    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);
    final changesRequest = fakeHttp.requests.singleWhere(
      (request) => request.url.path == '/sync/applyChanges',
    );
    final changes =
        _decodedRequestData(changesRequest)['changes'] as Map<String, dynamic>;
    final syncedDecks = (changes['decks'] as List)[0] as List<dynamic>;
    final syncedDeck = syncedDecks.cast<Map<String, dynamic>>().singleWhere(
          (deck) => deck['id'] == deckId,
        );
    expect(syncedDeck['crt'], legacyDeckCreationMillis ~/ 1000);
  });

  test('metadata migration preserves malformed notetype JSON', () async {
    const legacyDeckCreationMillis = 1700000000000;
    final collectionRow = (await collection.db.query(
      'col',
      columns: ['models', 'decks'],
      where: 'id = 1',
    ))
        .single;
    final originalModels = collectionRow['models'] as String;
    final decks =
        jsonDecode(collectionRow['decks'] as String) as Map<String, dynamic>;
    final deck = Map<String, dynamic>.from(decks.values.single as Map)
      ..['crt'] = legacyDeckCreationMillis
      ..['usn'] = 4;
    decks[decks.keys.single] = deck;
    await collection.db.update(
        'col',
        {
          'models': '{malformed',
          'decks': jsonEncode(decks),
        },
        where: 'id = 1');
    await _removeSyncMetadataMigrationMarker(workDir);

    await collection.close();
    collection = AnkiDatabase(basePath: workDir.path);
    await collection.open();

    final migrated = (await collection.db.query(
      'col',
      columns: ['models', 'decks'],
      where: 'id = 1',
    ))
        .single;
    expect(migrated['models'], '{malformed');
    final migratedDecks =
        jsonDecode(migrated['decks'] as String) as Map<String, dynamic>;
    expect(
      migratedDecks.values.single['crt'],
      legacyDeckCreationMillis ~/ 1000,
    );
    expect(originalModels, isNotEmpty);
  });

  test('local collection writes remain pending for the next sync', () async {
    final CardDao cards = collection.cards;
    final ColDao col = collection.col;
    final NoteDao notes = collection.notes;
    final RevlogDao revlog = collection.revlog;
    final model = col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['sync me', 'tracked'],
    );
    final card = anki.Card.createNew(note_id: note.id, deck_id: 1);
    final review = RevlogEntry(cid: card.id, button_chosen: 3, interval: 1);
    final beforeMod = (await collection.db.query('col')).single['mod'] as int;

    await notes.insert(note);
    await cards.insert(card);
    await revlog.insert(review);

    expect((await notes.get(note.id))!.usn, -1);
    expect((await cards.get(card.id))!.usn, -1);
    expect((await revlog.listByCard(card.id)).single.usn, -1);
    final changedCollectionMod =
        (await collection.db.query('col')).single['mod'] as int;
    expect(changedCollectionMod, greaterThanOrEqualTo(beforeMod));
    expect(changedCollectionMod, lessThan(100000000000));

    final deck = col.addDeck('Sync tracking test');
    col.renameDeck(deck.id, 'Renamed sync tracking test');
    await col.save();
    expect(col.getDeck(deck.id)!.usn, -1);
    expect(
      (await collection.db.query('col')).single['mod'],
      lessThan(100000000000),
    );

    await col.removeDeck(deck.id);
    expect(
      (await collection.db.query('col')).single['mod'],
      lessThan(100000000000),
    );
    await col.save();
    expect(
      (await collection.graves.all())
          .where((grave) => grave.oid == deck.id)
          .map((grave) => (grave.type, grave.usn)),
      [(2, -1)],
    );
  });

  test(
    'removing the current deck selects a surviving deck in collection config',
    () async {
      final deletedDeck = collection.col.deckList.single;
      final survivor = collection.col.addDeck('Surviving deck');
      await collection.col.save();

      final config = jsonDecode(collection.col.confJson) as Map<String, dynamic>
        ..['curDeck'] = deletedDeck.id
        ..['activeDecks'] = [deletedDeck.id];
      collection.col.confJson = jsonEncode(config);
      await collection.db.update(
          'col',
          {
            'conf': collection.col.confJson,
          },
          where: 'id = 1');

      await collection.col.removeDeck(deletedDeck.id);

      final storedConfig = jsonDecode(
        (await collection.db.query('col', columns: ['conf'])).single['conf']
            as String,
      ) as Map<String, dynamic>;
      expect(storedConfig['curDeck'], survivor.id);
      expect(storedConfig['activeDecks'], [survivor.id]);
    },
  );

  test(
    'applies server note and card tuples into the local collection',
    () async {
      final model = collection.col.modelList.first..sortFieldIndex = 1;
      await collection.col.save();
      final modelId = model.id;
      final noteId = DateTime.now().microsecondsSinceEpoch;
      final cardId = noteId + 1;
      final mtime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteChunk: {
          'done': true,
          'notes': [
            [
              noteId,
              'remote-guid',
              modelId,
              mtime,
              0,
              ' tag ',
              '<b>front</b>\x1fremote sort',
              '',
              '',
              0,
              '',
            ],
          ],
          'cards': [
            [
              cardId,
              noteId,
              1,
              0,
              mtime,
              0,
              0,
              0,
              1,
              0,
              2500,
              0,
              0,
              0,
              0,
              0,
              0,
              '',
            ],
          ],
          'revlog': [],
        },
      );

      final result = await AnkiIncrementalSync.sync(collection, client);

      final importedNote = (await collection.notes.get(noteId))!;
      expect(importedNote.fields, ['<b>front</b>', 'remote sort']);
      expect(importedNote.sfldForDb, 'remote sort');
      expect(importedNote.csumForDb, Note.computeChecksum('<b>front</b>'));
      expect((await collection.cards.get(cardId))!.note_id, noteId);
      expect(result.changedNotes, 1);
      expect(result.changedCards, 1);
    },
  );

  test('remote collection config removes keys deleted on the server', () async {
    final localConfig = {'removedOnServer': 'stale', 'serverUpdated': 'old'};
    await collection.db.update(
        'col',
        {
          'conf': jsonEncode(localConfig),
        },
        where: 'id = 1');
    for (final entry in localConfig.entries) {
      await collection.db.insert('config', {
        'key': entry.key,
        'usn': 0,
        'mtime_secs': 1,
        'config': jsonEncode(entry.value),
      });
    }

    final row = (await collection.db.query('col')).single;
    const remoteConfig = {'serverUpdated': 'new'};
    await _queueCollectionSync(
      fakeHttp,
      collection,
      sanityStatus: 'ok',
      remoteModified: (row['mod'] as int) + 1,
      remoteChanges: {'conf': remoteConfig},
    );

    await AnkiIncrementalSync.sync(collection, client);

    final storedConfig = jsonDecode(
      (await collection.db.query('col', columns: ['conf'])).single['conf']
          as String,
    ) as Map<String, dynamic>;
    expect(storedConfig, remoteConfig);

    final configRows = await collection.db.query('config');
    expect(configRows.map((row) => row['key']), ['serverUpdated']);
    expect(jsonDecode(configRows.single['config'] as String), 'new');
  });

  test('pending notes do not make local collection settings newer', () async {
    final model = collection.col.modelList.first;
    final note = Note.createNew(
      notetype_id: model.id,
      fields: ['pending', 'note'],
    );
    await collection.notes.insert(note);
    await collection.db.update('col', {'mod': 1000}, where: 'id = 1');
    final remoteConfig = Map<String, dynamic>.from(
      jsonDecode(collection.col.confJson) as Map,
    )..['reviewLimit'] = 7;
    await _queueCollectionSync(
      fakeHttp,
      collection,
      sanityStatus: 'ok',
      remoteModified: 2000,
      remoteChanges: {'conf': remoteConfig, 'crt': 123},
    );

    await AnkiIncrementalSync.sync(collection, client);

    final startRequest = fakeHttp.requests.singleWhere(
      (request) => request.url.path == '/sync/start',
    );
    expect(_decodedRequestData(startRequest)['lnewer'], isFalse);
    final changesRequest = fakeHttp.requests.singleWhere(
      (request) => request.url.path == '/sync/applyChanges',
    );
    final changes =
        _decodedRequestData(changesRequest)['changes'] as Map<String, dynamic>;
    expect(changes.containsKey('conf'), isFalse);
    expect(changes.containsKey('crt'), isFalse);
    final localCollection = (await collection.db.query('col')).single;
    expect(localCollection['crt'], 123);
    final collectionConfig =
        jsonDecode(localCollection['conf'] as String) as Map<String, dynamic>;
    expect(collectionConfig['reviewLimit'], 7);
    expect(collectionConfig['activeDecks'], isNotEmpty);
    final remoteConfigRows = await collection.db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['reviewLimit'],
    );
    expect(jsonDecode(remoteConfigRows.single['config'] as String), 7);
  });

  test(
    'uploads collection settings from col.conf when the sidecar is empty',
    () async {
      final originalConfig =
          jsonDecode(collection.col.confJson) as Map<String, dynamic>;
      final localConfig = {...originalConfig, 'reviewLimit': 42};
      await collection.db.update(
          'col',
          {
            'conf': jsonEncode(localConfig),
          },
          where: 'id = 1');
      expect(await collection.db.query('config'), isEmpty);
      await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');

      await AnkiIncrementalSync.sync(collection, client);

      final changesRequest = fakeHttp.requests.singleWhere(
        (request) => request.url.path == '/sync/applyChanges',
      );
      final changes = _decodedRequestData(changesRequest)['changes']
          as Map<String, dynamic>;
      expect(changes['conf'], localConfig);
    },
  );

  test('renames remote decks that collide with a local deck name', () async {
    final localDeck = collection.col.addDeck('Sync collision deck');
    await collection.col.save();
    final remoteDeck = anki_deck.Deck.createNew(name: localDeck.name)
      ..id = localDeck.id + 1
      ..usn = 0;

    await _queueCollectionSync(
      fakeHttp,
      collection,
      sanityStatus: 'ok',
      remoteChanges: {
        'decks': [
          [remoteDeck.toJson()],
          [],
        ],
      },
    );

    await AnkiIncrementalSync.sync(collection, client);

    final row = (await collection.db.query('col')).single;
    final decks = jsonDecode(row['decks'] as String) as Map<String, dynamic>;
    final storedRemote = anki_deck.Deck.fromJson(
      Map<String, dynamic>.from(decks[remoteDeck.id.toString()] as Map),
    );
    final names =
        decks.values.cast<Map>().map((deck) => deck['name'] as String).toList();

    expect(storedRemote.id, remoteDeck.id);
    expect(storedRemote.name, isNot(localDeck.name));
    expect(storedRemote.usn, -1);
    expect(names.toSet(), hasLength(names.length));
  });

  test('remote deck graves choose a surviving current deck', () async {
    final deletedDeck = collection.col.addDeck('Remote deleted deck');
    await collection.col.save();
    final survivor = collection.col.deckList.firstWhere(
      (deck) => deck.id != deletedDeck.id,
    );
    final config = jsonDecode(collection.col.confJson) as Map<String, dynamic>
      ..['curDeck'] = deletedDeck.id
      ..['activeDecks'] = [deletedDeck.id];
    await collection.db.update(
        'col',
        {
          'conf': jsonEncode(config),
        },
        where: 'id = 1');

    await _queueCollectionSync(
      fakeHttp,
      collection,
      sanityStatus: 'ok',
      remoteGraves: {
        'cards': [],
        'notes': [],
        'decks': [deletedDeck.id],
      },
    );
    await AnkiIncrementalSync.sync(collection, client);

    final rows = await collection.db.query(
      'col',
      columns: ['conf', 'decks'],
      where: 'id = 1',
    );
    final storedConfig =
        jsonDecode(rows.single['conf'] as String) as Map<String, dynamic>;
    final storedDecks =
        jsonDecode(rows.single['decks'] as String) as Map<String, dynamic>;
    expect(storedDecks, isNot(contains(deletedDeck.id.toString())));
    expect(storedConfig['curDeck'], survivor.id);
    expect(storedConfig['activeDecks'], [survivor.id]);
  });

  test('rejects malformed remote grave IDs without advancing the collection',
      () async {
    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    for (final key in ['cards', 'notes', 'decks']) {
      final before = (await collection.db.query('col')).single;
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteModified: (before['mod'] as int) - 1,
        remoteGraves: {
          'cards': <dynamic>[],
          'notes': <dynamic>[],
          'decks': <dynamic>[],
          key: ['invalid-id'],
        },
      );

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncException>()),
      );

      expect(fakeHttp.requests.last.url.path, '/sync/abort');
      expect(await collection.db.query('graves', where: 'oid = 0'), isEmpty);
      final after = (await collection.db.query('col')).single;
      expect(after['mod'], before['mod']);
      expect(after['usn'], before['usn']);
      fakeHttp.responses.clear();
    }
  });

  test('rejects missing or null remote grave lists', () async {
    await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
    await AnkiIncrementalSync.sync(collection, client);

    for (final key in ['cards', 'notes', 'decks']) {
      for (final omitKey in [false, true]) {
        final before = (await collection.db.query('col')).single;
        final remoteGraves = <String, dynamic>{
          'cards': <dynamic>[],
          'notes': <dynamic>[],
          'decks': <dynamic>[],
        };
        if (omitKey) {
          remoteGraves.remove(key);
        } else {
          remoteGraves[key] = null;
        }
        await _queueCollectionSync(
          fakeHttp,
          collection,
          sanityStatus: 'ok',
          remoteModified: (before['mod'] as int) - 1,
          remoteGraves: remoteGraves,
        );

        await expectLater(
          AnkiIncrementalSync.sync(collection, client),
          throwsA(isA<AnkiSyncException>()),
        );

        expect(fakeHttp.requests.last.url.path, '/sync/abort');
        final after = (await collection.db.query('col')).single;
        expect(after['mod'], before['mod']);
        expect(after['usn'], before['usn']);
        fakeHttp.responses.clear();
      }
    }
  });

  test(
    'remote graves remove history and remain pending for another sync',
    () async {
      final modelId = collection.col.modelList.first.id;
      final deletedCardNote = Note.createNew(
        notetype_id: modelId,
        fields: ['remote card grave', 'note'],
      );
      final deletedNote = Note.createNew(
        notetype_id: modelId,
        fields: ['remote note grave', 'note'],
      );
      await collection.notes.insert(deletedCardNote);
      await collection.notes.insert(deletedNote);
      final cardOnlyDeleted = anki.Card.createNew(
        note_id: deletedCardNote.id,
        deck_id: 1,
      );
      final cardDeletedWithNote = anki.Card.createNew(
        note_id: deletedNote.id,
        deck_id: 1,
      );
      await collection.cards.insert(cardOnlyDeleted);
      await collection.cards.insert(cardDeletedWithNote);
      await collection.revlog.insert(
        RevlogEntry(cid: cardOnlyDeleted.id, button_chosen: 3, interval: 1),
      );
      await collection.revlog.insert(
        RevlogEntry(cid: cardDeletedWithNote.id, button_chosen: 3, interval: 1),
      );
      await _queueCollectionSync(
        fakeHttp,
        collection,
        sanityStatus: 'ok',
        remoteGraves: {
          'cards': [cardOnlyDeleted.id],
          'notes': [deletedNote.id],
          'decks': [],
        },
      );

      await AnkiIncrementalSync.sync(collection, client);

      expect(await collection.revlog.listByCard(cardOnlyDeleted.id), isEmpty);
      expect(
        await collection.revlog.listByCard(cardDeletedWithNote.id),
        isEmpty,
      );
      expect(await collection.notes.get(deletedCardNote.id), isNotNull);
      expect(await collection.notes.get(deletedNote.id), isNull);

      final pendingGraves = await collection.graves.all();
      expect(
        pendingGraves
            .map((grave) => (grave.oid, grave.type, grave.usn))
            .toSet(),
        {(cardOnlyDeleted.id, 0, -1), (deletedNote.id, 1, -1)},
      );

      await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'ok');
      // The follow-up sync first acknowledges the local grave batch.
      fakeHttp.responses.insert(2, _json(null));
      await AnkiIncrementalSync.sync(collection, client);

      final applyGravesRequest = fakeHttp.requests.lastWhere(
        (request) => request.url.path == '/sync/applyGraves',
      );
      final sentGraves = _decodedRequestData(applyGravesRequest)['chunk']
          as Map<String, dynamic>;
      expect(sentGraves['cards'], contains(cardOnlyDeleted.id));
      expect(sentGraves['notes'], contains(deletedNote.id));
    },
  );

  test(
    'rolls back local transaction and aborts server on sanity failure',
    () async {
      final model = collection.col.modelList.first;
      final note = Note.createNew(
        notetype_id: model.id,
        fields: ['front', 'back'],
      );
      await collection.notes.insert(note);
      final beforeMod = (await collection.db.query('col')).single['mod'];
      await _queueCollectionSync(fakeHttp, collection, sanityStatus: 'bad');

      await expectLater(
        AnkiIncrementalSync.sync(collection, client),
        throwsA(isA<AnkiSyncException>()),
      );

      expect((await collection.notes.get(note.id))!.usn, -1);
      expect((await collection.db.query('col')).single['mod'], beforeMod);
      expect(fakeHttp.requests.last.url.path, '/sync/abort');
    },
  );
}

Future<void> _removeSyncMetadataMigrationMarker(Directory directory) async {
  // Model a collection from a Stroom build that predates the one-time marker.
  await AnkiDatabase.invalidateLegacySyncMetadataMigrationMarker(
    basePath: directory.path,
  );
}

Future<void> _queueCollectionSync(
  _QueueHttpClient httpClient,
  AnkiDatabase collection, {
  required String sanityStatus,
  Map<String, dynamic>? remoteChunk,
  int? remoteModified,
  int? remoteUsn,
  int? remoteSchema,
  Map<String, dynamic>? remoteGraves,
  Map<String, dynamic>? remoteChanges,
}) async {
  final row = (await collection.db.query('col')).single;
  final now = DateTime.now().millisecondsSinceEpoch;
  final nowSecs = now ~/ 1000;
  final changes = <String, dynamic>{
    'models': [],
    'decks': [[], []],
    'tags': [],
    ...?remoteChanges,
  };
  httpClient.responses.addAll([
    _json({
      'mod': remoteModified ?? (row['mod'] as int) - 1,
      'scm': remoteSchema ?? row['scm'],
      'usn': remoteUsn ?? row['usn'],
      'ts': nowSecs,
      'msg': '',
      'cont': true,
      'hostNum': 1,
      'empty': false,
      'media_usn': 0,
    }),
    _json({
      'graves': remoteGraves ?? {'cards': [], 'notes': [], 'decks': []},
    }),
    _json(changes),
    _json(remoteChunk ?? {'done': true}),
    _json(null),
    _json({'status': sanityStatus}),
  ]);
  if (sanityStatus == 'ok') httpClient.responses.add(_json(now));
  if (sanityStatus != 'ok') httpClient.responses.add(_json(null));
}

http.Response _json(Object? value) =>
    http.Response(jsonEncode(value), HttpStatus.ok);

Map<String, dynamic> _decodedRequestData(_CapturedRequest request) {
  final fields = _multipartFields(request);
  return jsonDecode(utf8.decode(gzip.decode(fields['data']!)))
      as Map<String, dynamic>;
}

Map<String, List<int>> _multipartFields(_CapturedRequest request) {
  final boundary =
      RegExp(r'boundary=(.+)$').firstMatch(request.contentType)!.group(1)!;
  final delimiter = ascii.encode('--$boundary\r\n');
  final nextPart = ascii.encode('\r\n--$boundary');
  final output = <String, List<int>>{};
  var offset = 0;
  while (true) {
    final partStart = _indexOf(request.body, delimiter, offset);
    if (partStart < 0) break;
    final headersStart = partStart + delimiter.length;
    final headersEnd = _indexOf(
      request.body,
      ascii.encode('\r\n\r\n'),
      headersStart,
    );
    if (headersEnd < 0) break;
    final headers = utf8.decode(request.body.sublist(headersStart, headersEnd));
    final name = RegExp(r'name="([^"]+)"').firstMatch(headers)?.group(1);
    final dataStart = headersEnd + 4;
    final dataEnd = _indexOf(request.body, nextPart, dataStart);
    if (name == null || dataEnd < 0) break;
    output[name] = request.body.sublist(dataStart, dataEnd);
    offset = dataEnd + 2;
  }
  return output;
}

int _indexOf(List<int> source, List<int> pattern, int start) {
  for (var i = start; i <= source.length - pattern.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length; j++) {
      if (source[i + j] != pattern[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return -1;
}

class _CapturedRequest {
  final Uri url;
  final String contentType;
  final List<int> body;

  const _CapturedRequest(this.url, this.contentType, this.body);
}

class _QueueHttpClient extends http.BaseClient {
  final responses = <http.Response>[];
  final requests = <_CapturedRequest>[];
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw StateError('HTTP client is closed');
    final body = await request.finalize().fold<List<int>>(
      <int>[],
      (collected, chunk) => collected..addAll(chunk),
    );
    requests.add(
      _CapturedRequest(
        request.url,
        request.headers['content-type'] ?? '',
        body,
      ),
    );
    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => _closed = true;
}
