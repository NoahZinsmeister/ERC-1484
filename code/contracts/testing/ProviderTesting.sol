pragma solidity ^0.4.24;

contract IdentityRegistry {
    function getIdentity(address _address) public view returns (uint identity);
    function mintIdentityDelegated(
        address recoveryAddress,
        address associatedAddress,
        address[] resolvers,
        uint8 v, bytes32 r, bytes32 s) public returns (uint);
    function addAddress(
        uint identity,
        address addressToAdd,
        address approvingAddress,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt) public;
    function removeAddress(uint identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public;
    function addProviders(
        uint identity,
        address[] providers,
        address approvingAddress,
        uint8 v, bytes32 r, bytes32 s, uint salt) public;
    function removeProviders(
        uint identity,
        address[] providers,
        address approvingAddress,
        uint8 v, bytes32 r, bytes32 s, uint salt) public;
    function addResolvers(uint identity, address[] resolvers) public;
    function removeResolvers(uint identity, address[] resolvers) public;
    function initiateRecoveryAddressChange(uint identity, address newRecoveryAddress) public;
}

contract ProviderTesting {
    IdentityRegistry registry;

    constructor (address identityRegistryAddress) public {
        registry = IdentityRegistry(identityRegistryAddress);
    }

    function mintIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers, uint8 v, bytes32 r, bytes32 s
    )
        public
    {
        registry.mintIdentityDelegated(recoveryAddress, associatedAddress, resolvers, v, r, s);
    }


    function addResolvers(address[] resolvers) public {
        registry.addResolvers(registry.getIdentity(msg.sender), resolvers);
    }

    function removeResolvers(uint identity, address[] resolvers) public {
        require(
            registry.getIdentity(msg.sender) == identity,
            "This provider only allows resolvers to be removed from addresses associated with the identity in question"
        );
        registry.removeResolvers(identity, resolvers);
    }

    function addAddress(
        uint identity,
        address addressToAdd,
        address approvingAddress,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt
    ) public {
        registry.addAddress(identity, addressToAdd, approvingAddress, v, r, s, salt);
    }

    function removeAddress(uint identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public {
        registry.removeAddress(identity, addressToRemove, v, r, s, salt);
    }
}
