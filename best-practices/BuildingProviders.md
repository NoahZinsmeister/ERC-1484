## Building a Provider

A crucial role that `Providers` play in the ERC-1484 ecosystem is permissioning access to `IdentityRegistry` functionality. In addition, since `Resolvers` are also encouraged to allow `Providers` to interact with their smart contracts on behalf of users (see [BuildingResolvers.md](./BuildingResolvers.md)), `Providers` should also be written to accommodate these use cases.

Without further ado, here are some best practices around building a robust resolver

### Permissioning
There are several routes a `Provider` could take when choosing how to let `Identities` interact with their smart contracts. `Providers` are recommended to implement one or more of the best practices outlined below.

Before diving in, let's first sketch out a `wrappedAddResolversFor` function that we want to call. Say it is wrapping the `addResolversFor` function of the `IdentityRegistry`.

```solidity
function wrappedAddResolversFor(...) {
  ...
  IdentityRegistry.addResolversFor(ein, ...);
}
```

Obviously, we have to be _very_ careful about who can call this function, and how calls are permissioned to affect the data of `Identities`.

#### 1. Allow `Identities` to call functions directly.
The first and simplest option is to allow any `associatedAddress` of an identity to call `wrappedAddResolversFor` by simply looking up their `EIN` from the 1484 registry via `getEIN`. All further operations can now use that `EIN`.

```solidity
function wrappedAddResolversFor(...) {
  uint ein = identityRegistry.getEIN(msg.sender);
  ...
  IdentityRegistry.addResolversFor(ein, ...);
}
```

#### 2.Allow third parties to submit permission signatures on behalf of `Identities`
In some cases, users of your `Provider` will be unable or unwilling to submit and manage transactions on their own behalf. To alleviate this issue, `Providers` are encouraged to gather signatures from `Identities` and use these to manage user `Identites` on their behalf. This technique is know as meta transactions, and a [sample `Provider` implementing this pattern can be found here](../contracts/examples/Providers/MetaTransactions).

So, we want to allow a `Provider` to call `updateInformation` _on behalf of_ an EIN. In order to ensure that allowing someone other than an `associatedAddress` to call functions pertaining to an `EIN` is not an anti-pattern, we must:

- Garner an appropriate permission signature from an `associatedAddress`.
- Be thoughtful about the identity of the third parties that may submit signatures. In most cases, `public` functions will be fine, but `onlyOwner` or other permission schemes may be appropriate on a case-by-case basis.
- Take care to avoid replay attacks under such a scheme (see [VerifyingSignatures.md](./VerifyingSignatures.md) for more information)

After the above have been taken care of, a `Provider` has 3 signature verification options:

##### Only Address (*Recommended*)
One solution is to simply accept the address that generated the passed signature as an argument, and get the `EIN` from that address.

```solidity
function wrappedAddResolversFor(address approvingAddress, uint8 v, bytes32 r, bytes32 s, ...) public {
  bytes32 messageHash = keccak256(abi.encodePacked(...));
  require(identityRegistry.isSigned(approvingAddress, messageHash, v, r, s);
  uint ein = identityRegistry.getEIN(approvingAddress);
  ...
  IdentityRegistry.addResolversFor(ein, ...);
}
```

This is a nice solution, because we know that the EIN is automatically valid once we know the signature checks out!

##### (**Not Recommended**) Passing the EIN
Another (perhaps more 'obvious') solution is to pass the EIN of the user in question.

```solidity
function wrappedAddResolversFor(uint ein, uint8 v, bytes32 r, bytes32 s, ...) public {
  bytes32 messageHash = keccak256(abi.encodePacked(...));
  address signingAddress = ecrecover(messageHash, v, r, s);
  require(identityRegistry.isAddressFor(ein, signingAddress));
  ...
  IdentityRegistry.addResolversFor(ein, ...);
}
```

This solution has one big drawback. Recovering the address from the signature, and checking that it belongs to the passed `EIN`, only works for signatures of the specific form above. It notably does not work for signatures prefixed with the somewhat-standard `\x19Ethereum Signed Message:\n32`. So, this method cannot be agnostic between prefixed and un-prefixed signatures unless it recovers 2 addresses and checks that either one belongs to the `EIN`, which is somewhat unwieldy.

##### (**Not Recommended**) Both
To be extra safe, one could pass both the `EIN` and the `approvingAddress`.

```solidity
function wrappedAddResolversFor(uint ein, address approvingAddress, uint8 v, bytes32 r, bytes32 s, ...) public {
  require(identityRegistry.isAddressFor(ein, approvingAddress));
  bytes32 messageHash = keccak256(abi.encodePacked(...));
  require(identityRegistry.isSigned(approvingAddress, messageHash, v, r, s);
  ...
  IdentityRegistry.addResolversFor(ein, ...);
}
```


#### 3. Allow `Provider` owners to call `onlyOwner` functions on behalf of `Identities`
The easiest but most centralized/potentially insecure solution is to simply allow only the owner of the `Provider` contract to make calls for `EIN`s.

```solidity
function wrappedAddResolversFor(uint ein, ...) public onlyOwner {
  IdentityRegistry.addResolversFor(ein, ...);
}
```
