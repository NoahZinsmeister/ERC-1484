pragma solidity ^0.5.0;

import "../interfaces/IdentityRegistryInterface.sol";

contract Resolver {
    mapping(uint => string) internal emails;

    IdentityRegistryInterface identityRegistry;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
    }

    function setEmailAddress(string memory email) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        require(
            identityRegistry.isResolverFor(ein, address(this)), "The calling identity does not have this resolver set."
        );
        emails[ein] = email;
    }

    function getEmail(uint ein) public view returns(string memory) {
        require(identityRegistry.identityExists(ein), "The referenced identity does not exist.");
        return emails[ein];
    }
}
