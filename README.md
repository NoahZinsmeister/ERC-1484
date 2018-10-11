---
eip: TBD
title: Digital Identity Aggregator
author: Anurag Angara <anurag.angara@gmail.com>, Andy Chorlian <andychorlian@gmail.com>, Shane Hampton <shanehampton1@gmail.com>, Noah Zinsmeister <noahwz@gmail.com>
discussions-to: https://github.com/ethereum/EIPs/issues/TBD
status: Draft
type: Standards Track
category: ERC
created: 2018-10-08
---

## Simple Summary
A protocol for aggregating digital identity information that's broadly interoperable with existing, proposed, and hypothetical future digital identity standards.

## Abstract
This EIP proposes a identity management and aggregation framework on the Ethereum blockchain. It allows users to claim an identity via a singular identity `Registry` smart contract, associate it with other Ethereum addresses, and use it to interface with smart contracts providing arbitrarily complex identity-related functionality.

## Motivation
Emerging identity standards and related frameworks proposed by the Ethereum community (including ERCs/EIPs [725](https://github.com/ethereum/EIPs/issues/725), [735](https://github.com/ethereum/EIPs/issues/735), [780](https://github.com/ethereum/EIPs/issues/780), [1056](https://github.com/ethereum/EIPs/issues/1056), etc.) define and instrumentalize individuals' digital identities in a variety of ways. As existing approaches mature, new standards emerge, and isolated, non-standard approaches to identity develop, managing multiple identities will becoming increasingly burdensome and involve unnecessary duplication of work.

The proliferation of on-chain identity solutions can be traced back to the fact that each has codified their notion of identity and linked it to specific aspects of Ethereum (smart contracts, signature verification, etc.). This proposal eschews that approach, instead introducing a protocol layer in between the Ethereum network and identity applications. This solves identity management and interoperability challenges by enabling any identity-driven application to leverage an un-opinionated identity management protocol.

## Definitions
- `Registry`: A single smart contract which is the hub for all user `Identities`. The `Registry's` primary responsibility is enforcing a global namespace for identities, which are individually denominated by a unique `string` between 3 and 32 bytes long.

- `Identity`: The core data structure that constitutes a user's identity. Identities consist of 3 sets of addresses: `Associated Addresses`, `Providers`, and `Resolvers`.

- `Associated Address`: An Ethereum address publicly associated with an `Identity`. In order for an address to become an `Associated Address` for an `Identity`, the `Identity` must produce:

  - a signed message from the candidate address indicating intent to associate itself with the `Identity`
  - a signed message from an existing `Associated Address` of the `Identity` indicating the same.

- `Recovery Address`: An Ethereum address with functionality to recover lost identities as outlined in the **Address Recovery** section

- `Poison Pill`: In the event of irrecoverable control of your `Identity` we have implemented the ability to "nuke" your the `Identity`. When this happens, all `associated addresses`, `resolvers` and `providers` will be removed and the `Identity` will be unusable.

 `Identities` can remove an `Associated Address` by producing a signed message indicating intent to disassociate itself from the `Identity`. Signatures are stored in the `Registry` to prevent replay attacks.

- `Provider`: An Ethereum address (typically but not by definition a smart contract) authorized to add and remove `Resolvers` and `Associated Addresses` from the `Identities` of users who have authorized the `Provider` to act on their behalf.

- `Resolver`: A smart contract containing arbitrary information pertaining to users' `Identities`. A resolver may implement an identity standard, such as ERC 725, or may consist of a smart contract leveraging or declaring identifying information about `Identities`. These could be financial dApps, social media dApps, etc.

## Specification
A digital identity in this proposal can be viewed as an omnibus account, containing more information about an identity than any individual identity application could. This omnibus identity is resolvable to an unlimited number of sub-identities. Resolvers recognize identities by any of their associated addresses.

The protocol revolves around claiming an Identity, setting a `Provider` and managing associated addresses and resolvers. Users may do so directly, or delegate this responsibility to a `Provider`. `Provider` smart contracts or addresses may add `Resolvers` indiscriminately, but may only add and remove `Associated Addresses` with the appropriate permissions.

### Identity Registry
The Identity Registry contains functionality for a user to establish their core identity and manage their `Providers`, `Associated Addresses`, and `Resolvers`. It is important to note that this registry fundamentally requires transactions for every aspect of building out a user's identity through both resolvers and addresses. Nonetheless, we recognize the importance of global accessibility to dApps and identity applications. Accordingly, we include the option for a delegated identity-building scheme that allows smart contracts called `Providers` to build out a user's identity through signatures without requiring users to pay gas costs.

We propose that `Identities` be denominated by a `string` for user-friendliness instead of identifying individuals by an address. Identifying users by an address awkwardly provides added meaning to their owner address despite all `Associated Addresses` commonly identifying an individual. Further, it creates a more complicated user experience in passing their ID to a resolver or third-party. Currently, the only practical way for a user to identify themselves is to copy-and-paste their Ethereum address or to share a QR code. While QR codes are helpful, we do not feel that they should be the sole notion of user-friendliness by which a user may identify themselves.

### Address Management
The address management function consists of trustlessly connecting multiple user-owned `Associated Addresses` to a user's `Identity`. It does not prescribe any special status to any given identity-managing address, rather leaving this specification to identity applications built on top of the protocol - for instance, `management`, `action`, `claim` and `encryption` keys denominated in the ERC 725 standard. This allows a user to access common identity data from multiple wallets while still
- retaining flexibility to interact with contracts outside of their core identity pseudonymously
- taking advantage of address-specific permissions established at the application layer of a user's identity.

Trustlessness in the address management function is achieved through a signature and verification scheme that requires two transactions - one from an address already within the registry and one from the address to be claimed. This logic is implemented in . Importantly, the transaction need not come from the original user, which allows entities, governments, etc to bear the overhead of creating a core identity.

`initiateClaim`: `hash(addressToClaim, secret, coreID)`

`delegatedInitiateClaim`: `hash(signature, addressToClaim, secret, coreID)`

`finalizeClaim`: transact with `secret` and `coreID`

`removeAddress`: transact from a claimed address with `addressToRemove`


### Resolver Management
The resolver management function is similarly low-level. It considers a resolver to be any smart contract that encodes information which resolves to a user's core identity. It does not set a standard for specific information that can be encoded in a resolver, rather remaining agnostic to the nature of information itself.

`setResolver`: transact with `resolverAddress`

`delegatedSetResolver`: transact with `signature` and `resolverAddress`

`removeResolver`: transact with `resolverAddress`

The resolver standard is primarily what makes this ERC an identity protocol rather than an identity application. Resolvers resolve data about an atomic entity, the coreID, in the form of arbitrarily complex smart contracts rather than a pre-defined attestation structure.

### Provider Management
While the protocol allows for users to directly call identity management functions, it also aims to be more robust and future-proof by allowing arbitrary smart contracts to perform identity management functions on a user's behalf. A provider set by an individual can perform address management and resolver management functions by passing the user's `coreID` in function calls.

### Recovery
he specification introduces a `Recovery Address` to account for instances of lost user control over an `Associated Address`. Upon `Identity` creation, the public `Recovery Address` is passed as a parameter by a provider. Identity recovery functionality is triggered in three events.

**Recovery**: Recovery occurs when a user recognizes that an `Associated Address` belonging to the user is lost or stolen. A user in this instance needs to call `initiateRecovery` from the `Recovery Address`. `initiateRecovery` removes all `Associated Addresses` and `Providers` from the corresponding `Identity` and replaces them with an address passed in the `initiateRecovery` function call. The `Identity` and associated `Resolvers` maintain integrity. The user is now responsible for adding the appropriate uncompromised addresses back to their `Identity` in the `Registry`.

**Changing Recovery Key**: If a recovery key is lost, a provider can `initiateRecoveryAddressChange` with a signature from any claimed address. To prevent malicious change of a `Recovery Address` from someone who has gained control of an `Associated Address`, this occurs over a 14 day challenge period during which the `Recovery Address` may reject the change. If the `Recovery Address` does not reject the change within 14 days, the `Recovery Address` is changed. However, during the fourteen day period, the `Recovery Address` can dispute the change request by calling `triggerRecovery` in which case all `Associated Addresses` are removed, and an Address delegated in the `triggerRecovery` call becomes the only `Associated Address` for the `Identity`.

**Trap Card**
The Recovery scheme offers a lot of power to a `Recovery Address`; accordingly, `activateTrapCard` is a nuclear option to combat malicious control over an `Identity` when a `Recovery Address` is compromised. If a malicious actor compromises a user's `RecoveryAddress` and calls `triggerRecovery`, any address removed in the `Recovery` process can `activateTrapCard` to nuke the `Identity`. The user would then need to create a new `Identity` and would be responsible for engaging in recovery schemes for any Identity Applications built in the application layer.

#### Alternative Recovery Considerations
In devising the Recovery process outlined in this specification, we considered many Recovery options. We ultimately selected the scheme that was most unopinionated and modular to be consistent with the the `Resolver`, `Associated Address` and `Provider` components within the specification. Still, we feel it important to highlight some of the other recovery options considered to provide deeper rationale as to why we arrived at the above scheme.

**High Level Concerns**
Fundamentally, a Recovery scheme needed to be resilient to a compromised `Associated Address` taking control of a user's `Identity`. A secondary concern was preventing an `Associated Address` from maliciously destroying a user's identity due to off-chain utility, which is not an optimal scenario, but is strictly better than if they've gained control.  

**Nuclear Option**
This approach would allow any `Associated Address` to destroy an `Identity` whenever another `Associated Address` is compromised. While this may seem harsh, we held it in strong consideration due to the fact that ERC[TBD] is a protocol rather than an Identity *application*. Accordingly, once a user destroyed their compromised `Identity`, they would need to use whatever Restoration mechanisms were apparent in each of their actual identities. We ultimately dismissed this approach for two main reasons.
- It would increase the frequency of recovery requests for applications of identity due to the multiple addresses any of which could be compromised.
- It is not robust for instances in which a user has only one `Associated Address`

**Unilateral Address Removal from a provider** 
This would allow providers to remove an `Associated Address` without a signature from the `Associated Address`. To prevent a compromised address from setting a malicious provider to remove uncompromised addresses, this would require a waiting period between when a provider is set and when a provider is able to remove an `Associated Address`. This implementation would allow a provider to include arbitrarily sophisticated Recovery schemes - for instance, multi-sig requirements, centralized off-chain verification, user controlled master addresses, deferral to a jurisdictional contract, or more. We dismissed this approach because we felt it placed too high of a burden on `Providers`. If a `Provider` offered a sophisticated range of functionality to a user, but post-deployment a threat was found in the Recovery logic of the provider, provider-specific infrastructure would need to be rebuilt. We considered including a flag that allows a user to determine if a provider may or may not remove `Associated Addresses`; however, we ultimately concluded that breaking out removal of an `Associated Address` into a `Recovery Address` allows for equally sophisticated recovery logic while separating the functionality from providers and leaving less room for users to relinquish control to poorly implemented providers. 


*Importantly, the recovery address can be a user-controlled wallet or another address such as a multisig wallet or a smart contract address. This allows for more sophisticated recovery structures that can be compliant with identity standards for recovery such as those laid out by DID*

## Rationale
We find that at a protocol layer, identity should contain no claim or attestation structure and should rather simply lay a trustless framework upon which arbitrarily sophisticated claim and attestation structures may lie in conjunction.

The main criticism of an identity layer comes from restrictiveness; we aim to limit requirements to be modular and future-proof without providing any special functionality for any component within the core registry. It simply allows users the option to interact on the blockchain using an arbitrarily robust identity rather than just an address.

## Implementation

#### identityExists

Returns a `bool` indicating whether or not an `Identity` denominated by the passed `identity` string exists.

```solidity
function identityExists(string identity) public view returns (bool);
```

#### hasIdentity

Returns a `bool` indicating whether or not the passed `_address` is associated with an `Identity`.

```solidity
function hasIdentity(address _address) public view returns (bool);
```

#### getIdentity

Returns the `identity` associated with the passed `_address`. Throws if no such `identity` exists.

```solidity
function getIdentity(address _address) public view returns (string identity);
```

#### isProviderFor

Returns a `bool` indicating whether or not the passed `provider` is assigned to the passed `identity`.

```solidity
function isProviderFor(string identity, address provider) public view returns (bool);
```

#### isResolverFor

Returns a `bool` indicating whether or not the passed `resolver` is assigned to the passed `identity`.

```solidity
function isResolverFor(string identity, address resolver) public view returns (bool);
```

#### isAddressFor

Returns a `bool` indicating whether or not the passed `_address` is owned by the passed `identity`.

```solidity
function isAddressFor(string identity, address _address) public view returns (bool);
```

#### getDetails

Returns three `address` arrays of `associatedAddresses`, `providers` and `resolvers`. All of these arrays represent the addresses associated with the passed `identity`.

```solidity
function getDetails(string identity) public view returns (address[] associatedAddresses, address[] providers, address[] resolvers);
```

#### mintIdentity

Mints an `Identity` with the passed `identity` and `provider`.

```solidity
function mintIdentity(string identity, address provider) public;
```

#### mintIdentityDelegated

Preforms the same logic as `mintIdentity`, but can be called by a `provider`. This function requires a signature for the `associatedAddress` to confirm their consent.

```solidity
function mintIdentityDelegated(string identity, address associatedAddress, uint8 v, bytes32 r, bytes32 s) public;
```

#### addProviders

Adds an array of `providers` to the `Identity` of the `msg.sender`.

```solidity
function addProviders(address[] providers) public;
```

#### removeProviders

Removes an array of `providers` from the `Identity` of the `msg.sender`.

```solidity
function removeProviders(address[] providers) public;
```

#### addResolvers

Adds an array of `resolvers` to the passed `identity`. This must be called by a `provider`.

```solidity
function addResolvers(string identity, address[] resolvers) public;
```

#### removeResolvers

Removes an array of `resolvers` from the passed `identity`. This must be called by a `provider`.

```solidity
function removeResolvers(string identity, address[] resolvers) public;
```

#### addAddress

Adds the `addressToAdd` to the passed `identity`. Requires signatures from both the `addressToAdd` and the `approvingAddress`.

```solidity
function addAddress(string identity, address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt) public;
```

#### removeAddress

Removes an `addressToRemove` from the passed `identity`. Requires a signature from the `addressToRemove`.

```solidity
function removeAddress(string identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public;
```

#### Solidity Interface
```solidity
pragma solidity ^0.4.24;

contract ERCTBD {

  event IdentityMinted(string identity, address associatedAddress, address provider, bool delegated);
  event ResolverAdded(string identity, address resolvers, address provider);
  event ResolverRemoved(string identity, address resolvers, address provider);
  event AddressAdded(string identity, address addedAddress, address approvingAddress, address provider);
  event AddressRemoved(string identity, address removedAddress, address provider);

  struct Identity {
    AddressSet.Set associatedAddresses;
    AddressSet.Set providers;
    AddressSet.Set resolvers;
  }

  function identityExists(string identity) public view returns (bool);

  function hasIdentity(address _address) public view returns (bool);
  function getIdentity(address _address) public view returns (string identity);

  function isProviderFor(string identity, address provider) public view returns (bool);
  function isResolverFor(string identity, address resolver) public view returns (bool);
  function isAddressFor(string identity, address _address) public view returns (bool);

  function getDetails(string identity) public view returns (address[] associatedAddresses, address[] providers, address[] resolvers);

  function mintIdentity(string identity, address provider) public;
  function mintIdentityDelegated(string identity, address associatedAddress, uint8 v, bytes32 r, bytes32 s) public;

  function addProviders(address[] providers) public;
  function removeProviders(address[] providers) public;

  function addResolvers(string identity, address[] resolvers) public;
  function removeResolvers(string identity, address[] resolvers) public;

  function addAddress(string identity, address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt) public;
  function removeAddress(string identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public;
}
```
## Backwards Compatibility
`Identities` established under this standard consist of existing Ethereum addresses; accordingly, identity construction has no backwards compatibility issues. Deployed, non-upgradeable smart contracts that wish to become `Resolvers` to a user's `Identity` will need to write wrapper contracts that resolve addresses to `Identities` with `getIdentity`.

## Additional References

## Copyright
Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
