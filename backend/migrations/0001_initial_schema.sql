-- Migration: 0001_initial_schema.sql
-- Description: QuickNotes Premium Entitlement Ledger (BUG-001)

CREATE TABLE IF NOT EXISTS purchases (
    token_hash TEXT PRIMARY KEY,
    encrypted_token TEXT NULL,
    key_version TEXT NOT NULL,
    product_id TEXT NOT NULL,
    package_name TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('ACTIVE', 'REVOKED')),
    revocation_reason TEXT NULL,
    acknowledgement_state TEXT NOT NULL CHECK(acknowledgement_state IN ('PENDING', 'ACKNOWLEDGED', 'UNSPECIFIED', 'NOT_APPLICABLE')),
    ack_attempt_count INTEGER NOT NULL DEFAULT 0,
    next_ack_attempt_at INTEGER NULL,    -- Scheduled backoff retry timestamp (Unix ms)
    ack_claim_expires_at INTEGER NULL,   -- Active in-flight worker lease timestamp (Unix ms)
    last_ack_failure_reason TEXT NULL,
    last_check_status TEXT NOT NULL DEFAULT 'PENDING',
    purchase_time_ms INTEGER NULL,       -- Nullable: canceled or early-voided orders may lack completion time
    state_version INTEGER NOT NULL DEFAULT 1,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
);

-- Partial index strictly covering active, pending rows awaiting acknowledgement retry
CREATE INDEX IF NOT EXISTS idx_purchases_ack_queue 
ON purchases(next_ack_attempt_at, created_at_ms, token_hash)
WHERE status = 'ACTIVE' 
  AND acknowledgement_state = 'PENDING' 
  AND next_ack_attempt_at IS NOT NULL;
