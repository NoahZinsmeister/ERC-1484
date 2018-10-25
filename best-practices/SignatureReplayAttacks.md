## Signature Replay Attacks

Often, `Providers` and `Resolvers` want to be able to permission calls on their registry with signatures (see [EINPermissioning.md](./EINPermissioning.md)). Care must be taken to prevent replay attacks, one of the 4 strategies below is *highly* recommended.

### 1. Designed signature uniqueness
One-time signatures.

### 2. Enforced Signature.
Signature logs.

### 3. Timeouts
Rolling timeout with timestamps.

### 4. Nonces
Per-call nonce.
