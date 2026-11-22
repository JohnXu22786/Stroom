/// xxHash64 for raw byte sequences, with explicit unsigned 64-bit arithmetic.
BigInt xxHash64(List<int> bytes, {BigInt? seed}) {
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  final p1 = BigInt.parse('9e3779b185ebca87', radix: 16);
  final p2 = BigInt.parse('c2b2ae3d27d4eb4f', radix: 16);
  final p3 = BigInt.parse('165667b19e3779f9', radix: 16);
  final p4 = BigInt.parse('85ebca77c2b2ae63', radix: 16);
  final p5 = BigInt.parse('27d4eb2f165667c5', radix: 16);
  final initialSeed = seed ?? BigInt.zero;
  BigInt u(BigInt value) => value & mask;
  BigInt rotate(BigInt value, int bits) =>
      u((value << bits) | (value >> (64 - bits)));
  BigInt read64(int offset) {
    var value = BigInt.zero;
    for (var i = 0; i < 8; i++) {
      value |= BigInt.from(bytes[offset + i] & 0xff) << (8 * i);
    }
    return value;
  }

  BigInt round(BigInt acc, BigInt input) =>
      u(rotate(u(acc + u(input * p2)), 31) * p1);
  BigInt merge(BigInt acc, BigInt value) =>
      u(u(acc ^ round(BigInt.zero, value)) * p1 + p4);

  final length = bytes.length;
  var offset = 0;
  late BigInt hash;
  if (length >= 32) {
    var v1 = u(initialSeed + p1 + p2);
    var v2 = u(initialSeed + p2);
    var v3 = u(initialSeed);
    var v4 = u(initialSeed - p1);
    while (offset <= length - 32) {
      v1 = round(v1, read64(offset));
      v2 = round(v2, read64(offset + 8));
      v3 = round(v3, read64(offset + 16));
      v4 = round(v4, read64(offset + 24));
      offset += 32;
    }
    hash = u(rotate(v1, 1) + rotate(v2, 7) + rotate(v3, 12) + rotate(v4, 18));
    hash = merge(merge(merge(merge(hash, v1), v2), v3), v4);
  } else {
    hash = u(initialSeed + p5);
  }
  hash = u(hash + BigInt.from(length));
  while (offset <= length - 8) {
    hash = u(rotate(hash ^ round(BigInt.zero, read64(offset)), 27) * p1 + p4);
    offset += 8;
  }
  if (offset <= length - 4) {
    var word = BigInt.zero;
    for (var i = 0; i < 4; i++) {
      word |= BigInt.from(bytes[offset + i] & 0xff) << (8 * i);
    }
    hash = u(rotate(hash ^ u(word * p1), 23) * p2 + p3);
    offset += 4;
  }
  while (offset < length) {
    hash = u(rotate(hash ^ u(BigInt.from(bytes[offset] & 0xff) * p5), 11) * p1);
    offset++;
  }
  hash ^= hash >> 33;
  hash = u(hash * p2);
  hash ^= hash >> 29;
  hash = u(hash * p3);
  hash ^= hash >> 32;
  return u(hash);
}
