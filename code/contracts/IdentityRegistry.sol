pragma solidity ^0.4.24;

import "./AddressSet/AddressSet.sol";


contract SignatureVerifier {
    // define the Ethereum prefix for signing a message of length 32
    bytes private prefix = "\x19Ethereum Signed Message:\n32";

    // checks if the provided (v, r, s) signature of messageHash was created by the private key associated with _address
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {
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
        private view returns (bool)
    {
        return _isSigned(_address, keccak256(abi.encodePacked(prefix, messageHash)), v, r, s);
    }
}


contract IdentityRegistry is SignatureVerifier {
    // bind address library
    using AddressSet for AddressSet.Set;

    // define identity data structure and mappings
    struct Identity {
        bool minted;
        address recoveryAddress;
        AddressSet.Set associatedAddresses;
        AddressSet.Set providers;
        AddressSet.Set resolvers;
    }

    uint public nextIdentity = 1;
    mapping (uint => Identity) private identityDirectory;
    mapping (address => uint) private associatedAddressDirectory;

    // signature log to prevent replay attacks
    mapping (bytes32 => bool) public signatureLog;

    // define data structures required for recovery and, in dire circumstances, poison pills
    uint public maxAssociatedAddresses = 20;
    uint public recoveryTimeout = 2 weeks;

    struct RecoveryAddressChange {
        uint timestamp;
        address oldRecoveryAddress;
    }
    mapping (uint => RecoveryAddressChange) private recoveryAddressChangeLogs;

    struct RecoveredChange {
        uint timestamp;
        bytes32 hashedOldAssociatedAddresses;
    }
    mapping (uint => RecoveredChange) private recoveredChangeLogs;


    // checks whether a given identity exists (does not throw)
    function identityExists(uint identity) public view returns (bool) {
        return identityDirectory[identity].minted;
    }

    // checks whether a given identity exists (does not throw)
    modifier _identityExists(uint identity, bool check) {
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
    function getIdentity(address _address) public view _hasIdentity(_address, true) returns (uint identity) {
        return associatedAddressDirectory[_address];
    }

    // checks whether a given identity has an address (does not throw)
    function isAddressFor(uint identity, address _address) public view returns (bool) {
        if (!identityExists(identity)) return false;
        return identityDirectory[identity].associatedAddresses.contains(_address);
    }

    // checks whether a given identity has a provider (does not throw)
    function isProviderFor(uint identity, address provider) public view returns (bool) {
        if (!identityExists(identity)) return false;
        return identityDirectory[identity].providers.contains(provider);
    }

    // enforces that an identity has a provider
    modifier _isProviderFor(uint identity, address provider) {
        require(isProviderFor(identity, provider), "The passed identity has/has not set the passed provider.");
        _;
    }

    // checks whether a given identity has a resolver (does not throw)
    function isResolverFor(uint identity, address resolver) public view returns (bool) {
        if (!identityExists(identity)) return false;
        return identityDirectory[identity].resolvers.contains(resolver);
    }

    // functions to read identity values (throws if the passed identity does not exist)
    function getDetails(uint identity) public view _identityExists(identity, true)
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

    // checks whether or not a passed timestamp is within/not within the timeout period
    function isTimedOut(uint timestamp) private view returns (bool) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp > timestamp + recoveryTimeout;
    }


    // mints a new identity for the msg.sender
    function mintIdentity(address recoveryAddress, address provider, address[] resolvers) public returns (uint identity)
    {
        return mintIdentity(recoveryAddress, msg.sender, provider, resolvers, false);
    }

    // mints a new identity for the passed address (with the msg.sender as the implicit provider)
    function mintIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers, uint8 v, bytes32 r, bytes32 s
    )
        public returns (uint identity)
    {
        require(
            isSigned(
                associatedAddress,
                keccak256(
                    abi.encodePacked(
                        "Mint", address(this), identity, recoveryAddress, associatedAddress, msg.sender, resolvers
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        return mintIdentity(recoveryAddress, associatedAddress, msg.sender, resolvers, true);
    }

    // common logic for all identity minting
    function mintIdentity(
        address recoveryAddress,
        address associatedAddress,
        address provider,
        address[] resolvers,
        bool delegated
    )
        private _identityExists(identity, false) _hasIdentity(associatedAddress, false) returns (uint)
    {
        uint identity = nextIdentity++;

        // set identity variables
        Identity storage _identity = identityDirectory[identity];
        _identity.minted = true;
        _identity.recoveryAddress = recoveryAddress;
        _identity.associatedAddresses.insert(associatedAddress);
        _identity.providers.insert(provider);
        for (uint i; i < resolvers.length; i++) {
            _identity.resolvers.insert(resolvers[i]);
        }

        // set reverse address lookup
        associatedAddressDirectory[associatedAddress] = identity;

        emit IdentityMinted(identity, recoveryAddress, associatedAddress, provider, resolvers, delegated);

        return identity;
    }

    // allow providers to add addresses
    function addAddress(
        uint identity,
        address addressToAdd,
        address approvingAddress,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt
    )
        public _isProviderFor(identity, msg.sender) _hasIdentity(addressToAdd, false)
    {
        Identity storage _identity = identityDirectory[identity];
        require(
            _identity.associatedAddresses.contains(approvingAddress),
            "The passed approvingAddress is not associated with the passed identity."
        );
        require(_identity.associatedAddresses.length() <= maxAssociatedAddresses, "Cannot add >20 addresses.");

        bytes32 messageHash = keccak256(abi.encodePacked("Add Address", identity, addressToAdd, salt));
        require(signatureLog[messageHash] == false, "Message hash has already been used.");
        require(isSigned(approvingAddress, messageHash, v[0], r[0], s[0]), "Permission denied from approving address.");
        require(isSigned(addressToAdd, messageHash, v[1], r[1], s[1]), "Permission denied from address to add.");
        signatureLog[messageHash] = true;

        _identity.associatedAddresses.insert(addressToAdd);
        associatedAddressDirectory[addressToAdd] = identity;

        emit AddressAdded(identity, addressToAdd, approvingAddress, msg.sender);
    }

    // allow providers to remove addresses
    function removeAddress(uint identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt)
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

    // allows addresses associated with an identity to add providers
    function addProviders(address[] providers) public _hasIdentity(msg.sender, true) {
        addProviders(getIdentity(msg.sender), providers, false);
    }

    // allows providers to add other providers for addresses
    function addProviders(
        uint identity, address[] providers, address approvingAddress, uint8 v, bytes32 r, bytes32 s, uint salt
    )
        public _isProviderFor(identity, msg.sender)
    {
        Identity storage _identity = identityDirectory[identity];

        require(
            _identity.associatedAddresses.contains(approvingAddress),
            "The passed approvingAddress is not associated with the passed identity."
        );

        bytes32 messageHash = keccak256(abi.encodePacked("Add Provider", identity, providers, salt));
        require(signatureLog[messageHash] == false, "Message hash has already been used.");
        require(isSigned(approvingAddress, messageHash, v, r, s), "Permission denied.");
        signatureLog[messageHash] = true;

        addProviders(identity, providers, true);
    }

    function addProviders(uint identity, address[] providers, bool delegated) private {
        Identity storage _identity = identityDirectory[identity];
        for (uint i; i < providers.length; i++) {
            _identity.providers.insert(providers[i]);
            emit ProviderAdded(identity, providers[i], delegated);
        }
    }

    // allows addresses associated with an identity to remove providers
    function removeProviders(address[] providers) public _hasIdentity(msg.sender, true) {
        removeProviders(getIdentity(msg.sender), providers, false);
    }

    // allows providers to remove other providers for addresses
    function removeProviders(
        uint identity, address[] providers, address approvingAddress, uint8 v, bytes32 r, bytes32 s, uint salt
    )
        public _isProviderFor(identity, msg.sender)
    {
        Identity storage _identity = identityDirectory[identity];

        require(
            _identity.associatedAddresses.contains(approvingAddress),
            "The passed approvingAddress is not associated with the passed identity."
        );

        bytes32 messageHash = keccak256(abi.encodePacked("Remove Provider", identity, providers, salt));
        require(signatureLog[messageHash] == false, "Message hash has already been used.");
        require(isSigned(approvingAddress, messageHash, v, r, s), "Permission denied.");
        signatureLog[messageHash] = true;

        removeProviders(identity, providers, true);
    }

    function removeProviders(uint identity, address[] providers, bool delegated) private {
        Identity storage _identity = identityDirectory[identity];
        for (uint i; i < providers.length; i++) {
            _identity.providers.remove(providers[i]);
            emit ProviderRemoved(identity, providers[i], delegated);
        }
    }

    // allow providers to add resolvers
    function addResolvers(uint identity, address[] resolvers) public _isProviderFor(identity, msg.sender) {
        Identity storage _identity = identityDirectory[identity];
        for (uint i; i < resolvers.length; i++) {
            _identity.resolvers.insert(resolvers[i]);
            emit ResolverAdded(identity, resolvers[i], msg.sender);
        }
    }

    // allow providers to remove resolvers
    function removeResolvers(uint identity, address[] resolvers) public _isProviderFor(identity, msg.sender) {
        Identity storage _identity = identityDirectory[identity];
        for (uint i; i < resolvers.length; i++) {
            _identity.resolvers.remove(resolvers[i]);
            emit ResolverRemoved(identity, resolvers[i], msg.sender);
        }
    }


    // initiate a change in recovery address
    function initiateRecoveryAddressChange(uint identity, address newRecoveryAddress)
        public _isProviderFor(identity, msg.sender)
    {
        RecoveryAddressChange storage log = recoveryAddressChangeLogs[identity];
        require(isTimedOut(log.timestamp), "Pending change of recovery address has not timed out.");

        // log the old recovery address
        Identity storage _identity = identityDirectory[identity];
        address oldRecoveryAddress = _identity.recoveryAddress;
        // solium-disable-next-line security/no-block-members
        log.timestamp = block.timestamp;
        log.oldRecoveryAddress = oldRecoveryAddress;

        // make the change
        _identity.recoveryAddress = newRecoveryAddress;

        emit RecoveryAddressChangeInitiated(identity, oldRecoveryAddress, newRecoveryAddress);
    }

    // initiate recovery, only callable by the current recovery address, or the one changed within the past 2 weeks
    function triggerRecovery(uint identity, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s)
        public  _identityExists(identity, true) _hasIdentity(newAssociatedAddress, false)
    {
        RecoveredChange storage recoveredChange = recoveredChangeLogs[identity];
        require(isTimedOut(recoveredChange.timestamp), "It's not been long enough since the last recovery.");

        // ensure the sender is the recovery address/old recovery address if there's been a recent change
        Identity storage _identity = identityDirectory[identity];
        RecoveryAddressChange storage recoveryAddressChange = recoveryAddressChangeLogs[identity];
        if (isTimedOut(recoveryAddressChange.timestamp)) {
            require(
                msg.sender == _identity.recoveryAddress,
                "Only the current recovery address can initiate a recovery."
            );
        } else {
            require(
                msg.sender == recoveryAddressChange.oldRecoveryAddress,
                "Only the recently removed recovery address can initiate a recovery."
            );
        }

        require(
            isSigned(
                newAssociatedAddress,
                keccak256(abi.encodePacked("Recover", address(this), identity, newAssociatedAddress)),
                v, r, s
            ),
            "Permission denied."
        );

        // log the old associated addresses to unlock the poison pill
        address[] memory oldAssociatedAddresses = _identity.associatedAddresses.members;
        // solium-disable-next-line security/no-block-members
        recoveredChange.timestamp = block.timestamp;
        recoveredChange.hashedOldAssociatedAddresses = keccak256(abi.encodePacked(oldAssociatedAddresses));

        // remove identity data, and add the new address as the sole provider
        clearAllIdentityData(_identity, false);
        _identity.associatedAddresses.insert(newAssociatedAddress);
        associatedAddressDirectory[newAssociatedAddress] = identity;

        emit RecoveryTriggered(identity, msg.sender, oldAssociatedAddresses, newAssociatedAddress);
    }

    // allows addresses recently removed by recovery to permanently disable the identity they were removed from
    function triggerPoisonPill(uint identity, address[] firstChunk, address[] lastChunk, bool clearResolvers)
        public _identityExists(identity, true)
    {
        RecoveredChange storage log = recoveredChangeLogs[identity];
        require(!isTimedOut(log.timestamp), "No addresses have recently been removed from a recovery.");
        
        // ensure that the msg.sender was an old associated address for the passed identity
        address[1] memory middleChunk = [msg.sender];
        require(
            keccak256(abi.encodePacked(firstChunk, middleChunk, lastChunk)) == log.hashedOldAssociatedAddresses,
            "Cannot activate the poison pill from an address that was not recently removed via recover."
        );

        // poison the identity
        Identity storage _identity = identityDirectory[identity];
        clearAllIdentityData(_identity, clearResolvers);

        emit Poisoned(identity, msg.sender, clearResolvers);
    }

    // removes all associated addresses, providers, and optionally resolvers from an identity
    function clearAllIdentityData(Identity storage identity, bool clearResolvers) private {
        address[] storage associatedAddresses = identity.associatedAddresses.members;
        for (uint i; i < associatedAddresses.length; i++) {
            delete associatedAddressDirectory[associatedAddresses[i]];
        }
        delete identity.associatedAddresses;
        delete identity.providers;
        if (clearResolvers) delete identity.providers;
    }


    // define events
    event IdentityMinted(
        uint indexed identity,
        address recoveryAddress,
        address associatedAddress,
        address provider,
        address[] resolvers,
        bool delegated
    );
    event AddressAdded(uint indexed identity, address addedAddress, address approvingAddress, address provider);
    event AddressRemoved(uint indexed identity, address removedAddress, address provider);
    event ProviderAdded(uint indexed identity, address provider, bool delegated);
    event ProviderRemoved(uint indexed identity, address provider, bool delegated);
    event ResolverAdded(uint indexed identity, address resolvers, address provider);
    event ResolverRemoved(uint indexed identity, address resolvers, address provider);
    event RecoveryAddressChangeInitiated(uint indexed identity, address oldRecoveryAddress, address newRecoveryAddress);
    event RecoveryTriggered(
        uint indexed identity, address recoveryAddress, address[] oldAssociatedAddress, address newAssociatedAddress
    );
    event Poisoned(uint indexed identity, address poisoner, bool resolversCleared);
}
