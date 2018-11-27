pragma solidity ^0.5.0;

import "../interfaces/IdentityRegistryInterface.sol";

contract Provider {
    IdentityRegistryInterface identityRegistry;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
    }

    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] memory resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public returns (uint ein)
    {
        address[] memory providers = new address[](1);
        providers[0] = address(this);
        return identityRegistry.createIdentityDelegated(
            recoveryAddress, associatedAddress, providers, resolvers, v, r, s, timestamp
        );
    }

    function addAssociatedAddressDelegated(
        address approvingAddress, address addressToAdd,
        uint8[2] memory v, bytes32[2] memory r, bytes32[2] memory s, uint[2] memory timestamp
    )
        public
    {
        identityRegistry.addAssociatedAddressDelegated(approvingAddress, addressToAdd, v, r, s, timestamp);
    }

    function removeAssociatedAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        public
    {
        identityRegistry.removeAssociatedAddressDelegated(addressToRemove, v, r, s, timestamp);
    }

    function addProvidersFor(address[] memory providers) public {
        identityRegistry.addProvidersFor(identityRegistry.getEIN(msg.sender), providers);
    }

    function removeProvidersFor(address[] memory providers) public {
        identityRegistry.removeProvidersFor(identityRegistry.getEIN(msg.sender), providers);
    }

    function addResolversFor(address[] memory resolvers) public {
        identityRegistry.addResolversFor(identityRegistry.getEIN(msg.sender), resolvers);
    }

    function removeResolversFor(address[] memory resolvers) public {
        identityRegistry.removeResolversFor(identityRegistry.getEIN(msg.sender), resolvers);
    }

    function triggerRecoveryAddressChangeFor(address newRecoveryAddress) public {
        identityRegistry.triggerRecoveryAddressChangeFor(identityRegistry.getEIN(msg.sender), newRecoveryAddress);
    }
}
