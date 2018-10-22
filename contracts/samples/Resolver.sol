pragma solidity ^0.4.24;

interface IdentityRegistryInterface {
    function getEIN(address _address) external view returns (uint ein);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    function identityExists(uint ein) external view returns (bool);
}

contract Resolver {
    mapping(uint => string) internal emails;

    IdentityRegistryInterface identityRegistry;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
    }

    function setEmailAddress(string email) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        require(
            identityRegistry.isResolverFor(ein, address(this)),
            "The calling identity does not have this resolver set."
        );
        emails[ein] = email;
    }

    function getEmail(uint ein) public view returns(string) {
        require(identityRegistry.identityExists(ein), "The referenced identity does not exist.");
        return emails[ein];
    }
}
