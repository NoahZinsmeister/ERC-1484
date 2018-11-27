## Verifying Signatures

### Background on Signatures in Ethereum
There has been a lot of discussion around optimal signature schemes in Ethereum. This has included the controversial and confusing inclusion/non-inclusion of the notorious [`\x19Ethereum Signed Message:\n32` prefix](https://ethereum.stackexchange.com/questions/19582/does-ecrecover-in-solidity-expects-the-x19ethereum-signed-message-n-prefix) in signatures, discussions over whether to sign data or the hash of data, inconsistent signature implementations across software packages. So, before diving in, some clarifications. As far as this document/ERC-1484 are concerned:

- Only message hashes should be signed, not raw messages. The downside is that the user is typically signing what looks like gibberish. The upside is that these signatures can be directly verified in the EVM. For example:

```solidity
  bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, "123", 100))
  address signingAddress = ecrecover(messageHash, v, r, s);  
```

- To ensure that users are not signing an RLP-encoded transaction, signatures should be constructed according to the commonly used [ERC191](https://github.com/ethereum/EIPs/issues/191) signature scheme. This also ensures that signatures include data specific to the contract being interacted with, i.e. `address(this)`. ERC1484 uses 191 signatures.

- To improve the UX of signing message hashes, a trusted UI could show users the data which hashes to what they are signing. This would be a big improvement, with the only remaining problem being that the *names* of the data fields could not be verified (leading to potential confusion/misdirection in cases when users sign data that includes multiple addresses, a `to` and a `from`, for example). Recent efforts such as [ERC-712](https://github.com/ethereum/EIPs/pull/712)) aim to solve this problem by hard-coding values in smart contracts to enable complex front-end signature verification.

- The 'official' Ethereum signed message prefix is not encouraged, should at best be *optional*, and if included, be prepended to the hash of the data, hashed again, and then signed. For example:

```solidity
  bytes prefix = "\x19Ethereum Signed Message:\n32";
  bytes32 innerHash = keccak256(abi.encodePacked(...));
  bytes32 messageHash = keccak256(abi.encodePacked(prefix, innerHash));
```


### Preventing Replay Attacks
Often, `Providers` want to be able to permission calls on their registry with signatures (see [BuildingProviders.md](./BuildingProviders.md)). Care must be taken to prevent replay attacks, and one/a combination of the 4 strategies below is *highly* recommended.

**Before diving in, note that care must be taken that signatures cannot be replayed across networks.** If a user signs permission with any of the methods below on Rinkeby, this same signature can be used on any other network, including mainnet, if the contract address and user address are the same! The easiest way to prevent this issue, absent including a hard-coded chain id in the signature, is to ensure that common contracts across networks do not share the same address, and to include `address(this)` in all signatures per ERC191.

Now that that's out of the way, let's dive into specific strategies for ensuring that signatures can't be replayed!


### 1. Designed signature uniqueness
The technically hardest but conceptually easiest solution is to simply ensure that a given signature can, by design, only be used once. This is ideal for one-time sign-up situations, where what is being signed precludes the signature from ever being used again.

### 2. Enforced Signature Uniqueness
If uniqueness by design isn't possible, it can be enforced in two ways:

#### Timeouts
Every time an address calls a permissioned function, included in the message they sign must be a timestamp that is within some lagged window of the current block's timestamp.
- Pros: Does not require on-chain storage or on-chain read/writes.
- Cons: Signatures can be replayed within short windows, can introduce fragility around transaction timing, block timestamps are slightly manipulable by miners.

#### Nonces
Every time an address calls a permissioned function, included in the message they sign must be a nonce that increments every call.
- Pros: Relatively light on gas costs (only ~5k gas to update an existing storage variable)
- Cons: Requires an on-chain read and write for every transaction. Can introduce fragility around having >1 pending transaction.

The topics discussed above can be seen implemented in the [`SignatureVerifier` contract](../contracts/SignatureVerifier.sol) that the registry inherits from and in code throughout the [`IdentityRegistry`](../contracts/IdentityRegistry.sol).
