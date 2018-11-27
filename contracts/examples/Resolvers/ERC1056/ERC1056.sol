pragma solidity ^0.5.0;

import "../../../interfaces/IdentityRegistryInterface.sol";
import "./EthereumDIDRegistryInterface.sol";

contract ERC1056 {
    IdentityRegistryInterface identityRegistry;
    EthereumDIDRegistryInterface ethereumDIDRegistry;

    constructor (address identityRegistryAddress, address ethereumDIDRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
        ethereumDIDRegistry = EthereumDIDRegistryInterface(ethereumDIDRegistryAddress);
    }

    mapping(uint => address) public einToDID;
    mapping(uint => uint) public actionNonce;

    function initialize(address identity, uint8 v, bytes32 r, bytes32 s) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        require(einToDID[ein] == address(0), "This EIN has already been initialized");
        ethereumDIDRegistry.changeOwnerSigned(identity, v, r, s, address(this));
        einToDID[ein] = identity;
    }

    function changeOwner(address newOwner) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _changeOwner(einToDID[ein], newOwner);
    }

    function changeOwnerDelegated(address approvingAddress, address newOwner, uint8 v, bytes32 r, bytes32 s) public {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this), "changeOwnerDelegated", newOwner, actionNonce[ein]
                    )
                ),
                v, r, s
            ),
            "Function execution is incorrectly signed."
        );
        actionNonce[ein]++;
        _changeOwner(einToDID[ein], newOwner);
    }

    function _changeOwner(address _did, address _newOwner) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.changeOwner(_did, _newOwner);
    }

    function addDelegate(bytes32 delegateType, address delegate, uint validity) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _addDelegate(einToDID[ein], delegateType, delegate, validity);
    }

    function addDelegateDelegated(
        address approvingAddress, bytes32 delegateType, address delegate, uint validity, uint8 v, bytes32 r, bytes32 s
    )
        public
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "addDelegateDelegated", delegateType, delegate, validity, actionNonce[ein]
                    )
                ),
                v, r, s
            ),
            "Function execution is incorrectly signed."
        );
        actionNonce[ein]++;
        _addDelegate(einToDID[ein], delegateType, delegate, validity);
    }

    function _addDelegate(address _did, bytes32 _delegateType, address _delegate, uint _validity) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.addDelegate(_did, _delegateType, _delegate, _validity);
    }

    function revokeDelegate(bytes32 delegateType, address delegate) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _revokeDelegate(einToDID[ein], delegateType, delegate);
    }

    function revokeDelegateDelegated(
        address approvingAddress, bytes32 delegateType, address delegate, uint8 v, bytes32 r, bytes32 s
    )
        public
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "revokeDelegateDelegated", delegateType, delegate, actionNonce[ein]
                    )
                ),
                v, r, s
            ),
            "Function execution is incorrectly signed."
        );
        actionNonce[ein]++;
        _revokeDelegate(einToDID[ein], delegateType, delegate);
    }

    function _revokeDelegate(address _did, bytes32 _delegateType, address _delegate) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.revokeDelegate(_did, _delegateType, _delegate);
    }

    function setAttribute(bytes32 name, bytes memory value, uint validity) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _setAttribute(einToDID[ein], name, value, validity);
    }

    function setAttributeDelegated(
        address approvingAddress, bytes32 name, bytes memory value, uint validity, uint8 v, bytes32 r, bytes32 s
    )
        public
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "setAttributeDelegated", name, value, validity, actionNonce[ein]
                    )
                ),
                v, r, s
            ),
            "Function execution is incorrectly signed."
        );
        actionNonce[ein]++;
        _setAttribute(einToDID[ein], name, value, validity);
    }

    function _setAttribute(address _did, bytes32 _name, bytes memory _value, uint _validity) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.setAttribute(_did, _name, _value, _validity);
    }

    function revokeAttribute(bytes32 name, bytes memory value) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _revokeAttribute(einToDID[ein], name, value);
    }

    function revokeAttributeDelegated(
        address approvingAddress, bytes32 name, bytes memory value, uint8 v, bytes32 r, bytes32 s
    )
        public
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "revokeAttributeDelegated", name, value, actionNonce[ein]
                    )
                ),
                v, r, s
            ),
            "Function execution is incorrectly signed."
        );
        actionNonce[ein]++;
        _revokeAttribute(einToDID[ein], name, value);
    }

    function _revokeAttribute(address _did, bytes32 _name, bytes memory _value) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.revokeAttribute(_did, _name, _value);
    }
}
