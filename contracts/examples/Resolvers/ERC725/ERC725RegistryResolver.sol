pragma solidity ^0.5.0;

import "./ClaimHolder.sol";
import "../../../interfaces/IdentityRegistryInterface.sol";

contract ERC725RegistryResolver {
    IdentityRegistryInterface registry;

    constructor (address _identityRegistryAddress) public {
        registry = IdentityRegistryInterface(_identityRegistryAddress);
    }

    mapping(uint => address) einTo725;

    function create725() public returns(address) {
        uint ein = registry.getEIN(msg.sender);

        require(einTo725[ein] == address(0), "You already have a 725");

        ClaimHolder claim = new ClaimHolder();
        // TODO: change this if addKey implementation changes s.t. it can return false
        claim.addKey(keccak256(abi.encodePacked(msg.sender)), 1, 1);

        einTo725[ein] = address(claim);

        return(address(claim));
    }

    function claim725(address _contract) public returns(bool) {
        uint ein = registry.getEIN(msg.sender);

        address[] memory ownedAddresses;
        (,ownedAddresses,,) = registry.getIdentity(ein);

        require(einTo725[ein] == address(0), "You already have a 725");

        ClaimHolder claim = ClaimHolder(_contract);
        bytes32 key;

        for (uint x = 0; x < ownedAddresses.length; x++) {
            (,,key) = claim.getKey(keccak256(abi.encodePacked(ownedAddresses[x])));
            if (key == keccak256(abi.encodePacked(ownedAddresses[x]))) {
                einTo725[ein] = _contract;
                return true;
            }
        }

        return false;
    }

    function remove725() public {
        uint ein = registry.getEIN(msg.sender);

        einTo725[ein] = address(0);
    }

    function get725(uint _ein) public view returns(address) {
        return einTo725[_ein];
    }

}
