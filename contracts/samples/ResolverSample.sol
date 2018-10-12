pragma solidity ^0.4.24;

interface IdentityRegistry {
    function getEIN(address _address) external view returns (uint ein);
    function identityExists(uint ein) external view returns (bool);
}

contract ResolverSample {
    mapping(uint => string) internal emails;

    IdentityRegistry identityRegistry;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistry(identityRegistryAddress);
    }

    function setEmailAddress(string _email) public {
        emails[identityRegistry.getEIN(msg.sender)] = _email;
    }

    function getEmail(uint ein) public view returns(string){
        require(identityRegistry.identityExists(ein), "The referenced identity does not exist.");
        return emails[ein];
    }
}
