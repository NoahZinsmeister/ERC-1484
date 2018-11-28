pragma solidity ^0.5.0;

import "../../../interfaces/IdentityRegistryInterface.sol";

contract BurnerProvider {
    IdentityRegistryInterface identityRegistry;

    address public dummyPerpetualResolver = 0x1111111deFaCED1c0FfEe1CAfE1facaDe1111111;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
    }

    function burnIdentity(
        address _address, uint8[2] memory v, bytes32[2] memory r, bytes32[2] memory s, uint[2] memory timestamp
    )
        public returns (uint ein)
    {
        address[] memory providers = new address[](0);
        address[] memory resolvers = new address[](1);
        resolvers[0] = dummyPerpetualResolver;

        uint _ein = identityRegistry.createIdentityDelegated(
            address(0), _address, providers, resolvers, v[0], r[0], s[0], timestamp[0]
        );

        identityRegistry.removeAssociatedAddressDelegated(_address, v[1], r[1], s[1], timestamp[1]);

        return _ein;
    }
}
