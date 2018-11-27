pragma solidity ^0.5.0;

interface EthereumDIDRegistryInterface {
    function identityOwner(address identity) external view returns(address);
    function validDelegate(address identity, bytes32 delegateType, address delegate) external view returns(bool);
    function changeOwner(address identity, address newOwner) external;
    function changeOwnerSigned(address identity, uint8 sigV, bytes32 sigR, bytes32 sigS, address newOwner) external;
    function addDelegate(address identity, bytes32 delegateType, address delegate, uint validity) external;
    function revokeDelegate(address identity, bytes32 delegateType, address delegate) external;
    function setAttribute(address identity, bytes32 name, bytes calldata value, uint validity) external;
    function revokeAttribute(address identity, bytes32 name, bytes calldata value) external;
}