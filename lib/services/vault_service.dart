import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;

class VaultService {
  VaultService._privateConstructor();
  static final VaultService instance = VaultService._privateConstructor();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Checks if biometric authentication is available on the device
  Future<bool> get isBiometricAvailable async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  // Authenticate using biometrics (Fingerprint / Face ID)
  Future<bool> authenticateBiometrically() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint or face to access Secure Vault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (e) {
      return false;
    }
  }

  // Initialize or fetch the Master Encryption Key
  Future<String> _getOrCreateMasterKey() async {
    String? masterKey = await _secureStorage.read(key: 'vault_master_key');
    if (masterKey == null) {
      // Generate random 256-bit (32-byte) key
      final key = enc.Key.fromSecureRandom(32);
      masterKey = key.base64;
      await _secureStorage.write(key: 'vault_master_key', value: masterKey);
    }
    return masterKey;
  }

  // Set or change vault PIN passcode
  Future<void> setVaultPin(String pin) async {
    await _secureStorage.write(key: 'vault_pin', value: pin);
    // Ensure master key is initialized
    await _getOrCreateMasterKey();
  }

  // Verify entered PIN passcode
  Future<bool> verifyPin(String pin) async {
    final storedPin = await _secureStorage.read(key: 'vault_pin');
    // If no pin is set, default PIN is '1234'
    if (storedPin == null) {
      return pin == '1234';
    }
    return storedPin == pin;
  }

  // Check if a custom PIN is already set
  Future<bool> hasPinConfigured() async {
    final pin = await _secureStorage.read(key: 'vault_pin');
    return pin != null;
  }

  // Get/Set Biometric setting
  Future<bool> isBiometricsEnabled() async {
    final enabled = await _secureStorage.read(key: 'vault_biometrics_enabled');
    return enabled == 'true';
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _secureStorage.write(key: 'vault_biometrics_enabled', value: enabled ? 'true' : 'false');
  }

  // AES-256-CBC encryption of plain text notes content
  Future<String> encryptText(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;
    final keyBase64 = await _getOrCreateMasterKey();
    final key = enc.Key.fromBase64(keyBase64);
    final iv = enc.IV.fromSecureRandom(16); // 16-byte random initialization vector
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    // Prepend IV so that every encryption of the same text looks unique
    return "${base64Encode(iv.bytes)}:${encrypted.base64}";
  }


  // AES-256-CBC decryption
  Future<String> decryptText(String ciphertextWithIv) async {
    if (ciphertextWithIv.isEmpty) return ciphertextWithIv;
    try {
      final parts = ciphertextWithIv.split(':');
      if (parts.length != 2) {
        // Plaintext fallback if note was previously unencrypted
        return ciphertextWithIv;
      }
      
      final keyBase64 = await _getOrCreateMasterKey();
      final key = enc.Key.fromBase64(keyBase64);
      final iv = enc.IV(base64Decode(parts[0]));
      final encrypted = enc.Encrypted.fromBase64(parts[1]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return ciphertextWithIv;
    }
  }
}
