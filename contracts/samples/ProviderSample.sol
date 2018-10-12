pragma solidity ^0.4.24;

interface IdentityRegistry {
    function getEIN(address _address) external view returns (uint ein);
    function mintIdentityDelegated(
        address recoveryAddress,
        address associatedAddress,
        address[] resolvers,
        uint8 v, bytes32 r, bytes32 s) external returns (uint ein);
    function addAddress(
        uint ein,
        address addressToAdd,
        address approvingAddress,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt) external;
    function removeAddress(uint ein, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) external;
    function addProviders(
        uint ein,
        address[] providers,
        address approvingAddress,
        uint8 v, bytes32 r, bytes32 s, uint salt) external;
    function removeProviders(
        uint ein,
        address[] providers,
        address approvingAddress,
        uint8 v, bytes32 r, bytes32 s, uint salt) external;
    function addResolvers(uint ein, address[] resolvers) external;
    function removeResolvers(uint ein, address[] resolvers) external;
    function initiateRecoveryAddressChange(uint ein, address newRecoveryAddress) external;
}

contract ProviderSample {
    IdentityRegistry identityRegistry;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistry(identityRegistryAddress);
    }

    function mintIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers, uint8 v, bytes32 r, bytes32 s
    )
        public returns (uint ein)
    {
        return identityRegistry.mintIdentityDelegated(recoveryAddress, associatedAddress, resolvers, v, r, s);
    }

    function addAddress(
        uint ein,
        address addressToAdd,
        address approvingAddress,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt
    )
        public
    {
        identityRegistry.addAddress(ein, addressToAdd, approvingAddress, v, r, s, salt);
    }

    function removeAddress(uint ein, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public {
        identityRegistry.removeAddress(ein, addressToRemove, v, r, s, salt);
    }

    function addProviders(
        uint ein, address[] providers, address approvingAddress, uint8 v, bytes32 r, bytes32 s, uint salt
    )
        public
    {
        identityRegistry.addProviders(ein, providers, approvingAddress, v, r, s, salt);
    }

    function removeProviders(
        uint ein, address[] providers, address approvingAddress, uint8 v, bytes32 r, bytes32 s, uint salt
    )
        public
    {
        identityRegistry.removeProviders(ein, providers, approvingAddress, v, r, s, salt);
    }

    function addResolvers(address[] resolvers) public {
        identityRegistry.addResolvers(identityRegistry.getEIN(msg.sender), resolvers);
    }

    function removeResolvers(address[] resolvers) public {
        identityRegistry.removeResolvers(identityRegistry.getEIN(msg.sender), resolvers);
    }
}
