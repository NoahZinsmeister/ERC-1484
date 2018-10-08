---
eip: TBD
title: Digital Identity Aggregator
author: Anurag Angara, Noah Zinsmeister, Shane Hampton, Andy Chorlian
discussions-to: https://github.com/ethereum/EIPs/issues/TBD
status: Draft
type: Standards Track
category: ERC
created: 2018-10-08
---

## Simple Summary
Protocol for aggregating digital identity information.

## Abstract
This is a proposal for an identity management and aggregation framework on the Ethereum blockchain. It includes a set of standard functions to manage identity applications that are all tied to a unique core identity.

## Motivation
Emerging identity standards and related frameworks proposed by the Ethereum community (including ERC/EIP 725, 735, 780, 1056, etc.) add value to an individual's digital identity in various ways. As these and new standards come along - in addition to many other isolated, non-standard instances of identity in the global digital ecosystem - the on-chain management of multiple identities will likely become burdensome and involve the unnecessary duplication of work.

To a large extent, the functional fixedness of any given identity application exists because identity applications are built *directly* on Ethereum as a protocol. Ethereum exists as a governance protocol which should lie a layer below application-specific protocols. In the case of identity, this structure allows for multiple instances of an identity to maintain interoperability. Accordingly, this proposal consists of a protocol layer in between the Ethereum network and existing identity applications.

This proposal attempts to solve existing identity management and interoperability challenges by introducing an aggregatory identity protocol. As identity clusters become more comprehensive, robust, and complex, all stakeholders in the digital identity ecosystem can benefit from a standard identity management protocol.

## Definitions
- `Resolvers`: smart contracts containing arbitrary information that resolves back to a user's `coreID`. A resolver may be any identity standard such as  `ERC 725`, but may also consist of other smart contracts leveraging or declaring identifying information such as a lending dApp, a credit score, a social media dApp, etc.

- `coreID`: A mapping of a user's owned Ethereum addresses to a searchable string

- `Providers`: Smart contracts authorized to `set` resolvers, `remove` resolvers, `add` addresses, and `remove` addresses from a user's core identity, given a signature from a user-owned address.

## Specification
A core digital identity (the center of an identity cluster) can be viewed as an omnibus account, consisting of more information than any individual identity application can contain about an individual. This omnibus identity is resolvable to an unlimited number of sub-identities. The protocol recognizes ownership of two things: addresses (Ethereum addresses) and resolvers (external entities housing any identifying information that can be resolved to the Ethereum network).

The specification allows for users directly, or user-approved smart contracts on a user's behalf, to establish a `coreID` and drive address-management and resolver-management for a given user. A user's `coreID` consists of a `string`-searchable Ethereum `owner_address` stored on a Universal Registry.


### Universal Registry
The Universal Registry should contain functionality for a user to establish their core identity and manage their Ethereum addresses and Resolvers. It is important to note that this registry fundamentally requires transactions for every aspect of building out a user's identity through both resolvers and addresses. Nonetheless, we recognize the importance of global accessibility to dApps and identity applications; accordingly, we include the option for a delegated identity-building scheme that allows smart contracts called `providers` to build out a user's identity through signatures without requiring users to pay gas costs.

A string-based `coreID` is proposed for user-friendliness instead of identifying individuals by an address. Identifying users by an address awkwardly provides added meaning to their owner address despite all linked addresses commonly identifying an individual. Further, it creates a more complicated user experience in passing their coreID to a resolver or third-party. Currently, the only practical way for a user to identify themselves is to copy-and-paste their Ethereum address or to share a QR code. While QR codes are helpful, we do not feel that they should be the sole notion of user-friendliness by which a user may identify themselves.

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

## Implementation
### Solidity Interface
```solidity
pragma solidity ^0.4.24;

contract ERCTBD {

}
```
## Additional References

## Copyright
Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
