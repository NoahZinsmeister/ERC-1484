did:erc1484 method
=================
16th October 2018

Anurag Angara <<anurag.angara@gmail.com>>,
Andy Chorlian <<andychorlian@gmail.com>>,
Shane Hampton <<shanehampton1@gmail.com>>,
Noah Zinsmeister <<noahwz@gmail.com>>


Decentralized Identifiers (DIDs, see **[1]**) are designed to be compatible with any distributed ledger or network (called the target system).
In the Ethereum community, a pattern known as ERC1484 (see **[2]**) utilizes an on-chain registry to resolve a user-controlled `Identity` to arbitrary data structures in smart contracts.
We propose a new DID method that allows ERC1484 identities to be treated as valid DIDs, denominated by a globally unique `EIN` designated in a `Registry` that enables construction of each unique `Identity`.

One advantage of this DID method over others appears to be the ability to aggregate arbitrarily sophisticated identity management frameworks to an entity on the Ethereum network.

## DID Method Name

The namestring that shall identify this DID method is: `erc1484`.

A DID that uses this method MUST begin with the following prefix: `did:erc1484`. Per the DID specification, this string MUST be in lowercase. The remainder of the DID, after the prefix, is specified below.

## Method Specific Identifier

The method specific identifier is composed of an optional Ethereum network identifier with a `:` separator, followed by the IdentityRegistry contract address, and an `EIN` encoded as a 32-byte hex string.

	erc1484-did = "did:erc1484:" [erc1484-specific-idstring]
	erc1484-specific-idstring = [erc1484-network]  ":" [IdentityRegistry contract address] ":" [hex-encoded EIN]
	erc1484-network  = "mainnet" / "ropsten" / "rinkeby" / "kovan"
	[IdentityRegistry contract Address] = Ideally [TBD]; however the DID should account for alternate implementations
	hex-encoded EIN = [EIN denoted in IdentityRegistry encoded as a 32-byte hex string]


The `EIN` in the IdentityRegistry is encoded as a uint; however, to standardize the DID, it is hex-encoded in this DID method. Ultimately, the DID should be: `did:erc1484:<network>:<contract_address>:<32-byte hex EIN>` where the absence of <network> defaults to `mainnet`.

This specification currently only supports Ethereum "mainnet", "ropsten", "rinkeby", and "kovan", but
can be extended in the future to support arbitrary Ethereum instances (including private ones).

### Example

Example `erc1484` DIDs:

 * `did:erc1484:0xd26846cd6EE289AccF82350c8b2087fedB8A0C07:00000000000000000000000000000000000000000000000000000000000000e1`
 * `did:erc1484:mainnet:0xd26846cd6EE289AccF82350c8b2087fedB8A0C07:00000000000000000000000000000000000000000000000000000000000000e1`
 * `did:erc1484:ropsten:0xdd974D5C2e2928deA5C21b9825b8c916686AC200:00000000000000000000000000000000000000000000000000000000000000e1`

## DID Document

### Example

	{
		"@context": "https://w3id.org/did/v1",
		"id": "did:erc1484:ropsten:0xdd974D5C2e2928deA5C21b9825b8c916686AC200:00000000000000000000000000000000000000000000000000000000000000e1",
		"RecoveryKey": [{
			//this can initiate recovery as outlined in the IdentityRegistry
			"id": "did:erc1484:ropsten:0xdd974D5C2e2928deA5C21b9825b8c916686AC200:00000000000000000000000000000000000000000000000000000000000000e1",
      		"type": ["Secp256k1RecoveryKey2018"]
			"publicKeyHex": "0c8181aaf9bfcd703f25cc6b3814023d4a38cae4aba6e7f1ce8e0c41fbc84210edbc04a97ea6f566e376261c465387f730a39f2f87fd74512ca55a32caea71ce"
		},
		"authentication": {
			//this can be used to authenticate an identity through signatures
			"type": "Secp256k1AssociatedAddress2018",
			"publicKeyHex": "3e5ff6bea277535d32368325f416492fb89b58cae0b53ec415a2d8c65b670f182c26eb093402b6f5315816d881806f0b8b8cce4e9ee5cf5d759ff99af1da7d65"
		},
		"authentication": {
			"type": "Secp256k1AssociatedAddress2018",
			"publicKeyHex": "cd509276b337548586915d1dfb4c38af16f8717c099e4f739f8935c3983773dd4b232c6fec946832afe092fa60b1033a767c50469fb58e4b91e4a21a16dbe1ac"
		}
		"service": []
	}


## CRUD Operation Definitions

### Create (Register)

To create a DID, the `createIdentity` or `createIdentityDelegated` functions of the ERC-1484 `IdentityRegistry` must be called. The returned `EIN` becomes the entity defined by the DID per the specifications above (i.e. `did:erc1484:00000000000000000000000000000000000000000000000000000000000000e1`).

### Read (Resolve)

To construct a valid DID document from an `erc1484` DID, the following steps are performed:

1. Determine the Ethereum network identifier ("mainnet", "ropsten", "rinkeby", or "kovan"). If the DID contains no network identifier, then the default is "mainnet".
1. Determine the IdentityRegistry contract address on which the `EIN` is registered.
1. Invoke the `getDetails` function of the `Identity Registry ERC 1484 contract` for the `EIN`. Hex-encode the `EIN`.
  1. Add the returned `Recovery Address` to the DID Document in the specified format above.
  1. For the returned `Recovery Address` address, look up the secp256k1 public key associated with the key address. Add the public key to the DID Document in the specified format above.
1. For each `Associated Address` public key:
	1. Add a `publicKeyHex` of type `Secp256k1AssociatedAddress2018` (see **[3]**) to the DID Document.

Note: Service endpoints and other elements of a DID Document may be supported in future versions of this specification.

### Update

The DID Document may be updated by invoking the relevant smart contract functions as defined by the ERC1484 standard:

 * `function initiateRecoveryAddressChange(uint ein, address newRecoveryAddress) public;`
 * `function addAddress(
    uint ein, address addressToAdd, address approvingAddress, uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt
) public;`
 * `function removeAddress(uint ein, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public;`
 * `function triggerRecovery(uint ein, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s) public;`

Note that these methods are written in the Solidity language. Ethereum smart contracts are actually executed as binary code running in the Ethereum Virtual Machine (EVM).

### Delete (Revoke)

Revoking the DID can be supported by executing a `triggerPoisonPill` function in the smart contract. This will effectively mark the DID as revoked.

`function triggerPoisonPill(uint ein, address[] firstChunk, address[] lastChunk, bool clearResolvers) public;`

## Security Considerations

TODO

## Privacy Considerations

TODO

## Performance Considerations

In Ethereum, looking up a raw public key from a native 20-byte address is a complex and resource-intensive process. The DID community may want to consider allowing the truncated hash of a public key in the DID documents instead of (or in addition to) the raw public keys. It seems this would make certain DID methods such as `erc725` or `erc1484` much simpler to implement, while at the same time not really limiting the spirit and potential use cases of DIDs.

References
----------

 **[1]** https://w3c-ccg.github.io/did-spec/

 **[2]** https://github.com/ethereum/EIPs/pull/1484

 **[3]** https://w3c-dvcg.github.io/lds-koblitz2016/
