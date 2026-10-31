// backend/src/google-play.ts
// Google Play Developer API v3 REST Client and Evaluation Logic

import {
  EvaluatedValidationResult,
  ProductPurchaseV2
} from './types';
import { bytesToBase64Url, stringToBytes } from './crypto';

// In-memory token cache within the isolate
let cachedAccessToken: { token: string; expiresAtMs: number } | null = null;

export function evaluateGooglePlayResponse(
  data: ProductPurchaseV2,
  expectedPackage: string,
  expectedSku: string
): EvaluatedValidationResult {
  // 1. Package Name Validation
  if (!data.packageName || data.packageName !== expectedPackage) {
    return {
      purchaseState: 'INDETERMINATE',
      acknowledgementState: 'UNSPECIFIED',
      rawPurchaseState: 'INVALID_PACKAGE',
      rawAckState: 'INVALID_PACKAGE',
      purchaseCompletionTimeMs: null,
      error: 'PACKAGE_NAME_MISMATCH'
    };
  }

  // 2. Line Item & SKU Validation
  const hasValidSku = data.productLineItem?.some(item => item.productId === expectedSku);
  if (!hasValidSku) {
    return {
      purchaseState: 'INDETERMINATE',
      acknowledgementState: 'UNSPECIFIED',
      rawPurchaseState: 'SKU_MISMATCH',
      rawAckState: 'SKU_MISMATCH',
      purchaseCompletionTimeMs: null,
      error: 'PRODUCT_ID_NOT_FOUND'
    };
  }

  // 3. Purchase State Evaluation (Fail-Closed)
  const rawPurchase = data.purchaseStateContext?.purchaseState ?? 'MISSING';
  let evaluatedPurchase: EvaluatedValidationResult['purchaseState'];
  switch (rawPurchase) {
    case 'PURCHASED':
      evaluatedPurchase = 'PURCHASED';
      break;
    case 'PENDING':
      evaluatedPurchase = 'PENDING';
      break;
    case 'CANCELLED':
      evaluatedPurchase = 'CANCELLED';
      break;
    default:
      // Unknown enum or PURCHASE_STATE_UNSPECIFIED: Indeterminate; never assume cancellation
      evaluatedPurchase = 'INDETERMINATE';
      break;
  }

  // 4. Acknowledgement State Evaluation (Fail-Closed; Do NOT coerce to PENDING)
  const rawAck = data.acknowledgementState ?? 'MISSING';
  let evaluatedAck: EvaluatedValidationResult['acknowledgementState'];
  switch (rawAck) {
    case 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED':
      evaluatedAck = 'ACKNOWLEDGED';
      break;
    case 'ACKNOWLEDGEMENT_STATE_PENDING':
      evaluatedAck = 'PENDING';
      break;
    default:
      // Unknown enum, ACKNOWLEDGEMENT_STATE_UNSPECIFIED, or missing: Strictly indeterminate
      evaluatedAck = 'UNSPECIFIED';
      break;
  }

  // 5. Parse purchaseCompletionTime (RFC 3339 string to Unix ms)
  let completionTimeMs: number | null = null;
  const rawTime = data.purchaseStateContext?.purchaseCompletionTime;
  if (rawTime) {
    const parsed = Date.parse(rawTime);
    if (!isNaN(parsed)) {
      completionTimeMs = parsed;
    }
  }

  return {
    purchaseState: evaluatedPurchase,
    acknowledgementState: evaluatedAck,
    rawPurchaseState: String(rawPurchase),
    rawAckState: String(rawAck),
    purchaseCompletionTimeMs: completionTimeMs
  };
}

export async function getGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  const now = Date.now();
  if (cachedAccessToken && cachedAccessToken.expiresAtMs > now + 60000) {
    return cachedAccessToken.token;
  }

  const sa = JSON.parse(serviceAccountJson);
  const nowSec = Math.floor(now / 1000);
  const expSec = nowSec + 3600;

  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    exp: expSec,
    iat: nowSec
  };

  const encodedHeader = bytesToBase64Url(stringToBytes(JSON.stringify(header)));
  const encodedClaims = bytesToBase64Url(stringToBytes(JSON.stringify(claimSet)));
  const signingInput = `${encodedHeader}.${encodedClaims}`;

  // Clean and import RSA private key
  const pem = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const binaryDer = atob(pem);
  const keyBytes = new Uint8Array(binaryDer.length);
  for (let i = 0; i < binaryDer.length; i++) {
    keyBytes[i] = binaryDer.charCodeAt(i);
  }

  const rsaKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const sigBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    rsaKey,
    stringToBytes(signingInput)
  );

  const assertion = `${signingInput}.${bytesToBase64Url(new Uint8Array(sigBuffer))}`;

  const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion
    })
  });

  if (!tokenResp.ok) {
    const errText = await tokenResp.text();
    throw new Error(`Google OAuth2 token exchange failed (${tokenResp.status}): ${errText}`);
  }

  const tokenData = (await tokenResp.json()) as { access_token: string; expires_in: number };
  cachedAccessToken = {
    token: tokenData.access_token,
    expiresAtMs: now + (tokenData.expires_in * 1000)
  };

  return cachedAccessToken.token;
}

export async function fetchProductPurchaseV2(
  packageName: string,
  token: string,
  accessToken: string
): Promise<{ status: number; data?: ProductPurchaseV2; errorText?: string }> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(
    packageName
  )}/purchases/productsv2/tokens/${encodeURIComponent(token)}`;

  try {
    const resp = await fetch(url, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json'
      }
    });

    if (resp.status === 200) {
      const data = (await resp.json()) as ProductPurchaseV2;
      return { status: 200, data };
    } else {
      const errorText = await resp.text();
      return { status: resp.status, errorText };
    }
  } catch (err: any) {
    return { status: 502, errorText: String(err?.message ?? err) };
  }
}

export async function acknowledgePurchase(
  packageName: string,
  productId: string,
  token: string,
  accessToken: string
): Promise<{ status: number; errorText?: string }> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(
    packageName
  )}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}:acknowledge`;

  try {
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({})
    });

    if (resp.status === 200 || resp.status === 204) {
      return { status: resp.status };
    } else {
      const errorText = await resp.text();
      return { status: resp.status, errorText };
    }
  } catch (err: any) {
    return { status: 502, errorText: String(err?.message ?? err) };
  }
}
