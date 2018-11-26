pragma solidity ^0.5.0;

import "./Forwarder.sol";

// this is a fragile proxy in that the allowedCaller can't change, but for PoC purposes it will suffice
contract ExternalProxy is Forwarder {
    uint owner; // the EIN that owns this proxy
    address allowedCaller; // an address that can use this proxy, initially set to the Provider that created this proxy

    constructor (uint _owner, address _allowedCaller) public {
        owner = _owner;
        allowedCaller = _allowedCaller;
    }

    modifier onlyAllowedCaller() {
        require(msg.sender == allowedCaller, "Caller is not allowed.");
        _;
    }

    function forwardCall(address destination, bytes memory data)
        public onlyAllowedCaller() returns (bytes memory returnData)
    {
        return super.forwardCall(destination, data);
    }
}
