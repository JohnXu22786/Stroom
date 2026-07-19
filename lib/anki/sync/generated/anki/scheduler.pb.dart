// This is a generated file - do not edit.
//
// Generated from anki/scheduler.proto.

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

import 'cards.pb.dart' as $0;
import 'collection.pb.dart' as $2;
import 'config.pb.dart' as $1;
import 'deck_config.pbenum.dart' as $5;
import 'decks.pb.dart' as $4;
import 'generic.pb.dart' as $3;
import 'scheduler.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'scheduler.pbenum.dart';

class SchedulingState_New extends $pb.GeneratedMessage {
  factory SchedulingState_New({
    $core.int? position,
  }) {
    final result = create();
    if (position != null) result.position = position;
    return result;
  }

  SchedulingState_New._();

  factory SchedulingState_New.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState_New.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState.New',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'position', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_New clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_New copyWith(void Function(SchedulingState_New) updates) =>
      super.copyWith((message) => updates(message as SchedulingState_New))
          as SchedulingState_New;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState_New create() => SchedulingState_New._();
  @$core.override
  SchedulingState_New createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState_New getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState_New>(create);
  static SchedulingState_New? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get position => $_getIZ(0);
  @$pb.TagNumber(1)
  set position($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPosition() => $_has(0);
  @$pb.TagNumber(1)
  void clearPosition() => $_clearField(1);
}

class SchedulingState_Learning extends $pb.GeneratedMessage {
  factory SchedulingState_Learning({
    $core.int? remainingSteps,
    $core.int? scheduledSecs,
    $core.int? elapsedSecs,
    $0.FsrsMemoryState? memoryState,
  }) {
    final result = create();
    if (remainingSteps != null) result.remainingSteps = remainingSteps;
    if (scheduledSecs != null) result.scheduledSecs = scheduledSecs;
    if (elapsedSecs != null) result.elapsedSecs = elapsedSecs;
    if (memoryState != null) result.memoryState = memoryState;
    return result;
  }

  SchedulingState_Learning._();

  factory SchedulingState_Learning.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState_Learning.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState.Learning',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'remainingSteps',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'scheduledSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'elapsedSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<$0.FsrsMemoryState>(6, _omitFieldNames ? '' : 'memoryState',
        subBuilder: $0.FsrsMemoryState.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Learning clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Learning copyWith(
          void Function(SchedulingState_Learning) updates) =>
      super.copyWith((message) => updates(message as SchedulingState_Learning))
          as SchedulingState_Learning;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState_Learning create() => SchedulingState_Learning._();
  @$core.override
  SchedulingState_Learning createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState_Learning getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState_Learning>(create);
  static SchedulingState_Learning? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get remainingSteps => $_getIZ(0);
  @$pb.TagNumber(1)
  set remainingSteps($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRemainingSteps() => $_has(0);
  @$pb.TagNumber(1)
  void clearRemainingSteps() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get scheduledSecs => $_getIZ(1);
  @$pb.TagNumber(2)
  set scheduledSecs($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScheduledSecs() => $_has(1);
  @$pb.TagNumber(2)
  void clearScheduledSecs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get elapsedSecs => $_getIZ(2);
  @$pb.TagNumber(3)
  set elapsedSecs($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasElapsedSecs() => $_has(2);
  @$pb.TagNumber(3)
  void clearElapsedSecs() => $_clearField(3);

  @$pb.TagNumber(6)
  $0.FsrsMemoryState get memoryState => $_getN(3);
  @$pb.TagNumber(6)
  set memoryState($0.FsrsMemoryState value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMemoryState() => $_has(3);
  @$pb.TagNumber(6)
  void clearMemoryState() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.FsrsMemoryState ensureMemoryState() => $_ensure(3);
}

class SchedulingState_Review extends $pb.GeneratedMessage {
  factory SchedulingState_Review({
    $core.int? scheduledDays,
    $core.int? elapsedDays,
    $core.double? easeFactor,
    $core.int? lapses,
    $core.bool? leeched,
    $0.FsrsMemoryState? memoryState,
  }) {
    final result = create();
    if (scheduledDays != null) result.scheduledDays = scheduledDays;
    if (elapsedDays != null) result.elapsedDays = elapsedDays;
    if (easeFactor != null) result.easeFactor = easeFactor;
    if (lapses != null) result.lapses = lapses;
    if (leeched != null) result.leeched = leeched;
    if (memoryState != null) result.memoryState = memoryState;
    return result;
  }

  SchedulingState_Review._();

  factory SchedulingState_Review.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState_Review.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState.Review',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'scheduledDays',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'elapsedDays',
        fieldType: $pb.PbFieldType.OU3)
    ..aD(3, _omitFieldNames ? '' : 'easeFactor', fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'lapses', fieldType: $pb.PbFieldType.OU3)
    ..aOB(5, _omitFieldNames ? '' : 'leeched')
    ..aOM<$0.FsrsMemoryState>(6, _omitFieldNames ? '' : 'memoryState',
        subBuilder: $0.FsrsMemoryState.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Review clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Review copyWith(
          void Function(SchedulingState_Review) updates) =>
      super.copyWith((message) => updates(message as SchedulingState_Review))
          as SchedulingState_Review;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState_Review create() => SchedulingState_Review._();
  @$core.override
  SchedulingState_Review createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState_Review getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState_Review>(create);
  static SchedulingState_Review? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get scheduledDays => $_getIZ(0);
  @$pb.TagNumber(1)
  set scheduledDays($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScheduledDays() => $_has(0);
  @$pb.TagNumber(1)
  void clearScheduledDays() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get elapsedDays => $_getIZ(1);
  @$pb.TagNumber(2)
  set elapsedDays($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasElapsedDays() => $_has(1);
  @$pb.TagNumber(2)
  void clearElapsedDays() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get easeFactor => $_getN(2);
  @$pb.TagNumber(3)
  set easeFactor($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEaseFactor() => $_has(2);
  @$pb.TagNumber(3)
  void clearEaseFactor() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get lapses => $_getIZ(3);
  @$pb.TagNumber(4)
  set lapses($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLapses() => $_has(3);
  @$pb.TagNumber(4)
  void clearLapses() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get leeched => $_getBF(4);
  @$pb.TagNumber(5)
  set leeched($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLeeched() => $_has(4);
  @$pb.TagNumber(5)
  void clearLeeched() => $_clearField(5);

  @$pb.TagNumber(6)
  $0.FsrsMemoryState get memoryState => $_getN(5);
  @$pb.TagNumber(6)
  set memoryState($0.FsrsMemoryState value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMemoryState() => $_has(5);
  @$pb.TagNumber(6)
  void clearMemoryState() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.FsrsMemoryState ensureMemoryState() => $_ensure(5);
}

class SchedulingState_Relearning extends $pb.GeneratedMessage {
  factory SchedulingState_Relearning({
    SchedulingState_Review? review,
    SchedulingState_Learning? learning,
  }) {
    final result = create();
    if (review != null) result.review = review;
    if (learning != null) result.learning = learning;
    return result;
  }

  SchedulingState_Relearning._();

  factory SchedulingState_Relearning.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState_Relearning.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState.Relearning',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOM<SchedulingState_Review>(1, _omitFieldNames ? '' : 'review',
        subBuilder: SchedulingState_Review.create)
    ..aOM<SchedulingState_Learning>(2, _omitFieldNames ? '' : 'learning',
        subBuilder: SchedulingState_Learning.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Relearning clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Relearning copyWith(
          void Function(SchedulingState_Relearning) updates) =>
      super.copyWith(
              (message) => updates(message as SchedulingState_Relearning))
          as SchedulingState_Relearning;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState_Relearning create() => SchedulingState_Relearning._();
  @$core.override
  SchedulingState_Relearning createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState_Relearning getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState_Relearning>(create);
  static SchedulingState_Relearning? _defaultInstance;

  @$pb.TagNumber(1)
  SchedulingState_Review get review => $_getN(0);
  @$pb.TagNumber(1)
  set review(SchedulingState_Review value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasReview() => $_has(0);
  @$pb.TagNumber(1)
  void clearReview() => $_clearField(1);
  @$pb.TagNumber(1)
  SchedulingState_Review ensureReview() => $_ensure(0);

  @$pb.TagNumber(2)
  SchedulingState_Learning get learning => $_getN(1);
  @$pb.TagNumber(2)
  set learning(SchedulingState_Learning value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLearning() => $_has(1);
  @$pb.TagNumber(2)
  void clearLearning() => $_clearField(2);
  @$pb.TagNumber(2)
  SchedulingState_Learning ensureLearning() => $_ensure(1);
}

enum SchedulingState_Normal_Kind { new_1, learning, review, relearning, notSet }

class SchedulingState_Normal extends $pb.GeneratedMessage {
  factory SchedulingState_Normal({
    SchedulingState_New? new_1,
    SchedulingState_Learning? learning,
    SchedulingState_Review? review,
    SchedulingState_Relearning? relearning,
  }) {
    final result = create();
    if (new_1 != null) result.new_1 = new_1;
    if (learning != null) result.learning = learning;
    if (review != null) result.review = review;
    if (relearning != null) result.relearning = relearning;
    return result;
  }

  SchedulingState_Normal._();

  factory SchedulingState_Normal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState_Normal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SchedulingState_Normal_Kind>
      _SchedulingState_Normal_KindByTag = {
    1: SchedulingState_Normal_Kind.new_1,
    2: SchedulingState_Normal_Kind.learning,
    3: SchedulingState_Normal_Kind.review,
    4: SchedulingState_Normal_Kind.relearning,
    0: SchedulingState_Normal_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState.Normal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4])
    ..aOM<SchedulingState_New>(1, _omitFieldNames ? '' : 'new',
        subBuilder: SchedulingState_New.create)
    ..aOM<SchedulingState_Learning>(2, _omitFieldNames ? '' : 'learning',
        subBuilder: SchedulingState_Learning.create)
    ..aOM<SchedulingState_Review>(3, _omitFieldNames ? '' : 'review',
        subBuilder: SchedulingState_Review.create)
    ..aOM<SchedulingState_Relearning>(4, _omitFieldNames ? '' : 'relearning',
        subBuilder: SchedulingState_Relearning.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Normal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Normal copyWith(
          void Function(SchedulingState_Normal) updates) =>
      super.copyWith((message) => updates(message as SchedulingState_Normal))
          as SchedulingState_Normal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState_Normal create() => SchedulingState_Normal._();
  @$core.override
  SchedulingState_Normal createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState_Normal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState_Normal>(create);
  static SchedulingState_Normal? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  SchedulingState_Normal_Kind whichKind() =>
      _SchedulingState_Normal_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SchedulingState_New get new_1 => $_getN(0);
  @$pb.TagNumber(1)
  set new_1(SchedulingState_New value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNew_1() => $_has(0);
  @$pb.TagNumber(1)
  void clearNew_1() => $_clearField(1);
  @$pb.TagNumber(1)
  SchedulingState_New ensureNew_1() => $_ensure(0);

  @$pb.TagNumber(2)
  SchedulingState_Learning get learning => $_getN(1);
  @$pb.TagNumber(2)
  set learning(SchedulingState_Learning value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasLearning() => $_has(1);
  @$pb.TagNumber(2)
  void clearLearning() => $_clearField(2);
  @$pb.TagNumber(2)
  SchedulingState_Learning ensureLearning() => $_ensure(1);

  @$pb.TagNumber(3)
  SchedulingState_Review get review => $_getN(2);
  @$pb.TagNumber(3)
  set review(SchedulingState_Review value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasReview() => $_has(2);
  @$pb.TagNumber(3)
  void clearReview() => $_clearField(3);
  @$pb.TagNumber(3)
  SchedulingState_Review ensureReview() => $_ensure(2);

  @$pb.TagNumber(4)
  SchedulingState_Relearning get relearning => $_getN(3);
  @$pb.TagNumber(4)
  set relearning(SchedulingState_Relearning value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRelearning() => $_has(3);
  @$pb.TagNumber(4)
  void clearRelearning() => $_clearField(4);
  @$pb.TagNumber(4)
  SchedulingState_Relearning ensureRelearning() => $_ensure(3);
}

class SchedulingState_Preview extends $pb.GeneratedMessage {
  factory SchedulingState_Preview({
    $core.int? scheduledSecs,
    $core.bool? finished,
  }) {
    final result = create();
    if (scheduledSecs != null) result.scheduledSecs = scheduledSecs;
    if (finished != null) result.finished = finished;
    return result;
  }

  SchedulingState_Preview._();

  factory SchedulingState_Preview.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState_Preview.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState.Preview',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'scheduledSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(2, _omitFieldNames ? '' : 'finished')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Preview clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Preview copyWith(
          void Function(SchedulingState_Preview) updates) =>
      super.copyWith((message) => updates(message as SchedulingState_Preview))
          as SchedulingState_Preview;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState_Preview create() => SchedulingState_Preview._();
  @$core.override
  SchedulingState_Preview createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState_Preview getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState_Preview>(create);
  static SchedulingState_Preview? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get scheduledSecs => $_getIZ(0);
  @$pb.TagNumber(1)
  set scheduledSecs($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScheduledSecs() => $_has(0);
  @$pb.TagNumber(1)
  void clearScheduledSecs() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get finished => $_getBF(1);
  @$pb.TagNumber(2)
  set finished($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFinished() => $_has(1);
  @$pb.TagNumber(2)
  void clearFinished() => $_clearField(2);
}

class SchedulingState_ReschedulingFilter extends $pb.GeneratedMessage {
  factory SchedulingState_ReschedulingFilter({
    SchedulingState_Normal? originalState,
  }) {
    final result = create();
    if (originalState != null) result.originalState = originalState;
    return result;
  }

  SchedulingState_ReschedulingFilter._();

  factory SchedulingState_ReschedulingFilter.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState_ReschedulingFilter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState.ReschedulingFilter',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOM<SchedulingState_Normal>(1, _omitFieldNames ? '' : 'originalState',
        subBuilder: SchedulingState_Normal.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_ReschedulingFilter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_ReschedulingFilter copyWith(
          void Function(SchedulingState_ReschedulingFilter) updates) =>
      super.copyWith((message) =>
              updates(message as SchedulingState_ReschedulingFilter))
          as SchedulingState_ReschedulingFilter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState_ReschedulingFilter create() =>
      SchedulingState_ReschedulingFilter._();
  @$core.override
  SchedulingState_ReschedulingFilter createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState_ReschedulingFilter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState_ReschedulingFilter>(
          create);
  static SchedulingState_ReschedulingFilter? _defaultInstance;

  @$pb.TagNumber(1)
  SchedulingState_Normal get originalState => $_getN(0);
  @$pb.TagNumber(1)
  set originalState(SchedulingState_Normal value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOriginalState() => $_has(0);
  @$pb.TagNumber(1)
  void clearOriginalState() => $_clearField(1);
  @$pb.TagNumber(1)
  SchedulingState_Normal ensureOriginalState() => $_ensure(0);
}

enum SchedulingState_Filtered_Kind { preview, rescheduling, notSet }

class SchedulingState_Filtered extends $pb.GeneratedMessage {
  factory SchedulingState_Filtered({
    SchedulingState_Preview? preview,
    SchedulingState_ReschedulingFilter? rescheduling,
  }) {
    final result = create();
    if (preview != null) result.preview = preview;
    if (rescheduling != null) result.rescheduling = rescheduling;
    return result;
  }

  SchedulingState_Filtered._();

  factory SchedulingState_Filtered.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState_Filtered.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SchedulingState_Filtered_Kind>
      _SchedulingState_Filtered_KindByTag = {
    1: SchedulingState_Filtered_Kind.preview,
    2: SchedulingState_Filtered_Kind.rescheduling,
    0: SchedulingState_Filtered_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState.Filtered',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<SchedulingState_Preview>(1, _omitFieldNames ? '' : 'preview',
        subBuilder: SchedulingState_Preview.create)
    ..aOM<SchedulingState_ReschedulingFilter>(
        2, _omitFieldNames ? '' : 'rescheduling',
        subBuilder: SchedulingState_ReschedulingFilter.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Filtered clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState_Filtered copyWith(
          void Function(SchedulingState_Filtered) updates) =>
      super.copyWith((message) => updates(message as SchedulingState_Filtered))
          as SchedulingState_Filtered;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState_Filtered create() => SchedulingState_Filtered._();
  @$core.override
  SchedulingState_Filtered createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState_Filtered getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState_Filtered>(create);
  static SchedulingState_Filtered? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  SchedulingState_Filtered_Kind whichKind() =>
      _SchedulingState_Filtered_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SchedulingState_Preview get preview => $_getN(0);
  @$pb.TagNumber(1)
  set preview(SchedulingState_Preview value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPreview() => $_has(0);
  @$pb.TagNumber(1)
  void clearPreview() => $_clearField(1);
  @$pb.TagNumber(1)
  SchedulingState_Preview ensurePreview() => $_ensure(0);

  @$pb.TagNumber(2)
  SchedulingState_ReschedulingFilter get rescheduling => $_getN(1);
  @$pb.TagNumber(2)
  set rescheduling(SchedulingState_ReschedulingFilter value) =>
      $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRescheduling() => $_has(1);
  @$pb.TagNumber(2)
  void clearRescheduling() => $_clearField(2);
  @$pb.TagNumber(2)
  SchedulingState_ReschedulingFilter ensureRescheduling() => $_ensure(1);
}

enum SchedulingState_Kind { normal, filtered, notSet }

class SchedulingState extends $pb.GeneratedMessage {
  factory SchedulingState({
    SchedulingState_Normal? normal,
    SchedulingState_Filtered? filtered,
    $core.String? customData,
  }) {
    final result = create();
    if (normal != null) result.normal = normal;
    if (filtered != null) result.filtered = filtered;
    if (customData != null) result.customData = customData;
    return result;
  }

  SchedulingState._();

  factory SchedulingState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SchedulingState_Kind>
      _SchedulingState_KindByTag = {
    1: SchedulingState_Kind.normal,
    2: SchedulingState_Kind.filtered,
    0: SchedulingState_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<SchedulingState_Normal>(1, _omitFieldNames ? '' : 'normal',
        subBuilder: SchedulingState_Normal.create)
    ..aOM<SchedulingState_Filtered>(2, _omitFieldNames ? '' : 'filtered',
        subBuilder: SchedulingState_Filtered.create)
    ..aOS(3, _omitFieldNames ? '' : 'customData')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingState copyWith(void Function(SchedulingState) updates) =>
      super.copyWith((message) => updates(message as SchedulingState))
          as SchedulingState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingState create() => SchedulingState._();
  @$core.override
  SchedulingState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingState>(create);
  static SchedulingState? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  SchedulingState_Kind whichKind() =>
      _SchedulingState_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SchedulingState_Normal get normal => $_getN(0);
  @$pb.TagNumber(1)
  set normal(SchedulingState_Normal value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNormal() => $_has(0);
  @$pb.TagNumber(1)
  void clearNormal() => $_clearField(1);
  @$pb.TagNumber(1)
  SchedulingState_Normal ensureNormal() => $_ensure(0);

  @$pb.TagNumber(2)
  SchedulingState_Filtered get filtered => $_getN(1);
  @$pb.TagNumber(2)
  set filtered(SchedulingState_Filtered value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFiltered() => $_has(1);
  @$pb.TagNumber(2)
  void clearFiltered() => $_clearField(2);
  @$pb.TagNumber(2)
  SchedulingState_Filtered ensureFiltered() => $_ensure(1);

  /// The backend does not populate this field in GetQueuedCards; the front-end
  /// is expected to populate it based on the provided Card. If it's not set when
  /// answering a card, the existing custom data will not be updated.
  @$pb.TagNumber(3)
  $core.String get customData => $_getSZ(2);
  @$pb.TagNumber(3)
  set customData($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCustomData() => $_has(2);
  @$pb.TagNumber(3)
  void clearCustomData() => $_clearField(3);
}

class QueuedCards_QueuedCard extends $pb.GeneratedMessage {
  factory QueuedCards_QueuedCard({
    $0.Card? card,
    QueuedCards_Queue? queue,
    SchedulingStates? states,
    SchedulingContext? context,
  }) {
    final result = create();
    if (card != null) result.card = card;
    if (queue != null) result.queue = queue;
    if (states != null) result.states = states;
    if (context != null) result.context = context;
    return result;
  }

  QueuedCards_QueuedCard._();

  factory QueuedCards_QueuedCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QueuedCards_QueuedCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QueuedCards.QueuedCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOM<$0.Card>(1, _omitFieldNames ? '' : 'card', subBuilder: $0.Card.create)
    ..aE<QueuedCards_Queue>(2, _omitFieldNames ? '' : 'queue',
        enumValues: QueuedCards_Queue.values)
    ..aOM<SchedulingStates>(3, _omitFieldNames ? '' : 'states',
        subBuilder: SchedulingStates.create)
    ..aOM<SchedulingContext>(4, _omitFieldNames ? '' : 'context',
        subBuilder: SchedulingContext.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueuedCards_QueuedCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueuedCards_QueuedCard copyWith(
          void Function(QueuedCards_QueuedCard) updates) =>
      super.copyWith((message) => updates(message as QueuedCards_QueuedCard))
          as QueuedCards_QueuedCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueuedCards_QueuedCard create() => QueuedCards_QueuedCard._();
  @$core.override
  QueuedCards_QueuedCard createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QueuedCards_QueuedCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QueuedCards_QueuedCard>(create);
  static QueuedCards_QueuedCard? _defaultInstance;

  @$pb.TagNumber(1)
  $0.Card get card => $_getN(0);
  @$pb.TagNumber(1)
  set card($0.Card value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCard() => $_has(0);
  @$pb.TagNumber(1)
  void clearCard() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.Card ensureCard() => $_ensure(0);

  @$pb.TagNumber(2)
  QueuedCards_Queue get queue => $_getN(1);
  @$pb.TagNumber(2)
  set queue(QueuedCards_Queue value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasQueue() => $_has(1);
  @$pb.TagNumber(2)
  void clearQueue() => $_clearField(2);

  @$pb.TagNumber(3)
  SchedulingStates get states => $_getN(2);
  @$pb.TagNumber(3)
  set states(SchedulingStates value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStates() => $_has(2);
  @$pb.TagNumber(3)
  void clearStates() => $_clearField(3);
  @$pb.TagNumber(3)
  SchedulingStates ensureStates() => $_ensure(2);

  @$pb.TagNumber(4)
  SchedulingContext get context => $_getN(3);
  @$pb.TagNumber(4)
  set context(SchedulingContext value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasContext() => $_has(3);
  @$pb.TagNumber(4)
  void clearContext() => $_clearField(4);
  @$pb.TagNumber(4)
  SchedulingContext ensureContext() => $_ensure(3);
}

class QueuedCards extends $pb.GeneratedMessage {
  factory QueuedCards({
    $core.Iterable<QueuedCards_QueuedCard>? cards,
    $core.int? newCount,
    $core.int? learningCount,
    $core.int? reviewCount,
  }) {
    final result = create();
    if (cards != null) result.cards.addAll(cards);
    if (newCount != null) result.newCount = newCount;
    if (learningCount != null) result.learningCount = learningCount;
    if (reviewCount != null) result.reviewCount = reviewCount;
    return result;
  }

  QueuedCards._();

  factory QueuedCards.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QueuedCards.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QueuedCards',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..pPM<QueuedCards_QueuedCard>(1, _omitFieldNames ? '' : 'cards',
        subBuilder: QueuedCards_QueuedCard.create)
    ..aI(2, _omitFieldNames ? '' : 'newCount', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'learningCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'reviewCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueuedCards clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueuedCards copyWith(void Function(QueuedCards) updates) =>
      super.copyWith((message) => updates(message as QueuedCards))
          as QueuedCards;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QueuedCards create() => QueuedCards._();
  @$core.override
  QueuedCards createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QueuedCards getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QueuedCards>(create);
  static QueuedCards? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<QueuedCards_QueuedCard> get cards => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get newCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set newCount($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNewCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get learningCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set learningCount($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLearningCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearLearningCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get reviewCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set reviewCount($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReviewCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearReviewCount() => $_clearField(4);
}

class GetQueuedCardsRequest extends $pb.GeneratedMessage {
  factory GetQueuedCardsRequest({
    $core.int? fetchLimit,
    $core.bool? intradayLearningOnly,
  }) {
    final result = create();
    if (fetchLimit != null) result.fetchLimit = fetchLimit;
    if (intradayLearningOnly != null)
      result.intradayLearningOnly = intradayLearningOnly;
    return result;
  }

  GetQueuedCardsRequest._();

  factory GetQueuedCardsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetQueuedCardsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetQueuedCardsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'fetchLimit', fieldType: $pb.PbFieldType.OU3)
    ..aOB(2, _omitFieldNames ? '' : 'intradayLearningOnly')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQueuedCardsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetQueuedCardsRequest copyWith(
          void Function(GetQueuedCardsRequest) updates) =>
      super.copyWith((message) => updates(message as GetQueuedCardsRequest))
          as GetQueuedCardsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetQueuedCardsRequest create() => GetQueuedCardsRequest._();
  @$core.override
  GetQueuedCardsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetQueuedCardsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetQueuedCardsRequest>(create);
  static GetQueuedCardsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get fetchLimit => $_getIZ(0);
  @$pb.TagNumber(1)
  set fetchLimit($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFetchLimit() => $_has(0);
  @$pb.TagNumber(1)
  void clearFetchLimit() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get intradayLearningOnly => $_getBF(1);
  @$pb.TagNumber(2)
  set intradayLearningOnly($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIntradayLearningOnly() => $_has(1);
  @$pb.TagNumber(2)
  void clearIntradayLearningOnly() => $_clearField(2);
}

class SchedTimingTodayResponse extends $pb.GeneratedMessage {
  factory SchedTimingTodayResponse({
    $core.int? daysElapsed,
    $fixnum.Int64? nextDayAt,
  }) {
    final result = create();
    if (daysElapsed != null) result.daysElapsed = daysElapsed;
    if (nextDayAt != null) result.nextDayAt = nextDayAt;
    return result;
  }

  SchedTimingTodayResponse._();

  factory SchedTimingTodayResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedTimingTodayResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedTimingTodayResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'daysElapsed',
        fieldType: $pb.PbFieldType.OU3)
    ..aInt64(2, _omitFieldNames ? '' : 'nextDayAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedTimingTodayResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedTimingTodayResponse copyWith(
          void Function(SchedTimingTodayResponse) updates) =>
      super.copyWith((message) => updates(message as SchedTimingTodayResponse))
          as SchedTimingTodayResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedTimingTodayResponse create() => SchedTimingTodayResponse._();
  @$core.override
  SchedTimingTodayResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedTimingTodayResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedTimingTodayResponse>(create);
  static SchedTimingTodayResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get daysElapsed => $_getIZ(0);
  @$pb.TagNumber(1)
  set daysElapsed($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDaysElapsed() => $_has(0);
  @$pb.TagNumber(1)
  void clearDaysElapsed() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get nextDayAt => $_getI64(1);
  @$pb.TagNumber(2)
  set nextDayAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextDayAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextDayAt() => $_clearField(2);
}

class StudiedTodayMessageRequest extends $pb.GeneratedMessage {
  factory StudiedTodayMessageRequest({
    $core.int? cards,
    $core.double? seconds,
  }) {
    final result = create();
    if (cards != null) result.cards = cards;
    if (seconds != null) result.seconds = seconds;
    return result;
  }

  StudiedTodayMessageRequest._();

  factory StudiedTodayMessageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StudiedTodayMessageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StudiedTodayMessageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'cards', fieldType: $pb.PbFieldType.OU3)
    ..aD(2, _omitFieldNames ? '' : 'seconds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudiedTodayMessageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StudiedTodayMessageRequest copyWith(
          void Function(StudiedTodayMessageRequest) updates) =>
      super.copyWith(
              (message) => updates(message as StudiedTodayMessageRequest))
          as StudiedTodayMessageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StudiedTodayMessageRequest create() => StudiedTodayMessageRequest._();
  @$core.override
  StudiedTodayMessageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StudiedTodayMessageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StudiedTodayMessageRequest>(create);
  static StudiedTodayMessageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get cards => $_getIZ(0);
  @$pb.TagNumber(1)
  set cards($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCards() => $_has(0);
  @$pb.TagNumber(1)
  void clearCards() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get seconds => $_getN(1);
  @$pb.TagNumber(2)
  set seconds($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeconds() => $_clearField(2);
}

class UpdateStatsRequest extends $pb.GeneratedMessage {
  factory UpdateStatsRequest({
    $fixnum.Int64? deckId,
    $core.int? newDelta,
    $core.int? reviewDelta,
    $core.int? millisecondDelta,
  }) {
    final result = create();
    if (deckId != null) result.deckId = deckId;
    if (newDelta != null) result.newDelta = newDelta;
    if (reviewDelta != null) result.reviewDelta = reviewDelta;
    if (millisecondDelta != null) result.millisecondDelta = millisecondDelta;
    return result;
  }

  UpdateStatsRequest._();

  factory UpdateStatsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateStatsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateStatsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deckId')
    ..aI(2, _omitFieldNames ? '' : 'newDelta')
    ..aI(4, _omitFieldNames ? '' : 'reviewDelta')
    ..aI(5, _omitFieldNames ? '' : 'millisecondDelta')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateStatsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateStatsRequest copyWith(void Function(UpdateStatsRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateStatsRequest))
          as UpdateStatsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateStatsRequest create() => UpdateStatsRequest._();
  @$core.override
  UpdateStatsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateStatsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateStatsRequest>(create);
  static UpdateStatsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deckId => $_getI64(0);
  @$pb.TagNumber(1)
  set deckId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get newDelta => $_getIZ(1);
  @$pb.TagNumber(2)
  set newDelta($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNewDelta() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewDelta() => $_clearField(2);

  @$pb.TagNumber(4)
  $core.int get reviewDelta => $_getIZ(2);
  @$pb.TagNumber(4)
  set reviewDelta($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(4)
  $core.bool hasReviewDelta() => $_has(2);
  @$pb.TagNumber(4)
  void clearReviewDelta() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get millisecondDelta => $_getIZ(3);
  @$pb.TagNumber(5)
  set millisecondDelta($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(5)
  $core.bool hasMillisecondDelta() => $_has(3);
  @$pb.TagNumber(5)
  void clearMillisecondDelta() => $_clearField(5);
}

class ExtendLimitsRequest extends $pb.GeneratedMessage {
  factory ExtendLimitsRequest({
    $fixnum.Int64? deckId,
    $core.int? newDelta,
    $core.int? reviewDelta,
  }) {
    final result = create();
    if (deckId != null) result.deckId = deckId;
    if (newDelta != null) result.newDelta = newDelta;
    if (reviewDelta != null) result.reviewDelta = reviewDelta;
    return result;
  }

  ExtendLimitsRequest._();

  factory ExtendLimitsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExtendLimitsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExtendLimitsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deckId')
    ..aI(2, _omitFieldNames ? '' : 'newDelta')
    ..aI(3, _omitFieldNames ? '' : 'reviewDelta')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExtendLimitsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExtendLimitsRequest copyWith(void Function(ExtendLimitsRequest) updates) =>
      super.copyWith((message) => updates(message as ExtendLimitsRequest))
          as ExtendLimitsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExtendLimitsRequest create() => ExtendLimitsRequest._();
  @$core.override
  ExtendLimitsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExtendLimitsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExtendLimitsRequest>(create);
  static ExtendLimitsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deckId => $_getI64(0);
  @$pb.TagNumber(1)
  set deckId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get newDelta => $_getIZ(1);
  @$pb.TagNumber(2)
  set newDelta($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNewDelta() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewDelta() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get reviewDelta => $_getIZ(2);
  @$pb.TagNumber(3)
  set reviewDelta($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReviewDelta() => $_has(2);
  @$pb.TagNumber(3)
  void clearReviewDelta() => $_clearField(3);
}

class CountsForDeckTodayResponse extends $pb.GeneratedMessage {
  factory CountsForDeckTodayResponse({
    $core.int? new_1,
    $core.int? review,
  }) {
    final result = create();
    if (new_1 != null) result.new_1 = new_1;
    if (review != null) result.review = review;
    return result;
  }

  CountsForDeckTodayResponse._();

  factory CountsForDeckTodayResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CountsForDeckTodayResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CountsForDeckTodayResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'new')
    ..aI(2, _omitFieldNames ? '' : 'review')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CountsForDeckTodayResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CountsForDeckTodayResponse copyWith(
          void Function(CountsForDeckTodayResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CountsForDeckTodayResponse))
          as CountsForDeckTodayResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CountsForDeckTodayResponse create() => CountsForDeckTodayResponse._();
  @$core.override
  CountsForDeckTodayResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CountsForDeckTodayResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CountsForDeckTodayResponse>(create);
  static CountsForDeckTodayResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get new_1 => $_getIZ(0);
  @$pb.TagNumber(1)
  set new_1($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNew_1() => $_has(0);
  @$pb.TagNumber(1)
  void clearNew_1() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get review => $_getIZ(1);
  @$pb.TagNumber(2)
  set review($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReview() => $_has(1);
  @$pb.TagNumber(2)
  void clearReview() => $_clearField(2);
}

class CongratsInfoResponse extends $pb.GeneratedMessage {
  factory CongratsInfoResponse({
    $core.int? learnRemaining,
    $core.int? secsUntilNextLearn,
    $core.bool? reviewRemaining,
    $core.bool? newRemaining,
    $core.bool? haveSchedBuried,
    $core.bool? haveUserBuried,
    $core.bool? isFilteredDeck,
    $core.bool? bridgeCommandsSupported,
    $core.String? deckDescription,
  }) {
    final result = create();
    if (learnRemaining != null) result.learnRemaining = learnRemaining;
    if (secsUntilNextLearn != null)
      result.secsUntilNextLearn = secsUntilNextLearn;
    if (reviewRemaining != null) result.reviewRemaining = reviewRemaining;
    if (newRemaining != null) result.newRemaining = newRemaining;
    if (haveSchedBuried != null) result.haveSchedBuried = haveSchedBuried;
    if (haveUserBuried != null) result.haveUserBuried = haveUserBuried;
    if (isFilteredDeck != null) result.isFilteredDeck = isFilteredDeck;
    if (bridgeCommandsSupported != null)
      result.bridgeCommandsSupported = bridgeCommandsSupported;
    if (deckDescription != null) result.deckDescription = deckDescription;
    return result;
  }

  CongratsInfoResponse._();

  factory CongratsInfoResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CongratsInfoResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CongratsInfoResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'learnRemaining',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'secsUntilNextLearn',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'reviewRemaining')
    ..aOB(4, _omitFieldNames ? '' : 'newRemaining')
    ..aOB(5, _omitFieldNames ? '' : 'haveSchedBuried')
    ..aOB(6, _omitFieldNames ? '' : 'haveUserBuried')
    ..aOB(7, _omitFieldNames ? '' : 'isFilteredDeck')
    ..aOB(8, _omitFieldNames ? '' : 'bridgeCommandsSupported')
    ..aOS(9, _omitFieldNames ? '' : 'deckDescription')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CongratsInfoResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CongratsInfoResponse copyWith(void Function(CongratsInfoResponse) updates) =>
      super.copyWith((message) => updates(message as CongratsInfoResponse))
          as CongratsInfoResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CongratsInfoResponse create() => CongratsInfoResponse._();
  @$core.override
  CongratsInfoResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CongratsInfoResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CongratsInfoResponse>(create);
  static CongratsInfoResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get learnRemaining => $_getIZ(0);
  @$pb.TagNumber(1)
  set learnRemaining($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLearnRemaining() => $_has(0);
  @$pb.TagNumber(1)
  void clearLearnRemaining() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get secsUntilNextLearn => $_getIZ(1);
  @$pb.TagNumber(2)
  set secsUntilNextLearn($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSecsUntilNextLearn() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecsUntilNextLearn() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get reviewRemaining => $_getBF(2);
  @$pb.TagNumber(3)
  set reviewRemaining($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReviewRemaining() => $_has(2);
  @$pb.TagNumber(3)
  void clearReviewRemaining() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get newRemaining => $_getBF(3);
  @$pb.TagNumber(4)
  set newRemaining($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewRemaining() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewRemaining() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get haveSchedBuried => $_getBF(4);
  @$pb.TagNumber(5)
  set haveSchedBuried($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHaveSchedBuried() => $_has(4);
  @$pb.TagNumber(5)
  void clearHaveSchedBuried() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get haveUserBuried => $_getBF(5);
  @$pb.TagNumber(6)
  set haveUserBuried($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHaveUserBuried() => $_has(5);
  @$pb.TagNumber(6)
  void clearHaveUserBuried() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isFilteredDeck => $_getBF(6);
  @$pb.TagNumber(7)
  set isFilteredDeck($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsFilteredDeck() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsFilteredDeck() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get bridgeCommandsSupported => $_getBF(7);
  @$pb.TagNumber(8)
  set bridgeCommandsSupported($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBridgeCommandsSupported() => $_has(7);
  @$pb.TagNumber(8)
  void clearBridgeCommandsSupported() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get deckDescription => $_getSZ(8);
  @$pb.TagNumber(9)
  set deckDescription($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDeckDescription() => $_has(8);
  @$pb.TagNumber(9)
  void clearDeckDescription() => $_clearField(9);
}

class UnburyDeckRequest extends $pb.GeneratedMessage {
  factory UnburyDeckRequest({
    $fixnum.Int64? deckId,
    UnburyDeckRequest_Mode? mode,
  }) {
    final result = create();
    if (deckId != null) result.deckId = deckId;
    if (mode != null) result.mode = mode;
    return result;
  }

  UnburyDeckRequest._();

  factory UnburyDeckRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnburyDeckRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnburyDeckRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deckId')
    ..aE<UnburyDeckRequest_Mode>(2, _omitFieldNames ? '' : 'mode',
        enumValues: UnburyDeckRequest_Mode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnburyDeckRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnburyDeckRequest copyWith(void Function(UnburyDeckRequest) updates) =>
      super.copyWith((message) => updates(message as UnburyDeckRequest))
          as UnburyDeckRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnburyDeckRequest create() => UnburyDeckRequest._();
  @$core.override
  UnburyDeckRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnburyDeckRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnburyDeckRequest>(create);
  static UnburyDeckRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deckId => $_getI64(0);
  @$pb.TagNumber(1)
  set deckId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);

  @$pb.TagNumber(2)
  UnburyDeckRequest_Mode get mode => $_getN(1);
  @$pb.TagNumber(2)
  set mode(UnburyDeckRequest_Mode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearMode() => $_clearField(2);
}

class BuryOrSuspendCardsRequest extends $pb.GeneratedMessage {
  factory BuryOrSuspendCardsRequest({
    $core.Iterable<$fixnum.Int64>? cardIds,
    $core.Iterable<$fixnum.Int64>? noteIds,
    BuryOrSuspendCardsRequest_Mode? mode,
  }) {
    final result = create();
    if (cardIds != null) result.cardIds.addAll(cardIds);
    if (noteIds != null) result.noteIds.addAll(noteIds);
    if (mode != null) result.mode = mode;
    return result;
  }

  BuryOrSuspendCardsRequest._();

  factory BuryOrSuspendCardsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BuryOrSuspendCardsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BuryOrSuspendCardsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cardIds', $pb.PbFieldType.K6)
    ..p<$fixnum.Int64>(2, _omitFieldNames ? '' : 'noteIds', $pb.PbFieldType.K6)
    ..aE<BuryOrSuspendCardsRequest_Mode>(3, _omitFieldNames ? '' : 'mode',
        enumValues: BuryOrSuspendCardsRequest_Mode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuryOrSuspendCardsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BuryOrSuspendCardsRequest copyWith(
          void Function(BuryOrSuspendCardsRequest) updates) =>
      super.copyWith((message) => updates(message as BuryOrSuspendCardsRequest))
          as BuryOrSuspendCardsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BuryOrSuspendCardsRequest create() => BuryOrSuspendCardsRequest._();
  @$core.override
  BuryOrSuspendCardsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BuryOrSuspendCardsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BuryOrSuspendCardsRequest>(create);
  static BuryOrSuspendCardsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get cardIds => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$fixnum.Int64> get noteIds => $_getList(1);

  @$pb.TagNumber(3)
  BuryOrSuspendCardsRequest_Mode get mode => $_getN(2);
  @$pb.TagNumber(3)
  set mode(BuryOrSuspendCardsRequest_Mode value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearMode() => $_clearField(3);
}

class ScheduleCardsAsNewRequest extends $pb.GeneratedMessage {
  factory ScheduleCardsAsNewRequest({
    $core.Iterable<$fixnum.Int64>? cardIds,
    $core.bool? log,
    $core.bool? restorePosition,
    $core.bool? resetCounts,
    ScheduleCardsAsNewRequest_Context? context,
  }) {
    final result = create();
    if (cardIds != null) result.cardIds.addAll(cardIds);
    if (log != null) result.log = log;
    if (restorePosition != null) result.restorePosition = restorePosition;
    if (resetCounts != null) result.resetCounts = resetCounts;
    if (context != null) result.context = context;
    return result;
  }

  ScheduleCardsAsNewRequest._();

  factory ScheduleCardsAsNewRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScheduleCardsAsNewRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScheduleCardsAsNewRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cardIds', $pb.PbFieldType.K6)
    ..aOB(2, _omitFieldNames ? '' : 'log')
    ..aOB(3, _omitFieldNames ? '' : 'restorePosition')
    ..aOB(4, _omitFieldNames ? '' : 'resetCounts')
    ..aE<ScheduleCardsAsNewRequest_Context>(5, _omitFieldNames ? '' : 'context',
        enumValues: ScheduleCardsAsNewRequest_Context.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScheduleCardsAsNewRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScheduleCardsAsNewRequest copyWith(
          void Function(ScheduleCardsAsNewRequest) updates) =>
      super.copyWith((message) => updates(message as ScheduleCardsAsNewRequest))
          as ScheduleCardsAsNewRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScheduleCardsAsNewRequest create() => ScheduleCardsAsNewRequest._();
  @$core.override
  ScheduleCardsAsNewRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScheduleCardsAsNewRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScheduleCardsAsNewRequest>(create);
  static ScheduleCardsAsNewRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get cardIds => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get log => $_getBF(1);
  @$pb.TagNumber(2)
  set log($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLog() => $_has(1);
  @$pb.TagNumber(2)
  void clearLog() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get restorePosition => $_getBF(2);
  @$pb.TagNumber(3)
  set restorePosition($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRestorePosition() => $_has(2);
  @$pb.TagNumber(3)
  void clearRestorePosition() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get resetCounts => $_getBF(3);
  @$pb.TagNumber(4)
  set resetCounts($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasResetCounts() => $_has(3);
  @$pb.TagNumber(4)
  void clearResetCounts() => $_clearField(4);

  @$pb.TagNumber(5)
  ScheduleCardsAsNewRequest_Context get context => $_getN(4);
  @$pb.TagNumber(5)
  set context(ScheduleCardsAsNewRequest_Context value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasContext() => $_has(4);
  @$pb.TagNumber(5)
  void clearContext() => $_clearField(5);
}

class ScheduleCardsAsNewDefaultsRequest extends $pb.GeneratedMessage {
  factory ScheduleCardsAsNewDefaultsRequest({
    ScheduleCardsAsNewRequest_Context? context,
  }) {
    final result = create();
    if (context != null) result.context = context;
    return result;
  }

  ScheduleCardsAsNewDefaultsRequest._();

  factory ScheduleCardsAsNewDefaultsRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScheduleCardsAsNewDefaultsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScheduleCardsAsNewDefaultsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aE<ScheduleCardsAsNewRequest_Context>(1, _omitFieldNames ? '' : 'context',
        enumValues: ScheduleCardsAsNewRequest_Context.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScheduleCardsAsNewDefaultsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScheduleCardsAsNewDefaultsRequest copyWith(
          void Function(ScheduleCardsAsNewDefaultsRequest) updates) =>
      super.copyWith((message) =>
              updates(message as ScheduleCardsAsNewDefaultsRequest))
          as ScheduleCardsAsNewDefaultsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScheduleCardsAsNewDefaultsRequest create() =>
      ScheduleCardsAsNewDefaultsRequest._();
  @$core.override
  ScheduleCardsAsNewDefaultsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScheduleCardsAsNewDefaultsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScheduleCardsAsNewDefaultsRequest>(
          create);
  static ScheduleCardsAsNewDefaultsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  ScheduleCardsAsNewRequest_Context get context => $_getN(0);
  @$pb.TagNumber(1)
  set context(ScheduleCardsAsNewRequest_Context value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasContext() => $_has(0);
  @$pb.TagNumber(1)
  void clearContext() => $_clearField(1);
}

class ScheduleCardsAsNewDefaultsResponse extends $pb.GeneratedMessage {
  factory ScheduleCardsAsNewDefaultsResponse({
    $core.bool? restorePosition,
    $core.bool? resetCounts,
  }) {
    final result = create();
    if (restorePosition != null) result.restorePosition = restorePosition;
    if (resetCounts != null) result.resetCounts = resetCounts;
    return result;
  }

  ScheduleCardsAsNewDefaultsResponse._();

  factory ScheduleCardsAsNewDefaultsResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ScheduleCardsAsNewDefaultsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScheduleCardsAsNewDefaultsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'restorePosition')
    ..aOB(2, _omitFieldNames ? '' : 'resetCounts')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScheduleCardsAsNewDefaultsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ScheduleCardsAsNewDefaultsResponse copyWith(
          void Function(ScheduleCardsAsNewDefaultsResponse) updates) =>
      super.copyWith((message) =>
              updates(message as ScheduleCardsAsNewDefaultsResponse))
          as ScheduleCardsAsNewDefaultsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScheduleCardsAsNewDefaultsResponse create() =>
      ScheduleCardsAsNewDefaultsResponse._();
  @$core.override
  ScheduleCardsAsNewDefaultsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ScheduleCardsAsNewDefaultsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScheduleCardsAsNewDefaultsResponse>(
          create);
  static ScheduleCardsAsNewDefaultsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get restorePosition => $_getBF(0);
  @$pb.TagNumber(1)
  set restorePosition($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRestorePosition() => $_has(0);
  @$pb.TagNumber(1)
  void clearRestorePosition() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get resetCounts => $_getBF(1);
  @$pb.TagNumber(2)
  set resetCounts($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResetCounts() => $_has(1);
  @$pb.TagNumber(2)
  void clearResetCounts() => $_clearField(2);
}

class SetDueDateRequest extends $pb.GeneratedMessage {
  factory SetDueDateRequest({
    $core.Iterable<$fixnum.Int64>? cardIds,
    $core.String? days,
    $1.OptionalStringConfigKey? configKey,
  }) {
    final result = create();
    if (cardIds != null) result.cardIds.addAll(cardIds);
    if (days != null) result.days = days;
    if (configKey != null) result.configKey = configKey;
    return result;
  }

  SetDueDateRequest._();

  factory SetDueDateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetDueDateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetDueDateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cardIds', $pb.PbFieldType.K6)
    ..aOS(2, _omitFieldNames ? '' : 'days')
    ..aOM<$1.OptionalStringConfigKey>(3, _omitFieldNames ? '' : 'configKey',
        subBuilder: $1.OptionalStringConfigKey.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetDueDateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetDueDateRequest copyWith(void Function(SetDueDateRequest) updates) =>
      super.copyWith((message) => updates(message as SetDueDateRequest))
          as SetDueDateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDueDateRequest create() => SetDueDateRequest._();
  @$core.override
  SetDueDateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetDueDateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetDueDateRequest>(create);
  static SetDueDateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get cardIds => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get days => $_getSZ(1);
  @$pb.TagNumber(2)
  set days($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDays() => $_has(1);
  @$pb.TagNumber(2)
  void clearDays() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.OptionalStringConfigKey get configKey => $_getN(2);
  @$pb.TagNumber(3)
  set configKey($1.OptionalStringConfigKey value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasConfigKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearConfigKey() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.OptionalStringConfigKey ensureConfigKey() => $_ensure(2);
}

class GradeNowRequest extends $pb.GeneratedMessage {
  factory GradeNowRequest({
    $core.Iterable<$fixnum.Int64>? cardIds,
    CardAnswer_Rating? rating,
  }) {
    final result = create();
    if (cardIds != null) result.cardIds.addAll(cardIds);
    if (rating != null) result.rating = rating;
    return result;
  }

  GradeNowRequest._();

  factory GradeNowRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GradeNowRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GradeNowRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cardIds', $pb.PbFieldType.K6)
    ..aE<CardAnswer_Rating>(2, _omitFieldNames ? '' : 'rating',
        enumValues: CardAnswer_Rating.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradeNowRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GradeNowRequest copyWith(void Function(GradeNowRequest) updates) =>
      super.copyWith((message) => updates(message as GradeNowRequest))
          as GradeNowRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GradeNowRequest create() => GradeNowRequest._();
  @$core.override
  GradeNowRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GradeNowRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GradeNowRequest>(create);
  static GradeNowRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get cardIds => $_getList(0);

  @$pb.TagNumber(2)
  CardAnswer_Rating get rating => $_getN(1);
  @$pb.TagNumber(2)
  set rating(CardAnswer_Rating value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRating() => $_has(1);
  @$pb.TagNumber(2)
  void clearRating() => $_clearField(2);
}

class SortCardsRequest extends $pb.GeneratedMessage {
  factory SortCardsRequest({
    $core.Iterable<$fixnum.Int64>? cardIds,
    $core.int? startingFrom,
    $core.int? stepSize,
    $core.bool? randomize,
    $core.bool? shiftExisting,
  }) {
    final result = create();
    if (cardIds != null) result.cardIds.addAll(cardIds);
    if (startingFrom != null) result.startingFrom = startingFrom;
    if (stepSize != null) result.stepSize = stepSize;
    if (randomize != null) result.randomize = randomize;
    if (shiftExisting != null) result.shiftExisting = shiftExisting;
    return result;
  }

  SortCardsRequest._();

  factory SortCardsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SortCardsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SortCardsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$fixnum.Int64>(1, _omitFieldNames ? '' : 'cardIds', $pb.PbFieldType.K6)
    ..aI(2, _omitFieldNames ? '' : 'startingFrom',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'stepSize', fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'randomize')
    ..aOB(5, _omitFieldNames ? '' : 'shiftExisting')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SortCardsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SortCardsRequest copyWith(void Function(SortCardsRequest) updates) =>
      super.copyWith((message) => updates(message as SortCardsRequest))
          as SortCardsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SortCardsRequest create() => SortCardsRequest._();
  @$core.override
  SortCardsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SortCardsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SortCardsRequest>(create);
  static SortCardsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$fixnum.Int64> get cardIds => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get startingFrom => $_getIZ(1);
  @$pb.TagNumber(2)
  set startingFrom($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartingFrom() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartingFrom() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get stepSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set stepSize($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStepSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearStepSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get randomize => $_getBF(3);
  @$pb.TagNumber(4)
  set randomize($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRandomize() => $_has(3);
  @$pb.TagNumber(4)
  void clearRandomize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get shiftExisting => $_getBF(4);
  @$pb.TagNumber(5)
  set shiftExisting($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShiftExisting() => $_has(4);
  @$pb.TagNumber(5)
  void clearShiftExisting() => $_clearField(5);
}

class SortDeckRequest extends $pb.GeneratedMessage {
  factory SortDeckRequest({
    $fixnum.Int64? deckId,
    $core.bool? randomize,
  }) {
    final result = create();
    if (deckId != null) result.deckId = deckId;
    if (randomize != null) result.randomize = randomize;
    return result;
  }

  SortDeckRequest._();

  factory SortDeckRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SortDeckRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SortDeckRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deckId')
    ..aOB(2, _omitFieldNames ? '' : 'randomize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SortDeckRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SortDeckRequest copyWith(void Function(SortDeckRequest) updates) =>
      super.copyWith((message) => updates(message as SortDeckRequest))
          as SortDeckRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SortDeckRequest create() => SortDeckRequest._();
  @$core.override
  SortDeckRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SortDeckRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SortDeckRequest>(create);
  static SortDeckRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deckId => $_getI64(0);
  @$pb.TagNumber(1)
  set deckId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get randomize => $_getBF(1);
  @$pb.TagNumber(2)
  set randomize($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRandomize() => $_has(1);
  @$pb.TagNumber(2)
  void clearRandomize() => $_clearField(2);
}

class SchedulingStates extends $pb.GeneratedMessage {
  factory SchedulingStates({
    SchedulingState? current,
    SchedulingState? again,
    SchedulingState? hard,
    SchedulingState? good,
    SchedulingState? easy,
  }) {
    final result = create();
    if (current != null) result.current = current;
    if (again != null) result.again = again;
    if (hard != null) result.hard = hard;
    if (good != null) result.good = good;
    if (easy != null) result.easy = easy;
    return result;
  }

  SchedulingStates._();

  factory SchedulingStates.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingStates.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingStates',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOM<SchedulingState>(1, _omitFieldNames ? '' : 'current',
        subBuilder: SchedulingState.create)
    ..aOM<SchedulingState>(2, _omitFieldNames ? '' : 'again',
        subBuilder: SchedulingState.create)
    ..aOM<SchedulingState>(3, _omitFieldNames ? '' : 'hard',
        subBuilder: SchedulingState.create)
    ..aOM<SchedulingState>(4, _omitFieldNames ? '' : 'good',
        subBuilder: SchedulingState.create)
    ..aOM<SchedulingState>(5, _omitFieldNames ? '' : 'easy',
        subBuilder: SchedulingState.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingStates clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingStates copyWith(void Function(SchedulingStates) updates) =>
      super.copyWith((message) => updates(message as SchedulingStates))
          as SchedulingStates;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingStates create() => SchedulingStates._();
  @$core.override
  SchedulingStates createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingStates getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingStates>(create);
  static SchedulingStates? _defaultInstance;

  @$pb.TagNumber(1)
  SchedulingState get current => $_getN(0);
  @$pb.TagNumber(1)
  set current(SchedulingState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrent() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrent() => $_clearField(1);
  @$pb.TagNumber(1)
  SchedulingState ensureCurrent() => $_ensure(0);

  @$pb.TagNumber(2)
  SchedulingState get again => $_getN(1);
  @$pb.TagNumber(2)
  set again(SchedulingState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAgain() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgain() => $_clearField(2);
  @$pb.TagNumber(2)
  SchedulingState ensureAgain() => $_ensure(1);

  @$pb.TagNumber(3)
  SchedulingState get hard => $_getN(2);
  @$pb.TagNumber(3)
  set hard(SchedulingState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasHard() => $_has(2);
  @$pb.TagNumber(3)
  void clearHard() => $_clearField(3);
  @$pb.TagNumber(3)
  SchedulingState ensureHard() => $_ensure(2);

  @$pb.TagNumber(4)
  SchedulingState get good => $_getN(3);
  @$pb.TagNumber(4)
  set good(SchedulingState value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasGood() => $_has(3);
  @$pb.TagNumber(4)
  void clearGood() => $_clearField(4);
  @$pb.TagNumber(4)
  SchedulingState ensureGood() => $_ensure(3);

  @$pb.TagNumber(5)
  SchedulingState get easy => $_getN(4);
  @$pb.TagNumber(5)
  set easy(SchedulingState value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEasy() => $_has(4);
  @$pb.TagNumber(5)
  void clearEasy() => $_clearField(5);
  @$pb.TagNumber(5)
  SchedulingState ensureEasy() => $_ensure(4);
}

class CardAnswer extends $pb.GeneratedMessage {
  factory CardAnswer({
    $fixnum.Int64? cardId,
    SchedulingState? currentState,
    SchedulingState? newState,
    CardAnswer_Rating? rating,
    $fixnum.Int64? answeredAtMillis,
    $core.int? millisecondsTaken,
  }) {
    final result = create();
    if (cardId != null) result.cardId = cardId;
    if (currentState != null) result.currentState = currentState;
    if (newState != null) result.newState = newState;
    if (rating != null) result.rating = rating;
    if (answeredAtMillis != null) result.answeredAtMillis = answeredAtMillis;
    if (millisecondsTaken != null) result.millisecondsTaken = millisecondsTaken;
    return result;
  }

  CardAnswer._();

  factory CardAnswer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CardAnswer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CardAnswer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'cardId')
    ..aOM<SchedulingState>(2, _omitFieldNames ? '' : 'currentState',
        subBuilder: SchedulingState.create)
    ..aOM<SchedulingState>(3, _omitFieldNames ? '' : 'newState',
        subBuilder: SchedulingState.create)
    ..aE<CardAnswer_Rating>(4, _omitFieldNames ? '' : 'rating',
        enumValues: CardAnswer_Rating.values)
    ..aInt64(5, _omitFieldNames ? '' : 'answeredAtMillis')
    ..aI(6, _omitFieldNames ? '' : 'millisecondsTaken',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardAnswer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CardAnswer copyWith(void Function(CardAnswer) updates) =>
      super.copyWith((message) => updates(message as CardAnswer)) as CardAnswer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CardAnswer create() => CardAnswer._();
  @$core.override
  CardAnswer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CardAnswer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CardAnswer>(create);
  static CardAnswer? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cardId => $_getI64(0);
  @$pb.TagNumber(1)
  set cardId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCardId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCardId() => $_clearField(1);

  @$pb.TagNumber(2)
  SchedulingState get currentState => $_getN(1);
  @$pb.TagNumber(2)
  set currentState(SchedulingState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCurrentState() => $_has(1);
  @$pb.TagNumber(2)
  void clearCurrentState() => $_clearField(2);
  @$pb.TagNumber(2)
  SchedulingState ensureCurrentState() => $_ensure(1);

  @$pb.TagNumber(3)
  SchedulingState get newState => $_getN(2);
  @$pb.TagNumber(3)
  set newState(SchedulingState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasNewState() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewState() => $_clearField(3);
  @$pb.TagNumber(3)
  SchedulingState ensureNewState() => $_ensure(2);

  @$pb.TagNumber(4)
  CardAnswer_Rating get rating => $_getN(3);
  @$pb.TagNumber(4)
  set rating(CardAnswer_Rating value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRating() => $_has(3);
  @$pb.TagNumber(4)
  void clearRating() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get answeredAtMillis => $_getI64(4);
  @$pb.TagNumber(5)
  set answeredAtMillis($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAnsweredAtMillis() => $_has(4);
  @$pb.TagNumber(5)
  void clearAnsweredAtMillis() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get millisecondsTaken => $_getIZ(5);
  @$pb.TagNumber(6)
  set millisecondsTaken($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMillisecondsTaken() => $_has(5);
  @$pb.TagNumber(6)
  void clearMillisecondsTaken() => $_clearField(6);
}

class CustomStudyRequest_Cram extends $pb.GeneratedMessage {
  factory CustomStudyRequest_Cram({
    CustomStudyRequest_Cram_CramKind? kind,
    $core.int? cardLimit,
    $core.Iterable<$core.String>? tagsToInclude,
    $core.Iterable<$core.String>? tagsToExclude,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (cardLimit != null) result.cardLimit = cardLimit;
    if (tagsToInclude != null) result.tagsToInclude.addAll(tagsToInclude);
    if (tagsToExclude != null) result.tagsToExclude.addAll(tagsToExclude);
    return result;
  }

  CustomStudyRequest_Cram._();

  factory CustomStudyRequest_Cram.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CustomStudyRequest_Cram.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomStudyRequest.Cram',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aE<CustomStudyRequest_Cram_CramKind>(1, _omitFieldNames ? '' : 'kind',
        enumValues: CustomStudyRequest_Cram_CramKind.values)
    ..aI(2, _omitFieldNames ? '' : 'cardLimit', fieldType: $pb.PbFieldType.OU3)
    ..pPS(3, _omitFieldNames ? '' : 'tagsToInclude')
    ..pPS(4, _omitFieldNames ? '' : 'tagsToExclude')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyRequest_Cram clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyRequest_Cram copyWith(
          void Function(CustomStudyRequest_Cram) updates) =>
      super.copyWith((message) => updates(message as CustomStudyRequest_Cram))
          as CustomStudyRequest_Cram;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CustomStudyRequest_Cram create() => CustomStudyRequest_Cram._();
  @$core.override
  CustomStudyRequest_Cram createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CustomStudyRequest_Cram getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomStudyRequest_Cram>(create);
  static CustomStudyRequest_Cram? _defaultInstance;

  @$pb.TagNumber(1)
  CustomStudyRequest_Cram_CramKind get kind => $_getN(0);
  @$pb.TagNumber(1)
  set kind(CustomStudyRequest_Cram_CramKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  /// the maximum number of cards
  @$pb.TagNumber(2)
  $core.int get cardLimit => $_getIZ(1);
  @$pb.TagNumber(2)
  set cardLimit($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCardLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearCardLimit() => $_clearField(2);

  /// cards must match one of these, if unempty
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get tagsToInclude => $_getList(2);

  /// cards must not match any of these
  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get tagsToExclude => $_getList(3);
}

enum CustomStudyRequest_Value {
  newLimitDelta,
  reviewLimitDelta,
  forgotDays,
  reviewAheadDays,
  previewDays,
  cram,
  notSet
}

class CustomStudyRequest extends $pb.GeneratedMessage {
  factory CustomStudyRequest({
    $fixnum.Int64? deckId,
    $core.int? newLimitDelta,
    $core.int? reviewLimitDelta,
    $core.int? forgotDays,
    $core.int? reviewAheadDays,
    $core.int? previewDays,
    CustomStudyRequest_Cram? cram,
  }) {
    final result = create();
    if (deckId != null) result.deckId = deckId;
    if (newLimitDelta != null) result.newLimitDelta = newLimitDelta;
    if (reviewLimitDelta != null) result.reviewLimitDelta = reviewLimitDelta;
    if (forgotDays != null) result.forgotDays = forgotDays;
    if (reviewAheadDays != null) result.reviewAheadDays = reviewAheadDays;
    if (previewDays != null) result.previewDays = previewDays;
    if (cram != null) result.cram = cram;
    return result;
  }

  CustomStudyRequest._();

  factory CustomStudyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CustomStudyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, CustomStudyRequest_Value>
      _CustomStudyRequest_ValueByTag = {
    2: CustomStudyRequest_Value.newLimitDelta,
    3: CustomStudyRequest_Value.reviewLimitDelta,
    4: CustomStudyRequest_Value.forgotDays,
    5: CustomStudyRequest_Value.reviewAheadDays,
    6: CustomStudyRequest_Value.previewDays,
    7: CustomStudyRequest_Value.cram,
    0: CustomStudyRequest_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomStudyRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5, 6, 7])
    ..aInt64(1, _omitFieldNames ? '' : 'deckId')
    ..aI(2, _omitFieldNames ? '' : 'newLimitDelta')
    ..aI(3, _omitFieldNames ? '' : 'reviewLimitDelta')
    ..aI(4, _omitFieldNames ? '' : 'forgotDays', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'reviewAheadDays',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'previewDays',
        fieldType: $pb.PbFieldType.OU3)
    ..aOM<CustomStudyRequest_Cram>(7, _omitFieldNames ? '' : 'cram',
        subBuilder: CustomStudyRequest_Cram.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyRequest copyWith(void Function(CustomStudyRequest) updates) =>
      super.copyWith((message) => updates(message as CustomStudyRequest))
          as CustomStudyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CustomStudyRequest create() => CustomStudyRequest._();
  @$core.override
  CustomStudyRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CustomStudyRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomStudyRequest>(create);
  static CustomStudyRequest? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  CustomStudyRequest_Value whichValue() =>
      _CustomStudyRequest_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearValue() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get deckId => $_getI64(0);
  @$pb.TagNumber(1)
  set deckId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);

  /// increase new limit by x
  @$pb.TagNumber(2)
  $core.int get newLimitDelta => $_getIZ(1);
  @$pb.TagNumber(2)
  set newLimitDelta($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNewLimitDelta() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewLimitDelta() => $_clearField(2);

  /// increase review limit by x
  @$pb.TagNumber(3)
  $core.int get reviewLimitDelta => $_getIZ(2);
  @$pb.TagNumber(3)
  set reviewLimitDelta($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReviewLimitDelta() => $_has(2);
  @$pb.TagNumber(3)
  void clearReviewLimitDelta() => $_clearField(3);

  /// repeat cards forgotten in the last x days
  @$pb.TagNumber(4)
  $core.int get forgotDays => $_getIZ(3);
  @$pb.TagNumber(4)
  set forgotDays($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasForgotDays() => $_has(3);
  @$pb.TagNumber(4)
  void clearForgotDays() => $_clearField(4);

  /// review cards due in the next x days
  @$pb.TagNumber(5)
  $core.int get reviewAheadDays => $_getIZ(4);
  @$pb.TagNumber(5)
  set reviewAheadDays($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReviewAheadDays() => $_has(4);
  @$pb.TagNumber(5)
  void clearReviewAheadDays() => $_clearField(5);

  /// preview new cards added in the last x days
  @$pb.TagNumber(6)
  $core.int get previewDays => $_getIZ(5);
  @$pb.TagNumber(6)
  set previewDays($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPreviewDays() => $_has(5);
  @$pb.TagNumber(6)
  void clearPreviewDays() => $_clearField(6);

  @$pb.TagNumber(7)
  CustomStudyRequest_Cram get cram => $_getN(6);
  @$pb.TagNumber(7)
  set cram(CustomStudyRequest_Cram value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCram() => $_has(6);
  @$pb.TagNumber(7)
  void clearCram() => $_clearField(7);
  @$pb.TagNumber(7)
  CustomStudyRequest_Cram ensureCram() => $_ensure(6);
}

class SchedulingContext extends $pb.GeneratedMessage {
  factory SchedulingContext({
    $core.String? deckName,
    $fixnum.Int64? seed,
    $core.double? decay,
    $core.double? desiredRetention,
  }) {
    final result = create();
    if (deckName != null) result.deckName = deckName;
    if (seed != null) result.seed = seed;
    if (decay != null) result.decay = decay;
    if (desiredRetention != null) result.desiredRetention = desiredRetention;
    return result;
  }

  SchedulingContext._();

  factory SchedulingContext.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SchedulingContext.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SchedulingContext',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deckName')
    ..a<$fixnum.Int64>(2, _omitFieldNames ? '' : 'seed', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aD(3, _omitFieldNames ? '' : 'decay', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'desiredRetention',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingContext clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SchedulingContext copyWith(void Function(SchedulingContext) updates) =>
      super.copyWith((message) => updates(message as SchedulingContext))
          as SchedulingContext;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SchedulingContext create() => SchedulingContext._();
  @$core.override
  SchedulingContext createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SchedulingContext getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SchedulingContext>(create);
  static SchedulingContext? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deckName => $_getSZ(0);
  @$pb.TagNumber(1)
  set deckName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckName() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckName() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get seed => $_getI64(1);
  @$pb.TagNumber(2)
  set seed($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeed() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeed() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get decay => $_getN(2);
  @$pb.TagNumber(3)
  set decay($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDecay() => $_has(2);
  @$pb.TagNumber(3)
  void clearDecay() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get desiredRetention => $_getN(3);
  @$pb.TagNumber(4)
  set desiredRetention($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDesiredRetention() => $_has(3);
  @$pb.TagNumber(4)
  void clearDesiredRetention() => $_clearField(4);
}

class CustomStudyDefaultsRequest extends $pb.GeneratedMessage {
  factory CustomStudyDefaultsRequest({
    $fixnum.Int64? deckId,
  }) {
    final result = create();
    if (deckId != null) result.deckId = deckId;
    return result;
  }

  CustomStudyDefaultsRequest._();

  factory CustomStudyDefaultsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CustomStudyDefaultsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomStudyDefaultsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deckId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyDefaultsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyDefaultsRequest copyWith(
          void Function(CustomStudyDefaultsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as CustomStudyDefaultsRequest))
          as CustomStudyDefaultsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CustomStudyDefaultsRequest create() => CustomStudyDefaultsRequest._();
  @$core.override
  CustomStudyDefaultsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CustomStudyDefaultsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomStudyDefaultsRequest>(create);
  static CustomStudyDefaultsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deckId => $_getI64(0);
  @$pb.TagNumber(1)
  set deckId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckId() => $_clearField(1);
}

class CustomStudyDefaultsResponse_Tag extends $pb.GeneratedMessage {
  factory CustomStudyDefaultsResponse_Tag({
    $core.String? name,
    $core.bool? include,
    $core.bool? exclude,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (include != null) result.include = include;
    if (exclude != null) result.exclude = exclude;
    return result;
  }

  CustomStudyDefaultsResponse_Tag._();

  factory CustomStudyDefaultsResponse_Tag.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CustomStudyDefaultsResponse_Tag.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomStudyDefaultsResponse.Tag',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOB(2, _omitFieldNames ? '' : 'include')
    ..aOB(3, _omitFieldNames ? '' : 'exclude')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyDefaultsResponse_Tag clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyDefaultsResponse_Tag copyWith(
          void Function(CustomStudyDefaultsResponse_Tag) updates) =>
      super.copyWith(
              (message) => updates(message as CustomStudyDefaultsResponse_Tag))
          as CustomStudyDefaultsResponse_Tag;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CustomStudyDefaultsResponse_Tag create() =>
      CustomStudyDefaultsResponse_Tag._();
  @$core.override
  CustomStudyDefaultsResponse_Tag createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CustomStudyDefaultsResponse_Tag getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomStudyDefaultsResponse_Tag>(
          create);
  static CustomStudyDefaultsResponse_Tag? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get include => $_getBF(1);
  @$pb.TagNumber(2)
  set include($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInclude() => $_has(1);
  @$pb.TagNumber(2)
  void clearInclude() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get exclude => $_getBF(2);
  @$pb.TagNumber(3)
  set exclude($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExclude() => $_has(2);
  @$pb.TagNumber(3)
  void clearExclude() => $_clearField(3);
}

class CustomStudyDefaultsResponse extends $pb.GeneratedMessage {
  factory CustomStudyDefaultsResponse({
    $core.Iterable<CustomStudyDefaultsResponse_Tag>? tags,
    $core.int? extendNew,
    $core.int? extendReview,
    $core.int? availableNew,
    $core.int? availableReview,
    $core.int? availableNewInChildren,
    $core.int? availableReviewInChildren,
  }) {
    final result = create();
    if (tags != null) result.tags.addAll(tags);
    if (extendNew != null) result.extendNew = extendNew;
    if (extendReview != null) result.extendReview = extendReview;
    if (availableNew != null) result.availableNew = availableNew;
    if (availableReview != null) result.availableReview = availableReview;
    if (availableNewInChildren != null)
      result.availableNewInChildren = availableNewInChildren;
    if (availableReviewInChildren != null)
      result.availableReviewInChildren = availableReviewInChildren;
    return result;
  }

  CustomStudyDefaultsResponse._();

  factory CustomStudyDefaultsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CustomStudyDefaultsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomStudyDefaultsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..pPM<CustomStudyDefaultsResponse_Tag>(1, _omitFieldNames ? '' : 'tags',
        subBuilder: CustomStudyDefaultsResponse_Tag.create)
    ..aI(2, _omitFieldNames ? '' : 'extendNew', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'extendReview',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'availableNew',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'availableReview',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'availableNewInChildren',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'availableReviewInChildren',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyDefaultsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomStudyDefaultsResponse copyWith(
          void Function(CustomStudyDefaultsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CustomStudyDefaultsResponse))
          as CustomStudyDefaultsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CustomStudyDefaultsResponse create() =>
      CustomStudyDefaultsResponse._();
  @$core.override
  CustomStudyDefaultsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CustomStudyDefaultsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomStudyDefaultsResponse>(create);
  static CustomStudyDefaultsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CustomStudyDefaultsResponse_Tag> get tags => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get extendNew => $_getIZ(1);
  @$pb.TagNumber(2)
  set extendNew($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExtendNew() => $_has(1);
  @$pb.TagNumber(2)
  void clearExtendNew() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get extendReview => $_getIZ(2);
  @$pb.TagNumber(3)
  set extendReview($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExtendReview() => $_has(2);
  @$pb.TagNumber(3)
  void clearExtendReview() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get availableNew => $_getIZ(3);
  @$pb.TagNumber(4)
  set availableNew($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAvailableNew() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvailableNew() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get availableReview => $_getIZ(4);
  @$pb.TagNumber(5)
  set availableReview($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvailableReview() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvailableReview() => $_clearField(5);

  /// in v3, counts for children are provided separately
  @$pb.TagNumber(6)
  $core.int get availableNewInChildren => $_getIZ(5);
  @$pb.TagNumber(6)
  set availableNewInChildren($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAvailableNewInChildren() => $_has(5);
  @$pb.TagNumber(6)
  void clearAvailableNewInChildren() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get availableReviewInChildren => $_getIZ(6);
  @$pb.TagNumber(7)
  set availableReviewInChildren($core.int value) =>
      $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAvailableReviewInChildren() => $_has(6);
  @$pb.TagNumber(7)
  void clearAvailableReviewInChildren() => $_clearField(7);
}

class RepositionDefaultsResponse extends $pb.GeneratedMessage {
  factory RepositionDefaultsResponse({
    $core.bool? random,
    $core.bool? shift,
  }) {
    final result = create();
    if (random != null) result.random = random;
    if (shift != null) result.shift = shift;
    return result;
  }

  RepositionDefaultsResponse._();

  factory RepositionDefaultsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RepositionDefaultsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RepositionDefaultsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'random')
    ..aOB(2, _omitFieldNames ? '' : 'shift')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RepositionDefaultsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RepositionDefaultsResponse copyWith(
          void Function(RepositionDefaultsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as RepositionDefaultsResponse))
          as RepositionDefaultsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RepositionDefaultsResponse create() => RepositionDefaultsResponse._();
  @$core.override
  RepositionDefaultsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RepositionDefaultsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RepositionDefaultsResponse>(create);
  static RepositionDefaultsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get random => $_getBF(0);
  @$pb.TagNumber(1)
  set random($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRandom() => $_has(0);
  @$pb.TagNumber(1)
  void clearRandom() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get shift => $_getBF(1);
  @$pb.TagNumber(2)
  set shift($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShift() => $_has(1);
  @$pb.TagNumber(2)
  void clearShift() => $_clearField(2);
}

class ComputeFsrsParamsRequest extends $pb.GeneratedMessage {
  factory ComputeFsrsParamsRequest({
    $core.String? search,
    $core.Iterable<$core.double>? currentParams,
    $fixnum.Int64? ignoreRevlogsBeforeMs,
    $core.int? numOfRelearningSteps,
    $core.bool? healthCheck,
  }) {
    final result = create();
    if (search != null) result.search = search;
    if (currentParams != null) result.currentParams.addAll(currentParams);
    if (ignoreRevlogsBeforeMs != null)
      result.ignoreRevlogsBeforeMs = ignoreRevlogsBeforeMs;
    if (numOfRelearningSteps != null)
      result.numOfRelearningSteps = numOfRelearningSteps;
    if (healthCheck != null) result.healthCheck = healthCheck;
    return result;
  }

  ComputeFsrsParamsRequest._();

  factory ComputeFsrsParamsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComputeFsrsParamsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComputeFsrsParamsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'search')
    ..p<$core.double>(
        2, _omitFieldNames ? '' : 'currentParams', $pb.PbFieldType.KF)
    ..aInt64(3, _omitFieldNames ? '' : 'ignoreRevlogsBeforeMs')
    ..aI(4, _omitFieldNames ? '' : 'numOfRelearningSteps',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(5, _omitFieldNames ? '' : 'healthCheck')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeFsrsParamsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeFsrsParamsRequest copyWith(
          void Function(ComputeFsrsParamsRequest) updates) =>
      super.copyWith((message) => updates(message as ComputeFsrsParamsRequest))
          as ComputeFsrsParamsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComputeFsrsParamsRequest create() => ComputeFsrsParamsRequest._();
  @$core.override
  ComputeFsrsParamsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComputeFsrsParamsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComputeFsrsParamsRequest>(create);
  static ComputeFsrsParamsRequest? _defaultInstance;

  /// / The search used to gather cards for training
  @$pb.TagNumber(1)
  $core.String get search => $_getSZ(0);
  @$pb.TagNumber(1)
  set search($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSearch() => $_has(0);
  @$pb.TagNumber(1)
  void clearSearch() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.double> get currentParams => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get ignoreRevlogsBeforeMs => $_getI64(2);
  @$pb.TagNumber(3)
  set ignoreRevlogsBeforeMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIgnoreRevlogsBeforeMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearIgnoreRevlogsBeforeMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get numOfRelearningSteps => $_getIZ(3);
  @$pb.TagNumber(4)
  set numOfRelearningSteps($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNumOfRelearningSteps() => $_has(3);
  @$pb.TagNumber(4)
  void clearNumOfRelearningSteps() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get healthCheck => $_getBF(4);
  @$pb.TagNumber(5)
  set healthCheck($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHealthCheck() => $_has(4);
  @$pb.TagNumber(5)
  void clearHealthCheck() => $_clearField(5);
}

class ComputeFsrsParamsResponse extends $pb.GeneratedMessage {
  factory ComputeFsrsParamsResponse({
    $core.Iterable<$core.double>? params,
    $core.int? fsrsItems,
    $core.bool? healthCheckPassed,
  }) {
    final result = create();
    if (params != null) result.params.addAll(params);
    if (fsrsItems != null) result.fsrsItems = fsrsItems;
    if (healthCheckPassed != null) result.healthCheckPassed = healthCheckPassed;
    return result;
  }

  ComputeFsrsParamsResponse._();

  factory ComputeFsrsParamsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComputeFsrsParamsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComputeFsrsParamsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$core.double>(1, _omitFieldNames ? '' : 'params', $pb.PbFieldType.KF)
    ..aI(2, _omitFieldNames ? '' : 'fsrsItems', fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'healthCheckPassed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeFsrsParamsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeFsrsParamsResponse copyWith(
          void Function(ComputeFsrsParamsResponse) updates) =>
      super.copyWith((message) => updates(message as ComputeFsrsParamsResponse))
          as ComputeFsrsParamsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComputeFsrsParamsResponse create() => ComputeFsrsParamsResponse._();
  @$core.override
  ComputeFsrsParamsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComputeFsrsParamsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComputeFsrsParamsResponse>(create);
  static ComputeFsrsParamsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.double> get params => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get fsrsItems => $_getIZ(1);
  @$pb.TagNumber(2)
  set fsrsItems($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFsrsItems() => $_has(1);
  @$pb.TagNumber(2)
  void clearFsrsItems() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get healthCheckPassed => $_getBF(2);
  @$pb.TagNumber(3)
  set healthCheckPassed($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHealthCheckPassed() => $_has(2);
  @$pb.TagNumber(3)
  void clearHealthCheckPassed() => $_clearField(3);
}

class ComputeFsrsParamsFromItemsRequest extends $pb.GeneratedMessage {
  factory ComputeFsrsParamsFromItemsRequest({
    $core.Iterable<FsrsItem>? items,
  }) {
    final result = create();
    if (items != null) result.items.addAll(items);
    return result;
  }

  ComputeFsrsParamsFromItemsRequest._();

  factory ComputeFsrsParamsFromItemsRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComputeFsrsParamsFromItemsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComputeFsrsParamsFromItemsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..pPM<FsrsItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: FsrsItem.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeFsrsParamsFromItemsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeFsrsParamsFromItemsRequest copyWith(
          void Function(ComputeFsrsParamsFromItemsRequest) updates) =>
      super.copyWith((message) =>
              updates(message as ComputeFsrsParamsFromItemsRequest))
          as ComputeFsrsParamsFromItemsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComputeFsrsParamsFromItemsRequest create() =>
      ComputeFsrsParamsFromItemsRequest._();
  @$core.override
  ComputeFsrsParamsFromItemsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComputeFsrsParamsFromItemsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComputeFsrsParamsFromItemsRequest>(
          create);
  static ComputeFsrsParamsFromItemsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<FsrsItem> get items => $_getList(0);
}

class FsrsBenchmarkRequest extends $pb.GeneratedMessage {
  factory FsrsBenchmarkRequest({
    $core.Iterable<FsrsItem>? trainSet,
  }) {
    final result = create();
    if (trainSet != null) result.trainSet.addAll(trainSet);
    return result;
  }

  FsrsBenchmarkRequest._();

  factory FsrsBenchmarkRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FsrsBenchmarkRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FsrsBenchmarkRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..pPM<FsrsItem>(1, _omitFieldNames ? '' : 'trainSet',
        subBuilder: FsrsItem.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FsrsBenchmarkRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FsrsBenchmarkRequest copyWith(void Function(FsrsBenchmarkRequest) updates) =>
      super.copyWith((message) => updates(message as FsrsBenchmarkRequest))
          as FsrsBenchmarkRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FsrsBenchmarkRequest create() => FsrsBenchmarkRequest._();
  @$core.override
  FsrsBenchmarkRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FsrsBenchmarkRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FsrsBenchmarkRequest>(create);
  static FsrsBenchmarkRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<FsrsItem> get trainSet => $_getList(0);
}

class FsrsBenchmarkResponse extends $pb.GeneratedMessage {
  factory FsrsBenchmarkResponse({
    $core.Iterable<$core.double>? params,
  }) {
    final result = create();
    if (params != null) result.params.addAll(params);
    return result;
  }

  FsrsBenchmarkResponse._();

  factory FsrsBenchmarkResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FsrsBenchmarkResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FsrsBenchmarkResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$core.double>(1, _omitFieldNames ? '' : 'params', $pb.PbFieldType.KF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FsrsBenchmarkResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FsrsBenchmarkResponse copyWith(
          void Function(FsrsBenchmarkResponse) updates) =>
      super.copyWith((message) => updates(message as FsrsBenchmarkResponse))
          as FsrsBenchmarkResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FsrsBenchmarkResponse create() => FsrsBenchmarkResponse._();
  @$core.override
  FsrsBenchmarkResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FsrsBenchmarkResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FsrsBenchmarkResponse>(create);
  static FsrsBenchmarkResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.double> get params => $_getList(0);
}

class ExportDatasetRequest extends $pb.GeneratedMessage {
  factory ExportDatasetRequest({
    $core.int? minEntries,
    $core.String? targetPath,
  }) {
    final result = create();
    if (minEntries != null) result.minEntries = minEntries;
    if (targetPath != null) result.targetPath = targetPath;
    return result;
  }

  ExportDatasetRequest._();

  factory ExportDatasetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExportDatasetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportDatasetRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'minEntries', fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'targetPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportDatasetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportDatasetRequest copyWith(void Function(ExportDatasetRequest) updates) =>
      super.copyWith((message) => updates(message as ExportDatasetRequest))
          as ExportDatasetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExportDatasetRequest create() => ExportDatasetRequest._();
  @$core.override
  ExportDatasetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExportDatasetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportDatasetRequest>(create);
  static ExportDatasetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get minEntries => $_getIZ(0);
  @$pb.TagNumber(1)
  set minEntries($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMinEntries() => $_has(0);
  @$pb.TagNumber(1)
  void clearMinEntries() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetPath => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetPath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetPath() => $_clearField(2);
}

class FsrsItem extends $pb.GeneratedMessage {
  factory FsrsItem({
    $core.Iterable<FsrsReview>? reviews,
  }) {
    final result = create();
    if (reviews != null) result.reviews.addAll(reviews);
    return result;
  }

  FsrsItem._();

  factory FsrsItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FsrsItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FsrsItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..pPM<FsrsReview>(1, _omitFieldNames ? '' : 'reviews',
        subBuilder: FsrsReview.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FsrsItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FsrsItem copyWith(void Function(FsrsItem) updates) =>
      super.copyWith((message) => updates(message as FsrsItem)) as FsrsItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FsrsItem create() => FsrsItem._();
  @$core.override
  FsrsItem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FsrsItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FsrsItem>(create);
  static FsrsItem? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<FsrsReview> get reviews => $_getList(0);
}

class FsrsReview extends $pb.GeneratedMessage {
  factory FsrsReview({
    $core.int? rating,
    $core.int? deltaT,
  }) {
    final result = create();
    if (rating != null) result.rating = rating;
    if (deltaT != null) result.deltaT = deltaT;
    return result;
  }

  FsrsReview._();

  factory FsrsReview.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FsrsReview.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FsrsReview',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'rating', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'deltaT', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FsrsReview clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FsrsReview copyWith(void Function(FsrsReview) updates) =>
      super.copyWith((message) => updates(message as FsrsReview)) as FsrsReview;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FsrsReview create() => FsrsReview._();
  @$core.override
  FsrsReview createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FsrsReview getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FsrsReview>(create);
  static FsrsReview? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get rating => $_getIZ(0);
  @$pb.TagNumber(1)
  set rating($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRating() => $_has(0);
  @$pb.TagNumber(1)
  void clearRating() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get deltaT => $_getIZ(1);
  @$pb.TagNumber(2)
  set deltaT($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeltaT() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeltaT() => $_clearField(2);
}

class SimulateFsrsReviewRequest extends $pb.GeneratedMessage {
  factory SimulateFsrsReviewRequest({
    $core.Iterable<$core.double>? params,
    $core.double? desiredRetention,
    $core.int? deckSize,
    $core.int? daysToSimulate,
    $core.int? newLimit,
    $core.int? reviewLimit,
    $core.int? maxInterval,
    $core.String? search,
    $core.bool? newCardsIgnoreReviewLimit,
    $core.Iterable<$core.double>? easyDaysPercentages,
    $5.DeckConfig_Config_ReviewCardOrder? reviewOrder,
    $core.int? suspendAfterLapseCount,
    $core.double? historicalRetention,
    $core.int? learningStepCount,
    $core.int? relearningStepCount,
  }) {
    final result = create();
    if (params != null) result.params.addAll(params);
    if (desiredRetention != null) result.desiredRetention = desiredRetention;
    if (deckSize != null) result.deckSize = deckSize;
    if (daysToSimulate != null) result.daysToSimulate = daysToSimulate;
    if (newLimit != null) result.newLimit = newLimit;
    if (reviewLimit != null) result.reviewLimit = reviewLimit;
    if (maxInterval != null) result.maxInterval = maxInterval;
    if (search != null) result.search = search;
    if (newCardsIgnoreReviewLimit != null)
      result.newCardsIgnoreReviewLimit = newCardsIgnoreReviewLimit;
    if (easyDaysPercentages != null)
      result.easyDaysPercentages.addAll(easyDaysPercentages);
    if (reviewOrder != null) result.reviewOrder = reviewOrder;
    if (suspendAfterLapseCount != null)
      result.suspendAfterLapseCount = suspendAfterLapseCount;
    if (historicalRetention != null)
      result.historicalRetention = historicalRetention;
    if (learningStepCount != null) result.learningStepCount = learningStepCount;
    if (relearningStepCount != null)
      result.relearningStepCount = relearningStepCount;
    return result;
  }

  SimulateFsrsReviewRequest._();

  factory SimulateFsrsReviewRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SimulateFsrsReviewRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SimulateFsrsReviewRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$core.double>(1, _omitFieldNames ? '' : 'params', $pb.PbFieldType.KF)
    ..aD(2, _omitFieldNames ? '' : 'desiredRetention',
        fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'deckSize', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'daysToSimulate',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'newLimit', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'reviewLimit',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'maxInterval',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(8, _omitFieldNames ? '' : 'search')
    ..aOB(9, _omitFieldNames ? '' : 'newCardsIgnoreReviewLimit')
    ..p<$core.double>(
        10, _omitFieldNames ? '' : 'easyDaysPercentages', $pb.PbFieldType.KF)
    ..aE<$5.DeckConfig_Config_ReviewCardOrder>(
        11, _omitFieldNames ? '' : 'reviewOrder',
        enumValues: $5.DeckConfig_Config_ReviewCardOrder.values)
    ..aI(12, _omitFieldNames ? '' : 'suspendAfterLapseCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aD(13, _omitFieldNames ? '' : 'historicalRetention',
        fieldType: $pb.PbFieldType.OF)
    ..aI(14, _omitFieldNames ? '' : 'learningStepCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(15, _omitFieldNames ? '' : 'relearningStepCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimulateFsrsReviewRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimulateFsrsReviewRequest copyWith(
          void Function(SimulateFsrsReviewRequest) updates) =>
      super.copyWith((message) => updates(message as SimulateFsrsReviewRequest))
          as SimulateFsrsReviewRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimulateFsrsReviewRequest create() => SimulateFsrsReviewRequest._();
  @$core.override
  SimulateFsrsReviewRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SimulateFsrsReviewRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SimulateFsrsReviewRequest>(create);
  static SimulateFsrsReviewRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.double> get params => $_getList(0);

  @$pb.TagNumber(2)
  $core.double get desiredRetention => $_getN(1);
  @$pb.TagNumber(2)
  set desiredRetention($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDesiredRetention() => $_has(1);
  @$pb.TagNumber(2)
  void clearDesiredRetention() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get deckSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set deckSize($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDeckSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeckSize() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get daysToSimulate => $_getIZ(3);
  @$pb.TagNumber(4)
  set daysToSimulate($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDaysToSimulate() => $_has(3);
  @$pb.TagNumber(4)
  void clearDaysToSimulate() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get newLimit => $_getIZ(4);
  @$pb.TagNumber(5)
  set newLimit($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNewLimit() => $_has(4);
  @$pb.TagNumber(5)
  void clearNewLimit() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get reviewLimit => $_getIZ(5);
  @$pb.TagNumber(6)
  set reviewLimit($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasReviewLimit() => $_has(5);
  @$pb.TagNumber(6)
  void clearReviewLimit() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get maxInterval => $_getIZ(6);
  @$pb.TagNumber(7)
  set maxInterval($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMaxInterval() => $_has(6);
  @$pb.TagNumber(7)
  void clearMaxInterval() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get search => $_getSZ(7);
  @$pb.TagNumber(8)
  set search($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSearch() => $_has(7);
  @$pb.TagNumber(8)
  void clearSearch() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get newCardsIgnoreReviewLimit => $_getBF(8);
  @$pb.TagNumber(9)
  set newCardsIgnoreReviewLimit($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasNewCardsIgnoreReviewLimit() => $_has(8);
  @$pb.TagNumber(9)
  void clearNewCardsIgnoreReviewLimit() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<$core.double> get easyDaysPercentages => $_getList(9);

  @$pb.TagNumber(11)
  $5.DeckConfig_Config_ReviewCardOrder get reviewOrder => $_getN(10);
  @$pb.TagNumber(11)
  set reviewOrder($5.DeckConfig_Config_ReviewCardOrder value) =>
      $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasReviewOrder() => $_has(10);
  @$pb.TagNumber(11)
  void clearReviewOrder() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get suspendAfterLapseCount => $_getIZ(11);
  @$pb.TagNumber(12)
  set suspendAfterLapseCount($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSuspendAfterLapseCount() => $_has(11);
  @$pb.TagNumber(12)
  void clearSuspendAfterLapseCount() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.double get historicalRetention => $_getN(12);
  @$pb.TagNumber(13)
  set historicalRetention($core.double value) => $_setFloat(12, value);
  @$pb.TagNumber(13)
  $core.bool hasHistoricalRetention() => $_has(12);
  @$pb.TagNumber(13)
  void clearHistoricalRetention() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get learningStepCount => $_getIZ(13);
  @$pb.TagNumber(14)
  set learningStepCount($core.int value) => $_setUnsignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasLearningStepCount() => $_has(13);
  @$pb.TagNumber(14)
  void clearLearningStepCount() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get relearningStepCount => $_getIZ(14);
  @$pb.TagNumber(15)
  set relearningStepCount($core.int value) => $_setUnsignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasRelearningStepCount() => $_has(14);
  @$pb.TagNumber(15)
  void clearRelearningStepCount() => $_clearField(15);
}

class SimulateFsrsReviewResponse extends $pb.GeneratedMessage {
  factory SimulateFsrsReviewResponse({
    $core.Iterable<$core.double>? accumulatedKnowledgeAcquisition,
    $core.Iterable<$core.int>? dailyReviewCount,
    $core.Iterable<$core.int>? dailyNewCount,
    $core.Iterable<$core.double>? dailyTimeCost,
  }) {
    final result = create();
    if (accumulatedKnowledgeAcquisition != null)
      result.accumulatedKnowledgeAcquisition
          .addAll(accumulatedKnowledgeAcquisition);
    if (dailyReviewCount != null)
      result.dailyReviewCount.addAll(dailyReviewCount);
    if (dailyNewCount != null) result.dailyNewCount.addAll(dailyNewCount);
    if (dailyTimeCost != null) result.dailyTimeCost.addAll(dailyTimeCost);
    return result;
  }

  SimulateFsrsReviewResponse._();

  factory SimulateFsrsReviewResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SimulateFsrsReviewResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SimulateFsrsReviewResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$core.double>(
        1,
        _omitFieldNames ? '' : 'accumulatedKnowledgeAcquisition',
        $pb.PbFieldType.KF)
    ..p<$core.int>(
        2, _omitFieldNames ? '' : 'dailyReviewCount', $pb.PbFieldType.KU3)
    ..p<$core.int>(
        3, _omitFieldNames ? '' : 'dailyNewCount', $pb.PbFieldType.KU3)
    ..p<$core.double>(
        4, _omitFieldNames ? '' : 'dailyTimeCost', $pb.PbFieldType.KF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimulateFsrsReviewResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimulateFsrsReviewResponse copyWith(
          void Function(SimulateFsrsReviewResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SimulateFsrsReviewResponse))
          as SimulateFsrsReviewResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimulateFsrsReviewResponse create() => SimulateFsrsReviewResponse._();
  @$core.override
  SimulateFsrsReviewResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SimulateFsrsReviewResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SimulateFsrsReviewResponse>(create);
  static SimulateFsrsReviewResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.double> get accumulatedKnowledgeAcquisition => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get dailyReviewCount => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.int> get dailyNewCount => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.double> get dailyTimeCost => $_getList(3);
}

class SimulateFsrsWorkloadResponse extends $pb.GeneratedMessage {
  factory SimulateFsrsWorkloadResponse({
    $core.Iterable<$core.MapEntry<$core.int, $core.double>>? cost,
    $core.double? reviewlessEndMemorized,
    $core.Iterable<$core.MapEntry<$core.int, $core.double>>? memorized,
    $core.Iterable<$core.MapEntry<$core.int, $core.int>>? reviewCount,
  }) {
    final result = create();
    if (cost != null) result.cost.addEntries(cost);
    if (reviewlessEndMemorized != null)
      result.reviewlessEndMemorized = reviewlessEndMemorized;
    if (memorized != null) result.memorized.addEntries(memorized);
    if (reviewCount != null) result.reviewCount.addEntries(reviewCount);
    return result;
  }

  SimulateFsrsWorkloadResponse._();

  factory SimulateFsrsWorkloadResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SimulateFsrsWorkloadResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SimulateFsrsWorkloadResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..m<$core.int, $core.double>(1, _omitFieldNames ? '' : 'cost',
        entryClassName: 'SimulateFsrsWorkloadResponse.CostEntry',
        keyFieldType: $pb.PbFieldType.OU3,
        valueFieldType: $pb.PbFieldType.OF,
        packageName: const $pb.PackageName('anki.scheduler'))
    ..aD(2, _omitFieldNames ? '' : 'reviewlessEndMemorized',
        fieldType: $pb.PbFieldType.OF)
    ..m<$core.int, $core.double>(3, _omitFieldNames ? '' : 'memorized',
        entryClassName: 'SimulateFsrsWorkloadResponse.MemorizedEntry',
        keyFieldType: $pb.PbFieldType.OU3,
        valueFieldType: $pb.PbFieldType.OF,
        packageName: const $pb.PackageName('anki.scheduler'))
    ..m<$core.int, $core.int>(4, _omitFieldNames ? '' : 'reviewCount',
        entryClassName: 'SimulateFsrsWorkloadResponse.ReviewCountEntry',
        keyFieldType: $pb.PbFieldType.OU3,
        valueFieldType: $pb.PbFieldType.OU3,
        packageName: const $pb.PackageName('anki.scheduler'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimulateFsrsWorkloadResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimulateFsrsWorkloadResponse copyWith(
          void Function(SimulateFsrsWorkloadResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SimulateFsrsWorkloadResponse))
          as SimulateFsrsWorkloadResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimulateFsrsWorkloadResponse create() =>
      SimulateFsrsWorkloadResponse._();
  @$core.override
  SimulateFsrsWorkloadResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SimulateFsrsWorkloadResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SimulateFsrsWorkloadResponse>(create);
  static SimulateFsrsWorkloadResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, $core.double> get cost => $_getMap(0);

  @$pb.TagNumber(2)
  $core.double get reviewlessEndMemorized => $_getN(1);
  @$pb.TagNumber(2)
  set reviewlessEndMemorized($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReviewlessEndMemorized() => $_has(1);
  @$pb.TagNumber(2)
  void clearReviewlessEndMemorized() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.int, $core.double> get memorized => $_getMap(2);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.int, $core.int> get reviewCount => $_getMap(3);
}

class ComputeOptimalRetentionResponse extends $pb.GeneratedMessage {
  factory ComputeOptimalRetentionResponse({
    $core.double? optimalRetention,
  }) {
    final result = create();
    if (optimalRetention != null) result.optimalRetention = optimalRetention;
    return result;
  }

  ComputeOptimalRetentionResponse._();

  factory ComputeOptimalRetentionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComputeOptimalRetentionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComputeOptimalRetentionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'optimalRetention',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeOptimalRetentionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeOptimalRetentionResponse copyWith(
          void Function(ComputeOptimalRetentionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ComputeOptimalRetentionResponse))
          as ComputeOptimalRetentionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComputeOptimalRetentionResponse create() =>
      ComputeOptimalRetentionResponse._();
  @$core.override
  ComputeOptimalRetentionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComputeOptimalRetentionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComputeOptimalRetentionResponse>(
          create);
  static ComputeOptimalRetentionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get optimalRetention => $_getN(0);
  @$pb.TagNumber(1)
  set optimalRetention($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOptimalRetention() => $_has(0);
  @$pb.TagNumber(1)
  void clearOptimalRetention() => $_clearField(1);
}

class GetOptimalRetentionParametersRequest extends $pb.GeneratedMessage {
  factory GetOptimalRetentionParametersRequest({
    $core.String? search,
  }) {
    final result = create();
    if (search != null) result.search = search;
    return result;
  }

  GetOptimalRetentionParametersRequest._();

  factory GetOptimalRetentionParametersRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetOptimalRetentionParametersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetOptimalRetentionParametersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'search')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOptimalRetentionParametersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOptimalRetentionParametersRequest copyWith(
          void Function(GetOptimalRetentionParametersRequest) updates) =>
      super.copyWith((message) =>
              updates(message as GetOptimalRetentionParametersRequest))
          as GetOptimalRetentionParametersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetOptimalRetentionParametersRequest create() =>
      GetOptimalRetentionParametersRequest._();
  @$core.override
  GetOptimalRetentionParametersRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetOptimalRetentionParametersRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetOptimalRetentionParametersRequest>(create);
  static GetOptimalRetentionParametersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get search => $_getSZ(0);
  @$pb.TagNumber(1)
  set search($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSearch() => $_has(0);
  @$pb.TagNumber(1)
  void clearSearch() => $_clearField(1);
}

class GetOptimalRetentionParametersResponse extends $pb.GeneratedMessage {
  factory GetOptimalRetentionParametersResponse({
    $core.int? deckSize,
    $core.int? learnSpan,
    $core.double? maxCostPerday,
    $core.double? maxIvl,
    $core.Iterable<$core.double>? firstRatingProb,
    $core.Iterable<$core.double>? reviewRatingProb,
    $core.double? lossAversion,
    $core.int? learnLimit,
    $core.int? reviewLimit,
    $core.Iterable<$core.double>? learningStepTransitions,
    $core.Iterable<$core.double>? relearningStepTransitions,
    $core.Iterable<$core.double>? stateRatingCosts,
    $core.int? learningStepCount,
    $core.int? relearningStepCount,
  }) {
    final result = create();
    if (deckSize != null) result.deckSize = deckSize;
    if (learnSpan != null) result.learnSpan = learnSpan;
    if (maxCostPerday != null) result.maxCostPerday = maxCostPerday;
    if (maxIvl != null) result.maxIvl = maxIvl;
    if (firstRatingProb != null) result.firstRatingProb.addAll(firstRatingProb);
    if (reviewRatingProb != null)
      result.reviewRatingProb.addAll(reviewRatingProb);
    if (lossAversion != null) result.lossAversion = lossAversion;
    if (learnLimit != null) result.learnLimit = learnLimit;
    if (reviewLimit != null) result.reviewLimit = reviewLimit;
    if (learningStepTransitions != null)
      result.learningStepTransitions.addAll(learningStepTransitions);
    if (relearningStepTransitions != null)
      result.relearningStepTransitions.addAll(relearningStepTransitions);
    if (stateRatingCosts != null)
      result.stateRatingCosts.addAll(stateRatingCosts);
    if (learningStepCount != null) result.learningStepCount = learningStepCount;
    if (relearningStepCount != null)
      result.relearningStepCount = relearningStepCount;
    return result;
  }

  GetOptimalRetentionParametersResponse._();

  factory GetOptimalRetentionParametersResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetOptimalRetentionParametersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetOptimalRetentionParametersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'deckSize', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'learnSpan', fieldType: $pb.PbFieldType.OU3)
    ..aD(3, _omitFieldNames ? '' : 'maxCostPerday',
        fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'maxIvl', fieldType: $pb.PbFieldType.OF)
    ..p<$core.double>(
        5, _omitFieldNames ? '' : 'firstRatingProb', $pb.PbFieldType.KF)
    ..p<$core.double>(
        6, _omitFieldNames ? '' : 'reviewRatingProb', $pb.PbFieldType.KF)
    ..aD(7, _omitFieldNames ? '' : 'lossAversion',
        fieldType: $pb.PbFieldType.OF)
    ..aI(8, _omitFieldNames ? '' : 'learnLimit', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'reviewLimit',
        fieldType: $pb.PbFieldType.OU3)
    ..p<$core.double>(10, _omitFieldNames ? '' : 'learningStepTransitions',
        $pb.PbFieldType.KF)
    ..p<$core.double>(11, _omitFieldNames ? '' : 'relearningStepTransitions',
        $pb.PbFieldType.KF)
    ..p<$core.double>(
        12, _omitFieldNames ? '' : 'stateRatingCosts', $pb.PbFieldType.KF)
    ..aI(13, _omitFieldNames ? '' : 'learningStepCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(14, _omitFieldNames ? '' : 'relearningStepCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOptimalRetentionParametersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetOptimalRetentionParametersResponse copyWith(
          void Function(GetOptimalRetentionParametersResponse) updates) =>
      super.copyWith((message) =>
              updates(message as GetOptimalRetentionParametersResponse))
          as GetOptimalRetentionParametersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetOptimalRetentionParametersResponse create() =>
      GetOptimalRetentionParametersResponse._();
  @$core.override
  GetOptimalRetentionParametersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetOptimalRetentionParametersResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetOptimalRetentionParametersResponse>(create);
  static GetOptimalRetentionParametersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get deckSize => $_getIZ(0);
  @$pb.TagNumber(1)
  set deckSize($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeckSize() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeckSize() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get learnSpan => $_getIZ(1);
  @$pb.TagNumber(2)
  set learnSpan($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLearnSpan() => $_has(1);
  @$pb.TagNumber(2)
  void clearLearnSpan() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get maxCostPerday => $_getN(2);
  @$pb.TagNumber(3)
  set maxCostPerday($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaxCostPerday() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxCostPerday() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get maxIvl => $_getN(3);
  @$pb.TagNumber(4)
  set maxIvl($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxIvl() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxIvl() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.double> get firstRatingProb => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.double> get reviewRatingProb => $_getList(5);

  @$pb.TagNumber(7)
  $core.double get lossAversion => $_getN(6);
  @$pb.TagNumber(7)
  set lossAversion($core.double value) => $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLossAversion() => $_has(6);
  @$pb.TagNumber(7)
  void clearLossAversion() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get learnLimit => $_getIZ(7);
  @$pb.TagNumber(8)
  set learnLimit($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLearnLimit() => $_has(7);
  @$pb.TagNumber(8)
  void clearLearnLimit() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get reviewLimit => $_getIZ(8);
  @$pb.TagNumber(9)
  set reviewLimit($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasReviewLimit() => $_has(8);
  @$pb.TagNumber(9)
  void clearReviewLimit() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<$core.double> get learningStepTransitions => $_getList(9);

  @$pb.TagNumber(11)
  $pb.PbList<$core.double> get relearningStepTransitions => $_getList(10);

  @$pb.TagNumber(12)
  $pb.PbList<$core.double> get stateRatingCosts => $_getList(11);

  @$pb.TagNumber(13)
  $core.int get learningStepCount => $_getIZ(12);
  @$pb.TagNumber(13)
  set learningStepCount($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasLearningStepCount() => $_has(12);
  @$pb.TagNumber(13)
  void clearLearningStepCount() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get relearningStepCount => $_getIZ(13);
  @$pb.TagNumber(14)
  set relearningStepCount($core.int value) => $_setUnsignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasRelearningStepCount() => $_has(13);
  @$pb.TagNumber(14)
  void clearRelearningStepCount() => $_clearField(14);
}

class EvaluateParamsRequest extends $pb.GeneratedMessage {
  factory EvaluateParamsRequest({
    $core.String? search,
    $fixnum.Int64? ignoreRevlogsBeforeMs,
    $core.int? numOfRelearningSteps,
  }) {
    final result = create();
    if (search != null) result.search = search;
    if (ignoreRevlogsBeforeMs != null)
      result.ignoreRevlogsBeforeMs = ignoreRevlogsBeforeMs;
    if (numOfRelearningSteps != null)
      result.numOfRelearningSteps = numOfRelearningSteps;
    return result;
  }

  EvaluateParamsRequest._();

  factory EvaluateParamsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EvaluateParamsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EvaluateParamsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'search')
    ..aInt64(2, _omitFieldNames ? '' : 'ignoreRevlogsBeforeMs')
    ..aI(3, _omitFieldNames ? '' : 'numOfRelearningSteps',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EvaluateParamsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EvaluateParamsRequest copyWith(
          void Function(EvaluateParamsRequest) updates) =>
      super.copyWith((message) => updates(message as EvaluateParamsRequest))
          as EvaluateParamsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvaluateParamsRequest create() => EvaluateParamsRequest._();
  @$core.override
  EvaluateParamsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EvaluateParamsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EvaluateParamsRequest>(create);
  static EvaluateParamsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get search => $_getSZ(0);
  @$pb.TagNumber(1)
  set search($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSearch() => $_has(0);
  @$pb.TagNumber(1)
  void clearSearch() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get ignoreRevlogsBeforeMs => $_getI64(1);
  @$pb.TagNumber(2)
  set ignoreRevlogsBeforeMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIgnoreRevlogsBeforeMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearIgnoreRevlogsBeforeMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get numOfRelearningSteps => $_getIZ(2);
  @$pb.TagNumber(3)
  set numOfRelearningSteps($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNumOfRelearningSteps() => $_has(2);
  @$pb.TagNumber(3)
  void clearNumOfRelearningSteps() => $_clearField(3);
}

class EvaluateParamsLegacyRequest extends $pb.GeneratedMessage {
  factory EvaluateParamsLegacyRequest({
    $core.Iterable<$core.double>? params,
    $core.String? search,
    $fixnum.Int64? ignoreRevlogsBeforeMs,
  }) {
    final result = create();
    if (params != null) result.params.addAll(params);
    if (search != null) result.search = search;
    if (ignoreRevlogsBeforeMs != null)
      result.ignoreRevlogsBeforeMs = ignoreRevlogsBeforeMs;
    return result;
  }

  EvaluateParamsLegacyRequest._();

  factory EvaluateParamsLegacyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EvaluateParamsLegacyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EvaluateParamsLegacyRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..p<$core.double>(1, _omitFieldNames ? '' : 'params', $pb.PbFieldType.KF)
    ..aOS(2, _omitFieldNames ? '' : 'search')
    ..aInt64(3, _omitFieldNames ? '' : 'ignoreRevlogsBeforeMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EvaluateParamsLegacyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EvaluateParamsLegacyRequest copyWith(
          void Function(EvaluateParamsLegacyRequest) updates) =>
      super.copyWith(
              (message) => updates(message as EvaluateParamsLegacyRequest))
          as EvaluateParamsLegacyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvaluateParamsLegacyRequest create() =>
      EvaluateParamsLegacyRequest._();
  @$core.override
  EvaluateParamsLegacyRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EvaluateParamsLegacyRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EvaluateParamsLegacyRequest>(create);
  static EvaluateParamsLegacyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.double> get params => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get search => $_getSZ(1);
  @$pb.TagNumber(2)
  set search($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSearch() => $_has(1);
  @$pb.TagNumber(2)
  void clearSearch() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get ignoreRevlogsBeforeMs => $_getI64(2);
  @$pb.TagNumber(3)
  set ignoreRevlogsBeforeMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIgnoreRevlogsBeforeMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearIgnoreRevlogsBeforeMs() => $_clearField(3);
}

class EvaluateParamsResponse extends $pb.GeneratedMessage {
  factory EvaluateParamsResponse({
    $core.double? logLoss,
    $core.double? rmseBins,
  }) {
    final result = create();
    if (logLoss != null) result.logLoss = logLoss;
    if (rmseBins != null) result.rmseBins = rmseBins;
    return result;
  }

  EvaluateParamsResponse._();

  factory EvaluateParamsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EvaluateParamsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EvaluateParamsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'logLoss', fieldType: $pb.PbFieldType.OF)
    ..aD(2, _omitFieldNames ? '' : 'rmseBins', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EvaluateParamsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EvaluateParamsResponse copyWith(
          void Function(EvaluateParamsResponse) updates) =>
      super.copyWith((message) => updates(message as EvaluateParamsResponse))
          as EvaluateParamsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EvaluateParamsResponse create() => EvaluateParamsResponse._();
  @$core.override
  EvaluateParamsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EvaluateParamsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EvaluateParamsResponse>(create);
  static EvaluateParamsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get logLoss => $_getN(0);
  @$pb.TagNumber(1)
  set logLoss($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLogLoss() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogLoss() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get rmseBins => $_getN(1);
  @$pb.TagNumber(2)
  set rmseBins($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRmseBins() => $_has(1);
  @$pb.TagNumber(2)
  void clearRmseBins() => $_clearField(2);
}

class ComputeMemoryStateResponse extends $pb.GeneratedMessage {
  factory ComputeMemoryStateResponse({
    $0.FsrsMemoryState? state,
    $core.double? desiredRetention,
    $core.double? decay,
  }) {
    final result = create();
    if (state != null) result.state = state;
    if (desiredRetention != null) result.desiredRetention = desiredRetention;
    if (decay != null) result.decay = decay;
    return result;
  }

  ComputeMemoryStateResponse._();

  factory ComputeMemoryStateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComputeMemoryStateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComputeMemoryStateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aOM<$0.FsrsMemoryState>(1, _omitFieldNames ? '' : 'state',
        subBuilder: $0.FsrsMemoryState.create)
    ..aD(2, _omitFieldNames ? '' : 'desiredRetention',
        fieldType: $pb.PbFieldType.OF)
    ..aD(3, _omitFieldNames ? '' : 'decay', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeMemoryStateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeMemoryStateResponse copyWith(
          void Function(ComputeMemoryStateResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ComputeMemoryStateResponse))
          as ComputeMemoryStateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComputeMemoryStateResponse create() => ComputeMemoryStateResponse._();
  @$core.override
  ComputeMemoryStateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComputeMemoryStateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComputeMemoryStateResponse>(create);
  static ComputeMemoryStateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $0.FsrsMemoryState get state => $_getN(0);
  @$pb.TagNumber(1)
  set state($0.FsrsMemoryState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.FsrsMemoryState ensureState() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.double get desiredRetention => $_getN(1);
  @$pb.TagNumber(2)
  set desiredRetention($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDesiredRetention() => $_has(1);
  @$pb.TagNumber(2)
  void clearDesiredRetention() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get decay => $_getN(2);
  @$pb.TagNumber(3)
  set decay($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDecay() => $_has(2);
  @$pb.TagNumber(3)
  void clearDecay() => $_clearField(3);
}

class FuzzDeltaRequest extends $pb.GeneratedMessage {
  factory FuzzDeltaRequest({
    $fixnum.Int64? cardId,
    $core.int? interval,
  }) {
    final result = create();
    if (cardId != null) result.cardId = cardId;
    if (interval != null) result.interval = interval;
    return result;
  }

  FuzzDeltaRequest._();

  factory FuzzDeltaRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FuzzDeltaRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FuzzDeltaRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'cardId')
    ..aI(2, _omitFieldNames ? '' : 'interval', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FuzzDeltaRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FuzzDeltaRequest copyWith(void Function(FuzzDeltaRequest) updates) =>
      super.copyWith((message) => updates(message as FuzzDeltaRequest))
          as FuzzDeltaRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FuzzDeltaRequest create() => FuzzDeltaRequest._();
  @$core.override
  FuzzDeltaRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FuzzDeltaRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FuzzDeltaRequest>(create);
  static FuzzDeltaRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get cardId => $_getI64(0);
  @$pb.TagNumber(1)
  set cardId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCardId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCardId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get interval => $_getIZ(1);
  @$pb.TagNumber(2)
  set interval($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInterval() => $_has(1);
  @$pb.TagNumber(2)
  void clearInterval() => $_clearField(2);
}

class FuzzDeltaResponse extends $pb.GeneratedMessage {
  factory FuzzDeltaResponse({
    $core.int? deltaDays,
  }) {
    final result = create();
    if (deltaDays != null) result.deltaDays = deltaDays;
    return result;
  }

  FuzzDeltaResponse._();

  factory FuzzDeltaResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FuzzDeltaResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FuzzDeltaResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'anki.scheduler'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'deltaDays', fieldType: $pb.PbFieldType.OS3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FuzzDeltaResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FuzzDeltaResponse copyWith(void Function(FuzzDeltaResponse) updates) =>
      super.copyWith((message) => updates(message as FuzzDeltaResponse))
          as FuzzDeltaResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FuzzDeltaResponse create() => FuzzDeltaResponse._();
  @$core.override
  FuzzDeltaResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FuzzDeltaResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FuzzDeltaResponse>(create);
  static FuzzDeltaResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get deltaDays => $_getIZ(0);
  @$pb.TagNumber(1)
  set deltaDays($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeltaDays() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeltaDays() => $_clearField(1);
}

class SchedulerServiceApi {
  final $pb.RpcClient _client;

  SchedulerServiceApi(this._client);

  $async.Future<QueuedCards> getQueuedCards(
          $pb.ClientContext? ctx, GetQueuedCardsRequest request) =>
      _client.invoke<QueuedCards>(
          ctx, 'SchedulerService', 'GetQueuedCards', request, QueuedCards());
  $async.Future<$2.OpChanges> answerCard(
          $pb.ClientContext? ctx, CardAnswer request) =>
      _client.invoke<$2.OpChanges>(
          ctx, 'SchedulerService', 'AnswerCard', request, $2.OpChanges());
  $async.Future<SchedTimingTodayResponse> schedTimingToday(
          $pb.ClientContext? ctx, $3.Empty request) =>
      _client.invoke<SchedTimingTodayResponse>(ctx, 'SchedulerService',
          'SchedTimingToday', request, SchedTimingTodayResponse());
  $async.Future<$3.String> studiedToday(
          $pb.ClientContext? ctx, $3.Empty request) =>
      _client.invoke<$3.String>(
          ctx, 'SchedulerService', 'StudiedToday', request, $3.String());
  $async.Future<$3.String> studiedTodayMessage(
          $pb.ClientContext? ctx, StudiedTodayMessageRequest request) =>
      _client.invoke<$3.String>(
          ctx, 'SchedulerService', 'StudiedTodayMessage', request, $3.String());
  $async.Future<$3.Empty> updateStats(
          $pb.ClientContext? ctx, UpdateStatsRequest request) =>
      _client.invoke<$3.Empty>(
          ctx, 'SchedulerService', 'UpdateStats', request, $3.Empty());
  $async.Future<$3.Empty> extendLimits(
          $pb.ClientContext? ctx, ExtendLimitsRequest request) =>
      _client.invoke<$3.Empty>(
          ctx, 'SchedulerService', 'ExtendLimits', request, $3.Empty());
  $async.Future<CountsForDeckTodayResponse> countsForDeckToday(
          $pb.ClientContext? ctx, $4.DeckId request) =>
      _client.invoke<CountsForDeckTodayResponse>(ctx, 'SchedulerService',
          'CountsForDeckToday', request, CountsForDeckTodayResponse());
  $async.Future<CongratsInfoResponse> congratsInfo(
          $pb.ClientContext? ctx, $3.Empty request) =>
      _client.invoke<CongratsInfoResponse>(ctx, 'SchedulerService',
          'CongratsInfo', request, CongratsInfoResponse());
  $async.Future<$2.OpChanges> restoreBuriedAndSuspendedCards(
          $pb.ClientContext? ctx, $0.CardIds request) =>
      _client.invoke<$2.OpChanges>(ctx, 'SchedulerService',
          'RestoreBuriedAndSuspendedCards', request, $2.OpChanges());
  $async.Future<$2.OpChanges> unburyDeck(
          $pb.ClientContext? ctx, UnburyDeckRequest request) =>
      _client.invoke<$2.OpChanges>(
          ctx, 'SchedulerService', 'UnburyDeck', request, $2.OpChanges());
  $async.Future<$2.OpChangesWithCount> buryOrSuspendCards(
          $pb.ClientContext? ctx, BuryOrSuspendCardsRequest request) =>
      _client.invoke<$2.OpChangesWithCount>(ctx, 'SchedulerService',
          'BuryOrSuspendCards', request, $2.OpChangesWithCount());
  $async.Future<$2.OpChanges> emptyFilteredDeck(
          $pb.ClientContext? ctx, $4.DeckId request) =>
      _client.invoke<$2.OpChanges>(ctx, 'SchedulerService', 'EmptyFilteredDeck',
          request, $2.OpChanges());
  $async.Future<$2.OpChangesWithCount> rebuildFilteredDeck(
          $pb.ClientContext? ctx, $4.DeckId request) =>
      _client.invoke<$2.OpChangesWithCount>(ctx, 'SchedulerService',
          'RebuildFilteredDeck', request, $2.OpChangesWithCount());
  $async.Future<$2.OpChanges> scheduleCardsAsNew(
          $pb.ClientContext? ctx, ScheduleCardsAsNewRequest request) =>
      _client.invoke<$2.OpChanges>(ctx, 'SchedulerService',
          'ScheduleCardsAsNew', request, $2.OpChanges());
  $async.Future<ScheduleCardsAsNewDefaultsResponse> scheduleCardsAsNewDefaults(
          $pb.ClientContext? ctx, ScheduleCardsAsNewDefaultsRequest request) =>
      _client.invoke<ScheduleCardsAsNewDefaultsResponse>(
          ctx,
          'SchedulerService',
          'ScheduleCardsAsNewDefaults',
          request,
          ScheduleCardsAsNewDefaultsResponse());
  $async.Future<$2.OpChanges> setDueDate(
          $pb.ClientContext? ctx, SetDueDateRequest request) =>
      _client.invoke<$2.OpChanges>(
          ctx, 'SchedulerService', 'SetDueDate', request, $2.OpChanges());
  $async.Future<$2.OpChanges> gradeNow(
          $pb.ClientContext? ctx, GradeNowRequest request) =>
      _client.invoke<$2.OpChanges>(
          ctx, 'SchedulerService', 'GradeNow', request, $2.OpChanges());
  $async.Future<$2.OpChangesWithCount> sortCards(
          $pb.ClientContext? ctx, SortCardsRequest request) =>
      _client.invoke<$2.OpChangesWithCount>(ctx, 'SchedulerService',
          'SortCards', request, $2.OpChangesWithCount());
  $async.Future<$2.OpChangesWithCount> sortDeck(
          $pb.ClientContext? ctx, SortDeckRequest request) =>
      _client.invoke<$2.OpChangesWithCount>(ctx, 'SchedulerService', 'SortDeck',
          request, $2.OpChangesWithCount());
  $async.Future<SchedulingStates> getSchedulingStates(
          $pb.ClientContext? ctx, $0.CardId request) =>
      _client.invoke<SchedulingStates>(ctx, 'SchedulerService',
          'GetSchedulingStates', request, SchedulingStates());
  $async.Future<$3.StringList> describeNextStates(
          $pb.ClientContext? ctx, SchedulingStates request) =>
      _client.invoke<$3.StringList>(ctx, 'SchedulerService',
          'DescribeNextStates', request, $3.StringList());
  $async.Future<$3.Bool> stateIsLeech(
          $pb.ClientContext? ctx, SchedulingState request) =>
      _client.invoke<$3.Bool>(
          ctx, 'SchedulerService', 'StateIsLeech', request, $3.Bool());
  $async.Future<$3.Empty> upgradeScheduler(
          $pb.ClientContext? ctx, $3.Empty request) =>
      _client.invoke<$3.Empty>(
          ctx, 'SchedulerService', 'UpgradeScheduler', request, $3.Empty());
  $async.Future<$2.OpChanges> customStudy(
          $pb.ClientContext? ctx, CustomStudyRequest request) =>
      _client.invoke<$2.OpChanges>(
          ctx, 'SchedulerService', 'CustomStudy', request, $2.OpChanges());
  $async.Future<CustomStudyDefaultsResponse> customStudyDefaults(
          $pb.ClientContext? ctx, CustomStudyDefaultsRequest request) =>
      _client.invoke<CustomStudyDefaultsResponse>(ctx, 'SchedulerService',
          'CustomStudyDefaults', request, CustomStudyDefaultsResponse());
  $async.Future<RepositionDefaultsResponse> repositionDefaults(
          $pb.ClientContext? ctx, $3.Empty request) =>
      _client.invoke<RepositionDefaultsResponse>(ctx, 'SchedulerService',
          'RepositionDefaults', request, RepositionDefaultsResponse());
  $async.Future<ComputeFsrsParamsResponse> computeFsrsParams(
          $pb.ClientContext? ctx, ComputeFsrsParamsRequest request) =>
      _client.invoke<ComputeFsrsParamsResponse>(ctx, 'SchedulerService',
          'ComputeFsrsParams', request, ComputeFsrsParamsResponse());
  $async.Future<GetOptimalRetentionParametersResponse>
      getOptimalRetentionParameters($pb.ClientContext? ctx,
              GetOptimalRetentionParametersRequest request) =>
          _client.invoke<GetOptimalRetentionParametersResponse>(
              ctx,
              'SchedulerService',
              'GetOptimalRetentionParameters',
              request,
              GetOptimalRetentionParametersResponse());
  $async.Future<ComputeOptimalRetentionResponse> computeOptimalRetention(
          $pb.ClientContext? ctx, SimulateFsrsReviewRequest request) =>
      _client.invoke<ComputeOptimalRetentionResponse>(
          ctx,
          'SchedulerService',
          'ComputeOptimalRetention',
          request,
          ComputeOptimalRetentionResponse());
  $async.Future<SimulateFsrsReviewResponse> simulateFsrsReview(
          $pb.ClientContext? ctx, SimulateFsrsReviewRequest request) =>
      _client.invoke<SimulateFsrsReviewResponse>(ctx, 'SchedulerService',
          'SimulateFsrsReview', request, SimulateFsrsReviewResponse());
  $async.Future<SimulateFsrsWorkloadResponse> simulateFsrsWorkload(
          $pb.ClientContext? ctx, SimulateFsrsReviewRequest request) =>
      _client.invoke<SimulateFsrsWorkloadResponse>(ctx, 'SchedulerService',
          'SimulateFsrsWorkload', request, SimulateFsrsWorkloadResponse());
  $async.Future<EvaluateParamsResponse> evaluateParams(
          $pb.ClientContext? ctx, EvaluateParamsRequest request) =>
      _client.invoke<EvaluateParamsResponse>(ctx, 'SchedulerService',
          'EvaluateParams', request, EvaluateParamsResponse());
  $async.Future<EvaluateParamsResponse> evaluateParamsLegacy(
          $pb.ClientContext? ctx, EvaluateParamsLegacyRequest request) =>
      _client.invoke<EvaluateParamsResponse>(ctx, 'SchedulerService',
          'EvaluateParamsLegacy', request, EvaluateParamsResponse());
  $async.Future<ComputeMemoryStateResponse> computeMemoryState(
          $pb.ClientContext? ctx, $0.CardId request) =>
      _client.invoke<ComputeMemoryStateResponse>(ctx, 'SchedulerService',
          'ComputeMemoryState', request, ComputeMemoryStateResponse());

  /// The number of days the calculated interval was fuzzed by on the previous
  /// review (if any). Utilized by the FSRS add-on.
  $async.Future<FuzzDeltaResponse> fuzzDelta(
          $pb.ClientContext? ctx, FuzzDeltaRequest request) =>
      _client.invoke<FuzzDeltaResponse>(
          ctx, 'SchedulerService', 'FuzzDelta', request, FuzzDeltaResponse());
}

/// Implicitly includes any of the above methods that are not listed in the
/// backend service.
class BackendSchedulerServiceApi {
  final $pb.RpcClient _client;

  BackendSchedulerServiceApi(this._client);

  $async.Future<ComputeFsrsParamsResponse> computeFsrsParamsFromItems(
          $pb.ClientContext? ctx, ComputeFsrsParamsFromItemsRequest request) =>
      _client.invoke<ComputeFsrsParamsResponse>(ctx, 'BackendSchedulerService',
          'ComputeFsrsParamsFromItems', request, ComputeFsrsParamsResponse());

  /// Generates parameters used for FSRS's scheduler benchmarks.
  $async.Future<FsrsBenchmarkResponse> fsrsBenchmark(
          $pb.ClientContext? ctx, FsrsBenchmarkRequest request) =>
      _client.invoke<FsrsBenchmarkResponse>(ctx, 'BackendSchedulerService',
          'FsrsBenchmark', request, FsrsBenchmarkResponse());

  /// Used for exporting revlogs for algorithm research.
  $async.Future<$3.Empty> exportDataset(
          $pb.ClientContext? ctx, ExportDatasetRequest request) =>
      _client.invoke<$3.Empty>(
          ctx, 'BackendSchedulerService', 'ExportDataset', request, $3.Empty());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
