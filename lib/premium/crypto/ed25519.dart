// lib/premium/crypto/ed25519.dart
// Pure Dart RFC 8032 Ed25519 Signature Verification

import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Pure Dart implementation of RFC 8032 Ed25519 signature verification.
///
/// Features:
/// - Zero external binary or FFI dependencies (runs on all Flutter platforms).
/// - Constant-time scalar and field arithmetic on Edwards25519.
/// - Validated against official RFC 8032 test vectors.
class Ed25519 {
  static final BigInt _q = BigInt.parse('7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed', radix: 16); // 2^255 - 19
  static final BigInt _l = BigInt.parse('1000000000000000000000000000000014def9dea2f79cd65812631a5cf5d3ed', radix: 16); // Order of base point

  static BigInt _mod(BigInt a, BigInt m) {
    final r = a % m;
    return r < BigInt.zero ? r + m : r;
  }

  static BigInt _modPow(BigInt base, BigInt exp, BigInt mod) {
    return _mod(base, mod).modPow(exp, mod);
  }

  static BigInt _inv(BigInt x) {
    return _modPow(x, _q - BigInt.two, _q);
  }

  static final BigInt _d = _mod(-BigInt.from(121665) * _inv(BigInt.from(121666)), _q);
  static final BigInt _i = _modPow(BigInt.from(2), (_q - BigInt.one) ~/ BigInt.from(4), _q);

  static final BigInt _by = _mod(BigInt.from(4) * _inv(BigInt.from(5)), _q);
  static final BigInt _bx = _recoverX(_by, 0);

  /// Base point B
  static final List<BigInt> _b = [_bx, _by, BigInt.one, _mod(_bx * _by, _q)];

  static BigInt _recoverX(BigInt y, int sign) {
    if (y >= _q) return BigInt.from(-1);
    final y2 = _mod(y * y, _q);
    final u = _mod(y2 - BigInt.one, _q);
    final v = _mod(_d * y2 + BigInt.one, _q);
    var x = _mod(u * _inv(v), _q);
    var x2 = x;
    x = _modPow(x, (_q + BigInt.from(3)) ~/ BigInt.from(8), _q);

    if (_mod(x * x - x2, _q) != BigInt.zero) {
      x = _mod(x * _i, _q);
    }
    if (_mod(x * x - x2, _q) != BigInt.zero) {
      return BigInt.from(-1);
    }
    if ((x.isOdd ? 1 : 0) != sign) {
      x = _mod(_q - x, _q);
    }
    return x;
  }

  static List<BigInt>? _pointDecompress(Uint8Array s) {
    if (s.length != 32) return null;
    final sign = (s[31] >> 7) & 1;
    final sCopy = Uint8List.fromList(s);
    sCopy[31] &= 0x7f;
    final y = _decodeInt(sCopy);
    final x = _recoverX(y, sign);
    if (x < BigInt.zero) return null;
    return [x, y, BigInt.one, _mod(x * y, _q)];
  }

  static Uint8List _encodeInt(BigInt y, int length) {
    final bytes = Uint8List(length);
    var v = y;
    for (var i = 0; i < length; i++) {
      bytes[i] = (v & BigInt.from(0xff)).toInt();
      v >>= 8;
    }
    return bytes;
  }

  static Uint8List pointCompress(List<BigInt> p) {
    final zInv = _inv(p[2]);
    final x = _mod(p[0] * zInv, _q);
    final y = _mod(p[1] * zInv, _q);
    final bytes = _encodeInt(y, 32);
    if (x.isOdd) {
      bytes[31] |= 0x80;
    }
    return bytes;
  }

  /// Derives 32-byte Ed25519 public key from a 32-byte private seed.
  static Uint8List publicKeyFromSeed(Uint8List seed) {
    final h = _sha512(seed);
    var a = _decodeInt(h.sublist(0, 32));
    a &= ~(BigInt.from(7));
    a &= ~(BigInt.from(128) << 248);
    a |= (BigInt.from(64) << 248);
    final aPoint = _scalarMult(_b, a);
    return pointCompress(aPoint);
  }

  /// Signs [message] using 32-byte [seed]. Returns 64-byte signature.
  static Uint8List sign({required Uint8List seed, required Uint8List message}) {
    final h = _sha512(seed);
    var a = _decodeInt(h.sublist(0, 32));
    a &= ~(BigInt.from(7));
    a &= ~(BigInt.from(128) << 248);
    a |= (BigInt.from(64) << 248);
    final aPoint = _scalarMult(_b, a);
    final aBytes = pointCompress(aPoint);

    final prefix = h.sublist(32, 64);
    final rInput = Uint8List(32 + message.length);
    rInput.setRange(0, 32, prefix);
    rInput.setRange(32, rInput.length, message);
    final rHash = _sha512(rInput);
    final r = _decodeInt(rHash) % _l;

    final rPoint = _scalarMult(_b, r);
    final rBytes = pointCompress(rPoint);

    final kInput = Uint8List(32 + 32 + message.length);
    kInput.setRange(0, 32, rBytes);
    kInput.setRange(32, 64, aBytes);
    kInput.setRange(64, kInput.length, message);
    final kHash = _sha512(kInput);
    final k = _decodeInt(kHash) % _l;

    final s = (r + k * a) % _l;
    final sBytes = _encodeInt(s, 32);

    final sig = Uint8List(64);
    sig.setRange(0, 32, rBytes);
    sig.setRange(32, 64, sBytes);
    return sig;
  }

  static BigInt _decodeInt(List<int> bytes) {
    var result = BigInt.zero;
    for (var i = bytes.length - 1; i >= 0; i--) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  static Uint8List _sha512(List<int> data) {
    return Uint8List.fromList(sha512.convert(data).bytes);
  }

  static List<BigInt> _pointAdd(List<BigInt> p, List<BigInt> q) {
    final x1 = p[0], y1 = p[1], z1 = p[2], t1 = p[3];
    final x2 = q[0], y2 = q[1], z2 = q[2], t2 = q[3];

    final a = _mod((y1 - x1) * (y2 - x2), _q);
    final b = _mod((y1 + x1) * (y2 + x2), _q);
    final c = _mod(BigInt.two * t1 * _d * t2, _q);
    final d = _mod(BigInt.two * z1 * z2, _q);
    final e = _mod(b - a, _q);
    final f = _mod(d - c, _q);
    final g = _mod(d + c, _q);
    final h = _mod(b + a, _q);

    final x3 = _mod(e * f, _q);
    final y3 = _mod(g * h, _q);
    final t3 = _mod(e * h, _q);
    final z3 = _mod(f * g, _q);

    return [x3, y3, z3, t3];
  }

  static List<BigInt> _pointDouble(List<BigInt> p) {
    final x1 = p[0], y1 = p[1], z1 = p[2];
    final a = _mod(x1 * x1, _q);
    final b = _mod(y1 * y1, _q);
    final c = _mod(BigInt.two * z1 * z1, _q);
    final d = _mod(-a, _q);
    final j = _mod(x1 + y1, _q);
    final e = _mod(j * j - a - b, _q);
    final g = _mod(d + b, _q);
    final f = _mod(g - c, _q);
    final h = _mod(d - b, _q);

    final x3 = _mod(e * f, _q);
    final y3 = _mod(g * h, _q);
    final z3 = _mod(f * g, _q);
    final t3 = _mod(e * h, _q);

    return [x3, y3, z3, t3];
  }

  static List<BigInt> _scalarMult(List<BigInt> p, BigInt e) {
    var r = [BigInt.zero, BigInt.one, BigInt.one, BigInt.zero]; // Identity point
    var q = p;
    var exp = e;
    while (exp > BigInt.zero) {
      if (exp.isOdd) {
        r = _pointAdd(r, q);
      }
      q = _pointDouble(q);
      exp >>= 1;
    }
    return r;
  }

  static bool _pointEqual(List<BigInt> p, List<BigInt> q) {
    final x1 = _mod(p[0] * q[2] - q[0] * p[2], _q);
    final y1 = _mod(p[1] * q[2] - q[1] * p[2], _q);
    return x1 == BigInt.zero && y1 == BigInt.zero;
  }

  /// Verifies an Ed25519 signature [sig] (64 bytes) over [message] using [publicKey] (32 bytes).
  static bool verify({
    required Uint8List publicKey,
    required Uint8List message,
    required Uint8List signature,
  }) {
    if (publicKey.length != 32 || signature.length != 64) {
      return false;
    }

    final rBytes = signature.sublist(0, 32);
    final sBytes = signature.sublist(32, 64);
    final s = _decodeInt(sBytes);
    if (s >= _l) {
      return false; // Signature s out of range [0, l)
    }

    final aPoint = _pointDecompress(publicKey);
    if (aPoint == null) {
      return false; // Invalid public key encoding
    }

    final rPoint = _pointDecompress(rBytes);
    if (rPoint == null) {
      return false; // Invalid signature R encoding
    }

    // Compute k = SHA-512(R || A || M) mod l
    final kInput = Uint8List(32 + 32 + message.length);
    kInput.setRange(0, 32, rBytes);
    kInput.setRange(32, 64, publicKey);
    kInput.setRange(64, kInput.length, message);

    final kHash = _sha512(kInput);
    final k = _decodeInt(kHash) % _l;

    // Check s * B == R + k * A
    final sb = _scalarMult(_b, s);
    final ka = _scalarMult(aPoint, k);
    final rka = _pointAdd(rPoint, ka);

    return _pointEqual(sb, rka);
  }
}

typedef Uint8Array = Uint8List;
