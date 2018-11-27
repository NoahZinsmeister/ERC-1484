pragma solidity ^0.5.0;

import "./ForwarderInterface.sol";

contract Forwarder is ForwarderInterface {
    function forwardCall(address destination, bytes memory data) public returns (bytes memory returnData) {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory _returnData) = destination.call(data);
        require(success, "Call was not successful.");
        return _returnData;
    }
}
