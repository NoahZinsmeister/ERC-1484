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

    // identity structure
    struct Identity {
        bool minted;
        address recoveryAddress;
        AddressSet.Set associatedAddresses;
        AddressSet.Set providers;
        AddressSet.Set resolvers;
    }
    mapping (string => Identity) internal identityDirectory;
    mapping (address => string) internal associatedAddressDirectory;

    // signature log to prevent replay attacks
    mapping (bytes32 => bool) public signatureLog;

    // removed address log to give recently removed addresses the ability to permanently disable identities
    // struct AddressRemoval {
    //     uint timestamp;
    //     string fromIdentity;
    // }
    // mapping (address => AddressRemoval) internal removalLog;

    // checks whether a given identity exists (does not throw)
    function identityExists(string identity) public view returns (bool) {
        return identityDirectory[identity].minted;
    }

    // checks whether a given identity exists (does not throw)
    modifier _identityExists(string identity, bool check) {
        require(identityExists(identity) == check, "The passed identity does/does not exist.");
        _;
    }

    // checks whether a given address has an identity (does not throw)
    function hasIdentity(address _address) public view returns (bool) {
        return identityExists(associatedAddressDirectory[_address]);
    }

    // enforces that a given address has/does not have an identity
    modifier _hasIdentity(address _address, bool check) {
        require(hasIdentity(_address) == check, "The passed address has/does not have an identity.");
        _;
    }

    // gets the identity of an address (throws if the address doesn't have an identity)
    function getIdentity(address _address) public view _hasIdentity(_address, true) returns (string identity) {
        return associatedAddressDirectory[_address];
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
        return identityDirectory[identity].associatedAddresses.contains(_address);
    }

    // functions to read identity values (throws if the passed identity does not exist)
    function getDetails(string identity) public view _identityExists(identity, true)
        returns (address recoveryAddress, address[] associatedAddresses, address[] providers, address[] resolvers)
    {
        Identity storage _identity = identityDirectory[identity];
        return (
            _identity.recoveryAddress,
            _identity.associatedAddresses.members,
            _identity.providers.members,
            _identity.resolvers.members
        );
    }

    // mints a new identity for the msg.sender and sets the passed provider
    function mintIdentity(string identity, address recoveryAddress, address provider) public {
        mintIdentity(identity,recoveryAddress, msg.sender, provider, false);
    }

    // mints a new identity for the passed address with the msg.sender as the provider
    function mintIdentityDelegated(
        string identity, address recoveryAddress, address associatedAddress, uint8 v, bytes32 r, bytes32 s
    )
        public
    {
        require(
            isSigned(
                associatedAddress,
                keccak256(abi.encodePacked("Mint Identity", address(this), identity, associatedAddress, msg.sender)),
                v, r, s
            ),
            "Permission denied."
        );
        mintIdentity(identity, recoveryAddress, associatedAddress, msg.sender, true);
    }

    // common logic for all identity minting
    function mintIdentity(
        string identity, address recoveryAddress, address associatedAddress, address provider, bool delegated
    )
        private _identityExists(identity, false) _hasIdentity(associatedAddress, false)
    {
        require(bytes(identity).length <= 32, "Username too long.");
        require(bytes(identity).length >= 3,  "Username too short.");

        Identity storage _identity = identityDirectory[identity];

        _identity.minted = true;
        _identity.recoveryAddress = recoveryAddress;
        _identity.associatedAddresses.insert(associatedAddress);
        _identity.providers.insert(provider);

        associatedAddressDirectory[associatedAddress] = identity;

        emit IdentityMinted(identity, recoveryAddress, associatedAddress, provider, delegated);
    }

    // allows addresses associated with an identity to add providers
    function addProviders(address[] providers) public {
        Identity storage _identity = identityDirectory[getIdentity(msg.sender)];
        for (uint i; i < providers.length; i++) {
            _identity.providers.insert(providers[i]);
        }
    }

    // allows addresses associated with an identity to add providers
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
            _identity.associatedAddresses.contains(approvingAddress),
            "The passed approvingAddress is not associated with the passed identity."
        );

        bytes32 messageHash = keccak256(abi.encodePacked("Claim Address", identity, addressToAdd, salt));
        require(signatureLog[messageHash] == false, "Message hash has already been used.");
        require(isSigned(approvingAddress, messageHash, v[0], r[0], s[0]), "Permission denied from approving address.");
        require(isSigned(addressToAdd, messageHash, v[1], r[1], s[1]), "Permission denied from address to add.");
        signatureLog[messageHash] = true;

        _identity.associatedAddresses.insert(addressToAdd);
        associatedAddressDirectory[addressToAdd] = identity;

        emit AddressAdded(identity, addressToAdd, approvingAddress, msg.sender);
    }

    // allow providers to remove addresses
    function removeAddress(string identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt)
        public _isProviderFor(identity, msg.sender)
    {
        Identity storage _identity = identityDirectory[identity];

        require(
            _identity.associatedAddresses.contains(addressToRemove),
            "The passed addressToRemove is not associated with the passed identity."
        );

        bytes32 messageHash = keccak256(abi.encodePacked("Remove Address", identity, addressToRemove, salt));
        require(signatureLog[messageHash] == false, "Message hash has already been used.");
        require(isSigned(addressToRemove, messageHash, v, r, s), "Permission denied from address to remove.");
        signatureLog[messageHash] = true;

        _identity.associatedAddresses.remove(addressToRemove);
        delete associatedAddressDirectory[addressToRemove];

        emit AddressRemoved(identity, addressToRemove, msg.sender);
    }

    uint timeout = 2 weeks;

    struct RecoveryAddressChangeLog {
        uint timestamp;
        address oldRecoveryAddress;
    }
    mapping (string => RecoveryAddressChangeLog) internal recoveryAddressChangeLogs;

    function initiateRecoveryAddressChange(string identity, address newRecoveryAddress)
        public _isProviderFor(identity, msg.sender)
    {
        Identity storage _identity = identityDirectory[identity];
        RecoveryAddressChangeLog storage log = recoveryAddressChangeLogs[identity];

        // solium-disable-next-line security/no-block-members
        require(block.timestamp > log.timestamp + timeout, "Must wait for pending Recovery Address Change.");

        address oldRecoveryAddress = _identity.recoveryAddress;
        // solium-disable-next-line security/no-block-members
        log.timestamp = block.timestamp;
        log.oldRecoveryAddress = oldRecoveryAddress;

        _identity.recoveryAddress = newRecoveryAddress;

        emit RecoveryAddressChangeInitiated(identity, oldRecoveryAddress, newRecoveryAddress);
    }

    struct RecoveredChangeLog {
        uint timestamp;
        bytes32 hashedAssociatedAddresses;
    }
    mapping (string => RecoveredChangeLog) internal RecoveredChangeLogs;

    function triggerRecovery(string identity, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s)
        public  _identityExists(identity, true) _hasIdentity(newAssociatedAddress, false)
    {
        Identity storage _identity = identityDirectory[identity];
        RecoveryAddressChangeLog storage recoveryAddressChangeLog = recoveryAddressChangeLogs[identity];
        RecoveredChangeLog storage recoveredChangeLog = RecoveredChangeLogs[identity];

        // require that the identity hasn't been recovered within the last 2 weeks
        // solium-disable-next-line security/no-block-members
        require(block.timestamp > recoveredChangeLog.timestamp + timeout, "Must wait before recovering again.");

        // if there has not been a change of recovery address in the past 2 weeks...
        // solium-disable-next-line security/no-block-members
        if (block.timestamp > recoveryAddressChangeLog.timestamp + timeout) {
            require(
                msg.sender == _identity.recoveryAddress,
                "Only the current recovery address can initiate a recovery."
            );
        } else {
            require(
                msg.sender == recoveryAddressChangeLog.oldRecoveryAddress,
                "Only the recently removed recovery address can initiate a recovery."
            );
        }

        require(
            isSigned(
                newAssociatedAddress,
                keccak256(abi.encodePacked("Recover", address(this), identity, newAssociatedAddress)),
                v, r, s
            ),
            "Permission denied from address."
        );

        address[] memory oldAssociatedAddresses = _identity.associatedAddresses.members;
        removeAllAssociatedAddressesAndProviders(_identity);

        _identity.associatedAddresses.insert(newAssociatedAddress);
        associatedAddressDirectory[newAssociatedAddress] = identity;

        // store the hash of all removed associated addresses to enable poison pill
        // solium-disable-next-line security/no-block-members
        recoveredChangeLog.timestamp = block.timestamp;
        recoveredChangeLog.hashedAssociatedAddresses = keccak256(abi.encodePacked(oldAssociatedAddresses));

        emit RecoveryTriggered(identity, msg.sender, oldAssociatedAddresses, newAssociatedAddress);
    }

    // allows recently removed addresses to permanently disable the identity they were removed from
    function triggerPoisonPill(string identity, address[] chunk1, address[] chunk2, bool clearResolvers)
        public _identityExists(identity, true)
    {
        RecoveredChangeLog storage log = RecoveredChangeLogs[identity];

        // solium-disable-next-line security/no-block-members
        require(block.timestamp <= log.timestamp + timeout, "Timeout has expired.");
        
        address[1] memory middleChunk = [msg.sender];
        require(
            keccak256(abi.encodePacked(chunk1, middleChunk, chunk2)) == log.hashedAssociatedAddresses,
            "Cannot poison pill from an address that was not recently removed via recover"
        );

        Identity storage _identity = identityDirectory[identity];

        removeAllAssociatedAddressesAndProviders(_identity);
        if (clearResolvers) delete _identity.resolvers;

        emit Poisoned(identity, msg.sender, clearResolvers);
    }

    function removeAllAssociatedAddressesAndProviders(Identity storage identity) internal {
        address[] storage associatedAddresses = identity.associatedAddresses.members;
        for (uint i; i < associatedAddresses.length; i++) {
            delete associatedAddressDirectory[associatedAddresses[i]];
        }

        delete identity.associatedAddresses;        

        delete identity.providers;
    }

    // events
    event RecoveryAddressChangeInitiated(string identity, address oldRecoveryAddress, address newRecoveryAddress);
    event RecoveryTriggered(
        string identity, address recoveryAddress, address[] oldAssociatedAddress, address newAssociatedAddress
    );
    event Poisoned(string identity, address initiator, bool resolversCleared);
    event IdentityMinted(
        string identity, address recoveryAddress, address associatedAddress, address provider, bool delegated
    );
    event ResolverAdded(string identity, address resolvers, address provider);
    event ResolverRemoved(string identity, address resolvers, address provider);
    event AddressAdded(string identity, address addedAddress, address approvingAddress, address provider);
    event AddressRemoved(string identity, address removedAddress, address provider);
}
