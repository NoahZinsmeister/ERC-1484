pragma solidity ^0.4.24;

contract IdentityRegistry {
    function getIdentity(address _address) public view returns (string identity);
    function identityExists(string identity) public view returns (bool);
}

contract ResolverTesting {
    mapping(string => string) internal emails;

    address identityRegistryAddress;

    constructor (address _identityRegistryAddress) public {
        identityRegistryAddress = _identityRegistryAddress;
    }

    function setEmailAddress(string _email) public {
        IdentityRegistry identityRegistry = IdentityRegistry(identityRegistryAddress);
        string memory identity = identityRegistry.getIdentity(msg.sender);

        emails[identity] = _email;
    }

    function getEmail(string _identity) public view returns(string){
        IdentityRegistry identityRegistry = IdentityRegistry(identityRegistryAddress);
        require(identityRegistry.identityExists(_identity), "The passed identity does not exist.");

        return emails[_identity];
    }
}
