import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/premium/crypto/ed25519.dart';

void main() {
  group('Ed25519 RFC 8032 Pure Dart Verification Tests', () {
    test('RFC 8032 Test Vector 1 (Empty message)', () {
      final publicKey = _hexToBytes(
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
      );
      final signature = _hexToBytes(
        'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
      );
      final message = Uint8List(0);

      final isValid = Ed25519.verify(
        publicKey: publicKey,
        message: message,
        signature: signature,
      );

      expect(isValid, isTrue);
    });

    test('RFC 8032 Test Vector 2 (1-byte message)', () {
      final publicKey = _hexToBytes(
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
      );
      final signature = _hexToBytes(
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      );
      final message = Uint8List.fromList([0x72]);

      final isValid = Ed25519.verify(
        publicKey: publicKey,
        message: message,
        signature: signature,
      );

      expect(isValid, isTrue);
    });

    test('Signs message and verifies correctly (Roundtrip)', () {
      final seed = Uint8List.fromList(List.generate(32, (i) => i * 7 + 3));
      final pubKey = Ed25519.publicKeyFromSeed(seed);
      final message = Uint8List.fromList(utf8.encode('QuickNotes JWS Test Payload'));

      final sig = Ed25519.sign(seed: seed, message: message);
      expect(sig.length, equals(64));

      final ok = Ed25519.verify(
        publicKey: pubKey,
        message: message,
        signature: sig,
      );
      expect(ok, isTrue);
    });

    test('Rejects tampered signature byte', () {
      final publicKey = _hexToBytes(
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
      );
      final signature = _hexToBytes(
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      );
      // Flip one byte
      signature[10] ^= 0xFF;
      final message = Uint8List.fromList([0x72]);

      final isValid = Ed25519.verify(
        publicKey: publicKey,
        message: message,
        signature: signature,
      );

      expect(isValid, isFalse);
    });

    test('Rejects signature for wrong message content', () {
      final publicKey = _hexToBytes(
        '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
      );
      final signature = _hexToBytes(
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      );
      final wrongMessage = Uint8List.fromList([0x73]); // altered from 0x72

      final isValid = Ed25519.verify(
        publicKey: publicKey,
        message: wrongMessage,
        signature: signature,
      );

      expect(isValid, isFalse);
    });

    test('Rejects signature verified with wrong public key', () {
      final wrongPublicKey = _hexToBytes(
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
      );
      final signature = _hexToBytes(
        '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      );
      final message = Uint8List.fromList([0x72]);

      final isValid = Ed25519.verify(
        publicKey: wrongPublicKey,
        message: message,
        signature: signature,
      );

      expect(isValid, isFalse);
    });

    test('Rejects invalid length public key or signature', () {
      final shortKey = Uint8List(16);
      final normalSig = Uint8List(64);
      final msg = Uint8List(0);

      expect(
        Ed25519.verify(publicKey: shortKey, message: msg, signature: normalSig),
        isFalse,
      );

      final normalKey = Uint8List(32);
      final shortSig = Uint8List(32);
      expect(
        Ed25519.verify(publicKey: normalKey, message: msg, signature: shortSig),
        isFalse,
      );
    });
  });
}

Uint8List _hexToBytes(String hex) {
  final cleanHex = hex.replaceAll(' ', '');
  final bytes = Uint8List(cleanHex.length ~/ 2);
  for (var i = 0; i < cleanHex.length; i += 2) {
    bytes[i ~/ 2] = int.parse(cleanHex.substring(i, i + 2), radix: 16);
  }
  return bytes;
}
