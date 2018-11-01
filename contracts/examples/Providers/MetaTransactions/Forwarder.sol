pragma solidity ^0.4.24;

contract ForwarderInterface {
    function forwardCall(address destination, bytes memory data) public;
}

contract Forwarder is ForwarderInterface {
    function forwardCall(address destination, bytes memory data) public {
        require(destination.call(data), "Call was not successful."); // solium-disable-line security/no-low-level-calls
    }
}
