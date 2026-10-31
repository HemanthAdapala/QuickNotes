# BUG-001 — Production Deployment & Operator Runbook

> **Scope:** Cloudflare Worker & D1 Backend Deployment, Google Play Service Account Linking, Cryptographic Key Provisioning, and Android Release Configuration for Quick Notes Premium Entitlements (BUG-001).  
> **Status:** Local verification complete. Awaiting Owner Approval for cloud deployment and live credentials.

---

## 1. Preflight Checklist

Before starting production provisioning, verify the following prerequisites:

- [ ] **Owner Approval:** Production deployment and key provisioning explicitly authorized by project owner.
- [ ] **Cloudflare Account:** Active account with Cloudflare Workers and D1 enabled.
- [ ] **Cloudflare Account ID Verified:** Confirm target account ID via `npx wrangler whoami` (prevent multi-account misdirection).
- [ ] **Node.js Environment:** Node.js 20+ installed on host machine.
- [ ] **Google Cloud Platform:** Access to Google Cloud Console with authority to create Service Accounts.
- [ ] **Google Play Developer Console:** Account Owner or Admin access to `com.quicknotes.byhmnth`.
- [ ] **Physical Android Test Device:** Connected via ADB and configured as an internal tester on Google Play.

---

## 2. Secure Cryptographic Key Provisioning

All production keys must be generated locally on the operator's machine. **NEVER** paste private keys, seeds, or secret keyrings into chat, code repositories, issue trackers, or unencrypted logs.

> [!WARNING]
> **Windows NTFS Security Notice:**  
> In Node.js on Windows (NTFS), POSIX-style permission flags such as `{ mode: 0o700 }` or `{ mode: 0o600 }` only manipulate the legacy DOS `FILE_ATTRIBUTE_READONLY` flag. They do **NOT** establish Windows Discretionary Access Control Lists (DACLs). Without explicit NTFS ACL configuration, files written on Windows inherit permissive directory access, allowing any user or local background process to read them.
> 
> Production secret files should preferably be stored outside the Git repository in a dedicated user-profile directory with explicit NTFS ACL restrictions. Defensive repository ignore rules (`.secrets/`, `*_keyring.json`) serve as a secondary fail-safe, not a substitute for filesystem access control.

### Step 2.0: Create and Secure Secrets Storage Directory

> [!IMPORTANT]
> **Pre-Staging Verification Notice:**  
> The PowerShell ACL procedure below was empirically verified on Windows 11 NTFS against an isolated non-production test directory (`scratch/test_acls_dir`). Empirical testing proved that `icacls /inheritance:r` cleanly removes all inherited access entries (including non-default/local machine groups), whereas `icacls /inheritance:d` + selective removal leaves unprivileged non-standard groups with read access.
>
> Any operator executing this procedure must review the verification output in Step 5. **If the ACL verification fails or reveals unintended accounts, STOP IMMEDIATELY and do NOT generate or place keys.**

#### On Windows (PowerShell with NTFS ACL Enforcement):
Run PowerShell as your standard operator user (or administrative session) to create and restrict the directory:
```powershell
# 1. Target directory in operator user profile (outside repository)
$secretDir = "$HOME\.quicknotes_secrets"
New-Item -ItemType Directory -Force -Path $secretDir | Out-Null

# 2. Resolve the fully qualified current operator identity (supports domain, Azure AD, or local accounts)
$operatorIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if ([string]::IsNullOrWhiteSpace($operatorIdentity)) {
  $operatorIdentity = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { "$env:USERNAME" }
}

# 3. Disable inheritance and remove all inherited ACEs atomically (/inheritance:r)
icacls "$secretDir" /inheritance:r

# 4. Explicitly grant Full Control to operator account, SYSTEM, and Administrators with container & object inheritance (OI)(CI)
icacls "$secretDir" /grant:r "$($operatorIdentity):(OI)(CI)F" "NT AUTHORITY\SYSTEM:(OI)(CI)F" "BUILTIN\Administrators:(OI)(CI)F"

# 5. Verification: Inspect and strictly validate resulting ACL
# The operator MUST verify that ONLY the operator, SYSTEM, and Administrators appear in the ACL.
$acl = (Get-Acl "$secretDir").Access
$acl | Format-Table IdentityReference, FileSystemRights, AccessControlType, IsInherited -AutoSize

# Resolve operator SID (supports local accounts, domain, Azure AD)
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$operatorSid = $currentUser.User.Value
if ([string]::IsNullOrWhiteSpace($operatorSid)) {
  $operatorSid = try {
    (New-Object System.Security.Principal.NTAccount($operatorIdentity)).Translate([System.Security.Principal.SecurityIdentifier]).Value
  } catch {
    $null
  }
}

# Fail closed if operator SID cannot be resolved
if ([string]::IsNullOrWhiteSpace($operatorSid)) {
  Write-Error "CRITICAL: Could not resolve Security Identifier (SID) for operator identity: '$operatorIdentity'. Stop."
  exit 1
}

# Approved identities by SID (locale-agnostic: S-1-5-18 = SYSTEM, S-1-5-32-544 = Administrators)
# Built dynamically to safely deduplicate if operator runs as LocalSystem or an alias
$expectedSids = @{
  "S-1-5-18"     = "NT AUTHORITY\SYSTEM"
  "S-1-5-32-544" = "BUILTIN\Administrators"
}

if ($expectedSids.ContainsKey($operatorSid)) {
  $expectedSids[$operatorSid] = "$($expectedSids[$operatorSid]) (current operator: $operatorIdentity)"
} else {
  $expectedSids[$operatorSid] = "Current Operator ($operatorIdentity)"
}

$aclErrors = [System.Collections.Generic.List[string]]::new()
$observedSids = [System.Collections.Generic.HashSet[string]]::new()

foreach ($rule in $acl) {
  # 1. Deny check: Reject any Deny ACE
  if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
    $aclErrors.Add("Deny ACE detected: $($rule.IdentityReference.Value) has $($rule.AccessControlType) access.")
  }

  # 2. Inheritance check: Reject any inherited ACE (/inheritance:r must leave only explicit ACEs)
  if ($rule.IsInherited) {
    $aclErrors.Add("Inherited ACE detected: $($rule.IdentityReference.Value) is inherited (must be explicit).")
  }

  # 3. Identity check: Translate identity to SID to avoid locale-dependent account-name mismatches
  $sid = try {
    $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
  } catch {
    $null
  }

  if (-not $sid -or -not $expectedSids.ContainsKey($sid)) {
    $aclErrors.Add("Unexpected identity detected: $($rule.IdentityReference.Value) (SID: $sid).")
    continue
  }

  # 4. Duplicate/conflicting entry check: Each approved identity must have exactly one ACE
  if ($observedSids.Contains($sid)) {
    $aclErrors.Add("Duplicate or conflicting ACE detected for approved identity: $($expectedSids[$sid]) (SID: $sid).")
  } else {
    $observedSids.Add($sid) | Out-Null
  }

  # 5. Permission check: Every ACE for an approved identity must grant FullControl
  $hasFullControl = ($rule.FileSystemRights -eq [System.Security.AccessControl.FileSystemRights]::FullControl) -or
                    (($rule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq [System.Security.AccessControl.FileSystemRights]::FullControl)
  if (-not $hasFullControl) {
    $aclErrors.Add("Insufficient permissions: $($rule.IdentityReference.Value) has $($rule.FileSystemRights), expected FullControl.")
  }

  # 6. Child inheritance flags check: Must include ContainerInherit and ObjectInherit (OI)(CI)
  $hasInheritanceFlags = ($rule.InheritanceFlags -band [System.Security.AccessControl.InheritanceFlags]::ContainerInherit) -and
                         ($rule.InheritanceFlags -band [System.Security.AccessControl.InheritanceFlags]::ObjectInherit)
  if (-not $hasInheritanceFlags) {
    $aclErrors.Add("Missing inheritance flags: $($rule.IdentityReference.Value) has '$($rule.InheritanceFlags)', expected '(OI)(CI)' ContainerInherit and ObjectInherit.")
  }
}

# 7. Completeness check: Ensure all expected identities are present
foreach ($expSid in $expectedSids.Keys) {
  if (-not $observedSids.Contains($expSid)) {
    $aclErrors.Add("Missing required identity: $($expectedSids[$expSid]) (SID: $expSid) is missing from ACL.")
  }
}

# 8. Total count check: Exactly the approved entries must exist (no extra or unmanaged entries)
if ($acl.Count -ne $expectedSids.Count) {
  $aclErrors.Add("Expected exactly $($expectedSids.Count) ACL entries, but found $($acl.Count).")
}

# 9. Enforcement: Fail closed before key generation
if ($aclErrors.Count -gt 0) {
  Write-Error "CRITICAL: Secrets directory ACL verification failed:`n$($aclErrors -join "`n")`nSTOP IMMEDIATELY! Do NOT proceed with key generation."
  exit 1
} else {
  Write-Host "PASS: Secrets directory ACL strictly verified: exactly $($expectedSids.Count) approved identities have non-inherited FullControl with (OI)(CI) inheritance."
}
```

*(Alternative for local workspace testing: You may target `.secrets` instead of `$HOME\.quicknotes_secrets`, applying the identical `icacls` commands to `.secrets`.)*

#### On macOS / Linux (POSIX permissions):
```bash
export SECRET_DIR="$HOME/.quicknotes_secrets"
mkdir -p "$SECRET_DIR"
chmod 700 "$SECRET_DIR"
```

---

### A. Ed25519 Signing Keypair (JWS Entitlement Lease)

The backend signs leases using Ed25519 (`alg: EdDSA`, `typ: JWT`).
- **Private Key (`SIGNING_KEYRING`):** JSON map of key IDs to Base64-encoded PKCS#8 DER private keys (exactly 48 bytes: 16-byte ASN.1 prefix + 32-byte seed) or raw 32-byte seeds.
- **Public Key (`trustedPublicKeys`):** Raw 32-byte Edwards point, Base64-encoded (RFC 8032).

#### Atomic Generation Script:
Run the following local script. Key generation is atomic: all keys are generated in memory, validated with strict length assertions, written to a uniquely named temporary file with exclusive creation (`flag: 'wx'`), and atomically renamed to the final filename. If the final file already exists, the script halts to prevent accidental overwrite.

```bash
node -e "
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const secretsDir = process.env.SECRET_DIR || path.join(process.env.USERPROFILE || process.env.HOME || '.', '.quicknotes_secrets');
if (!fs.existsSync(secretsDir)) {
  fs.mkdirSync(secretsDir, { recursive: true });
}

const targetPath = path.join(secretsDir, 'signing_keyring.json');
if (fs.existsSync(targetPath)) {
  throw new Error('Refusing to overwrite existing signing keyring: ' + targetPath + '. Move or archive the existing file first.');
}

// 1. Generate keypair in-memory
const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');

// 2. Validate format and lengths in-memory before writing
const rawPub = publicKey.export({ type: 'spki', format: 'der' }).subarray(12);
if (rawPub.length !== 32) {
  throw new Error('Assertion failed: raw public key must be exactly 32 bytes, got ' + rawPub.length);
}
const pubB64 = rawPub.toString('base64');

const pkcs8Priv = privateKey.export({ type: 'pkcs8', format: 'der' });
if (pkcs8Priv.length !== 48) {
  throw new Error('Assertion failed: PKCS#8 DER private key must be exactly 48 bytes, got ' + pkcs8Priv.length);
}
const privB64 = pkcs8Priv.toString('base64');

const signingKeyring = JSON.stringify({ v1: privB64 });

// 3. Atomic write via temporary file
const tmpPath = path.join(secretsDir, '.signing_keyring.tmp.' + Date.now() + '.' + crypto.randomBytes(4).toString('hex'));
try {
  fs.writeFileSync(tmpPath, signingKeyring, { flag: 'wx', mode: 0o600 });
  fs.renameSync(tmpPath, targetPath);
} catch (err) {
  if (fs.existsSync(tmpPath)) {
    try { fs.unlinkSync(tmpPath); } catch (_) {}
  }
  throw new Error('Atomic write failed for signing keyring: ' + err.message);
}

console.log('PUBLIC_KEY_PIN_V1=' + pubB64);
console.log('Successfully and atomically saved signing_keyring.json.');
"
```

1. Note the printed `PUBLIC_KEY_PIN_V1`.
2. Update `lib/premium/premium_config.dart`:
   ```dart
   static const Map<String, String> trustedPublicKeys = {
     'v1': '<PUBLIC_KEY_PIN_V1>',
   };
   ```
3. **Verify Keypair Match (Zero Secret Exposure):** Run this command to verify that `signing_keyring.json` mathematically matches your pinned public key without exposing private key material:
   ```bash
   node -e "
   const crypto = require('crypto');
   const fs = require('fs');
   const path = require('path');
   const secretsDir = process.env.SECRET_DIR || path.join(process.env.USERPROFILE || process.env.HOME || '.', '.quicknotes_secrets');
   const keyPath = path.join(secretsDir, 'signing_keyring.json');
   const privB64 = JSON.parse(fs.readFileSync(keyPath))['v1'];
   const privKey = crypto.createPrivateKey({ key: Buffer.from(privB64, 'base64'), format: 'der', type: 'pkcs8' });
   const pubKey = crypto.createPublicKey(privKey);
   const derivedPubB64 = pubKey.export({ type: 'spki', format: 'der' }).subarray(12).toString('base64');
   const expectedPub = process.argv[1];
   if (derivedPubB64 === expectedPub) {
     console.log('PASS: Keyring private key correctly matches pinned public key.');
   } else {
     console.error('FAIL: Key mismatch!');
     process.exit(1);
   }
   " "<PASTE_PUBLIC_KEY_PIN_V1_HERE>"
   ```

---

### B. AES-256-GCM Token Encryption Key (D1 Data at Rest)

The backend encrypts Google Play purchase tokens at rest while pending acknowledgement.
- **Key Length:** Exactly 32 bytes (256 bits).
- **Format (`TOKEN_ENCRYPTION_KEYRING`):** JSON map of key versions to Base64-encoded raw 32 bytes.
- **Random Source:** Cryptographically secure `crypto.randomBytes(32)` (CSPRNG).

#### Atomic Generation Script:
```bash
node -e "
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const secretsDir = process.env.SECRET_DIR || path.join(process.env.USERPROFILE || process.env.HOME || '.', '.quicknotes_secrets');
if (!fs.existsSync(secretsDir)) {
  fs.mkdirSync(secretsDir, { recursive: true });
}

const targetPath = path.join(secretsDir, 'token_encryption_keyring.json');
if (fs.existsSync(targetPath)) {
  throw new Error('Refusing to overwrite existing token encryption keyring: ' + targetPath + '. Move or archive the existing file first.');
}

// 1. Generate AES-256 key in-memory
const aesKey = crypto.randomBytes(32);
if (aesKey.length !== 32) {
  throw new Error('Assertion failed: AES-256 key must be exactly 32 bytes, got ' + aesKey.length);
}
const aesKeyB64 = aesKey.toString('base64');
const tokenKeyring = JSON.stringify({ v1: aesKeyB64 });

// 2. Atomic write via temporary file
const tmpPath = path.join(secretsDir, '.token_keyring.tmp.' + Date.now() + '.' + crypto.randomBytes(4).toString('hex'));
try {
  fs.writeFileSync(tmpPath, tokenKeyring, { flag: 'wx', mode: 0o600 });
  fs.renameSync(tmpPath, targetPath);
} catch (err) {
  if (fs.existsSync(tmpPath)) {
    try { fs.unlinkSync(tmpPath); } catch (_) {}
  }
  throw new Error('Atomic write failed for token encryption keyring: ' + err.message);
}

console.log('Successfully and atomically saved token_encryption_keyring.json.');
"
```

> [!NOTE]
> **Independent Keyfile Atomicity & Recovery:**  
> Independent filesystem rename operations cannot atomically link multiple files together. If `signing_keyring.json` succeeds but `token_encryption_keyring.json` fails, the operator must NOT deploy secrets to Cloudflare. Address the failure cause, delete the partially generated keyring file, and regenerate both together to ensure synchronized key versions.

---

## 3. Cloudflare Authentication & D1 Database Provisioning

> **Owner Approval Required:** Authenticating and provisioning Cloudflare resources.

### Step 3.1: Authenticate Wrangler and Verify Account ID
Navigate to the `backend/` directory:
```bash
cd backend
npx wrangler login
```
Verify the authenticated user and account context:
```bash
npx wrangler whoami
```
*Note: If your Cloudflare login has access to multiple accounts (e.g. personal and organization), identify your target Account ID from the output. You can explicitly set it in `backend/wrangler.toml` to eliminate ambiguity:*
```toml
# backend/wrangler.toml
account_id = "<REPLACE_WITH_TARGET_CLOUDFLARE_ACCOUNT_ID>"
```

### Step 3.2: Create Production D1 Database
Execute:
```bash
npx wrangler d1 create quicknotes-db
```
The output will provide the `database_id` (UUID format).

### Step 3.3: Configure `backend/wrangler.toml`
Update `backend/wrangler.toml` with the production database ID:
```toml
[[d1_databases]]
binding = "DB"
database_name = "quicknotes-db"
database_id = "<REPLACE_WITH_ACTUAL_D1_UUID>"
```

### Step 3.4: Apply Schema Migration

#### For Staging Environment:
Execute against the confirmed staging D1 database:
```bash
npx wrangler d1 migrations apply quicknotes-db-staging --remote --env staging
```
Confirm the prompt when asked.

Verify tables were created in staging:
```bash
npx wrangler d1 execute quicknotes-db-staging --remote --env staging --command "SELECT name FROM sqlite_master WHERE type='table';"
```
Expected output tables: `purchases`, `d1_migrations`.

#### For Production Environment (Deferred until Staging Sign-Off):
Execute against production D1:
```bash
npx wrangler d1 migrations apply quicknotes-db --remote
```
Verify tables in production:
```bash
npx wrangler d1 execute quicknotes-db --remote --command "SELECT name FROM sqlite_master WHERE type='table';"
```
Expected output tables: `purchases`, `d1_migrations`.

---

## 4. Google Play Service Account Linking

> **Owner Approval Required:** Creating GCP Service Account and granting Google Play Console access.

### Step 4.1: Enable Google Play Android Developer API in GCP
1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Select your Google Cloud Project.
3. Navigate to **APIs & Services** > **Library**.
4. Search for **Google Play Android Developer API** and click **Enable**.

### Step 4.2: Create Service Account
1. Navigate to **IAM & Admin** > **Service Accounts**.
2. Click **Create Service Account**:
   - Name: `quicknotes-entitlements-worker`
   - Description: `Cloudflare Worker authoritative purchase verifier for Quick Notes`
3. Click **Create and Continue** (no project-level roles required; permissions are granted in Play Console).
4. Select the created Service Account > **Keys** tab > **Add Key** > **Create new key** > **JSON**.
5. Save the downloaded JSON file into your local secure directory as `.secrets/google-service-account.json`.

### Step 4.3: Grant Permissions in Google Play Developer Console
1. Open [Google Play Developer Console](https://play.google.com/console).
2. Go to **Users and permissions** > **Invite new users**.
3. Enter the Service Account email (from GCP).
4. Under **App permissions**, click **Add app** and select **Quick Notes** (`com.quicknotes.byhmnth`).
5. Grant ONLY the minimum required permissions:
   - [x] **View financial data, orders, and cancellation survey responses** (Required for `purchases.productsv2`)
   - [x] **Manage orders and subscriptions** (Required for `purchases.products.acknowledge`)
   - [ ] *DO NOT grant Admin, Release, or Store Listing management permissions.*
6. Click **Invite user** and accept/apply.

---

## 5. Provision Worker Secrets

> **Owner Approval Required:** Uploading secret keyrings to Cloudflare.

Run the following commands from `backend/` using the appropriate shell:

### For Staging Environment:

#### On Windows (PowerShell):
```powershell
$secretDir = if (Test-Path "$HOME\.quicknotes_secrets") { "$HOME\.quicknotes_secrets" } else { "..\.secrets" }
Get-Content -Raw "$secretDir\signing_keyring.json" | npx wrangler secret put SIGNING_KEYRING --env staging
Get-Content -Raw "$secretDir\token_encryption_keyring.json" | npx wrangler secret put TOKEN_ENCRYPTION_KEYRING --env staging
Get-Content -Raw "$secretDir\google-service-account.json" | npx wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON --env staging
```

#### On macOS / Linux (Bash):
```bash
SECRET_DIR="${SECRET_DIR:-$HOME/.quicknotes_secrets}"
[ ! -d "$SECRET_DIR" ] && SECRET_DIR="../.secrets"
npx wrangler secret put SIGNING_KEYRING --env staging < "$SECRET_DIR/signing_keyring.json"
npx wrangler secret put TOKEN_ENCRYPTION_KEYRING --env staging < "$SECRET_DIR/token_encryption_keyring.json"
npx wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON --env staging < "$SECRET_DIR/google-service-account.json"
```

### For Production Environment (Deferred until Staging Sign-Off):

#### On Windows (PowerShell):
```powershell
$secretDir = if (Test-Path "$HOME\.quicknotes_secrets") { "$HOME\.quicknotes_secrets" } else { "..\.secrets" }
Get-Content -Raw "$secretDir\signing_keyring.json" | npx wrangler secret put SIGNING_KEYRING
Get-Content -Raw "$secretDir\token_encryption_keyring.json" | npx wrangler secret put TOKEN_ENCRYPTION_KEYRING
Get-Content -Raw "$secretDir\google-service-account.json" | npx wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON
```

#### On macOS / Linux (Bash):
```bash
SECRET_DIR="${SECRET_DIR:-$HOME/.quicknotes_secrets}"
[ ! -d "$SECRET_DIR" ] && SECRET_DIR="../.secrets"
npx wrangler secret put SIGNING_KEYRING < "$SECRET_DIR/signing_keyring.json"
npx wrangler secret put TOKEN_ENCRYPTION_KEYRING < "$SECRET_DIR/token_encryption_keyring.json"
npx wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON < "$SECRET_DIR/google-service-account.json"
```

*After provisioning and verifying deployment, securely remove temporary local secret files or transfer them to an encrypted offline cold vault.*

---

## 6. Worker Deployment & Health Verification

> **Owner Approval Required:** Live deployment to Cloudflare network.

### Step 6.1: Deploy Worker

#### For Staging Environment:
Deploy directly using the confirmed staging environment:
```bash
npx wrangler deploy --env staging
```
Confirmed Staging URL:
`https://quicknotes-entitlements-staging.hemanth1-adapala.workers.dev`

#### For Production Environment (Deferred until Staging Sign-Off):
```bash
npx wrangler deploy
```

### Step 6.2: Liveness Probe Verification

#### Staging Health Check:
```bash
curl https://quicknotes-entitlements-staging.hemanth1-adapala.workers.dev/health
```
Expected output:
```json
{"status":"ok"}
```

#### Production Health Check:
```bash
curl https://quicknotes-entitlements.<account-subdomain>.workers.dev/health
```
Expected output:
```json
{"status":"ok"}
```

> [!WARNING]
> **Liveness vs. Functional Readiness:**  
> A `200 OK` from `GET /health` confirms **only** that the Worker isolate is routing HTTP requests. It does **not** prove that D1 connectivity, Google Play OAuth token exchange, or cryptographic signing keys are functional. Functional readiness requires performing a verified purchase transaction on the Google Play Internal Testing Track (Step 9). Never consider the service verified based solely on `/health`.

---

## 7. Android Release Build Configuration

### Step 7.1: Verify Pinned Public Key
Confirm `lib/premium/premium_config.dart` contains the matching `PUBLIC_KEY_PIN_V1`:
```dart
static const Map<String, String> trustedPublicKeys = {
  'v1': '<PUBLIC_KEY_PIN_V1>',
};
```

### Step 7.2: Build Signed Release AAB
Execute the release build command passing the authoritative issuer URL:
```bash
flutter build appbundle --release --dart-define=PREMIUM_ISSUER_URL=https://quicknotes-entitlements.<account-subdomain>.workers.dev
```

### Step 7.3: Verify Build Integrity
Per [`ReleaseAndBuildManagerSkill.md`](file:///c:/Users/heman/.gemini/antigravity-ide/scratch/QuickNotes/Agents/skills/ReleaseAndBuildManagerSkillFolder/ReleaseAndBuildManagerSkill.md):
```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

---

## 8. Rollback and Recovery Procedures

### 8.1 Worker Rollback
If an unexpected issue arises with worker application logic:
```bash
npx wrangler rollback
```

### 8.2 D1 Database Restore & Anti-Resurrection Architecture

Cloudflare takes an automatic snapshot backup before migrations. In case of database rollback:
```bash
npx wrangler d1 backup list quicknotes-db
npx wrangler d1 backup restore quicknotes-db <backup-id>
```

> [!IMPORTANT]
> **Anti-Resurrection, Snapshot Restores, and Architectural Boundaries:**  
> It is critical to distinguish between application-level invariants, live upstream gating, and physical database restoration:
> 
> 1. **Application-Level Terminal Protection:** As long as a revocation tombstone exists in D1 (`status = 'REVOKED'`), any application or cron attempt to resurrect the row to `ACTIVE` is strictly rejected by the SQL `WHERE status != 'REVOKED'` constraint in `updatePurchaseCas`.
> 2. **Physical Restore Overwrite Limitation:** A Cloudflare D1 point-in-time restore **physically overwrites the underlying SQLite database file**. If an older snapshot taken prior to a purchase cancellation is restored, that physical restoration will overwrite and delete the revocation tombstone, reverting the row to `status = 'ACTIVE'`. Application code cannot prevent a physical SQLite database restore from replacing table data. The tombstone does **not** survive a physical snapshot restore that predates it.
> 3. **Live Upstream Gating (Anti-Resurrection Guarantee):** Even if an old snapshot restores an `ACTIVE` row, **the Worker never issues an entitlement lease based on D1 state alone**. Every `/verify-purchase` call unconditionally queries the Google Play Developer API live. If Google Play confirms the purchase is `CANCELLED`, the restored `ACTIVE` row is immediately re-reconciled to `status = 'REVOKED'`, its token is purged, and HTTP 403 is emitted.
> 4. **Upstream Outage Fail-Closed Behavior:** If Google Play Developer API is unreachable, times out, or returns a transport/5xx error immediately following a snapshot restore, verification **strictly fails closed with HTTP 502 (`UPSTREAM_LOOKUP_FAILED`)**. No lease can ever be issued during an upstream outage, preventing unauthorized access even in the presence of stale restored state.
> 5. **User Data Integrity:** Rejection, failure, or revocation of Premium **never** deletes or locks user notes, folders, tasks, or attachments. Free tier functionality remains completely unhindered.

### 8.3 Key Rotation Procedure (`v1` to `v2`)
- **Step A:** Add `'v2'` public key to `lib/premium/premium_config.dart` `trustedPublicKeys` and release client update to Internal Testing track.
- **Step B:** Add `'v2'` private key to `SIGNING_KEYRING` on Worker.
- **Step C:** Update `backend/wrangler.toml` `PRIMARY_SIGNING_KEY_ID = "v2"` and `SERVER_ALLOWED_SIGNING_KEYS = "v1,v2"` and redeploy Worker.
- **Step D:** Once all active clients have updated, retire `'v1'` from `SERVER_ALLOWED_SIGNING_KEYS`.

---

## 9. Live Physical-Device Acceptance Tests

Perform these tests on a physical Android device installed via the Google Play Internal Testing Track:

1. **Purchase Grant:** Purchase `quicknotes_premium_lifetime` on the test device. Verify instant unlock, valid 7-day JWS lease issuance, and database entry with `status = 'ACTIVE'`.
2. **Offline Resilience:** Turn on Airplane mode. Restart app. Verify Premium features remain fully active offline under the valid 7-day cryptographic lease.
3. **Restore Purchase:** Clear app data, sign in with the Google Play test account, and tap **Restore Purchases**. Verify entitlement is restored within bounded timeout.
4. **Authoritative Revocation (Refund/Cancel):** In Google Play Console Order Management, issue a refund/cancel the purchase. Open app and trigger restore or wait for scheduled sync. Verify HTTP 403 `{"status":"REVOKED","reason":"GOOGLE_PLAY_CANCELLED"}` is returned, D1 tombstone committed, and entitlement reverted to free tier non-destructively.
