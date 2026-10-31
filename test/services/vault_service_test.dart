import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/services/vault_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> secureStorageMock = {};

  setUpAll(() {
    const MethodChannel secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel,
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'read':
          final key = methodCall.arguments['key'] as String?;
          return secureStorageMock[key];
        case 'write':
          final key = methodCall.arguments['key'] as String;
          final value = methodCall.arguments['value'] as String;
          secureStorageMock[key] = value;
          return null;
        case 'delete':
          final key = methodCall.arguments['key'] as String;
          secureStorageMock.remove(key);
          return null;
        case 'deleteAll':
          secureStorageMock.clear();
          return null;
        case 'containsKey':
          final key = methodCall.arguments['key'] as String;
          return secureStorageMock.containsKey(key);
        default:
          return null;
      }
    });

    const MethodChannel localAuthChannel =
        MethodChannel('plugins.flutter.io/local_auth');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel,
            (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'isDeviceSupported':
          return true;
        case 'getAvailableBiometrics':
          return <String>['fingerprint'];
        case 'authenticate':
          return true;
        default:
          return true;
      }
    });
  });

  setUp(() {
    secureStorageMock.clear();
  });

  group('VaultService Security & Encryption Unit Tests', () {
    test('1. Default PIN is 1234 when unconfigured', () async {
      final vault = VaultService.instance;
      expect(await vault.hasPinConfigured(), isFalse);
      expect(await vault.verifyPin('1234'), isTrue);
      expect(await vault.verifyPin('9999'), isFalse);
    });

    test('2. Setting custom PIN updates verification and persistence',
        () async {
      final vault = VaultService.instance;
      await vault.setVaultPin('5678');
      expect(await vault.hasPinConfigured(), isTrue);
      expect(await vault.verifyPin('5678'), isTrue);
      expect(await vault.verifyPin('1234'), isFalse);
    });

    test(
        '3. AES-256 encryption and decryption round-trip restores exact plaintext',
        () async {
      final vault = VaultService.instance;
      const originalText =
          'Highly confidential note content with special chars: 🔐 123 &%!';

      final encrypted = await vault.encryptText(originalText);
      expect(encrypted, isNot(equals(originalText)));
      expect(encrypted.contains(':'), isTrue); // IV:Ciphertext format

      final decrypted = await vault.decryptText(encrypted);
      expect(decrypted, equals(originalText));
    });

    test(
        '4. Encrypting identical text twice generates unique ciphertexts due to random IV',
        () async {
      final vault = VaultService.instance;
      const plain = 'Repeatable security string';

      final enc1 = await vault.encryptText(plain);
      final enc2 = await vault.encryptText(plain);

      expect(enc1, isNot(equals(enc2)));
      expect(await vault.decryptText(enc1), equals(plain));
      expect(await vault.decryptText(enc2), equals(plain));
    });

    test('5. Decrypting plaintext fallback or malformed input does not throw',
        () async {
      final vault = VaultService.instance;
      expect(await vault.decryptText(''), equals(''));
      expect(await vault.decryptText('unencrypted_legacy_text'),
          equals('unencrypted_legacy_text'));
      expect(await vault.decryptText('corrupted:bad_base64_payload=='),
          equals('corrupted:bad_base64_payload=='));
    });

    test('6. Biometrics toggle persists state in secure storage', () async {
      final vault = VaultService.instance;
      expect(await vault.isBiometricsEnabled(), isFalse);
      await vault.setBiometricsEnabled(true);
      expect(await vault.isBiometricsEnabled(), isTrue);
      await vault.setBiometricsEnabled(false);
      expect(await vault.isBiometricsEnabled(), isFalse);
    });
  });
}
