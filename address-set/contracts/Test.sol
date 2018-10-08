pragma solidity ^0.4.24;

import "./AddressSet.sol";


contract Test {
    using AddressSet for AddressSet.Set;

    AddressSet.Set internal mySet;

    function insert(address other) public {
        mySet.insert(other);
    }

    function remove(address other) public {
        mySet.remove(other);
    }

    function contains(address other) public view returns (bool) {
        return mySet.contains(other);
    }

    function length() public view returns (uint) {
        return mySet.length();
    }

    function members() public view returns (address[]) {
        return mySet.members;
    }
}
