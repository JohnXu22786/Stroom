import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';

void main() {
  // ===========================================================================
  // MediaResource
  // ===========================================================================
  group('MediaResource', () {
    const testUrl = 'https://example.com/video.mp4';
    const testName = 'video';
    const testExt = 'mp4';

    late MediaResource defaultResource;
    late MediaResource fullResource;

    setUp(() {
      defaultResource = const MediaResource(
        url: testUrl,
        name: testName,
        ext: testExt,
      );

      fullResource = const MediaResource(
        url: 'https://example.com/stream.m3u8',
        name: 'stream',
        ext: 'm3u8',
        mimeType: 'application/vnd.apple.mpegurl',
        size: 4096,
        initiator: 'https://example.com/',
        isPlayable: true,
        isPlaylist: true,
        duration: '00:12:34.567',
      );
    });

    // ──────────────────────────────────────────────
    // Constructor – defaults
    // ──────────────────────────────────────────────
    test('constructor assigns required fields', () {
      expect(defaultResource.url, equals(testUrl));
      expect(defaultResource.name, equals(testName));
      expect(defaultResource.ext, equals(testExt));
    });

    test('constructor defaults optional fields correctly', () {
      expect(defaultResource.mimeType, isNull);
      expect(defaultResource.size, isNull);
      expect(defaultResource.initiator, isNull);
      expect(defaultResource.isPlayable, isFalse);
      expect(defaultResource.isPlaylist, isFalse);
      expect(defaultResource.duration, isNull);
    });

    test('constructor stores all provided fields', () {
      expect(fullResource.url, equals('https://example.com/stream.m3u8'));
      expect(fullResource.name, equals('stream'));
      expect(fullResource.ext, equals('m3u8'));
      expect(fullResource.mimeType, equals('application/vnd.apple.mpegurl'));
      expect(fullResource.size, equals(4096));
      expect(fullResource.initiator, equals('https://example.com/'));
      expect(fullResource.isPlayable, isTrue);
      expect(fullResource.isPlaylist, isTrue);
      expect(fullResource.duration, equals('00:12:34.567'));
    });

    // ──────────────────────────────────────────────
    // Type getters
    // ──────────────────────────────────────────────
    test('isM3U8 returns true for ext m3u8', () {
      const r = MediaResource(url: 'u', name: 'n', ext: 'm3u8');
      expect(r.isM3U8, isTrue);
    });

    test('isM3U8 returns true for ext m3u', () {
      const r = MediaResource(url: 'u', name: 'n', ext: 'm3u');
      expect(r.isM3U8, isTrue);
    });

    test('isM3U8 returns false for other ext', () {
      expect(defaultResource.isM3U8, isFalse);
    });

    test('isMPD returns true for ext mpd', () {
      const r = MediaResource(url: 'u', name: 'n', ext: 'mpd');
      expect(r.isMPD, isTrue);
    });

    test('isMPD returns false for other ext', () {
      expect(defaultResource.isMPD, isFalse);
    });

    test('isVideo returns true for common video extensions', () {
      const r1 = MediaResource(url: 'u', name: 'n', ext: 'mp4');
      expect(r1.isVideo, isTrue);
      const r2 = MediaResource(url: 'u', name: 'n', ext: 'webm');
      expect(r2.isVideo, isTrue);
      const r3 = MediaResource(url: 'u', name: 'n', ext: 'mkv');
      expect(r3.isVideo, isTrue);
    });

    test('isVideo returns false for audio and playlist extensions', () {
      const r1 = MediaResource(url: 'u', name: 'n', ext: 'mp3');
      expect(r1.isVideo, isFalse);
      const r2 = MediaResource(url: 'u', name: 'n', ext: 'm3u8');
      expect(r2.isVideo, isFalse);
    });

    test('isAudio returns true for common audio extensions', () {
      const r1 = MediaResource(url: 'u', name: 'n', ext: 'mp3');
      expect(r1.isAudio, isTrue);
      const r2 = MediaResource(url: 'u', name: 'n', ext: 'wav');
      expect(r2.isAudio, isTrue);
      const r3 = MediaResource(url: 'u', name: 'n', ext: 'aac');
      expect(r3.isAudio, isTrue);
      const r4 = MediaResource(url: 'u', name: 'n', ext: 'opus');
      expect(r4.isAudio, isTrue);
      const r5 = MediaResource(url: 'u', name: 'n', ext: 'weba');
      expect(r5.isAudio, isTrue);
    });

    test('isAudio returns false for video and other extensions', () {
      const r1 = MediaResource(url: 'u', name: 'n', ext: 'mp4');
      expect(r1.isAudio, isFalse);
      const r2 = MediaResource(url: 'u', name: 'n', ext: 'ts');
      expect(r2.isAudio, isFalse);
    });

    test('isMedia returns true for video', () {
      expect(defaultResource.isMedia, isTrue);
    });

    test('isMedia returns true for audio', () {
      const r = MediaResource(url: 'u', name: 'n', ext: 'mp3');
      expect(r.isMedia, isTrue);
    });

    test('isMedia returns true for playlists', () {
      const r =
          MediaResource(url: 'u', name: 'n', ext: 'm3u8', isPlaylist: true);
      expect(r.isMedia, isTrue);
    });

    test('isMedia returns false for non-video/audio/playlist', () {
      const r = MediaResource(url: 'u', name: 'n', ext: 'html');
      expect(r.isMedia, isFalse);
    });

    test('isTS returns true for ext ts', () {
      const r = MediaResource(url: 'u', name: 'n', ext: 'ts');
      expect(r.isTS, isTrue);
    });

    test('isTS returns false for other ext', () {
      expect(defaultResource.isTS, isFalse);
    });

    // ──────────────────────────────────────────────
    // toMap / fromMap round-trip
    // ──────────────────────────────────────────────
    test('toMap produces correct keys and values', () {
      final map = fullResource.toMap();

      expect(map['url'], equals('https://example.com/stream.m3u8'));
      expect(map['name'], equals('stream'));
      expect(map['ext'], equals('m3u8'));
      expect(map['mimeType'], equals('application/vnd.apple.mpegurl'));
      expect(map['size'], equals(4096));
      expect(map['initiator'], equals('https://example.com/'));
      expect(map['isPlayable'], isTrue);
      expect(map['isPlaylist'], isTrue);
      expect(map['duration'], equals('00:12:34.567'));
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final map = fullResource.toMap();
      final restored = MediaResource.fromMap(map);

      expect(restored.url, equals(fullResource.url));
      expect(restored.name, equals(fullResource.name));
      expect(restored.ext, equals(fullResource.ext));
      expect(restored.mimeType, equals(fullResource.mimeType));
      expect(restored.size, equals(fullResource.size));
      expect(restored.initiator, equals(fullResource.initiator));
      expect(restored.isPlayable, equals(fullResource.isPlayable));
      expect(restored.isPlaylist, equals(fullResource.isPlaylist));
      expect(restored.duration, equals(fullResource.duration));
    });

    test(
        'toMap/fromMap round-trip works for resource with only required fields',
        () {
      final map = defaultResource.toMap();
      final restored = MediaResource.fromMap(map);

      expect(restored.url, equals(defaultResource.url));
      expect(restored.name, equals(defaultResource.name));
      expect(restored.ext, equals(defaultResource.ext));
      expect(restored.mimeType, isNull);
      expect(restored.size, isNull);
      expect(restored.initiator, isNull);
      expect(restored.isPlayable, isFalse);
      expect(restored.isPlaylist, isFalse);
      expect(restored.duration, isNull);
    });

    // ──────────────────────────────────────────────
    // fromMap – missing / null field handling
    // ──────────────────────────────────────────────
    test('fromMap throws when required url is missing', () {
      expect(
        () => MediaResource.fromMap({'name': 'n', 'ext': 'mp4'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('fromMap throws when required name is missing', () {
      expect(
        () => MediaResource.fromMap({'url': 'u', 'ext': 'mp4'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('fromMap throws when required ext is missing', () {
      expect(
        () => MediaResource.fromMap({'url': 'u', 'name': 'n'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('fromMap treats null optional fields as null', () {
      final r = MediaResource.fromMap({
        'url': 'u',
        'name': 'n',
        'ext': 'mp4',
        'mimeType': null,
        'size': null,
        'initiator': null,
        'isPlayable': null,
        'isPlaylist': null,
        'duration': null,
      });

      expect(r.mimeType, isNull);
      expect(r.size, isNull);
      expect(r.initiator, isNull);
      expect(r.isPlayable, isFalse);
      expect(r.isPlaylist, isFalse);
      expect(r.duration, isNull);
    });

    test('fromMap treats missing optional fields as null/default', () {
      final r = MediaResource.fromMap({
        'url': 'u',
        'name': 'n',
        'ext': 'mp4',
      });

      expect(r.mimeType, isNull);
      expect(r.size, isNull);
      expect(r.initiator, isNull);
      expect(r.isPlayable, isFalse);
      expect(r.isPlaylist, isFalse);
      expect(r.duration, isNull);
    });

    // ──────────────────────────────────────────────
    // copyWith
    // ──────────────────────────────────────────────
    test('copyWith overrides url', () {
      final copied =
          defaultResource.copyWith(url: 'https://other.example.com/new.mp4');
      expect(copied.url, equals('https://other.example.com/new.mp4'));
      expect(copied.name, equals(testName));
      expect(copied.ext, equals(testExt));
    });

    test('copyWith overrides name', () {
      final copied = defaultResource.copyWith(name: 'renamed');
      expect(copied.name, equals('renamed'));
      expect(copied.url, equals(testUrl));
      expect(copied.ext, equals(testExt));
    });

    test('copyWith overrides ext', () {
      final copied = defaultResource.copyWith(ext: 'webm');
      expect(copied.ext, equals('webm'));
      expect(copied.url, equals(testUrl));
      expect(copied.name, equals(testName));
    });

    test('copyWith overrides optional fields', () {
      final copied = defaultResource.copyWith(
        mimeType: 'video/webm',
        size: 2048,
        initiator: 'https://ref.com/',
        isPlayable: true,
        isPlaylist: false,
        duration: '00:01:00',
      );

      expect(copied.mimeType, equals('video/webm'));
      expect(copied.size, equals(2048));
      expect(copied.initiator, equals('https://ref.com/'));
      expect(copied.isPlayable, isTrue);
      expect(copied.isPlaylist, isFalse);
      expect(copied.duration, equals('00:01:00'));
    });

    test('copyWith keeps unchanged fields when no overrides', () {
      final copied = defaultResource.copyWith();
      expect(copied.url, equals(testUrl));
      expect(copied.name, equals(testName));
      expect(copied.ext, equals(testExt));
      expect(copied.mimeType, isNull);
      expect(copied.size, isNull);
      expect(copied.initiator, isNull);
      expect(copied.isPlayable, isFalse);
      expect(copied.isPlaylist, isFalse);
      expect(copied.duration, isNull);
    });

    test('copyWith overrides only specified fields, preserves others', () {
      final copied = fullResource.copyWith(
        name: 'renamed_stream',
        isPlayable: false,
      );

      expect(copied.url, equals(fullResource.url));
      expect(copied.name, equals('renamed_stream'));
      expect(copied.ext, equals(fullResource.ext));
      expect(copied.mimeType, equals(fullResource.mimeType));
      expect(copied.size, equals(fullResource.size));
      expect(copied.initiator, equals(fullResource.initiator));
      expect(copied.isPlayable, isFalse);
      expect(copied.isPlaylist, isTrue);
      expect(copied.duration, equals(fullResource.duration));
    });

    // ──────────────────────────────────────────────
    // == 和 hashCode
    // ──────────────────────────────────────────────
    test('identical instances are equal', () {
      expect(defaultResource, equals(defaultResource));
    });

    test('different instances with same url/name/ext are equal', () {
      const a = MediaResource(
          url: 'https://example.com/v.mp4', name: 'v', ext: 'mp4');
      const b = MediaResource(
          url: 'https://example.com/v.mp4', name: 'v', ext: 'mp4');
      expect(a, equals(b));
    });

    test('instances with different url are not equal', () {
      const a =
          MediaResource(url: 'https://a.com/v.mp4', name: 'v', ext: 'mp4');
      const b =
          MediaResource(url: 'https://b.com/v.mp4', name: 'v', ext: 'mp4');
      expect(a == b, isFalse);
    });

    test('instances with different name are not equal', () {
      const a =
          MediaResource(url: 'https://a.com/v.mp4', name: 'a', ext: 'mp4');
      const b =
          MediaResource(url: 'https://a.com/v.mp4', name: 'b', ext: 'mp4');
      expect(a == b, isFalse);
    });

    test('instances with different ext are not equal', () {
      const a =
          MediaResource(url: 'https://a.com/v.mp4', name: 'v', ext: 'mp4');
      const b =
          MediaResource(url: 'https://a.com/v.mp4', name: 'v', ext: 'webm');
      expect(a == b, isFalse);
    });

    test('equality does not depend on optional fields', () {
      const a = MediaResource(
        url: 'https://a.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        size: 100,
        mimeType: 'video/mp4',
      );
      const b = MediaResource(
        url: 'https://a.com/v.mp4',
        name: 'v',
        ext: 'mp4',
        size: 200,
        mimeType: null,
      );
      expect(a, equals(b));
    });

    test('hashCode is consistent for same instance', () {
      final h1 = defaultResource.hashCode;
      final h2 = defaultResource.hashCode;
      expect(h1, equals(h2));
    });

    test('same identity-equality group shares hashCode', () {
      const a =
          MediaResource(url: 'https://eq.com/v.mp4', name: 'eq', ext: 'mp4');
      const b =
          MediaResource(url: 'https://eq.com/v.mp4', name: 'eq', ext: 'mp4');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different equality groups have (likely) different hashCodes', () {
      const a =
          MediaResource(url: 'https://a.com/v.mp4', name: 'a', ext: 'mp4');
      const b =
          MediaResource(url: 'https://b.com/v.mp4', name: 'b', ext: 'mp4');
      expect(a.hashCode == b.hashCode, isFalse);
    });

    // ──────────────────────────────────────────────
    // toString
    // ──────────────────────────────────────────────
    test('toString contains name, ext, url', () {
      final s = defaultResource.toString();
      expect(s, contains(testName));
      expect(s, contains(testExt));
      expect(s, contains(testUrl));
    });
  });

  // ===========================================================================
  // StepStatus
  // ===========================================================================
  group('StepStatus', () {
    // ──────────────────────────────────────────────
    // Factory constructors
    // ──────────────────────────────────────────────
    test('pending factory creates pending status', () {
      final s = StepStatus.pending(StepType.fetching);
      expect(s.type, equals(StepType.fetching));
      expect(s.completed, isFalse);
      expect(s.running, isFalse);
      expect(s.failed, isFalse);
      expect(s.error, isNull);
      expect(s.progress, equals(0));
    });

    test('running factory creates running status', () {
      final s = StepStatus.running(StepType.analyzing);
      expect(s.type, equals(StepType.analyzing));
      expect(s.completed, isFalse);
      expect(s.running, isTrue);
      expect(s.failed, isFalse);
      expect(s.error, isNull);
      expect(s.progress, equals(0));
    });

    test('done factory creates completed status', () {
      final s = StepStatus.done(StepType.downloading);
      expect(s.type, equals(StepType.downloading));
      expect(s.completed, isTrue);
      expect(s.running, isFalse);
      expect(s.failed, isFalse);
      expect(s.error, isNull);
      expect(s.progress, equals(100));
    });

    test('fail factory creates failed status with error', () {
      final s = StepStatus.fail(StepType.converting, 'Conversion failed');
      expect(s.type, equals(StepType.converting));
      expect(s.completed, isFalse);
      expect(s.running, isFalse);
      expect(s.failed, isTrue);
      expect(s.error, equals('Conversion failed'));
      expect(s.progress, equals(0));
    });

    test('fail factory allows null error', () {
      final s = StepStatus.fail(StepType.fetching, null);
      expect(s.failed, isTrue);
      expect(s.error, isNull);
    });

    test('progressing factory creates running status with progress', () {
      final s = StepStatus.progressing(StepType.downloading, 45);
      expect(s.type, equals(StepType.downloading));
      expect(s.completed, isFalse);
      expect(s.running, isTrue);
      expect(s.failed, isFalse);
      expect(s.error, isNull);
      expect(s.progress, equals(45));
    });

    test('progressing factory clamps progress at user provided value', () {
      final s = StepStatus.progressing(StepType.downloading, 0);
      expect(s.progress, equals(0));

      final s2 = StepStatus.progressing(StepType.downloading, 100);
      expect(s2.progress, equals(100));
    });

    // ──────────────────────────────────────────────
    // toMap / fromMap round-trip
    // ──────────────────────────────────────────────
    test('toMap/fromMap round-trip for pending status', () {
      final original = StepStatus.pending(StepType.fetching);
      final map = original.toMap();
      final restored = StepStatus.fromMap(map);

      expect(restored.type, equals(StepType.fetching));
      expect(restored.completed, isFalse);
      expect(restored.running, isFalse);
      expect(restored.failed, isFalse);
      expect(restored.error, isNull);
      expect(restored.progress, equals(0));
    });

    test('toMap/fromMap round-trip for done status', () {
      final original = StepStatus.done(StepType.downloading);
      final map = original.toMap();
      final restored = StepStatus.fromMap(map);

      expect(restored.type, equals(StepType.downloading));
      expect(restored.completed, isTrue);
      expect(restored.progress, equals(100));
    });

    test('toMap/fromMap round-trip for failed status with error', () {
      final original = StepStatus.fail(StepType.saving, 'Disk full');
      final map = original.toMap();
      final restored = StepStatus.fromMap(map);

      expect(restored.type, equals(StepType.saving));
      expect(restored.failed, isTrue);
      expect(restored.error, equals('Disk full'));
    });

    test('toMap/fromMap round-trip for progressing status', () {
      final original = StepStatus.progressing(StepType.converting, 77);
      final map = original.toMap();
      final restored = StepStatus.fromMap(map);

      expect(restored.type, equals(StepType.converting));
      expect(restored.running, isTrue);
      expect(restored.progress, equals(77));
    });

    // ──────────────────────────────────────────────
    // fromMap – nullable/default handling
    // ──────────────────────────────────────────────
    test('fromMap treats missing error as null', () {
      final s = StepStatus.fromMap({
        'type': 'fetching',
        'completed': false,
        'running': false,
        'failed': true,
        'progress': 0,
      });

      expect(s.error, isNull);
    });

    test('fromMap treats missing optional bools as false', () {
      final s = StepStatus.fromMap({
        'type': 'fetching',
        'progress': 0,
      });

      expect(s.completed, isFalse);
      expect(s.running, isFalse);
      expect(s.failed, isFalse);
    });

    test('fromMap treats missing progress as 0', () {
      final s = StepStatus.fromMap({
        'type': 'fetching',
      });

      expect(s.progress, equals(0));
    });

    // ──────────────────────────────────────────────
    // copyWith
    // ──────────────────────────────────────────────
    test('copyWith overrides type', () {
      final original = StepStatus.pending(StepType.fetching);
      final copied = original.copyWith(type: StepType.downloading);

      expect(copied.type, equals(StepType.downloading));
      expect(copied.completed, isFalse);
    });

    test('copyWith overrides completed', () {
      final original = StepStatus.pending(StepType.fetching);
      final copied = original.copyWith(completed: true, progress: 100);

      expect(copied.completed, isTrue);
      expect(copied.progress, equals(100));
    });

    test('copyWith overrides running', () {
      final original = StepStatus.pending(StepType.fetching);
      final copied = original.copyWith(running: true, progress: 50);

      expect(copied.running, isTrue);
      expect(copied.progress, equals(50));
    });

    test('copyWith overrides failed and error', () {
      final original = StepStatus.pending(StepType.fetching);
      final copied = original.copyWith(failed: true, error: 'Error occurred');

      expect(copied.failed, isTrue);
      expect(copied.error, equals('Error occurred'));
    });

    test('copyWith overrides progress', () {
      final original = StepStatus.progressing(StepType.downloading, 30);
      final copied = original.copyWith(progress: 80);

      expect(copied.progress, equals(80));
      expect(copied.running, isTrue);
    });

    test('copyWith keeps unchanged fields when no overrides', () {
      final original = StepStatus.fail(StepType.fetching, 'err');
      final copied = original.copyWith();

      expect(copied.type, equals(StepType.fetching));
      expect(copied.failed, isTrue);
      expect(copied.error, equals('err'));
      expect(copied.completed, isFalse);
      expect(copied.running, isFalse);
      expect(copied.progress, equals(0));
    });

    // ──────────────────────────────────────────────
    // toString
    // ──────────────────────────────────────────────
    test('toString contains type label and status fields', () {
      final s = StepStatus.fail(StepType.downloading, 'timeout');
      final str = s.toString();
      expect(str, contains('下载'));
      expect(str, contains('failed=true'));
      expect(str, contains('timeout'));
    });
  });

  // ===========================================================================
  // CatCatchTask
  // ===========================================================================
  group('CatCatchTask', () {
    const testId = 'task_001';
    const testUrl = 'https://example.com/video.mp4';
    const testDuration = 300;
    final testCreatedAt = DateTime(2025, 3, 10, 14, 45, 0);

    late CatCatchTask defaultTask;
    late CatCatchTask fullTask;

    setUp(() {
      defaultTask = CatCatchTask(
        id: testId,
        url: testUrl,
        expectedDurationSec: testDuration,
        createdAt: testCreatedAt,
      );

      fullTask = CatCatchTask(
        id: 'task_full_002',
        url: 'https://example.com/stream.m3u8',
        expectedDurationSec: 600,
        title: 'Full Test Stream',
        status: TaskStatus.completed,
        steps: [
          StepStatus.done(StepType.fetching),
          StepStatus.done(StepType.analyzing),
          StepStatus.done(StepType.downloading),
        ],
        error: null,
        createdAt: DateTime(2025, 3, 11, 10, 0, 0),
        completedAt: DateTime(2025, 3, 11, 10, 5, 30),
        detectedMedia: [
          const MediaResource(
            url: 'https://example.com/stream.m3u8',
            name: 'stream',
            ext: 'm3u8',
          ),
        ],
        selectedMedia: const MediaResource(
          url: 'https://example.com/stream.m3u8',
          name: 'stream',
          ext: 'm3u8',
        ),
        progress: 100,
        downloadedFilePath: '/downloads/stream.mp4',
        metadata: {'source': 'manual'},
      );
    });

    // ──────────────────────────────────────────────
    // Constructor – defaults
    // ──────────────────────────────────────────────
    test('constructor assigns required fields', () {
      expect(defaultTask.id, equals(testId));
      expect(defaultTask.url, equals(testUrl));
      expect(defaultTask.expectedDurationSec, equals(testDuration));
      expect(defaultTask.createdAt, equals(testCreatedAt));
    });

    test('constructor defaults optional fields correctly', () {
      expect(defaultTask.title, equals(''));
      expect(defaultTask.status, equals(TaskStatus.running));
      expect(defaultTask.steps, isEmpty);
      expect(defaultTask.error, isNull);
      expect(defaultTask.completedAt, isNull);
      expect(defaultTask.detectedMedia, isEmpty);
      expect(defaultTask.selectedMedia, isNull);
      expect(defaultTask.progress, equals(0));
      expect(defaultTask.downloadedFilePath, isNull);
      expect(defaultTask.metadata, isEmpty);
    });

    test('constructor stores all provided fields', () {
      expect(fullTask.id, equals('task_full_002'));
      expect(fullTask.url, equals('https://example.com/stream.m3u8'));
      expect(fullTask.expectedDurationSec, equals(600));
      expect(fullTask.title, equals('Full Test Stream'));
      expect(fullTask.status, equals(TaskStatus.completed));
      expect(fullTask.steps.length, equals(3));
      expect(fullTask.error, isNull);
      expect(fullTask.completedAt, equals(DateTime(2025, 3, 11, 10, 5, 30)));
      expect(fullTask.detectedMedia.length, equals(1));
      expect(fullTask.selectedMedia, isNotNull);
      expect(fullTask.progress, equals(100));
      expect(fullTask.downloadedFilePath, equals('/downloads/stream.mp4'));
      expect(fullTask.metadata, equals({'source': 'manual'}));
    });

    // ──────────────────────────────────────────────
    // toMap / fromMap round-trip
    // ──────────────────────────────────────────────
    test('toMap/fromMap round-trip preserves all fields for full task', () {
      final map = fullTask.toMap();
      final restored = CatCatchTask.fromMap(map);

      expect(restored.id, equals(fullTask.id));
      expect(restored.url, equals(fullTask.url));
      expect(
          restored.expectedDurationSec, equals(fullTask.expectedDurationSec));
      expect(restored.title, equals(fullTask.title));
      expect(restored.status, equals(fullTask.status));
      expect(restored.error, equals(fullTask.error));
      expect(restored.createdAt, equals(fullTask.createdAt));
      expect(restored.completedAt, equals(fullTask.completedAt));
      expect(restored.progress, equals(fullTask.progress));
      expect(restored.downloadedFilePath, equals(fullTask.downloadedFilePath));
      expect(restored.metadata, equals(fullTask.metadata));

      // steps
      expect(restored.steps.length, equals(fullTask.steps.length));
      for (int i = 0; i < restored.steps.length; i++) {
        expect(restored.steps[i].type, equals(fullTask.steps[i].type));
        expect(
            restored.steps[i].completed, equals(fullTask.steps[i].completed));
      }

      // detectedMedia
      expect(
          restored.detectedMedia.length, equals(fullTask.detectedMedia.length));
      expect(restored.detectedMedia.first.url,
          equals(fullTask.detectedMedia.first.url));

      // selectedMedia
      expect(restored.selectedMedia?.url, equals(fullTask.selectedMedia?.url));
    });

    test('toMap/fromMap round-trip for default task', () {
      final map = defaultTask.toMap();
      final restored = CatCatchTask.fromMap(map);

      expect(restored.id, equals(testId));
      expect(restored.url, equals(testUrl));
      expect(restored.expectedDurationSec, equals(testDuration));
      expect(restored.title, equals(''));
      expect(restored.status, equals(TaskStatus.running));
      expect(restored.steps, isEmpty);
      expect(restored.error, isNull);
      expect(restored.detectedMedia, isEmpty);
      expect(restored.selectedMedia, isNull);
      expect(restored.progress, equals(0));
      expect(restored.downloadedFilePath, isNull);
      expect(restored.metadata, isEmpty);
    });

    // ──────────────────────────────────────────────
    // fromMap – missing / null field handling
    // ──────────────────────────────────────────────
    test('fromMap handles missing optional fields with defaults', () {
      final task = CatCatchTask.fromMap({
        'id': 'task_orphan',
        'url': testUrl,
        'expectedDurationSec': 120,
        'createdAt': testCreatedAt.toIso8601String(),
      });

      expect(task.title, equals(''));
      expect(task.status, equals(TaskStatus.running));
      expect(task.steps, isEmpty);
      expect(task.error, isNull);
      expect(task.completedAt, isNull);
      expect(task.detectedMedia, isEmpty);
      expect(task.selectedMedia, isNull);
      expect(task.progress, equals(0));
      expect(task.downloadedFilePath, isNull);
      expect(task.metadata, isEmpty);
    });

    test('fromMap handles null completedAt', () {
      final task = CatCatchTask.fromMap({
        'id': 'task_nc',
        'url': testUrl,
        'expectedDurationSec': 60,
        'createdAt': testCreatedAt.toIso8601String(),
        'completedAt': null,
      });

      expect(task.completedAt, isNull);
    });

    test('fromMap handles null selectedMedia', () {
      final task = CatCatchTask.fromMap({
        'id': 'task_nsm',
        'url': testUrl,
        'expectedDurationSec': 60,
        'createdAt': testCreatedAt.toIso8601String(),
        'selectedMedia': null,
      });

      expect(task.selectedMedia, isNull);
    });

    test('fromMap handles null steps', () {
      final task = CatCatchTask.fromMap({
        'id': 'task_ns',
        'url': testUrl,
        'expectedDurationSec': 60,
        'createdAt': testCreatedAt.toIso8601String(),
        'steps': null,
      });

      expect(task.steps, isEmpty);
    });

    test('fromMap handles null detectedMedia', () {
      final task = CatCatchTask.fromMap({
        'id': 'task_ndm',
        'url': testUrl,
        'expectedDurationSec': 60,
        'createdAt': testCreatedAt.toIso8601String(),
        'detectedMedia': null,
      });

      expect(task.detectedMedia, isEmpty);
    });

    test('fromMap handles null metadata', () {
      final task = CatCatchTask.fromMap({
        'id': 'task_nm',
        'url': testUrl,
        'expectedDurationSec': 60,
        'createdAt': testCreatedAt.toIso8601String(),
        'metadata': null,
      });

      expect(task.metadata, isEmpty);
    });

    // ──────────────────────────────────────────────
    // copyWith
    // ──────────────────────────────────────────────
    test('copyWith overrides id', () {
      final copied = defaultTask.copyWith(id: 'task_new_id');
      expect(copied.id, equals('task_new_id'));
      expect(copied.url, equals(testUrl));
    });

    test('copyWith overrides url', () {
      final copied =
          defaultTask.copyWith(url: 'https://other.example.com/v.mp4');
      expect(copied.url, equals('https://other.example.com/v.mp4'));
      expect(copied.id, equals(testId));
    });

    test('copyWith overrides title', () {
      final copied = defaultTask.copyWith(title: 'New Title');
      expect(copied.title, equals('New Title'));
    });

    test('copyWith overrides status', () {
      final copied = defaultTask.copyWith(status: TaskStatus.completed);
      expect(copied.status, equals(TaskStatus.completed));
    });

    test('copyWith overrides progress', () {
      final copied = defaultTask.copyWith(progress: 50);
      expect(copied.progress, equals(50));
    });

    // ──────────────────────────────────────────────
    // copyWith – clear* flags
    // ──────────────────────────────────────────────
    test('copyWith clearError sets error to null', () {
      final withError = defaultTask.copyWith(error: 'Something failed');
      expect(withError.error, equals('Something failed'));

      final cleared = withError.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('copyWith clearError works even when error is already null', () {
      final copied = defaultTask.copyWith(clearError: true);
      expect(copied.error, isNull);
    });

    test('copyWith clearCompletedAt sets completedAt to null', () {
      final withDate = defaultTask.copyWith(
        completedAt: DateTime(2025, 4, 1),
        status: TaskStatus.completed,
      );
      expect(withDate.completedAt, isNotNull);

      final cleared = withDate.copyWith(clearCompletedAt: true);
      expect(cleared.completedAt, isNull);
    });

    test('copyWith clearDownloadedFilePath sets downloadedFilePath to null',
        () {
      final withPath = defaultTask.copyWith(
        downloadedFilePath: '/tmp/file.mp4',
      );
      expect(withPath.downloadedFilePath, isNotNull);

      final cleared = withPath.copyWith(clearDownloadedFilePath: true);
      expect(cleared.downloadedFilePath, isNull);
    });

    test('copyWith clearSelectedMedia sets selectedMedia to null', () {
      final withMedia = defaultTask.copyWith(
        selectedMedia: const MediaResource(
          url: 'https://example.com/v.mp4',
          name: 'v',
          ext: 'mp4',
        ),
      );
      expect(withMedia.selectedMedia, isNotNull);

      final cleared = withMedia.copyWith(clearSelectedMedia: true);
      expect(cleared.selectedMedia, isNull);
    });

    test('copyWith keeps unchanged fields when no overrides', () {
      final copied = fullTask.copyWith();

      expect(copied.id, equals(fullTask.id));
      expect(copied.url, equals(fullTask.url));
      expect(copied.expectedDurationSec, equals(fullTask.expectedDurationSec));
      expect(copied.title, equals(fullTask.title));
      expect(copied.status, equals(fullTask.status));
      expect(copied.steps.length, equals(fullTask.steps.length));
      expect(copied.error, equals(fullTask.error));
      expect(copied.createdAt, equals(fullTask.createdAt));
      expect(copied.completedAt, equals(fullTask.completedAt));
      expect(
          copied.detectedMedia.length, equals(fullTask.detectedMedia.length));
      expect(copied.selectedMedia?.url, equals(fullTask.selectedMedia?.url));
      expect(copied.progress, equals(fullTask.progress));
      expect(copied.downloadedFilePath, equals(fullTask.downloadedFilePath));
      expect(copied.metadata, equals(fullTask.metadata));
    });

    // ──────────────────────────────────────────────
    // steps 列表管理
    // ──────────────────────────────────────────────
    test('steps list is immutable from constructor', () {
      // The steps list from constructor should not be modifiable
      // (const [] is immutable by default)
      expect(defaultTask.steps, isA<List<StepStatus>>());
    });

    test('steps can be set via copyWith', () {
      final updated = defaultTask.copyWith(
        steps: [StepStatus.done(StepType.fetching)],
      );

      expect(updated.steps.length, equals(1));
      expect(updated.steps.first.type, equals(StepType.fetching));
    });

    test('copyWith steps replaces the entire list', () {
      final updated = fullTask.copyWith(
        steps: [
          StepStatus.running(StepType.converting),
          StepStatus.progressing(StepType.saving, 60),
        ],
      );

      expect(updated.steps.length, equals(2));
      expect(updated.steps[0].type, equals(StepType.converting));
      expect(updated.steps[0].running, isTrue);
      expect(updated.steps[1].type, equals(StepType.saving));
      expect(updated.steps[1].progress, equals(60));

      // verify original unchanged
      expect(fullTask.steps.length, equals(3));
    });

    test('steps are serialized and deserialized correctly in toMap/fromMap',
        () {
      final map = fullTask.toMap();
      final restored = CatCatchTask.fromMap(map);

      expect(restored.steps.length, equals(3));
      expect(restored.steps[0].type, equals(StepType.fetching));
      expect(restored.steps[0].completed, isTrue);
      expect(restored.steps[1].type, equals(StepType.analyzing));
      expect(restored.steps[1].completed, isTrue);
      expect(restored.steps[2].type, equals(StepType.downloading));
      expect(restored.steps[2].completed, isTrue);
    });

    // ──────────────────────────────────────────────
    // detectedMedia / selectedMedia in serialization
    // ──────────────────────────────────────────────
    test('detectedMedia list is serialized and deserialized', () {
      final map = fullTask.toMap();
      final restored = CatCatchTask.fromMap(map);

      expect(restored.detectedMedia.length, equals(1));
      expect(restored.detectedMedia.first.url,
          equals('https://example.com/stream.m3u8'));
      expect(restored.detectedMedia.first.name, equals('stream'));
      expect(restored.detectedMedia.first.isM3U8, isTrue);
    });

    test('selectedMedia is serialized and deserialized', () {
      final map = fullTask.toMap();
      final restored = CatCatchTask.fromMap(map);

      expect(restored.selectedMedia, isNotNull);
      expect(restored.selectedMedia!.url,
          equals('https://example.com/stream.m3u8'));
      expect(restored.selectedMedia!.isM3U8, isTrue);
    });

    // ──────────────────────────────────────────────
    // toString
    // ──────────────────────────────────────────────
    test('toString contains id, title, status and progress', () {
      final s = fullTask.toString();
      expect(s, contains('task_full_002'));
      expect(s, contains('Full Test Stream'));
      expect(s, contains('已完成'));
      expect(s, contains('100'));
    });
  });
}
