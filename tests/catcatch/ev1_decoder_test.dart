import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/ev1_decoder.dart';

/// Minimal FLV byte builder (same structure as in dart_flv_remuxer_test).
Uint8List _u32(int value) => Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);

Uint8List _buildMinimalFlv() {
  final buf = BytesBuilder();
  buf.add([0x46, 0x4C, 0x56, 0x01, 0x01, 0x00, 0x00, 0x00, 0x09]);
  buf.add(_u32(0)); // previous tag size

  // Video sequence header (avcC)
  final sps = Uint8List.fromList([0x67, 0x42, 0x00, 0x1E, 0x8D]);
  final pps = Uint8List.fromList([0x68, 0xCE, 0x38, 0x80]);
  final avcC = BytesBuilder();
  avcC.add([0x01, 0x42, 0x00, 0x1E, 0xFF, 0xE1]);
  avcC.add([0x00, sps.length]);
  avcC.add(sps);
  avcC.add([0x01]);
  avcC.add([0x00, pps.length]);
  avcC.add(pps);

  void addTag(int type, int timestampMs, Uint8List data) {
    buf.add([type]);
    buf.add([
      (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
    ]);
    // FLV 时间戳为 24 位大端
    buf.add([
      (timestampMs >> 16) & 0xFF,
      (timestampMs >> 8) & 0xFF,
      timestampMs & 0xFF,
      0x00,
    ]);
    buf.add([0x00, 0x00, 0x00]);
    buf.add(data);
    buf.add(_u32(11 + data.length));
  }

  addTag(9, 0,
      Uint8List.fromList([0x17, 0x00, 0x00, 0x00, 0x00, ...avcC.toBytes()]));
  final nal = Uint8List.fromList([0x65, 0x88, 0x84]);
  addTag(
      9,
      1000,
      Uint8List.fromList([
        0x17,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        nal.length,
        ...nal,
      ]));
  // 第二个视频样本：确保文件总长超过 100 字节混淆窗口
  addTag(
      9,
      2000,
      Uint8List.fromList([
        0x27,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        nal.length,
        ...nal,
      ]));
  return buf.toBytes();
}

/// Obfuscate like the reference ev1-decoder: XOR the first 100 bytes with 0xFF.
Uint8List _obfuscate(Uint8List bytes) {
  final out = Uint8List.fromList(bytes);
  final n = bytes.length < 100 ? bytes.length : 100;
  for (int i = 0; i < n; i++) {
    out[i] = bytes[i] ^ 0xFF;
  }
  return out;
}

void main() {
  group('Ev1Decoder - detection', () {
    test('isEv1 detects obfuscated FLV head', () {
      final ev1 = _obfuscate(_buildMinimalFlv());
      expect(Ev1Decoder.isEv1(ev1.sublist(0, 16)), isTrue);
    });

    test('isEv1 rejects plain FLV head', () {
      final flv = _buildMinimalFlv();
      expect(Ev1Decoder.isEv1(flv.sublist(0, 16)), isFalse);
    });

    test('isEv1 rejects short/garbage data', () {
      expect(Ev1Decoder.isEv1(Uint8List(2)), isFalse);
      expect(Ev1Decoder.isEv1(Uint8List.fromList([1, 2, 3])), isFalse);
    });
  });

  group('Ev1Decoder - deobfuscate', () {
    test('XOR round-trip restores original FLV', () {
      final flv = _buildMinimalFlv();
      final ev1 = _obfuscate(flv);
      final restored = Ev1Decoder.deobfuscate(ev1);
      expect(restored, equals(flv));
    });

    test('applying deobfuscate twice is identity', () {
      final flv = _buildMinimalFlv();
      final ev1 = _obfuscate(flv);
      final twice = Ev1Decoder.deobfuscate(Ev1Decoder.deobfuscate(ev1));
      expect(twice, equals(ev1));
    });
  });

  group('Ev1Decoder - convertEv1ToMp4 (integration)', () {
    test('decodes obfuscated EV1 to valid MP4 and cleans up temp files',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('ev1_test_');
      try {
        final ev1Path = '${tempDir.path}\\video.ev1';
        final mp4Path = '${tempDir.path}\\video.mp4';
        await File(ev1Path).writeAsBytes(_obfuscate(_buildMinimalFlv()));

        final resultPath = await Ev1Decoder.convertEv1ToMp4(
          inputPath: ev1Path,
          outputPath: mp4Path,
        );
        expect(resultPath, equals(mp4Path));

        final mp4 = await File(mp4Path).readAsBytes();
        expect(mp4.length, greaterThan(100));
        expect(String.fromCharCodes(mp4.sublist(4, 8)), equals('ftyp'));
        expect(String.fromCharCodes(mp4).contains('moov'), isTrue);

        // 临时文件应被清理
        final leftovers = tempDir
            .listSync()
            .where((e) => e.path.contains('.tmp') || e.path.contains('_tmp'))
            .toList();
        expect(leftovers, isEmpty);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('accepts plain FLV input as-is', () async {
      final tempDir = Directory.systemTemp.createTempSync('ev1_plain_');
      try {
        final flvPath = '${tempDir.path}\\video.ev1';
        final mp4Path = '${tempDir.path}\\video.mp4';
        await File(flvPath).writeAsBytes(_buildMinimalFlv());

        final resultPath = await Ev1Decoder.convertEv1ToMp4(
          inputPath: flvPath,
          outputPath: mp4Path,
        );
        expect(resultPath, equals(mp4Path));
        expect(await File(mp4Path).length(), greaterThan(100));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('throws for files that are neither EV1 nor FLV', () async {
      final tempDir = Directory.systemTemp.createTempSync('ev1_bad_');
      try {
        final badPath = '${tempDir.path}\\video.ev1';
        final mp4Path = '${tempDir.path}\\video.mp4';
        await File(badPath)
            .writeAsBytes(Uint8List.fromList([0x11, 0x22, 0x33, 0x44, 0x55]));

        await expectLater(
          () => Ev1Decoder.convertEv1ToMp4(
            inputPath: badPath,
            outputPath: mp4Path,
          ),
          throwsFormatException,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
