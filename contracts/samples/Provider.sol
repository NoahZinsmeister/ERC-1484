pragma solidity ^0.4.24;

interface IdentityRegistryInterface {
    function getEIN(address _address) external view returns (uint ein);
    function mintIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addAddress(
        address approvingAddress, address addressToAdd,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    ) external;
    function removeAddress(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp) external;
    function addProviders(uint ein, address[] providers) external;
    function removeProviders(uint ein, address[] providers) external;
    function addResolvers(uint ein, address[] resolvers) external;
    function removeResolvers(uint ein, address[] resolvers) external;
    function initiateRecoveryAddressChange(uint ein, address newRecoveryAddress) external;
}

contract Provider {
    IdentityRegistryInterface identityRegistry;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
    }

    function mintIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public returns (uint ein)
    {
        return identityRegistry.mintIdentityDelegated(
            recoveryAddress, associatedAddress, resolvers, v, r, s, timestamp
        );
    }

    function addAddress(
        address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    )
        public
    {
        identityRegistry.addAddress(approvingAddress, addressToAdd, v, r, s, timestamp);
    }

    function removeAddress(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp) public {
        identityRegistry.removeAddress(addressToRemove, v, r, s, timestamp);
    }

    function addProviders(address[] providers) public {
        identityRegistry.addProviders(identityRegistry.getEIN(msg.sender), providers);
    }

    function removeProviders(address[] providers) public {
        identityRegistry.removeProviders(identityRegistry.getEIN(msg.sender), providers);
    }

    function addResolvers(address[] resolvers) public {
        identityRegistry.addResolvers(identityRegistry.getEIN(msg.sender), resolvers);
    }

    function removeResolvers(address[] resolvers) public {
        identityRegistry.removeResolvers(identityRegistry.getEIN(msg.sender), resolvers);
    }

    function initiateRecoveryAddressChange(address newRecoveryAddress) public {
        identityRegistry.initiateRecoveryAddressChange(identityRegistry.getEIN(msg.sender), newRecoveryAddress);
    }
}
