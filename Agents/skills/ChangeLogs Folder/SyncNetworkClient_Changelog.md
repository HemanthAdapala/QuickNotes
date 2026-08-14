# SyncNetworkClient Changelog

---

## v1.7.2

### Date
2026-08-14

### Author
Anti Gravity

### Type
- Feature
- Architecture
- Testing

---

### Summary

Engineered Phase 1.7.2 Sync Network Contract & Transport Boundary. Created provider-agnostic data models (`SyncMutationRequest`, `SyncMutationAck`, `SyncPullRequest`, `SyncPullResponse`, `RemoteChange`) and the central abstract transport interface `SyncNetworkClient` (`lib/services/sync_network_client.dart`).

---

### Detailed Changes

- **Network Data Models**:
  - `SyncMutationRequest`: Transports mutation metadata (`operationId`, `entityType`, `entityId`, `operation`, `localVersion`, `payload`, `createdAt`).
  - `SyncMutationAck`: Encapsulates server acknowledgements with `SyncAckStatus` (`acknowledged`, `stale`) and `remoteVersion`.
  - `SyncPullRequest`: Handles delta change queries with optional `cursor` and validated `limit`.
  - `RemoteChange`: Represents remote entity changes with `remoteVersion` authority.
  - `SyncPullResponse`: Envelopes pull responses with `changes`, `nextCursor`, and `hasMore`.
- **Abstract Transport Interface**:
  - `SyncNetworkClient`: Abstract class defining `pushMutations()` and `pullChanges()`.
- **Error Taxonomy**:
  - `SyncNetworkErrorType`: Categorizes errors into `authenticationFailure`, `transientFailure`, `permanentRejection`, and `malformedResponse`.
  - `SyncNetworkException`: Typed transport exception.
- **SessionManager Update**:
  - Exposed `getIdToken()` helper for retrieving securely stored OAuth ID tokens.

---

### Testing Status

- **Automated Tests**: Passed 100% of workspace tests (176/176 tests passed).
