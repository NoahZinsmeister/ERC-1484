pragma solidity ^0.4.24;

import "./zeppelin/ownership/Ownable.sol";

contract Provider is Ownable {
    address public identityRegistryAddress;

    function setIdentityRegistryAddress(address _address) public onlyOwner {
        identityRegistryAddress = _address;
    }
}
