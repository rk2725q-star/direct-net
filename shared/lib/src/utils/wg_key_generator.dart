import 'dart:typed_data';
import 'dart:math';

/// WireGuard uses Curve25519 (X25519) for key pairs.
/// This is a self-contained pure-Dart implementation — no external X25519
/// classes needed from pointycastle (which doesn't expose them in 3.x).
class WgKeyGenerator {
  /// Generate a WireGuard-compatible Curve25519 private key (base64 encoded)
  static String generatePrivateKey() {
    final bytes = _randomBytes(32);
    // RFC 7748 clamping — required by WireGuard spec
    bytes[0] &= 248;
    bytes[31] &= 127;
    bytes[31] |= 64;
    return _b64Encode(bytes);
  }

  /// Derive the Curve25519 public key from a private key (base64 encoded)
  static String derivePublicKey(String privateKeyBase64) {
    final scalar = _b64Decode(privateKeyBase64);
    final pub = _x25519(scalar, _basePoint());
    return _b64Encode(pub);
  }

  /// Generate a complete key pair {privateKey, publicKey} — both base64
  static Map<String, String> generateKeyPair() {
    final priv = generatePrivateKey();
    final pub = derivePublicKey(priv);
    return {'privateKey': priv, 'publicKey': pub};
  }

  // ── Curve25519 / X25519 ───────────────────────────────────────────────────

  static final BigInt _p =
      BigInt.parse('7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed',
          radix: 16);
  static final BigInt _a24 = BigInt.from(121665);

  /// Curve25519 base point u = 9 as 32-byte little-endian
  static Uint8List _basePoint() {
    final u = Uint8List(32);
    u[0] = 9;
    return u;
  }

  /// X25519 scalar multiplication: returns u-coordinate of scalar * point(u)
  static Uint8List _x25519(Uint8List kBytes, Uint8List uBytes) {
    // Clamp scalar
    final k = Uint8List.fromList(kBytes);
    k[0] &= 248;
    k[31] &= 127;
    k[31] |= 64;

    // u-coordinate as little-endian BigInt, masked to 255 bits
    BigInt u = _leToInt(uBytes) % _p;

    // Montgomery ladder
    BigInt x1 = u;
    BigInt x2 = BigInt.one;
    BigInt z2 = BigInt.zero;
    BigInt x3 = u;
    BigInt z3 = BigInt.one;
    int swap = 0;

    for (int t = 254; t >= 0; t--) {
      final kBit = ((k[t >> 3] >> (t & 7)) & 1);
      swap ^= kBit;
      if (swap == 1) {
        BigInt tmp;
        tmp = x2; x2 = x3; x3 = tmp;
        tmp = z2; z2 = z3; z3 = tmp;
      }
      swap = kBit;

      final a  = (x2 + z2) % _p;
      final aa = (a * a) % _p;
      final b  = (x2 - z2 + _p) % _p;
      final bb = (b * b) % _p;
      final e  = (aa - bb + _p) % _p;
      final c  = (x3 + z3) % _p;
      final d  = (x3 - z3 + _p) % _p;
      final da = (d * a) % _p;
      final cb = (c * b) % _p;

      x3 = _modpow((da + cb) % _p, BigInt.two, _p);
      z3 = (x1 * _modpow((da - cb + _p) % _p, BigInt.two, _p)) % _p;
      x2 = (aa * bb) % _p;
      z2 = (e * ((aa + _a24 * e) % _p)) % _p;
    }

    if (swap == 1) {
      BigInt tmp;
      tmp = x2; x2 = x3; x3 = tmp;
      tmp = z2; z2 = z3; z3 = tmp;
    }

    final result = (x2 * _modpow(z2, _p - BigInt.two, _p)) % _p;
    return _intToLe(result);
  }

  static BigInt _modpow(BigInt base, BigInt exp, BigInt mod) =>
      base.modPow(exp, mod);

  static BigInt _leToInt(Uint8List bytes) {
    BigInt n = BigInt.zero;
    for (int i = bytes.length - 1; i >= 0; i--) {
      n = (n << 8) | BigInt.from(bytes[i]);
    }
    return n;
  }

  static Uint8List _intToLe(BigInt n) {
    final out = Uint8List(32);
    BigInt val = n;
    for (int i = 0; i < 32; i++) {
      out[i] = (val & BigInt.from(0xFF)).toInt();
      val >>= 8;
    }
    return out;
  }

  // ── Random bytes ──────────────────────────────────────────────────────────

  static Uint8List _randomBytes(int len) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(len, (_) => rng.nextInt(256)));
  }

  // ── Base64 (standard, no line breaks) ─────────────────────────────────────

  static const _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  static String _b64Encode(Uint8List bytes) {
    final buf = StringBuffer();
    for (int i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      buf.write(_chars[(b0 >> 2) & 63]);
      buf.write(_chars[((b0 << 4) | (b1 >> 4)) & 63]);
      buf.write(i + 1 < bytes.length ? _chars[((b1 << 2) | (b2 >> 6)) & 63] : '=');
      buf.write(i + 2 < bytes.length ? _chars[b2 & 63] : '=');
    }
    return buf.toString();
  }

  static Uint8List _b64Decode(String b64) {
    final s = b64.replaceAll('-', '+').replaceAll('_', '/');
    final padded = s.padRight((s.length + 3) ~/ 4 * 4, '=');
    final out = <int>[];
    for (int i = 0; i < padded.length; i += 4) {
      final c0 = _chars.indexOf(padded[i]);
      final c1 = _chars.indexOf(padded[i + 1]);
      final c2 = padded[i + 2] == '=' ? 0 : _chars.indexOf(padded[i + 2]);
      final c3 = padded[i + 3] == '=' ? 0 : _chars.indexOf(padded[i + 3]);
      out.add((c0 << 2) | (c1 >> 4));
      if (padded[i + 2] != '=') out.add(((c1 & 0xF) << 4) | (c2 >> 2));
      if (padded[i + 3] != '=') out.add(((c2 & 0x3) << 6) | c3);
    }
    return Uint8List.fromList(out);
  }
}
