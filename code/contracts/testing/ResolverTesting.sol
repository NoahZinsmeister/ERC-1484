pragma solidity ^0.4.24;

contract IdentityRegistry {
    function getIdentity(address _address) public view returns (uint identity);
    function identityExists(uint identity) public view returns (bool);
}

contract ResolverTesting {
    mapping(uint => string) internal emails;

    address identityRegistryAddress;

    constructor (address _identityRegistryAddress) public {
        identityRegistryAddress = _identityRegistryAddress;
    }

    function setEmailAddress(string _email) public {
        IdentityRegistry identityRegistry = IdentityRegistry(identityRegistryAddress);
        uint identity = identityRegistry.getIdentity(msg.sender);

        emails[identity] = _email;
    }

    function getEmail(uint _identity) public view returns(string){
        IdentityRegistry identityRegistry = IdentityRegistry(identityRegistryAddress);
        require(identityRegistry.identityExists(_identity), "The passed identity does not exist.");

        return emails[_identity];
    }
}
