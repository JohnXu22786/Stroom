// This is a generated file - do not edit.
//
// Generated from anki/notes.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'cards.pb.dart' as $3;
import 'collection.pb.dart' as $0;
import 'decks.pb.dart' as $2;
import 'notes.pbenum.dart';
import 'notetypes.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'notes.pbenum.dart';

class NoteId extends $pb.GeneratedMessage {
  factory NoteId({
    $fixnum.Int64? nid,
  }) {
    final result = create();
    if (nid != null) result.nid = nid;
    return result;
  }

  NoteId._();

  factory NoteId.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NoteId.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NoteId',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'nid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoteId clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoteId copyWith(void Function(NoteId) updates) =>
      super.copyWith((message) => updates(message as NoteId)) as NoteId;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NoteId create() => NoteId._();
  @$core.override
  NoteId createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NoteId getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NoteId>(create);
  static NoteId? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nid => $_getI64(0);
  @$pb.TagNumber(1)
  set nid($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNid() => $_has(0);
  @$pb.TagNumber(1)
  void clearNid() => $_clearField(1);
}

class NoteIds extends $pb.GeneratedMessage {
  factory NoteIds({
    $core.Iterable<$fixnum.Int64>? noteIds,
  }) {
    final result = create();
    if (noteIds != null) result.noteIds.addAll(noteIds);
    return result;
  }

  NoteIds._();

  factory NoteIds.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NoteIds.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NoteIds',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'noteIds', $pb.PbFieldType.K6)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoteIds clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoteIds copyWith(void Function(NoteIds) updates) =>
      super.copyWith((message) => updates(message as NoteIds)) as NoteIds;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NoteIds create() => NoteIds._();
  @$core.override
  NoteIds createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NoteIds getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NoteIds>(create);
  static NoteIds? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get noteIds => $_getList(0);
}

class Note extends $pb.GeneratedMessage {
  factory Note({
    $fixnum.Int64? id,
    $core.String? guid,
    $fixnum.Int64? notetypeId,
    $core.int? mtimeSecs,
    $core.int? usn,
    $core.Iterable<$core.String>? tags,
    $core.Iterable<$core.String>? fields,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (guid != null) result.guid = guid;
    if (notetypeId != null) result.notetypeId = notetypeId;
    if (mtimeSecs != null) result.mtimeSecs = mtimeSecs;
    if (usn != null) result.usn = usn;
    if (tags != null) result.tags.addAll(tags);
    if (fields != null) result.fields.addAll(fields);
    return result;
  }

  Note._();

  factory Note.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Note.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Note',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'guid')
    ..aInt64(3, _omitFieldNames ? '' : 'notetypeId')
    ..aI(4, _omitFieldNames ? '' : 'mtimeSecs', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'usn')
    ..pPS(6, _omitFieldNames ? '' : 'tags')
    ..pPS(7, _omitFieldNames ? '' : 'fields')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Note clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Note copyWith(void Function(Note) updates) =>
      super.copyWith((message) => updates(message as Note)) as Note;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Note create() => Note._();
  @$core.override
  Note createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Note getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Note>(create);
  static Note? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get guid => $_getSZ(1);
  @$pb.TagNumber(2)
  set guid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGuid() => $_has(1);
  @$pb.TagNumber(2)
  void clearGuid() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get notetypeId => $_getI64(2);
  @$pb.TagNumber(3)
  set notetypeId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNotetypeId() => $_has(2);
  @$pb.TagNumber(3)
  void clearNotetypeId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get mtimeSecs => $_getIZ(3);
  @$pb.TagNumber(4)
  set mtimeSecs($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMtimeSecs() => $_has(3);
  @$pb.TagNumber(4)
  void clearMtimeSecs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get usn => $_getIZ(4);
  @$pb.TagNumber(5)
  set usn($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUsn() => $_has(4);
  @$pb.TagNumber(5)
  void clearUsn() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get tags => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get fields => $_getList(6);
}

class AddNoteRequest extends $pb.GeneratedMessage {
  factory AddNoteRequest({
    Note? note,
    $fixnum.Int64? deckId,
  }) {
    final result = create();
    if (note != null) result.note = note;
    if (deckId != null) result.deckId = deckId;
    return result;
  }

  AddNoteRequest._();

  factory AddNoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddNoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddNoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..aOM<Note>(1, _omitFieldNames ? '' : 'note', subBuilder: Note.create)
    ..aInt64(2, _omitFieldNames ? '' : 'deckId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddNoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddNoteRequest copyWith(void Function(AddNoteRequest) updates) =>
      super.copyWith((message) => updates(message as AddNoteRequest))
          as AddNoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddNoteRequest create() => AddNoteRequest._();
  @$core.override
  AddNoteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddNoteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddNoteRequest>(create);
  static AddNoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Note get note => $_getN(0);
  @$pb.TagNumber(1)
  set note(Note value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNote() => $_has(0);
  @$pb.TagNumber(1)
  void clearNote() => $_clearField(1);
  @$pb.TagNumber(1)
  Note ensureNote() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get deckId => $_getI64(1);
  @$pb.TagNumber(2)
  set deckId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeckId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeckId() => $_clearField(2);
}

class AddNoteResponse extends $pb.GeneratedMessage {
  factory AddNoteResponse({
    $0.OpChangesWithCount? changes,
    $fixnum.Int64? noteId,
  }) {
    final result = create();
    if (changes != null) result.changes = changes;
    if (noteId != null) result.noteId = noteId;
    return result;
  }

  AddNoteResponse._();

  factory AddNoteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddNoteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddNoteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..aOM<$0.OpChangesWithCount>(1, _omitFieldNames ? '' : 'changes',
        subBuilder: $0.OpChangesWithCount.create)
    ..aInt64(2, _omitFieldNames ? '' : 'noteId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddNoteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddNoteResponse copyWith(void Function(AddNoteResponse) updates) =>
      super.copyWith((message) => updates(message as AddNoteResponse))
          as AddNoteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddNoteResponse create() => AddNoteResponse._();
  @$core.override
  AddNoteResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddNoteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddNoteResponse>(create);
  static AddNoteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $0.OpChangesWithCount get changes => $_getN(0);
  @$pb.TagNumber(1)
  set changes($0.OpChangesWithCount value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasChanges() => $_has(0);
  @$pb.TagNumber(1)
  void clearChanges() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.OpChangesWithCount ensureChanges() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get noteId => $_getI64(1);
  @$pb.TagNumber(2)
  set noteId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNoteId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNoteId() => $_clearField(2);
}

class AddNotesRequest extends $pb.GeneratedMessage {
  factory AddNotesRequest({
    $core.Iterable<AddNoteRequest>? requests,
  }) {
    final result = create();
    if (requests != null) result.requests.addAll(requests);
    return result;
  }

  AddNotesRequest._();

  factory AddNotesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddNotesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddNotesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..pPM<AddNoteRequest>(1, _omitFieldNames ? '' : 'requests',
        subBuilder: AddNoteRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddNotesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddNotesRequest copyWith(void Function(AddNotesRequest) updates) =>
      super.copyWith((message) => updates(message as AddNotesRequest))
          as AddNotesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddNotesRequest create() => AddNotesRequest._();
  @$core.override
  AddNotesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddNotesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddNotesRequest>(create);
  static AddNotesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AddNoteRequest> get requests => $_getList(0);
}

class AddNotesResponse extends $pb.GeneratedMessage {
  factory AddNotesResponse({
    $0.OpChanges? changes,
    $core.Iterable<$fixnum.Int64>? nids,
  }) {
    final result = create();
    if (changes != null) result.changes = changes;
    if (nids != null) result.nids.addAll(nids);
    return result;
  }

  AddNotesResponse._();

  factory AddNotesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddNotesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddNotesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..aOM<$0.OpChanges>(1, _omitFieldNames ? '' : 'changes',
        subBuilder: $0.OpChanges.create)
    ..p<$fixnum.Int64>(2, _omitFieldNames ? '' : 'nids', $pb.PbFieldType.K6)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddNotesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddNotesResponse copyWith(void Function(AddNotesResponse) updates) =>
      super.copyWith((message) => updates(message as AddNotesResponse))
          as AddNotesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddNotesResponse create() => AddNotesResponse._();
  @$core.override
  AddNotesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddNotesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddNotesResponse>(create);
  static AddNotesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $0.OpChanges get changes => $_getN(0);
  @$pb.TagNumber(1)
  set changes($0.OpChanges value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasChanges() => $_has(0);
  @$pb.TagNumber(1)
  void clearChanges() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.OpChanges ensureChanges() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<$fixnum.Int64> get nids => $_getList(1);
}

class UpdateNotesRequest extends $pb.GeneratedMessage {
  factory UpdateNotesRequest({
    $core.Iterable<Note>? notes,
    $core.bool? skipUndoEntry,
  }) {
    final result = create();
    if (notes != null) result.notes.addAll(notes);
    if (skipUndoEntry != null) result.skipUndoEntry = skipUndoEntry;
    return result;
  }

  UpdateNotesRequest._();

  factory UpdateNotesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateNotesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateNotesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..pPM<Note>(1, _omitFieldNames ? '' : 'notes', subBuilder: Note.create)
    ..aOB(2, _omitFieldNames ? '' : 'skipUndoEntry')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateNotesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateNotesRequest copyWith(void Function(UpdateNotesRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateNotesRequest))
          as UpdateNotesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateNotesRequest create() => UpdateNotesRequest._();
  @$core.override
  UpdateNotesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateNotesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateNotesRequest>(create);
  static UpdateNotesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Note> get notes => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get skipUndoEntry => $_getBF(1);
  @$pb.TagNumber(2)
  set skipUndoEntry($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSkipUndoEntry() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkipUndoEntry() => $_clearField(2);
}

class DefaultsForAddingRequest extends $pb.GeneratedMessage {
  factory DefaultsForAddingRequest({
    $fixnum.Int64? homeDeckOfCurrentReviewCard,
  }) {
    final result = create();
    if (homeDeckOfCurrentReviewCard != null)
      result.homeDeckOfCurrentReviewCard = homeDeckOfCurrentReviewCard;
    return result;
  }

  DefaultsForAddingRequest._();

  factory DefaultsForAddingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DefaultsForAddingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DefaultsForAddingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'homeDeckOfCurrentReviewCard')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DefaultsForAddingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DefaultsForAddingRequest copyWith(
          void Function(DefaultsForAddingRequest) updates) =>
      super.copyWith((message) => updates(message as DefaultsForAddingRequest))
          as DefaultsForAddingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DefaultsForAddingRequest create() => DefaultsForAddingRequest._();
  @$core.override
  DefaultsForAddingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DefaultsForAddingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DefaultsForAddingRequest>(create);
  static DefaultsForAddingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get homeDeckOfCurrentReviewCard => $_getI64(0);
  @$pb.TagNumber(1)
  set homeDeckOfCurrentReviewCard($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHomeDeckOfCurrentReviewCard() => $_has(0);
  @$pb.TagNumber(1)
  void clearHomeDeckOfCurrentReviewCard() => $_clearField(1);
}

class DeckAndNotetype extends $pb.GeneratedMessage {
  factory DeckAndNotetype({
    $fixnum.Int64? deckId,
    $fixnum.Int64? notetypeId,
  }) {
    final result = create();
    if (deckId != null) result.deckId = deckId;
    if (notetypeId != null) result.notetypeId = notetypeId;
    return result;
  }

  DeckAndNotetype._();

  factory DeckAndNotetype.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeckAndNotetype.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeckAndNotetype',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deckId')
    ..aInt64(2, _omitFieldNames ? '' : 'notetypeId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeckAndNotetype clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeckAndNotetype copyWith(void Function(DeckAndNotetype) updates) =>
      super.copyWith((message) => updates(message as DeckAndNotetype))
          as DeckAndNotetype;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeckAndNotetype create() => DeckAndNotetype._();
  @$core.override
  DeckAndNotetype createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeckAndNotetype getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeckAndNotetype>(create);
  static DeckAndNotetype? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deckId => $_getI64(0);
  @$pb.TagNumber(1)
  set deckId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get notetypeId => $_getI64(1);
  @$pb.TagNumber(2)
  set notetypeId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNotetypeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNotetypeId() => $_clearField(2);
}

class RemoveNotesRequest extends $pb.GeneratedMessage {
  factory RemoveNotesRequest({
    $core.Iterable<$fixnum.Int64>? noteIds,
    $core.Iterable<$fixnum.Int64>? cardIds,
  }) {
    final result = create();
    if (noteIds != null) result.noteIds.addAll(noteIds);
    if (cardIds != null) result.cardIds.addAll(cardIds);
    return result;
  }

  RemoveNotesRequest._();

  factory RemoveNotesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveNotesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveNotesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'noteIds', $pb.PbFieldType.K6)
    ..p<$fixnum.Int64>(2, _omitFieldNames ? '' : 'cardIds', $pb.PbFieldType.K6)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveNotesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveNotesRequest copyWith(void Function(RemoveNotesRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveNotesRequest))
          as RemoveNotesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveNotesRequest create() => RemoveNotesRequest._();
  @$core.override
  RemoveNotesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveNotesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveNotesRequest>(create);
  static RemoveNotesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get noteIds => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$fixnum.Int64> get cardIds => $_getList(1);
}

class ClozeNumbersInNoteResponse extends $pb.GeneratedMessage {
  factory ClozeNumbersInNoteResponse({
    $core.Iterable<$core.int>? numbers,
  }) {
    final result = create();
    if (numbers != null) result.numbers.addAll(numbers);
    return result;
  }

  ClozeNumbersInNoteResponse._();

  factory ClozeNumbersInNoteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClozeNumbersInNoteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClozeNumbersInNoteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'numbers', $pb.PbFieldType.KU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClozeNumbersInNoteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClozeNumbersInNoteResponse copyWith(
          void Function(ClozeNumbersInNoteResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ClozeNumbersInNoteResponse))
          as ClozeNumbersInNoteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClozeNumbersInNoteResponse create() => ClozeNumbersInNoteResponse._();
  @$core.override
  ClozeNumbersInNoteResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClozeNumbersInNoteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClozeNumbersInNoteResponse>(create);
  static ClozeNumbersInNoteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get numbers => $_getList(0);
}

class AfterNoteUpdatesRequest extends $pb.GeneratedMessage {
  factory AfterNoteUpdatesRequest({
    $core.Iterable<$fixnum.Int64>? nids,
    $core.bool? markNotesModified,
    $core.bool? generateCards,
  }) {
    final result = create();
    if (nids != null) result.nids.addAll(nids);
    if (markNotesModified != null) result.markNotesModified = markNotesModified;
    if (generateCards != null) result.generateCards = generateCards;
    return result;
  }

  AfterNoteUpdatesRequest._();

  factory AfterNoteUpdatesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AfterNoteUpdatesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AfterNoteUpdatesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nids', $pb.PbFieldType.K6)
    ..aOB(2, _omitFieldNames ? '' : 'markNotesModified')
    ..aOB(3, _omitFieldNames ? '' : 'generateCards')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterNoteUpdatesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AfterNoteUpdatesRequest copyWith(
          void Function(AfterNoteUpdatesRequest) updates) =>
      super.copyWith((message) => updates(message as AfterNoteUpdatesRequest))
          as AfterNoteUpdatesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AfterNoteUpdatesRequest create() => AfterNoteUpdatesRequest._();
  @$core.override
  AfterNoteUpdatesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AfterNoteUpdatesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AfterNoteUpdatesRequest>(create);
  static AfterNoteUpdatesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get nids => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get markNotesModified => $_getBF(1);
  @$pb.TagNumber(2)
  set markNotesModified($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMarkNotesModified() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarkNotesModified() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get generateCards => $_getBF(2);
  @$pb.TagNumber(3)
  set generateCards($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGenerateCards() => $_has(2);
  @$pb.TagNumber(3)
  void clearGenerateCards() => $_clearField(3);
}

class FieldNamesForNotesRequest extends $pb.GeneratedMessage {
  factory FieldNamesForNotesRequest({
    $core.Iterable<$fixnum.Int64>? nids,
  }) {
    final result = create();
    if (nids != null) result.nids.addAll(nids);
    return result;
  }

  FieldNamesForNotesRequest._();

  factory FieldNamesForNotesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FieldNamesForNotesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FieldNamesForNotesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'nids', $pb.PbFieldType.K6)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldNamesForNotesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldNamesForNotesRequest copyWith(
          void Function(FieldNamesForNotesRequest) updates) =>
      super.copyWith((message) => updates(message as FieldNamesForNotesRequest))
          as FieldNamesForNotesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FieldNamesForNotesRequest create() => FieldNamesForNotesRequest._();
  @$core.override
  FieldNamesForNotesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FieldNamesForNotesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FieldNamesForNotesRequest>(create);
  static FieldNamesForNotesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get nids => $_getList(0);
}

class FieldNamesForNotesResponse extends $pb.GeneratedMessage {
  factory FieldNamesForNotesResponse({
    $core.Iterable<$core.String>? fields,
  }) {
    final result = create();
    if (fields != null) result.fields.addAll(fields);
    return result;
  }

  FieldNamesForNotesResponse._();

  factory FieldNamesForNotesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FieldNamesForNotesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FieldNamesForNotesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'fields')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldNamesForNotesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldNamesForNotesResponse copyWith(
          void Function(FieldNamesForNotesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as FieldNamesForNotesResponse))
          as FieldNamesForNotesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FieldNamesForNotesResponse create() => FieldNamesForNotesResponse._();
  @$core.override
  FieldNamesForNotesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FieldNamesForNotesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FieldNamesForNotesResponse>(create);
  static FieldNamesForNotesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get fields => $_getList(0);
}

class NoteFieldsCheckResponse extends $pb.GeneratedMessage {
  factory NoteFieldsCheckResponse({
    NoteFieldsCheckResponse_State? state,
  }) {
    final result = create();
    if (state != null) result.state = state;
    return result;
  }

  NoteFieldsCheckResponse._();

  factory NoteFieldsCheckResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NoteFieldsCheckResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NoteFieldsCheckResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.notes'),
      createEmptyInstance: create)
    ..aE<NoteFieldsCheckResponse_State>(1, _omitFieldNames ? '' : 'state',
        enumValues: NoteFieldsCheckResponse_State.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoteFieldsCheckResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NoteFieldsCheckResponse copyWith(
          void Function(NoteFieldsCheckResponse) updates) =>
      super.copyWith((message) => updates(message as NoteFieldsCheckResponse))
          as NoteFieldsCheckResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NoteFieldsCheckResponse create() => NoteFieldsCheckResponse._();
  @$core.override
  NoteFieldsCheckResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NoteFieldsCheckResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NoteFieldsCheckResponse>(create);
  static NoteFieldsCheckResponse? _defaultInstance;

  @$pb.TagNumber(1)
  NoteFieldsCheckResponse_State get state => $_getN(0);
  @$pb.TagNumber(1)
  set state(NoteFieldsCheckResponse_State value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);
}

class NotesServiceApi {
  final $pb.RpcClient _client;

  NotesServiceApi(this._client);

  $async.Future<Note> newNote($pb.ClientContext? ctx, $1.NotetypeId request) =>
      _client.invoke<Note>(ctx, 'NotesService', 'NewNote', request, Note());
  $async.Future<AddNoteResponse> addNote(
          $pb.ClientContext? ctx, AddNoteRequest request) =>
      _client.invoke<AddNoteResponse>(
          ctx, 'NotesService', 'AddNote', request, AddNoteResponse());
  $async.Future<AddNotesResponse> addNotes(
          $pb.ClientContext? ctx, AddNotesRequest request) =>
      _client.invoke<AddNotesResponse>(
          ctx, 'NotesService', 'AddNotes', request, AddNotesResponse());
  $async.Future<DeckAndNotetype> defaultsForAdding(
          $pb.ClientContext? ctx, DefaultsForAddingRequest request) =>
      _client.invoke<DeckAndNotetype>(
          ctx, 'NotesService', 'DefaultsForAdding', request, DeckAndNotetype());
  $async.Future<$2.DeckId> defaultDeckForNotetype(
          $pb.ClientContext? ctx, $1.NotetypeId request) =>
      _client.invoke<$2.DeckId>(
          ctx, 'NotesService', 'DefaultDeckForNotetype', request, $2.DeckId());
  $async.Future<$0.OpChanges> updateNotes(
          $pb.ClientContext? ctx, UpdateNotesRequest request) =>
      _client.invoke<$0.OpChanges>(
          ctx, 'NotesService', 'UpdateNotes', request, $0.OpChanges());
  $async.Future<Note> getNote($pb.ClientContext? ctx, NoteId request) =>
      _client.invoke<Note>(ctx, 'NotesService', 'GetNote', request, Note());
  $async.Future<$0.OpChangesWithCount> removeNotes(
          $pb.ClientContext? ctx, RemoveNotesRequest request) =>
      _client.invoke<$0.OpChangesWithCount>(
          ctx, 'NotesService', 'RemoveNotes', request, $0.OpChangesWithCount());
  $async.Future<ClozeNumbersInNoteResponse> clozeNumbersInNote(
          $pb.ClientContext? ctx, Note request) =>
      _client.invoke<ClozeNumbersInNoteResponse>(ctx, 'NotesService',
          'ClozeNumbersInNote', request, ClozeNumbersInNoteResponse());
  $async.Future<$0.OpChangesWithCount> afterNoteUpdates(
          $pb.ClientContext? ctx, AfterNoteUpdatesRequest request) =>
      _client.invoke<$0.OpChangesWithCount>(ctx, 'NotesService',
          'AfterNoteUpdates', request, $0.OpChangesWithCount());
  $async.Future<FieldNamesForNotesResponse> fieldNamesForNotes(
          $pb.ClientContext? ctx, FieldNamesForNotesRequest request) =>
      _client.invoke<FieldNamesForNotesResponse>(ctx, 'NotesService',
          'FieldNamesForNotes', request, FieldNamesForNotesResponse());
  $async.Future<NoteFieldsCheckResponse> noteFieldsCheck(
          $pb.ClientContext? ctx, Note request) =>
      _client.invoke<NoteFieldsCheckResponse>(ctx, 'NotesService',
          'NoteFieldsCheck', request, NoteFieldsCheckResponse());
  $async.Future<$3.CardIds> cardsOfNote(
          $pb.ClientContext? ctx, NoteId request) =>
      _client.invoke<$3.CardIds>(
          ctx, 'NotesService', 'CardsOfNote', request, $3.CardIds());
  $async.Future<$1.NotetypeId> getSingleNotetypeOfNotes(
          $pb.ClientContext? ctx, NoteIds request) =>
      _client.invoke<$1.NotetypeId>(ctx, 'NotesService',
          'GetSingleNotetypeOfNotes', request, $1.NotetypeId());
}

/// Implicitly includes any of the above methods that are not listed in the
/// backend service.
class BackendNotesServiceApi {
  final $pb.RpcClient _client;

  BackendNotesServiceApi(this._client);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
