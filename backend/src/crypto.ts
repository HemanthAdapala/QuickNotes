// backend/src/crypto.ts
// Cryptographic utilities using WebCrypto SubtleCrypto APIs

import { LeaseClaims } from './types';

export function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

export function base64UrlToBytes(str: string): Uint8Array {
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4 !== 0) {
    base64 += '=';
  }
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export function stringToBytes(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

export function bytesToString(bytes: Uint8Array): string {
  return new TextDecoder().decode(bytes);
}

export async function sha256Hex(message: string): Promise<string> {
  const data = stringToBytes(message);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// ── AES-256-GCM Token Encryption at Rest ──────────────────────────────────────
// Format: "{key_version}:{iv_base64}:{ciphertext_and_tag_base64}"

export async function encryptToken(
  rawToken: string,
  keyVersion: string,
  keyringJson: string
): Promise<string> {
  const keyring: Record<string, string> = JSON.parse(keyringJson);
  const keyBase64 = keyring[keyVersion];
  if (!keyBase64) {
    throw new Error(`Encryption key version "${keyVersion}" not found in keyring`);
  }

  const rawKeyBytes = base64ToBytes(keyBase64);
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    rawKeyBytes,
    { name: 'AES-GCM' },
    false,
    ['encrypt']
  );

  // 12-byte IV for AES-GCM
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const plaintextBytes = stringToBytes(rawToken);

  const encryptedBuffer = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    cryptoKey,
    plaintextBytes
  );

  const ciphertextBase64 = bytesToBase64(new Uint8Array(encryptedBuffer));
  const ivBase64 = bytesToBase64(iv);

  return `${keyVersion}:${ivBase64}:${ciphertextBase64}`;
}

export async function decryptToken(
  encryptedPayload: string,
  keyringJson: string
): Promise<string> {
  const parts = encryptedPayload.split(':');
  if (parts.length !== 3) {
    throw new Error('Invalid encrypted token payload format');
  }

  const [keyVersion, ivBase64, ciphertextBase64] = parts;
  const keyring: Record<string, string> = JSON.parse(keyringJson);
  const keyBase64 = keyring[keyVersion];
  if (!keyBase64) {
    throw new Error(`Decryption key version "${keyVersion}" not found in keyring`);
  }

  const rawKeyBytes = base64ToBytes(keyBase64);
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    rawKeyBytes,
    { name: 'AES-GCM' },
    false,
    ['decrypt']
  );

  const iv = base64ToBytes(ivBase64);
  const ciphertextBytes = base64ToBytes(ciphertextBase64);

  const decryptedBuffer = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    cryptoKey,
    ciphertextBytes
  );

  return bytesToString(new Uint8Array(decryptedBuffer));
}

// ── Ed25519 Compact JWS Lease Signing ─────────────────────────────────────────

export async function signJwsLease(
  claims: LeaseClaims,
  keyId: string,
  signingKeyringJson: string
): Promise<string> {
  const keyring: Record<string, string> = JSON.parse(signingKeyringJson);
  const privateKeyB64 = keyring[keyId];
  if (!privateKeyB64) {
    throw new Error(`Signing key "${keyId}" not found in signing keyring`);
  }

  const privateKeyBytes = base64ToBytes(privateKeyB64);

  // Import Ed25519 private key (supports PKCS#8 or raw 32-byte seed depending on format)
  let cryptoKey: CryptoKey;
  try {
    cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      privateKeyBytes,
      { name: 'Ed25519' },
      false,
      ['sign']
    );
  } catch (_) {
    // Fallback: If 32-byte raw seed is provided, wrap in standard PKCS#8 prefix for Ed25519:
    // 302e020100300506032b657004220420 + 32-byte-seed
    if (privateKeyBytes.length === 32) {
      const pkcs8Prefix = new Uint8Array([
        0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70,
        0x04, 0x22, 0x04, 0x20
      ]);
      const fullPkcs8 = new Uint8Array(pkcs8Prefix.length + privateKeyBytes.length);
      fullPkcs8.set(pkcs8Prefix, 0);
      fullPkcs8.set(privateKeyBytes, pkcs8Prefix.length);
      cryptoKey = await crypto.subtle.importKey(
        'pkcs8',
        fullPkcs8,
        { name: 'Ed25519' },
        false,
        ['sign']
      );
    } else {
      throw new Error(`Unable to import Ed25519 private key for keyId ${keyId}`);
    }
  }

  const header = {
    alg: 'EdDSA',
    typ: 'JWT',
    kid: keyId
  };

  const encodedHeader = bytesToBase64Url(stringToBytes(JSON.stringify(header)));
  const encodedPayload = bytesToBase64Url(stringToBytes(JSON.stringify(claims)));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const signatureBuffer = await crypto.subtle.sign(
    'Ed25519',
    cryptoKey,
    stringToBytes(signingInput)
  );

  const encodedSignature = bytesToBase64Url(new Uint8Array(signatureBuffer));
  return `${signingInput}.${encodedSignature}`;
}
