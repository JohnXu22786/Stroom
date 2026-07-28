import 'dart:typed_data';

// ============================================================================
// Pure-Dart audio codecs for cross-platform audio compression
//
// FLAC encoder: lossless, ~50-70% of original size for speech
// ADPCM encoder: lossy, ~25% of original size, good speech quality
// ============================================================================

// ============================================================================
// IMA ADPCM Encoder
//
// IMA (Interactive Multimedia Association) ADPCM is a simple waveform codec
// that encodes 16-bit PCM samples into 4-bit nibbles (4:1 compression).
// Standard for WAV ADPCM format.
//
// Algorithm: each sample is predicted from the previous, and the difference
// (delta) is quantized to 4 bits using an adaptive step size table.
// ============================================================================

/// IMA ADPCM encoder configuration.
class AdpcmConfig {
  /// Number of channels (1 = mono).
  final int channels;

  /// Samples per block (default 256, per IMA standard).
  final int blockSize;

  const AdpcmConfig({this.channels = 1, this.blockSize = 256});
}

/// IMA ADPCM step size table (89 values, from IMA/DVI specification).
const List<int> _imaStepTable = [
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  16,
  17,
  19,
  21,
  23,
  25,
  28,
  31,
  34,
  37,
  41,
  45,
  50,
  55,
  60,
  66,
  73,
  80,
  88,
  97,
  107,
  118,
  130,
  143,
  157,
  173,
  190,
  209,
  230,
  253,
  279,
  307,
  337,
  371,
  408,
  449,
  494,
  544,
  598,
  658,
  724,
  796,
  876,
  963,
  1060,
  1166,
  1282,
  1411,
  1552,
  1707,
  1878,
  2066,
  2272,
  2499,
  2749,
  3024,
  3327,
  3660,
  4026,
  4428,
  4871,
  5358,
  5894,
  6484,
  7132,
  7845,
  8630,
  9493,
  10442,
  11487,
  12635,
  13899,
  15289,
  16818,
  18500,
  20350,
  22385,
  24623,
  27086,
  29794,
  32767,
];

/// IMA ADPCM index adjustment table.
const List<int> _imaIndexTable = [-1, -1, -1, -1, 2, 4, 6, 8];

/// Encode PCM S16LE samples to IMA ADPCM.
///
/// Returns ADPCM bytes (4-bit nibbles, packed high nibble first per IMA spec).
Uint8List encodeAdpcm(Int16List pcmSamples, AdpcmConfig config) {
  final numBlocks = pcmSamples.length ~/ config.blockSize;
  final nibblesPerBlock = config.blockSize;

  final out = BytesOutput();
  int sampleIdx = 0;

  for (int block = 0; block < numBlocks; block++) {
    final blockSamples =
        pcmSamples.sublist(sampleIdx, sampleIdx + config.blockSize);

    for (int ch = 0; ch < config.channels; ch++) {
      // Block header: 2-byte predictor + 1-byte step index + 1 reserved
      out.writeUint16LE(blockSamples[ch]); // initial predictor
      out.writeByte(0); // step index starts at 0
      out.writeByte(0); // reserved
    }

    int stepIdx = 0;
    int predictor = blockSamples[0];

    // Encode nibbles (high nibble first)
    final nibbles = Uint8List(nibblesPerBlock - 1);
    for (int i = 1; i < blockSamples.length; i++) {
      final sample = blockSamples[i];
      int delta = sample - predictor;

      // Compute sign and magnitude
      int sign;
      if (delta < 0) {
        sign = 0x8;
        delta = -delta;
      } else {
        sign = 0;
      }

      // Quantize delta to 4-bit nibble
      var step = _imaStepTable[stepIdx];
      int nibble = 0;
      int diff = step >> 3;

      if (delta >= step) {
        nibble |= 4;
        delta -= step;
        diff += step;
      }
      step >>= 1;
      if (delta >= step) {
        nibble |= 2;
        delta -= step;
        diff += step;
      }
      step >>= 1;
      if (delta >= step) {
        nibble |= 1;
        diff += step;
      }

      nibble |= sign;

      // Update predictor
      if ((nibble & 0x8) != 0) {
        predictor -= diff;
      } else {
        predictor += diff;
      }
      predictor = predictor.clamp(-32768, 32767);

      // Update step index
      stepIdx += _imaIndexTable[nibble & 0x7];
      stepIdx = stepIdx.clamp(0, 88);

      nibbles[i - 1] = nibble;
    }

    // Pack nibbles into bytes (high nibble first)
    for (int i = 0; i < nibbles.length; i += 2) {
      final high = nibbles[i] & 0xF;
      final low = (i + 1 < nibbles.length) ? (nibbles[i + 1] & 0xF) : 0;
      out.writeByte((high << 4) | low);
    }

    sampleIdx += config.blockSize;
  }

  return out.toBytes();
}

// ============================================================================
// FLAC Encoder (pure Dart)
//
// Implements the FLAC subset format:
// - Fixed block size (4096 samples)
// - Fixed LPC prediction (orders 0-4)
// - Rice coding for residuals
// - CRC-8 for frames, CRC-16 for footers
// - Mono only (single channel)
// ============================================================================

const int _flacBlockSize = 4096;
const int _flacMaxRiceParam = 14;

/// Encode PCM S16LE mono samples to FLAC format.
///
/// Returns FLAC file bytes (fLaC marker + STREAMINFO + frames).
Uint8List encodeFlac(Int16List pcmSamples, {int sampleRate = 16000}) {
  final totalSamples = pcmSamples.length;
  final numFrames = (totalSamples + _flacBlockSize - 1) ~/ _flacBlockSize;

  final out = BytesOutput();

  // fLaC marker (4 bytes)
  out.writeString('fLaC');

  // STREAMINFO block
  _writeStreamInfo(out, totalSamples, sampleRate);

  // Encode frames
  int frameOffset = 0;
  for (int f = 0; f < numFrames; f++) {
    final blockLen = (_flacBlockSize < totalSamples - frameOffset)
        ? _flacBlockSize
        : totalSamples - frameOffset;
    final blockSamples =
        pcmSamples.sublist(frameOffset, frameOffset + blockLen);
    _writeFlacFrame(out, blockSamples, f, blockLen, sampleRate);
    frameOffset += blockLen;
  }

  return out.toBytes();
}

// ---- STREAMINFO block ----

void _writeStreamInfo(BytesOutput out, int totalSamples, int sampleRate) {
  // Block header: last-metadata-block=1, type=0 (STREAMINFO)
  out.writeByte(0x80);
  // Length = 34 for STREAMINFO (3 bytes big-endian)
  out.writeByte(0x00);
  out.writeByte(0x00);
  out.writeByte(0x22); // 34 bytes

  // Minimum block size (16 bits)
  out.writeUint16BE(_flacBlockSize);
  // Maximum block size (16 bits)
  out.writeUint16BE(_flacBlockSize);
  // Minimum frame size (24 bits) - approximate
  out.writeByte(0x00);
  out.writeByte(0x01);
  out.writeByte(0x00);
  // Maximum frame size (24 bits) - generous estimate
  final maxFrame = _flacBlockSize * 2 + 64;
  out.writeByte((maxFrame >> 16) & 0xFF);
  out.writeByte((maxFrame >> 8) & 0xFF);
  out.writeByte(maxFrame & 0xFF);

  // Sample rate (20 bits) | channels-1 (3 bits) | bps-1 (5 bits) | total samples (36 bits)
  // Pack: sample_rate(20) << 44 | channels(3) << 41 | bps(5) << 36 | total(36)
  final sr = sampleRate;
  final ch = 0; // mono -> 1 channel -> value 0
  final bps = 15; // 16-bit -> value 15
  final ts = totalSamples;

  out.writeByte((sr >> 12) & 0xFF);
  out.writeByte((sr >> 4) & 0xFF);
  out.writeByte(((sr & 0xF) << 4) | ((ch >> 1) & 0xF));
  out.writeByte(((ch & 0x1) << 7) | ((bps & 0x1F) << 2) | ((ts >> 34) & 0x3));
  out.writeByte((ts >> 26) & 0xFF);
  out.writeByte((ts >> 18) & 0xFF);
  out.writeByte((ts >> 10) & 0xFF);
  out.writeByte((ts >> 2) & 0xFF);
  out.writeByte((ts & 0x3) << 6);

  // MD5 (16 bytes, all zeros - placeholder)
  for (int i = 0; i < 16; i++) {
    out.writeByte(0);
  }
}

// ---- FLAC Frame ----

void _writeFlacFrame(
    BytesOutput out, Int16List samples, int frameIdx, int blockLen, int sr) {
  final headerBits = _BitWriter();
  final bodyBits = _BitWriter();

  // Sync code: 0x3FFE (14 bits)
  headerBits.write(0x3FFE, 14);
  // Reserved: 0
  headerBits.write(0, 1);
  // Blocking strategy: 0 = fixed
  headerBits.write(0, 1);
  // Block size: 0110 = 4096, 0111 = 4608 (closest for non-standard)
  // For our fixed 4096 blocks, use code 0110
  final bsCode = _blockSizeCode(blockLen);
  headerBits.write(bsCode, 4);
  // Sample rate: use code from table
  final srCode = _sampleRateCode(sr);
  headerBits.write(srCode, 4);
  // Channel assignment: 0000 = mono
  headerBits.write(0, 4);
  // Sample size: 100 = 16 bits
  headerBits.write(4, 3);
  // Reserved: 0
  headerBits.write(0, 1);

  // Frame/Sample number: UTF-8 coded
  final frameNum = frameIdx * _flacBlockSize;
  final utf8 = _encodeUtf8(frameNum);
  for (final b in utf8) {
    headerBits.write(b, 8);
  }

  // Block size (if variable): not needed for fixed
  // Sample rate (if variable): not needed

  // CRC-8 of header
  final headerBytes = headerBits.toBytes();
  final crc8 = _crc8(headerBytes, 0, headerBytes.length);
  headerBits.write(crc8, 8);

  // ---- Subframe: FIXED subframe ----

  // Subframe header: type=0001xx (FIXED), wasted_bits=0
  // Try each fixed order and pick the best
  int bestOrder = 0;
  int bestTotalBits = 0x7FFFFFFF;
  List<int> bestResiduals = [];

  for (int order = 0; order <= 4 && order < blockLen; order++) {
    final residuals = _computeFixedResiduals(samples, order);
    final riceBits = _estimateRiceBits(residuals);

    final totalBits = order * 16 + riceBits; // warmup costs 16 bits each
    if (totalBits < bestTotalBits) {
      bestTotalBits = totalBits;
      bestOrder = order;
      bestResiduals = residuals;
    }
  }

  // Subframe header
  // FIXED subframe: 001xxx where xxx = order
  // type = 0x20 | order
  final subType = 0x20 | bestOrder;
  bodyBits.write(subType, 6);
  // Wasted bits flag: 0
  bodyBits.write(0, 1);

  // Warmup samples (unencoded)
  for (int i = 0; i < bestOrder; i++) {
    bodyBits.write(samples[i] & 0xFFFF, 16);
  }

  // Residuals: Rice coded
  _writeRiceResiduals(bodyBits, bestResiduals, bestOrder);

  // Pad to byte boundary
  bodyBits.flush();

  // ---- Frame assembly ----
  final hdr = headerBits.toBytes();
  final body = bodyBits.toBytes();

  out.addBytes(hdr);
  out.addBytes(body);

  // Frame footer: CRC-16
  final frameData = Uint8List(hdr.length + body.length);
  frameData.setRange(0, hdr.length, hdr);
  frameData.setRange(hdr.length, frameData.length, body);
  final crc16 = _crc16(frameData, 0, frameData.length);
  out.writeUint16BE(crc16);
}

// ---- Prediction ----

/// Compute fixed LPC residuals for the given order.
/// Returns residuals for samples[order..end).
List<int> _computeFixedResiduals(Int16List samples, int order) {
  final n = samples.length - order;
  final residuals = List<int>.filled(n, 0);

  for (int i = 0; i < n; i++) {
    final idx = order + i;
    int pred = 0;

    switch (order) {
      case 0:
        pred = 0;
        break;
      case 1:
        pred = samples[idx - 1];
        break;
      case 2:
        pred = 2 * samples[idx - 1] - samples[idx - 2];
        break;
      case 3:
        pred = 3 * samples[idx - 1] - 3 * samples[idx - 2] + samples[idx - 3];
        break;
      case 4:
        pred = 4 * samples[idx - 1] -
            6 * samples[idx - 2] +
            4 * samples[idx - 3] -
            samples[idx - 4];
        break;
    }

    residuals[i] = samples[idx] - pred;
  }

  return residuals;
}

/// Estimate bits needed for Rice coding the residuals.
int _estimateRiceBits(List<int> residuals) {
  // Find optimal Rice parameter
  int bestBits = 0x7FFFFFFF;

  for (int k = 0; k <= _flacMaxRiceParam; k++) {
    int totalBits = 4; // Rice parameter costs 4 bits
    for (final r in residuals) {
      // Convert signed to unsigned
      final u = r >= 0 ? 2 * r : -2 * r - 1;
      final q = u >> k;
      totalBits += q + 1 + k; // quotient (unary) + stop bit + remainder
    }
    if (totalBits < bestBits) {
      bestBits = totalBits;
    }
  }

  return bestBits;
}

/// Write residuals using Rice coding.
void _writeRiceResiduals(_BitWriter bits, List<int> residuals, int order) {
  // Partition residuals into groups of ~128 samples
  const partitionOrder = 2; // 2^2 = 4 partitions per block
  final partitionSize = residuals.length >> partitionOrder;

  for (int p = 0; p < (1 << partitionOrder); p++) {
    final start = p * partitionSize;
    final end = p == (1 << partitionOrder) - 1
        ? residuals.length
        : start + partitionSize;
    if (start >= residuals.length) break;

    // Find best Rice parameter for this partition
    final n = end - start;
    int sum = 0;
    for (int i = start; i < end; i++) {
      final r = residuals[i];
      sum += r >= 0 ? r : -r - 1;
    }
    // Estimate: mean ≈ sum/n, k ≈ log2(mean)
    int k = 0;
    final mean = sum ~/ (n > 0 ? n : 1);
    while ((1 << k) < mean && k < _flacMaxRiceParam) {
      k++;
    }
    if (k > _flacMaxRiceParam) k = _flacMaxRiceParam;

    // Rice parameter (4 bits)
    bits.write(k, 4);

    // Escape code: if k == 15, use verbatim
    if (k >= _flacMaxRiceParam) {
      // Encode verbatim
      for (int i = start; i < end; i++) {
        bits.write(residuals[i] & 0xFFFF, 16);
      }
    } else {
      // Rice encode each residual
      for (int i = start; i < end; i++) {
        final r = residuals[i];
        final u = r >= 0 ? 2 * r : -2 * r - 1;
        final q = u >> k;
        final rem = u & ((1 << k) - 1);

        // Unary quotient: q ones followed by a zero
        for (int j = 0; j < q; j++) {
          bits.write(1, 1);
        }
        bits.write(0, 1);

        // Binary remainder
        bits.write(rem, k);
      }
    }
  }
}

// ---- FLAC Tables ----

int _blockSizeCode(int blockLen) {
  if (blockLen == 192) return 1;
  if (blockLen == 576) return 2;
  if (blockLen == 1152) return 3;
  if (blockLen == 2304) return 4;
  if (blockLen == 4608) return 5;
  if (blockLen == 256) return 8;
  if (blockLen == 512) return 9;
  if (blockLen == 1024) return 10;
  if (blockLen == 2048) return 11;
  if (blockLen == 4096) return 12;
  if (blockLen == 8192) return 13;
  if (blockLen == 16384) return 14;
  if (blockLen == 32768) return 15;
  return 0; // get from header
}

int _sampleRateCode(int sr) {
  if (sr == 88200) return 1;
  if (sr == 176400) return 2;
  if (sr == 192000) return 3;
  if (sr == 8000) return 4;
  if (sr == 16000) return 5;
  if (sr == 22050) return 6;
  if (sr == 24000) return 7;
  if (sr == 32000) return 8;
  if (sr == 44100) return 9;
  if (sr == 48000) return 10;
  if (sr == 96000) return 11;
  return 0; // get from header
}

List<int> _encodeUtf8(int value) {
  if (value < 0x80) return [value];
  if (value < 0x800) {
    return [
      0xC0 | (value >> 6),
      0x80 | (value & 0x3F),
    ];
  }
  if (value < 0x10000) {
    return [
      0xE0 | (value >> 12),
      0x80 | ((value >> 6) & 0x3F),
      0x80 | (value & 0x3F),
    ];
  }
  if (value < 0x200000) {
    return [
      0xF0 | (value >> 18),
      0x80 | ((value >> 12) & 0x3F),
      0x80 | ((value >> 6) & 0x3F),
      0x80 | (value & 0x3F),
    ];
  }
  // 5-byte
  return [
    0xF8 | (value >> 24),
    0x80 | ((value >> 18) & 0x3F),
    0x80 | ((value >> 12) & 0x3F),
    0x80 | ((value >> 6) & 0x3F),
    0x80 | (value & 0x3F),
  ];
}

// ---- CRC ----

int _crc8(Uint8List data, int offset, int length) {
  int crc = 0;
  for (int i = offset; i < offset + length; i++) {
    crc = _crc8Table[(crc ^ data[i]) & 0xFF];
  }
  return crc;
}

const List<int> _crc8Table = [
  0x00,
  0x07,
  0x0E,
  0x09,
  0x1C,
  0x1B,
  0x12,
  0x15,
  0x38,
  0x3F,
  0x36,
  0x31,
  0x24,
  0x23,
  0x2A,
  0x2D,
  0x70,
  0x77,
  0x7E,
  0x79,
  0x6C,
  0x6B,
  0x62,
  0x65,
  0x48,
  0x4F,
  0x46,
  0x41,
  0x54,
  0x53,
  0x5A,
  0x5D,
  0xE0,
  0xE7,
  0xEE,
  0xE9,
  0xFC,
  0xFB,
  0xF2,
  0xF5,
  0xD8,
  0xDF,
  0xD6,
  0xD1,
  0xC4,
  0xC3,
  0xCA,
  0xCD,
  0x90,
  0x97,
  0x9E,
  0x99,
  0x8C,
  0x8B,
  0x82,
  0x85,
  0xA8,
  0xAF,
  0xA6,
  0xA1,
  0xB4,
  0xB3,
  0xBA,
  0xBD,
  0xC7,
  0xC0,
  0xC9,
  0xCE,
  0xDB,
  0xDC,
  0xD5,
  0xD2,
  0xFF,
  0xF8,
  0xF1,
  0xF6,
  0xE3,
  0xE4,
  0xED,
  0xEA,
  0xB7,
  0xB0,
  0xB9,
  0xBE,
  0xAB,
  0xAC,
  0xA5,
  0xA2,
  0x8F,
  0x88,
  0x81,
  0x86,
  0x93,
  0x94,
  0x9D,
  0x9A,
  0x27,
  0x20,
  0x29,
  0x2E,
  0x3B,
  0x3C,
  0x35,
  0x32,
  0x1F,
  0x18,
  0x11,
  0x16,
  0x03,
  0x04,
  0x0D,
  0x0A,
  0x57,
  0x50,
  0x59,
  0x5E,
  0x4B,
  0x4C,
  0x45,
  0x42,
  0x6F,
  0x68,
  0x61,
  0x66,
  0x73,
  0x74,
  0x7D,
  0x7A,
  0x89,
  0x8E,
  0x87,
  0x80,
  0x95,
  0x92,
  0x9B,
  0x9C,
  0xB1,
  0xB6,
  0xBF,
  0xB8,
  0xAD,
  0xAA,
  0xA3,
  0xA4,
  0xF9,
  0xFE,
  0xF7,
  0xF0,
  0xE5,
  0xE2,
  0xEB,
  0xEC,
  0xC1,
  0xC6,
  0xCF,
  0xC8,
  0xDD,
  0xDA,
  0xD3,
  0xD4,
  0x69,
  0x6E,
  0x67,
  0x60,
  0x75,
  0x72,
  0x7B,
  0x7C,
  0x51,
  0x56,
  0x5F,
  0x58,
  0x4D,
  0x4A,
  0x43,
  0x44,
  0x19,
  0x1E,
  0x17,
  0x10,
  0x05,
  0x02,
  0x0B,
  0x0C,
  0x21,
  0x26,
  0x2F,
  0x28,
  0x3D,
  0x3A,
  0x33,
  0x34,
  0x4E,
  0x49,
  0x40,
  0x47,
  0x52,
  0x55,
  0x5C,
  0x5B,
  0x76,
  0x71,
  0x78,
  0x7F,
  0x6A,
  0x6D,
  0x64,
  0x63,
  0x3E,
  0x39,
  0x30,
  0x37,
  0x22,
  0x25,
  0x2C,
  0x2B,
  0x06,
  0x01,
  0x08,
  0x0F,
  0x1A,
  0x1D,
  0x14,
  0x13,
  0xAE,
  0xA9,
  0xA0,
  0xA7,
  0xB2,
  0xB5,
  0xBC,
  0xBB,
  0x96,
  0x91,
  0x98,
  0x9F,
  0x8A,
  0x8D,
  0x84,
  0x83,
  0xDE,
  0xD9,
  0xD0,
  0xD7,
  0xC2,
  0xC5,
  0xCC,
  0xCB,
  0xE6,
  0xE1,
  0xE8,
  0xEF,
  0xFA,
  0xFD,
  0xF4,
  0xF3,
];

int _crc16(Uint8List data, int offset, int length) {
  int crc = 0;
  for (int i = offset; i < offset + length; i++) {
    crc = ((crc << 8) ^ _crc16Table[((crc >> 8) ^ data[i]) & 0xFF]) & 0xFFFF;
  }
  return crc;
}

const List<int> _crc16Table = [
  0x0000,
  0x8005,
  0x800F,
  0x000A,
  0x801B,
  0x001E,
  0x0014,
  0x8011,
  0x8033,
  0x0036,
  0x003C,
  0x8039,
  0x0028,
  0x802D,
  0x8027,
  0x0022,
  0x8063,
  0x0066,
  0x006C,
  0x8069,
  0x0078,
  0x807D,
  0x8077,
  0x0072,
  0x0050,
  0x8055,
  0x805F,
  0x005A,
  0x804B,
  0x004E,
  0x0044,
  0x8041,
  0x80C3,
  0x00C6,
  0x00CC,
  0x80C9,
  0x00D8,
  0x80DD,
  0x80D7,
  0x00D2,
  0x00F0,
  0x80F5,
  0x80FF,
  0x00FA,
  0x80EB,
  0x00EE,
  0x00E4,
  0x80E1,
  0x00A0,
  0x80A5,
  0x80AF,
  0x00AA,
  0x80BB,
  0x00BE,
  0x00B4,
  0x80B1,
  0x8093,
  0x0096,
  0x009C,
  0x8099,
  0x0088,
  0x808D,
  0x8087,
  0x0082,
  0x8183,
  0x0186,
  0x018C,
  0x8189,
  0x0198,
  0x819D,
  0x8197,
  0x0192,
  0x01B0,
  0x81B5,
  0x81BF,
  0x01BA,
  0x81AB,
  0x01AE,
  0x01A4,
  0x81A1,
  0x01E0,
  0x81E5,
  0x81EF,
  0x01EA,
  0x81FB,
  0x01FE,
  0x01F4,
  0x81F1,
  0x81D3,
  0x01D6,
  0x01DC,
  0x81D9,
  0x01C8,
  0x81CD,
  0x81C7,
  0x01C2,
  0x0140,
  0x8145,
  0x814F,
  0x014A,
  0x815B,
  0x015E,
  0x0154,
  0x8151,
  0x8173,
  0x0176,
  0x017C,
  0x8179,
  0x0168,
  0x816D,
  0x8167,
  0x0162,
  0x8123,
  0x0126,
  0x012C,
  0x8129,
  0x0138,
  0x813D,
  0x8137,
  0x0132,
  0x0110,
  0x8115,
  0x811F,
  0x011A,
  0x810B,
  0x010E,
  0x0104,
  0x8101,
  0x8303,
  0x0306,
  0x030C,
  0x8309,
  0x0318,
  0x831D,
  0x8317,
  0x0312,
  0x0330,
  0x8335,
  0x833F,
  0x033A,
  0x832B,
  0x032E,
  0x0324,
  0x8321,
  0x0360,
  0x8365,
  0x836F,
  0x036A,
  0x837B,
  0x037E,
  0x0374,
  0x8371,
  0x8353,
  0x0356,
  0x035C,
  0x8359,
  0x0348,
  0x834D,
  0x8347,
  0x0342,
  0x03C0,
  0x83C5,
  0x83CF,
  0x03CA,
  0x83DB,
  0x03DE,
  0x03D4,
  0x83D1,
  0x83F3,
  0x03F6,
  0x03FC,
  0x83F9,
  0x03E8,
  0x83ED,
  0x83E7,
  0x03E2,
  0x83A3,
  0x03A6,
  0x03AC,
  0x83A9,
  0x03B8,
  0x83BD,
  0x83B7,
  0x03B2,
  0x0390,
  0x8395,
  0x839F,
  0x039A,
  0x838B,
  0x038E,
  0x0384,
  0x8381,
  0x0280,
  0x8285,
  0x828F,
  0x028A,
  0x829B,
  0x029E,
  0x0294,
  0x8291,
  0x82B3,
  0x02B6,
  0x02BC,
  0x82B9,
  0x02A8,
  0x82AD,
  0x82A7,
  0x02A2,
  0x82E3,
  0x02E6,
  0x02EC,
  0x82E9,
  0x02F8,
  0x82FD,
  0x82F7,
  0x02F2,
  0x02D0,
  0x82D5,
  0x82DF,
  0x02DA,
  0x82CB,
  0x02CE,
  0x02C4,
  0x82C1,
  0x8243,
  0x0246,
  0x024C,
  0x8249,
  0x0258,
  0x825D,
  0x8257,
  0x0252,
  0x0270,
  0x8275,
  0x827F,
  0x027A,
  0x826B,
  0x026E,
  0x0264,
  0x8261,
  0x0220,
  0x8225,
  0x822F,
  0x022A,
  0x823B,
  0x023E,
  0x0234,
  0x8231,
  0x8213,
  0x0216,
  0x021C,
  0x8219,
  0x0208,
  0x820D,
  0x8207,
  0x0202,
];

// ============================================================================
// Bit Writer (for FLAC bitstream construction)
// ============================================================================

class _BitWriter {
  final List<int> _bytes = [];
  int _currentByte = 0;
  int _bitsUsed = 0;

  void write(int value, int numBits) {
    for (int i = numBits - 1; i >= 0; i--) {
      _currentByte = (_currentByte << 1) | ((value >> i) & 1);
      _bitsUsed++;
      if (_bitsUsed == 8) {
        _bytes.add(_currentByte);
        _currentByte = 0;
        _bitsUsed = 0;
      }
    }
  }

  void flush() {
    if (_bitsUsed > 0) {
      _currentByte <<= (8 - _bitsUsed);
      _bytes.add(_currentByte);
      _currentByte = 0;
      _bitsUsed = 0;
    }
  }

  Uint8List toBytes() {
    flush();
    return Uint8List.fromList(_bytes);
  }
}

// ============================================================================
// Bytes Output helper
// ============================================================================

class BytesOutput {
  final List<int> _buffer = [];

  void writeByte(int b) => _buffer.add(b & 0xFF);
  void writeUint16LE(int v) {
    _buffer.add(v & 0xFF);
    _buffer.add((v >> 8) & 0xFF);
  }

  void writeUint16BE(int v) {
    _buffer.add((v >> 8) & 0xFF);
    _buffer.add(v & 0xFF);
  }

  void writeString(String s) {
    for (int i = 0; i < s.length; i++) {
      _buffer.add(s.codeUnitAt(i));
    }
  }

  void addBytes(Uint8List bytes) {
    _buffer.addAll(bytes);
  }

  Uint8List toBytes() => Uint8List.fromList(_buffer);
}

// ============================================================================
// Public API: compression codecs
// ============================================================================

/// Available compression codecs.
enum AudioCodec {
  /// No compression, keep as PCM WAV.
  none,

  /// IMA ADPCM (4:1 compression, lossy, speech-quality).
  adpcm,

  /// FLAC (lossless, ~50-70% of original size).
  flac,

  /// Opus encoder (requires native ffmpeg).
  opus,

  /// MP3 encoder (requires native ffmpeg).
  mp3,
}

/// Compress PCM WAV bytes using the selected codec.
///
/// [pcmBytes] must be the raw PCM data portion of a WAV file (S16LE).
/// Returns the compressed data in the target format.
/// For ADPCM: returns raw ADPCM nibbles (wrapper for WAV ADPCM format).
/// For FLAC: returns complete standalone FLAC file.
/// For opus/mp3: returns original bytes (stub — needs native ffmpeg).
Uint8List compressPcm(Int16List pcmSamples, AudioCodec codec,
    {int sampleRate = 16000}) {
  switch (codec) {
    case AudioCodec.none:
      // Return as S16LE bytes
      final out = Uint8List(pcmSamples.length * 2);
      final dv = ByteData.view(out.buffer);
      for (int i = 0; i < pcmSamples.length; i++) {
        dv.setInt16(i * 2, pcmSamples[i], Endian.little);
      }
      return out;

    case AudioCodec.adpcm:
      return encodeAdpcm(pcmSamples, AdpcmConfig());

    case AudioCodec.flac:
      return encodeFlac(pcmSamples, sampleRate: sampleRate);

    case AudioCodec.opus:
    case AudioCodec.mp3:
      // Requires native ffmpeg — return original as fallback
      return compressPcm(pcmSamples, AudioCodec.none);
  }
}
