pragma solidity ^0.4.24;

import "./AddressSet/AddressSet.sol";

contract SignatureVerifier {
    // checks if the provided (v, r, s) signature of messageHash was created by the private key associated with _address
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns (bool) {
        return _isSigned(_address, messageHash, v, r, s) || _isSignedPrefixed(_address, messageHash, v, r, s);
    }

    // checks unprefixed signatures
    function _isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        private pure returns (bool)
    {
        return ecrecover(messageHash, v, r, s) == _address;
    }

    // checks prefixed signatures
    function _isSignedPrefixed(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        private pure returns (bool)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedMessageHash = keccak256(abi.encodePacked(prefix, messageHash));
        return ecrecover(prefixedMessageHash, v, r, s) == _address;
    }
}

contract IdentityRegistry is SignatureVerifier {
    // bind address library
    using AddressSet for AddressSet.Set;

    // identity lookup mappings
    mapping (string => Identity) internal identityDirectory;
    mapping (address => string) internal identityAddressDirectory;

    // log to prevent duplicate signatures
    mapping (bytes32 => bool) signatureLog;

    // identity structures
    struct Identity {
        AddressSet.Set identityAddresses;
        AddressSet.Set providers;
        AddressSet.Set resolvers;
    }

    // checks whether a given identity exists (does not throw)
    function identityExists(string identity) public view returns (bool) {
        return identityDirectory[identity].identityAddresses.length() > 0;
    }

    // checks whether a given identity exists (does not throw)
    modifier _identityExists(string identity, bool check) {
        require(identityExists(identity) == check, "The passed identity does/does not exist.");
        _;
    }

    // checks whether a given address has an identity (does not throw)
    function hasIdentity(address _address) public view returns (bool) {
        return bytes(identityAddressDirectory[_address]).length > 0;
    }

    // enforces that a given address has/does not have an identity
    modifier _hasIdentity(address _address, bool check) {
        require(hasIdentity(_address) == check, "The passed address has/does not have an identity.");
        _;
    }

    // gets the identity of an address (throws if the address doesn't have an identity)
    function getIdentity(address _address) public view _hasIdentity(_address, true) returns (string identity) {
        return identityAddressDirectory[_address];
    }

    // checks whether a given identity has a provider (does not throw)
    function isProviderFor(string identity, address provider) public view returns (bool) {
        if (!identityExists(identity)) return false;
        return identityDirectory[identity].providers.contains(provider);
    }

    // enforces that an identity has a provider
    modifier _isProviderFor(string identity, address provider) {
        require(isProviderFor(identity, provider), "The passed identity has/has not set the passed provider.");
        _;
    }

    // checks whether a given identity has a resolver (does not throw)
    function isResolverFor(string identity, address resolver) public view returns (bool) {
        if (!identityExists(identity)) return false;
        return identityDirectory[identity].resolvers.contains(resolver);
    }

    // checks whether a given identity has an address (does not throw)
    function isAddressFor(string identity, address _address) public view returns (bool) {
        if (!identityExists(identity)) return false;
        return identityDirectory[identity].identityAddresses.contains(_address);
    }

    // functions to read identity values (throws if the passed identity does not exist)
    function getDetails(string identity) public view _identityExists(identity, true)
        returns (address[] identityAddresses, address[] providers, address[] resolvers)
    {
        Identity storage _identity = identityDirectory[identity];
        return (
            _identity.identityAddresses.members,
            _identity.providers.members,
            _identity.resolvers.members
        );
    }

    // mints a new identity for the msg.sender and sets the passed provider
    function mintIdentity(string identity, address provider) public {
        mintIdentity(identity, msg.sender, provider, false);
    }

    // mints a new identity for the passed address with the msg.sender as the provider
    function mintIdentityDelegated(string identity, address identityAddress, uint8 v, bytes32 r, bytes32 s) public {
        require(
            isSigned(
                identityAddress,
                keccak256(abi.encodePacked("Mint Identity", address(this), identity, identityAddress, msg.sender)),
                v, r, s
            ),
            "Permission denied."
        );
        mintIdentity(identity, identityAddress, msg.sender, true);
    }

    // common logic for all identity minting
    function mintIdentity(string identity, address identityAddress, address provider, bool delegated)
        private _identityExists(identity, false) _hasIdentity(identityAddress, false)
    {
        require(bytes(identity).length <= 32, "Username too long.");
        require(bytes(identity).length >= 3,  "Username too short.");

        Identity storage _identity = identityDirectory[identity];

        _identity.identityAddresses.insert(identityAddress);
        _identity.providers.insert(provider);

        identityAddressDirectory[identityAddress] = identity;

        emit IdentityMinted(identity, identityAddress, provider, delegated);
    }

    // add a provider from the identity associated with the msg.sender
    function addProviders(address[] providers) public {
        Identity storage _identity = identityDirectory[getIdentity(msg.sender)];
        for (uint i; i < providers.length; i++) {
            _identity.providers.insert(providers[i]);
        }
    }

    // remove a provider from the identity associated with the msg.sender
    function removeProviders(address[] providers) public {
        Identity storage _identity = identityDirectory[getIdentity(msg.sender)];
        for (uint i; i < providers.length; i++) {
            _identity.providers.remove(providers[i]);
        }
    }

    // allow providers to add resolvers
    function addResolvers(string identity, address[] resolvers) public _isProviderFor(identity, msg.sender) {
        Identity storage _identity = identityDirectory[identity];

        for (uint i; i < resolvers.length; i++) {
            _identity.resolvers.insert(resolvers[i]);
            emit ResolverAdded(identity, resolvers[i], msg.sender);
        }
    }

    // allow providers to remove resolvers
    function removeResolvers(string identity, address[] resolvers) public _isProviderFor(identity, msg.sender) {
        Identity storage _identity = identityDirectory[identity];

        for (uint i; i < resolvers.length; i++) {
            _identity.resolvers.remove(resolvers[i]);
            emit ResolverRemoved(identity, resolvers[i], msg.sender);
        }
    }

    // allow providers to add addresses
    function addAddress(
        string identity,
        address approvingAddress,
        address addressToAdd,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt
    )
        public _isProviderFor(identity, msg.sender) _hasIdentity(addressToAdd, false)
    {
        Identity storage _identity = identityDirectory[identity];

        require(
            _identity.identityAddresses.contains(approvingAddress),
            "The passed approvingAddress is not associated with the passed identity."
        );

        bytes32 messageHash = keccak256(abi.encodePacked("Claim Address", identity, addressToAdd, salt));
        require(signatureLog[messageHash] == false, "Message hash has already been used.");
        require(isSigned(approvingAddress, messageHash, v[0], r[0], s[0]), "Permission denied from approving address.");
        require(isSigned(addressToAdd, messageHash, v[1], r[1], s[1]), "Permission denied from address to add.");
        signatureLog[messageHash] = true;

        _identity.identityAddresses.insert(addressToAdd);

        emit AddressAdded(identity, addressToAdd, approvingAddress, msg.sender);
    }

    // allow providers to remove addresses
    function removeAddress(string identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt)
        public _isProviderFor(identity, msg.sender)
    {
        Identity storage _identity = identityDirectory[identity];

        require(
            _identity.identityAddresses.contains(addressToRemove),
            "The passed addressToRemove is not associated with the passed identity."
        );

        bytes32 messageHash = keccak256(abi.encodePacked("Remove Address", identity, addressToRemove, salt));
        require(signatureLog[messageHash] == false, "Message hash has already been used.");
        require(isSigned(addressToRemove, messageHash, v, r, s), "Permission denied from address to remove.");
        signatureLog[messageHash] = true;

        _identity.identityAddresses.remove(addressToRemove);

        emit AddressRemoved(identity, addressToRemove, msg.sender);
    }

    // events
    event IdentityMinted(string identity, address identityAddress, address provider, bool delegated);
    event ResolverAdded(string identity, address resolvers, address provider);
    event ResolverRemoved(string identity, address resolvers, address provider);
    event AddressAdded(string identity, address addedAddress, address approvingAddress, address provider);
    event AddressRemoved(string identity, address removedAddress, address provider);
}
