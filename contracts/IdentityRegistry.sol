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
        return _isSigned(_address, keccak256(abi.encodePacked(prefix, messageHash)), v, r, s);
    }
}


contract IdentityRegistry is SignatureVerifier {
    using AddressSet for AddressSet.Set;

    // define identity data structure and mappings
    struct Identity {
        address recoveryAddress;
        AddressSet.Set associatedAddresses;
        AddressSet.Set providers;
        AddressSet.Set resolvers;
    }

    uint public nextEIN = 1;
    mapping (uint => Identity) private identityDirectory;
    mapping (address => uint) private associatedAddressDirectory;

    // define signature timeout variables/data structures/modifiers
    uint public signatureTimeout = 1 days;

    modifier ensureSignatureTimeValid(uint timestamp) {
        require(
            // solium-disable-next-line security/no-block-members
            block.timestamp >= timestamp && block.timestamp <= timestamp + signatureTimeout, "Timestamp is not valid."
        );
        _;
    }

    // define recovery and poison pill variables/data structures/modifiers
    uint public recoveryTimeout = 2 weeks;
    uint public maxAssociatedAddresses = 25;

    struct RecoveryAddressChange {
        uint timestamp;
        address oldRecoveryAddress;
    }
    mapping (uint => RecoveryAddressChange) private recoveryAddressChangeLogs;

    struct Recovery {
        uint timestamp;
        bytes32 hashedOldAssociatedAddresses;
    }
    mapping (uint => Recovery) private recoveryLogs;

    // checks if the passed ein has changed recovery addresses within the recoveryTimeout
    function canChangeRecoveryAddress(uint ein) private view returns (bool) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp > recoveryAddressChangeLogs[ein].timestamp + recoveryTimeout;
    }

    // enforces that the passed ein has not changed recovery addresses within the recoveryTimeout
    modifier _canChangeRecoveryAddress(uint ein) {
        require(canChangeRecoveryAddress(ein), "Cannot trigger a change in recovery address yet.");
        _;
    }

    // enforces that the passed ein has not recovered within the recoveryTimeout
    function canRecover(uint ein, bool check) private view {
        require(
            // solium-disable-next-line security/no-block-members
            block.timestamp > recoveryLogs[ein].timestamp + recoveryTimeout == check,
            "Can/cannot trigger recovery yet."
        );
    }


    // checks whether a given identity exists (does not throw)
    function identityExists(uint ein) public view returns (bool) {
        return ein < nextEIN && ein > 0;
    }

    // checks whether a given identity exists
    modifier _identityExists(uint ein) {
        require(identityExists(ein), "The identity does not exist.");
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

    // gets the ein of an address (throws if the address doesn't have an ein)
    function getEIN(address _address) public view _hasIdentity(_address, true) returns (uint ein) {
        return associatedAddressDirectory[_address];
    }

    // checks whether a given identity has an address (does not throw)
    function isAssociatedAddressFor(uint ein, address _address) public view returns (bool) {
        return identityDirectory[ein].associatedAddresses.contains(_address);
    }

    // checks whether a given identity has a provider (does not throw)
    function isProviderFor(uint ein, address provider) public view returns (bool) {
        return identityDirectory[ein].providers.contains(provider);
    }

    // enforces that an the msg.sender is a provider for the passed identity
    modifier _isProviderFor(uint ein) {
        require(isProviderFor(ein, msg.sender), "The identity has not set the passed provider.");
        _;
    }

    // checks whether a given identity has a resolver (does not throw)
    function isResolverFor(uint ein, address resolver) public view returns (bool) {
        return identityDirectory[ein].resolvers.contains(resolver);
    }

    // functions to read identity values (throws if the passed EIN does not exist)
    function getIdentity(uint ein) public view _identityExists(ein)
        returns (address recoveryAddress, address[] associatedAddresses, address[] providers, address[] resolvers)
    {
        Identity storage _identity = identityDirectory[ein];

        return (
            _identity.recoveryAddress,
            _identity.associatedAddresses.members,
            _identity.providers.members,
            _identity.resolvers.members
        );
    }

    // creates a new identity for the msg.sender
    function createIdentity(address recoveryAddress, address provider, address[] resolvers) public returns (uint ein)
    {
        return createIdentity(recoveryAddress, msg.sender, provider, resolvers, false);
    }

    // creates a new identity for the passed address (with the msg.sender as the implicit provider)
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public ensureSignatureTimeValid(timestamp) returns (uint ein)
    {
        require(
            isSigned(
                associatedAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize the creation of an Identity on my behalf.",
                        recoveryAddress, associatedAddress, msg.sender, resolvers, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        return createIdentity(recoveryAddress, associatedAddress, msg.sender, resolvers, true);
    }

    // common logic for all identity creation
    function createIdentity(
        address recoveryAddress, address associatedAddress, address provider, address[] resolvers, bool delegated
    )
        private _hasIdentity(associatedAddress, false) returns (uint)
    {
        uint ein = nextEIN++;

        // set identity variables
        Identity storage _identity = identityDirectory[ein];
        _identity.recoveryAddress = recoveryAddress;
        _identity.associatedAddresses.insert(associatedAddress);
        _identity.providers.insert(provider);
        for (uint i; i < resolvers.length; i++) {
            _identity.resolvers.insert(resolvers[i]);
        }

        // set reverse address lookup
        associatedAddressDirectory[associatedAddress] = ein;

        emit IdentityCreated(msg.sender, ein, recoveryAddress, associatedAddress, provider, resolvers, delegated);

        return ein;
    }

    // allow providers to add addresses
    function addAddressDelegated(
        address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    )
        public _hasIdentity(addressToAdd, false)
        ensureSignatureTimeValid(timestamp[0]) ensureSignatureTimeValid(timestamp[1])
    {
        uint ein = getEIN(approvingAddress);
        require(isProviderFor(ein, msg.sender), "The identity has not set the passed provider.");
        require(
            identityDirectory[ein].associatedAddresses.length() <= maxAssociatedAddresses,
            "Cannot add too many addresses."
        );

        require(
            isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize adding this address to my Identity.",
                        ein, addressToAdd, timestamp[0]
                    )
                ),
                v[0], r[0], s[0]
            ),
            "Permission denied from approving address."
        );
        require(
            isSigned(
                addressToAdd,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize being added to this Identity.",
                        ein, addressToAdd, timestamp[1]
                    )
                ),
                v[1], r[1], s[1]
            ),
            "Permission denied from address to add."
        );

        identityDirectory[ein].associatedAddresses.insert(addressToAdd);
        associatedAddressDirectory[addressToAdd] = ein;

        emit AddressAdded(msg.sender, ein, addressToAdd, approvingAddress);
    }

    // allow providers to remove addresses
    function removeAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        public ensureSignatureTimeValid(timestamp)
    {
        uint ein = getEIN(addressToRemove);
        require(isProviderFor(ein, msg.sender), "The identity has not set the passed provider.");

        require(
            isSigned(
                addressToRemove,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize removing this address from my Identity.",
                        ein, addressToRemove, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        identityDirectory[ein].associatedAddresses.remove(addressToRemove);
        delete associatedAddressDirectory[addressToRemove];

        emit AddressRemoved(msg.sender, ein, addressToRemove);
    }

    // allows addresses associated with an identity to add providers
    function addProviders(address[] providers) public {
        addProviders(getEIN(msg.sender), providers, false);
    }

    // allows providers to add other providers for addresses
    function addProvidersFor(uint ein, address[] providers) public _isProviderFor(ein) {
        addProviders(ein, providers, true);
    }

    // common functionality to add providers
    function addProviders(uint ein, address[] providers, bool delegated) private {
        Identity storage _identity = identityDirectory[ein];
        for (uint i; i < providers.length; i++) {
            _identity.providers.insert(providers[i]);
            emit ProviderAdded(msg.sender, ein, providers[i], delegated);
        }
    }

    // allows addresses associated with an identity to remove providers
    function removeProviders(address[] providers) public {
        removeProviders(getEIN(msg.sender), providers, false);
    }

    // allows providers to remove other providers for addresses
    function removeProvidersFor(uint ein, address[] providers) public _isProviderFor(ein) {
        removeProviders(ein, providers, true);
    }

    // common functionality to remove providers
    function removeProviders(uint ein, address[] providers, bool delegated) private {
        Identity storage _identity = identityDirectory[ein];
        for (uint i; i < providers.length; i++) {
            _identity.providers.remove(providers[i]);
            emit ProviderRemoved(msg.sender, ein, providers[i], delegated);
        }
    }

    // allow providers to add resolvers
    function addResolversFor(uint ein, address[] resolvers) public _isProviderFor(ein) {
        Identity storage _identity = identityDirectory[ein];
        for (uint i; i < resolvers.length; i++) {
            _identity.resolvers.insert(resolvers[i]);
            emit ResolverAdded(msg.sender, ein, resolvers[i]);
        }
    }

    // allow providers to remove resolvers
    function removeResolversFor(uint ein, address[] resolvers) public _isProviderFor(ein) {
        Identity storage _identity = identityDirectory[ein];
        for (uint i; i < resolvers.length; i++) {
            _identity.resolvers.remove(resolvers[i]);
            emit ResolverRemoved(msg.sender, ein, resolvers[i]);
        }
    }


    // trigger a change in recovery address
    function triggerRecoveryAddressChangeFor(uint ein, address newRecoveryAddress)
        public _isProviderFor(ein) _canChangeRecoveryAddress(ein)
    {
        Identity storage _identity = identityDirectory[ein];

         // solium-disable-next-line security/no-block-members
        recoveryAddressChangeLogs[ein] = RecoveryAddressChange(block.timestamp, _identity.recoveryAddress);

        emit RecoveryAddressChangeTriggered(msg.sender, ein, _identity.recoveryAddress, newRecoveryAddress);

        // make the change
        _identity.recoveryAddress = newRecoveryAddress;
    }

    // trigger recovery, only callable by the current recovery address, or the one changed within the past 2 weeks
    function triggerRecovery(uint ein, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        public _identityExists(ein) _hasIdentity(newAssociatedAddress, false) ensureSignatureTimeValid(timestamp)
    {
        canRecover(ein, true);
        Identity storage _identity = identityDirectory[ein];

        // ensure the sender is the recovery address/old recovery address if there's been a recent change
        if (canChangeRecoveryAddress(ein)) {
            require(
                msg.sender == _identity.recoveryAddress, "Only the current recovery address can trigger recovery."
            );
        } else {
            require(
                msg.sender == recoveryAddressChangeLogs[ein].oldRecoveryAddress,
                "Only the recently removed recovery address can trigger recovery."
            );
        }

        require(
            isSigned(
                newAssociatedAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize being added to this Identity via recovery.",
                        ein, newAssociatedAddress, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        // log the old associated addresses to unlock the poison pill
        recoveryLogs[ein] = Recovery(
            block.timestamp, // solium-disable-line security/no-block-members
            keccak256(abi.encodePacked(_identity.associatedAddresses.members))
        );

        emit RecoveryTriggered(msg.sender, ein, _identity.associatedAddresses.members, newAssociatedAddress);

        // remove identity data, and add the new address as the sole associated address
        resetIdentityData(_identity, false);
        _identity.recoveryAddress = msg.sender;
        _identity.associatedAddresses.insert(newAssociatedAddress);
        associatedAddressDirectory[newAssociatedAddress] = ein;
    }

    // allows addresses recently removed by recovery to permanently disable the identity they were removed from
    function triggerPoisonPill(uint ein, address[] firstChunk, address[] lastChunk, bool resetResolvers)
        public _identityExists(ein)
    {
        canRecover(ein, false);
        Identity storage _identity = identityDirectory[ein];

        // ensure that the msg.sender was an old associated address for the referenced identity
        address[1] memory middleChunk = [msg.sender];
        require(
            keccak256(abi.encodePacked(firstChunk, middleChunk, lastChunk)) ==
                recoveryLogs[ein].hashedOldAssociatedAddresses,
            "Cannot activate the poison pill from an address that was not recently removed via recovery."
        );

        emit IdentityPoisoned(msg.sender, ein, _identity.recoveryAddress, resetResolvers);

        resetIdentityData(_identity, resetResolvers);
    }

    // removes all associated addresses, providers, and optionally resolvers from an identity
    function resetIdentityData(Identity storage identity, bool resetResolvers) private {
        address[] storage associatedAddresses = identity.associatedAddresses.members;
        for (uint i; i < associatedAddresses.length; i++) {
            delete associatedAddressDirectory[associatedAddresses[i]];
        }
        delete identity.associatedAddresses;
        delete identity.providers;
        if (resetResolvers) delete identity.resolvers;
    }


    // define events
    event IdentityCreated(
        address indexed initiator, uint indexed ein,
        address recoveryAddress, address associatedAddress, address provider, address[] resolvers, bool delegated
    );
    event AddressAdded    (address indexed initiator, uint indexed ein, address addedAddress, address approvingAddress);
    event AddressRemoved  (address indexed initiator, uint indexed ein, address removedAddress);
    event ProviderAdded   (address indexed initiator, uint indexed ein, address provider, bool delegated);
    event ProviderRemoved (address indexed initiator, uint indexed ein, address provider, bool delegated);
    event ResolverAdded   (address indexed initiator, uint indexed ein, address resolvers);
    event ResolverRemoved (address indexed initiator, uint indexed ein, address resolvers);
    event RecoveryAddressChangeTriggered(
        address indexed initiator, uint indexed ein, address oldRecoveryAddress, address newRecoveryAddress
    );
    event RecoveryTriggered(
        address indexed initiator, uint indexed ein, address[] oldAssociatedAddresses, address newAssociatedAddress
    );
    event IdentityPoisoned(address indexed initiator, uint indexed ein, address recoveryAddress, bool resolversReset);
}
