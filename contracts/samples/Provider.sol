pragma solidity ^0.4.24;

interface IdentityRegistryInterface {
    function getEIN(address _address) external view returns (uint ein);
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addAssociatedAddressDelegated(
        address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    ) external;
    function removeAssociatedAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp) external;
    function addProvidersFor   (uint ein, address[] providers) external;
    function removeProvidersFor(uint ein, address[] providers) external;
    function addResolversFor   (uint ein, address[] resolvers) external;
    function removeResolversFor(uint ein, address[] resolvers) external;
    function triggerRecoveryAddressChangeFor(uint ein, address newRecoveryAddress) external;
}

contract Provider {
    IdentityRegistryInterface identityRegistry;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
    }

    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public returns (uint ein)
    {
        return identityRegistry.createIdentityDelegated(
            recoveryAddress, associatedAddress, resolvers, v, r, s, timestamp
        );
    }

    function addAssociatedAddressDelegated(
        address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    )
        public
    {
        identityRegistry.addAssociatedAddressDelegated(approvingAddress, addressToAdd, v, r, s, timestamp);
    }

    function removeAssociatedAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp) public {
        identityRegistry.removeAssociatedAddressDelegated(addressToRemove, v, r, s, timestamp);
    }

    function addProvidersFor(address[] providers) public {
        identityRegistry.addProvidersFor(identityRegistry.getEIN(msg.sender), providers);
    }

    function removeProvidersFor(address[] providers) public {
        identityRegistry.removeProvidersFor(identityRegistry.getEIN(msg.sender), providers);
    }

    function addResolversFor(address[] resolvers) public {
        identityRegistry.addResolversFor(identityRegistry.getEIN(msg.sender), resolvers);
    }

    function removeResolversFor(address[] resolvers) public {
        identityRegistry.removeResolversFor(identityRegistry.getEIN(msg.sender), resolvers);
    }

    function triggerRecoveryAddressChangeFor(address newRecoveryAddress) public {
        identityRegistry.triggerRecoveryAddressChangeFor(identityRegistry.getEIN(msg.sender), newRecoveryAddress);
    }
}
