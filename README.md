---
eip: TBD
title: Digital Identity Aggregator
author: Anurag Angara, Andy Chorlian, Shane Hampton, Noah Zinsmeister <noahwz@gmail.com>
discussions-to: https://github.com/ethereum/EIPs/issues/TBD
status: Draft
type: Standards Track
category: ERC
created: 2018-10-08
---

## Simple Summary
A protocol for aggregating digital identity information that's broadly interoperable with existing, proposed, and hypothetical future digital identity standards.

## Abstract
This EIP proposes a identity management and aggregation framework on the Ethereum blockchain. It allows users to claim an identity via a singular `Identity Registry` smart contract, associate it with other Ethereum addresses, and use it to interface with smart contracts providing arbitrarily complex identity-related functionality.

## Motivation
Emerging identity standards and related frameworks proposed by the Ethereum community (including ERCs/EIPs [725](https://github.com/ethereum/EIPs/issues/725), [735](https://github.com/ethereum/EIPs/issues/735), [780](https://github.com/ethereum/EIPs/issues/780), [1056](https://github.com/ethereum/EIPs/issues/1056), etc.) add value to an individual's digital identity in a variety of ways. As these and new standards come along - in addition to many other isolated, non-standard instances of identity in the global digital ecosystem - the management of multiple identities will likely become burdensome and involve unnecessary duplication of work.

To a large extent, the a given identity application exists because identity applications are built *directly* on Ethereum as a protocol. Ethereum exists as a governance protocol which should lie a layer below application-specific protocols. In the case of identity, this structure allows for multiple instances of an identity to maintain interoperability. Accordingly, this proposal consists of a protocol layer in between the Ethereum network and existing identity applications.

This proposal attempts to solve existing identity management and interoperability challenges by introducing a novel identity protocol. As identity clusters become more comprehensive, robust, and complex, all stakeholders in the digital identity ecosystem can benefit from a standard identity management protocol.

## Definitions
- `Identity`: The core data structure that constitutes a user's identity. Identities are denominated by a `string` variable with byte-length between 3 and 32 (inclusive). Identities consist of 3 sets of addresses: `Associated Addresses`, `Providers`, and `Resolvers`.

- `Associated Address`: An Ethereum address publicly associated with an `Identity`. In order for an address to become an `Associated Address` for an `Identity`, the `Identity` must produce a signed message from the candidate address indicating intent to associate itself with the `Identity`, as well as a signed message from an existing `Associated Address` indicating the same. `Identity` can remove an `Associated Address` by producing a signed message indicating intent to disassociate itself from the `Identity`.

- `Provider`: An Ethereum address (typically but not by definition a smart contract) authorized to add and remove `Resolvers` and `Associated Addresses` from the `Identities` of users who have authorized the `Provider` to act on their behalf.

- `Resolver`: A smart contract containing arbitrary information pertaining to user's `Identity`. A resolver may implement any identity standard, such as `ERC 725`, or may consist of a smart contract leveraging or declaring identifying information about `Identities`. These could include financial dApps, social media dApps, etc.

## Specification
A core digital identity (the center of an identity cluster) can be viewed as an omnibus account, consisting of more information than any individual identity application can contain about an individual. This omnibus identity is resolvable to an unlimited number of sub-identities. The protocol recognizes ownership of two things: addresses (Ethereum addresses) and resolvers (external entities housing any identifying information that can be resolved to the Ethereum network).

The specification allows for users directly, or user-approved smart contracts on a user's behalf, to establish an `Identity` and drive address- and resolver-management for a given user. A user's `Identity` consists of a `string` stored in a Universal Identity Registry.


### Universal Identity Registry
The Universal Identity Registry contains functionality for a user to establish their core identity and manage their `Associated Addresses` and `Resolvers`. It is important to note that this registry fundamentally requires transactions for every aspect of building out a user's identity through both resolvers and addresses. Nonetheless, we recognize the importance of global accessibility to dApps and identity applications; accordingly, we include the option for a delegated identity-building scheme that allows smart contracts called `Providers` to build out a user's identity through signatures without requiring users to pay gas costs.

We propose that `Identities` be denominated by a `string` for user-friendliness instead of identifying individuals by an address. Identifying users by an address awkwardly provides added meaning to their owner address despite all linked addresses commonly identifying an individual. Further, it creates a more complicated user experience in passing their coreID to a resolver or third-party. Currently, the only practical way for a user to identify themselves is to copy-and-paste their Ethereum address or to share a QR code. While QR codes are helpful, we do not feel that they should be the sole notion of user-friendliness by which a user may identify themselves.

### Address Management
The address management function is very low-level. It consists of trustlessly connecting multiple user-owned `claimed_addresses` to a user's `coreID`. It does not prescribe any special status to any given address, rather leaving this specification to identity applications built on top of the protocol - for instance, `management`, `action`, `claim` and `encryption` keys denominated in the ERC-725 standard. This allows a user to access common identity data from multiple wallets while still
- retaining flexibility to interact with contracts outside of their core identity pseudonymously
- taking advantage of address-specific permissions established at the application layer of a user's identity.

Trustlessness in the address management function is achieved through a signature and verification scheme that requires two transactions - one from an address already within the registry and one from the address to be claimed.
We propose the following functions within the Universal Registry:

`createCoreID`: requires that the user sign: `hash("Create core ID", address, coreID, provider)` after which a transaction can be submitted that includes [`address`, `coreID`, `provider`, `signature`]. Importantly, the transaction need not come from the original user, which allows entities, governments, etc to bear the overhead of creating a core identity.

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


The following sample functions might be included in a provider:

- `mintIdentityToken`
- `mintIdentityTokenDelegated`
- `addResolvers`
- `addResolversDelegated`
- `removeResolvers`
- `removeResolversDelegated`
- `hasResolver`
- `ownsAddress`
- `initiateClaim`
- `unclaim`
- `getDetails`
- `whitelistResolver`
- `isWhitelisted`
- `getWhitelistedResolvers`
- `hasToken`

### ID backups
Backing up a user's coreID and associated addresses is important in any digital identity scheme. While various applications of identity may have independent on-chain and off-chain backup functions, we strongly suggest a strictly off-chain backup scheme for a user's core identity. This process should be enforced by providers. We propose selective user-trust to back up private keys using Shamir's secret sharing. A user may choose services or family and friends to retain identity fragments, a subset of which are required to restore his or her `coreID`. We recognize the inherent threat in the possibility of some centralized entities acting as 'identity vaults' colluding or maintaining poor security standards, a user is able to distribute this list by selecting a variety of custodians with different recovery criteria - security words, two-factor authentication, passwords, biometrics, photo-verification, and more. Moreover, we find the threat of collusion mitigated because if a user loses trust in custodians, he or she may remove the address over which the custodians possess fragments from their `coreID` in favor of a new access over which the user retains control. A serious collusion by custodials would likely require governance to resolve; however, we find this to be strictly better than the current standard of complete control by a single custodial as well as an enforced back-up standard that does not offer users flexibility in their selected level and nature of control. This on-chain functionality is important since a user is otherwise unable to revoke ownership of a key distributed under a secret-sharing scheme.

### Rationale
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

### Solidity Interface
```solidity
pragma solidity ^0.4.24;

contract ERCTBD {

  event IdentityMinted(string identity, address identityAddress, address provider, bool delegated);
  event ResolverAdded(string identity, address resolvers, address provider);
  event ResolverRemoved(string identity, address resolvers, address provider);
  event AddressAdded(string identity, address addedAddress, address approvingAddress, address provider);
  event AddressRemoved(string identity, address removedAddress, address provider);

  struct Identity {
    AddressSet.Set identityAddresses;
    AddressSet.Set providers;
    AddressSet.Set resolvers;
  }

  function identityExists(string identity) public view returns (bool);
  function hasIdentity(address _address) public view returns (bool);
  function getIdentity(address _address) public view returns (string identity);
  function isProviderFor(string identity, address provider) public view returns (bool);
  function isResolverFor(string identity, address resolver) public view returns (bool);
  function isAddressFor(string identity, address _address) public view returns (bool);
  function getDetails(string identity) public view returns (address[] identityAddresses, address[] providers, address[] resolvers);
  function mintIdentity(string identity, address provider) public;
  function mintIdentityDelegated(string identity, address identityAddress, uint8 v, bytes32 r, bytes32 s) public;
  function addProviders(address[] providers) public;
  function removeProviders(address[] providers) public;
  function addResolvers(string identity, address[] resolvers) public;
  function removeResolvers(string identity, address[] resolvers) public;
  function addAddress(string identity, address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt) public;
  function removeAddress(string identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public;
}
```
## Backwards Compatibility
`coreIDs` established under this standard are built from existing Ethereum addresses; accordingly, identity construction has no backwards compatibility issues.
Deployed, non-upgradeable smart contracts that wish to become `Resolvers` to a user's `coreID` will require wrapper contracts for `setResolver` and `removeResolver` functions. They will preserve all prior functionality.

## Additional References

## Copyright
Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
