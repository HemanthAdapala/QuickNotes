// backend/src/types.ts
// Domain and API types for QuickNotes Premium Entitlement Backend

export interface Env {
  DB: D1Database;
  PACKAGE_NAME: string;
  PRODUCT_ID: string;
  ISSUER_URL: string;
  PRIMARY_SIGNING_KEY_ID: string;
  SERVER_ALLOWED_SIGNING_KEYS: string; // comma-separated, e.g. "v1,v2"
  MINIMUM_SUPPORTED_APP_VERSION?: string; // integer version code, e.g. "1"
  TOKEN_ENCRYPTION_KEYRING: string; // JSON: { "v1": "<base64_32_bytes>" }
  SIGNING_KEYRING: string; // JSON: { "v1": "<base64_pkcs8_or_raw_ed25519_private_key>" }
  GOOGLE_SERVICE_ACCOUNT_JSON?: string;
}

export type PurchaseStatus = 'ACTIVE' | 'REVOKED';
export type AcknowledgementState = 'PENDING' | 'ACKNOWLEDGED' | 'UNSPECIFIED' | 'NOT_APPLICABLE';

export interface PurchaseRow {
  token_hash: string;
  encrypted_token: string | null;
  key_version: string;
  product_id: string;
  package_name: string;
  status: PurchaseStatus;
  revocation_reason: string | null;
  acknowledgement_state: AcknowledgementState;
  ack_attempt_count: number;
  next_ack_attempt_at: number | null;
  ack_claim_expires_at: number | null;
  last_ack_failure_reason: string | null;
  last_check_status: string;
  purchase_time_ms: number | null;
  state_version: number;
  created_at_ms: number;
  updated_at_ms: number;
}

export interface VerifyPurchaseRequest {
  purchase_token: string;
  package_name: string;
  product_id: string;
  client_version?: number;
  supported_key_versions?: string[];
}

export interface VerifyPurchaseResponse {
  status: 'ACTIVE' | 'REVOKED' | 'PENDING';
  lease_token?: string;
  expires_at?: number; // Unix seconds
  reason?: string;
  error?: string;
}

export interface LeaseClaims {
  iss: string;
  aud: string;
  sub: string;
  entitlement: string;
  product_id: string;
  status: string;
  iat: number;
  nbf: number;
  exp: number;
  jti: string;
}

// Google Play Developer API v3 REST models (purchases.productsv2)
export interface ProductLineItem {
  productId: string;
  expiryTime?: string;
}

export interface PurchaseStateContext {
  purchaseState: 'PURCHASED' | 'PENDING' | 'CANCELLED' | 'PURCHASE_STATE_UNSPECIFIED' | string;
  purchaseCompletionTime?: string;
}

export interface ProductPurchaseV2 {
  packageName: string;
  productLineItem: ProductLineItem[];
  orderId?: string;
  purchaseStateContext?: PurchaseStateContext;
  acknowledgementState?: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' | 'ACKNOWLEDGEMENT_STATE_PENDING' | 'ACKNOWLEDGEMENT_STATE_UNSPECIFIED' | string;
}

export type EvaluatedPurchaseState = 'PURCHASED' | 'PENDING' | 'CANCELLED' | 'INDETERMINATE';
export type EvaluatedAckState = 'ACKNOWLEDGED' | 'PENDING' | 'UNSPECIFIED' | 'NOT_APPLICABLE';

export interface EvaluatedValidationResult {
  purchaseState: EvaluatedPurchaseState;
  acknowledgementState: EvaluatedAckState;
  rawPurchaseState: string;
  rawAckState: string;
  purchaseCompletionTimeMs: number | null;
  error?: string;
}
