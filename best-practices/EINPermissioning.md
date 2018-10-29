## EIN Permissioning

Often, `Providers` and `Resolvers` want to be able to permission function calls on their smart contracts to allow maximum flexibility in how users interact with their product. This issue has 4 main solutions:

1. Allow `Identities` to call functions directly.

2. Have `Identities` sign a message with an `Associated Address` and allow any third party to make a permissioned call on their behalf.

3. Have `Resolver`/`Provider` owners do so unilaterally.

4. (`Resolver`-only) Allow `Providers` to call functions for `EIN`s that have set them.

Before diving in, let's first sketch out a `performLogic` function that we want to call. Say it modifies data associated with an `Identity`. For example, this could be a `Provider` function that adds a resolver to an `Identity`, or a `Resolver` function that changes some data field about an `Identity`.

```solidity
// perform the desired operations on the EIN's Identity
function performLogic(uint ein, ...) private {
    ...
}
```

Obviously, we can't let just anyone call this function, so we'll make it private and write public interfaces to it, permissioned appropriately.

### Interface 1: Permission by `msg.sender`
This is simple. We can allow any `AssociatedAddress` of an identity to call the private function by simply looking up their `EIN` from the registry with `getEIN`.

```solidity
function performLogic(...) public {
  performLogic(identityRegistry.getEIN(msg.sender), ...);
}
```

### Interface 2: Permission by signature
If we are going to allow someone other than an `AssociatedAddress` holder to call functions pertaining to an EIN, an `AssociatedAddress` will have to sign their permission. **Importantly, one must take care to avoid replay attacks under such a scheme (see [SignatureReplayAttacks.md](./SignatureReplayAttacks.md))**. However, any well-implemented solution will have 3 options to pass the `Identity` to the app:

#### Only Address (*Recommended*)
One solution is to simply pass the address that generated the passed signature, and get the `EIN` from that signature.

```solidity
function performLogic(address approvingAddress, uint8 v, bytes32 r, bytes32 s, ...) public {
  bytes32 messageHash = keccak256(abi.encodePacked(...));
  require(identityRegistry.isSigned(approvingAddress, messageHash, v, r, s);
  uint ein = identityRegistry.getEIN(approvingAddress);

  performLogic(ein, ...);
}
```

This is a nice solution, because we know that the EIN is automatically valid once we know the signature checks out!

#### Passing the EIN
Another (perhaps more 'obvious') solution is to pass the EIN of the user in question.

```solidity
function performLogic(uint ein, uint8 v, bytes32 r, bytes32 s, ...) public {
  bytes32 messageHash = keccak256(abi.encodePacked(...));
  address signingAddress = ecrecover(messageHash, v, r, s);
  require(identityRegistry.isAddressFor(ein, signingAddress));

  performLogic(ein, ...);
}
```

This solution has one big drawback. Recovering the address from the signature, and checking that it belongs to the passed `EIN` only works for signatures of the specific form above. It notably does not work for signatures prefixed with the somewhat-standard `\x19Ethereum Signed Message:\n32`. So, this method cannot be agnostic between prefixed and un-prefixed signatures unless it recovers 2 addresses and checks that either one belongs to the `EIN`, which is somewhat unwieldy. For more information see [SignatureReplayAttacks.md](./SignatureReplayAttacks.md).

#### Both
To be extra safe, one could pass both the `EIN` and the `approvingAddress`.

```solidity
function performLogic(uint ein, address approvingAddress, uint8 v, bytes32 r, bytes32 s, ...) public {
  require(identityRegistry.isAddressFor(ein, approvingAddress));
  bytes32 messageHash = keccak256(abi.encodePacked(...));
  require(identityRegistry.isSigned(approvingAddress, messageHash, v, r, s);

  performLogic(ein, ...);
}
```

### Interface 3: Permission by onlyOwner
The easiest but most centralized/potentially insecure solution is to simply allow only the owner of the contract to make calls for `EIN`s.

```solidity
function performLogic(uint ein, ...) public onlyOwner {
  performLogic(ein, ...);
}
```

### Interface 4 (`Resolver`-only): Permission by `Provider`
An easy solution for `Resolvers` is to simply let `Providers` call functions for `EIN`s which have them set.

```solidity
function performLogic(uint ein, ...) public onlyOwner {
  require(identityRegistry.isProviderFor(ein, msg.sender));
  performLogic(ein, ...);
}
```
