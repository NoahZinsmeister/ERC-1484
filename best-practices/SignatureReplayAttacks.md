## Signature Replay Attacks

Often, `Providers` and `Resolvers` want to be able to permission calls on their registry with signatures (see [EINPermissioning.md](./EINPermissioning.md)). Care must be taken to prevent replay attacks, one of the 4 strategies below is *highly* recommended.

### Comments on Signatures in Ethereum
There has been a lot of discussion around optimal signature schemes in Ethereum. This has included the controversial and confusing inclusion/non-inclusion of the notorious [`\x19Ethereum Signed Message:\n32` prefix](https://ethereum.stackexchange.com/questions/19582/does-ecrecover-in-solidity-expects-the-x19ethereum-signed-message-n-prefix) in signatures, discussions over whether to sign data or the hash of data, inconsistently signature implementations across software packages, and recent proposals to hard-code values in smart contracts [to enable complex front-end signature schemes](https://github.com/ethereum/EIPs/pull/712). So, before diving in, some clarifications. As far as this document/ERC-1484 are concerned:

- Only message hashes should be signed, not raw messages. The downside is that the user is signing what looks like gibberish. The upside is that these signatures can be directly verified in the EVM [without any fragile, per-smart contract implementations of custom signature verification schemes](https://github.com/ethereum/EIPs/pull/712#issuecomment-428263777). For example:
```solidity
bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, "123", 100))
```
  - One way to improve the UX of this approach would be for a trusted UI to show users the data which hashes to what they are signing. This would be a big improvement, with the only remaining problem being that the *names* of the data fields could not be verified (leading to potential confusion/misdirection in cases when users sign data that includes multiple addresses, a `to` and `from`, for example).

- The 'official' Ethereum signed message prefix should be *optional*, and if included, be prepended to the hash of the data, hashed again, and then signed. For example:

```solidity
bytes prefix = "\x19Ethereum Signed Message:\n32";
bytes32 innerHash = keccak256(abi.encodePacked(msg.sender, "123", 100));
bytes32 messageHash = keccak256(abi.encodePacked(prefix, innerHash));
```

- Signatures should include data specific to the contract being interacted with. This is often as simple as including `address(this)` in the raw message.

This logic is all reflected in the [SignatureVerifier contract](../contracts/IdentityRegistry.sol) that the `IdentityRegistry` inherits from. `Providers` and `Resolvers` are all strongly encouraged to use the public `isSigned` method!

Now that that's out of the way, let's dive into specific strategies for ensuring that signatures can't be replayed!

### 1. Designed signature uniqueness
The technically hardest but conceptually easiest solution is to simply ensure that a given signature can, by design, only be used once. This is ideal for one-time sign-up situations, where what is being signed precludes the signature from ever being used again.

### 2. Enforced Signature Uniqueness
If uniqueness by design isn't possible, it can be enforced in three ways:

#### Nonces
Every time an address calls a permissioned function, included in the message they sign must be a nonce that increments every call.
- Pros: Relatively light on gas costs (only ~5k gas to update an existing storage variable)
- Cons: Requires an on-chain read for every transaction. Can lead to complications with >1 pending transaction.

#### Timeouts
Every time an address calls a permissioned function, included in the message they sign must be a timestamp that is within some window of the current block's timestamp.
- Pros: Relatively light on gas costs (only ~5k gas to update an existing storage variable)
- Cons: Requires an on-chain read for every transaction. Can lead to complications with >1 pending transaction.

#### Signature Logs (*Not Recommended*)
Every time an address calls a permissioned function, the message hash is stored in a log, and must be enforced to never be reused. To ensure that the same signature can be passed twice (if intended), a per-transaction salt must be included.
- Pros: No on-chain reads or timing issues.
- Cons: Gas-intensive (extra ~20k per call).
