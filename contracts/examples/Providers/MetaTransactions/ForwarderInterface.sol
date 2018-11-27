pragma solidity ^0.5.0;

contract ForwarderInterface {
    function forwardCall(address destination, bytes memory data) public returns (bytes memory returnData);
}
