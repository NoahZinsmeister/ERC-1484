pragma solidity ^0.4.24;

interface IdentityRegistryInterface {
    function isSigned(
        address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s
    ) external view returns (bool);
    function getEIN(address _address) external view returns (uint ein);
}

interface EthereumDIDRegistryInterface {
    function identityOwner    (address identity) external view returns(address);
    function validDelegate    (address identity, bytes32 delegateType, address delegate) external view returns(bool);
    function changeOwner      (address identity, address newOwner) external;
    function changeOwnerSigned(address identity, uint8 sigV, bytes32 sigR, bytes32 sigS, address newOwner) external;
    function addDelegate      (address identity, bytes32 delegateType, address delegate, uint validity) external;
    function revokeDelegate   (address identity, bytes32 delegateType, address delegate) external;
    function setAttribute     (address identity, bytes32 name, bytes value, uint validity) external;
    function revokeAttribute  (address identity, bytes32 name, bytes value) external;
}

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

    function setAttribute(bytes32 name, bytes value, uint validity) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _setAttribute(einToDID[ein], name, value, validity);
    }

    function setAttributeDelegated(
        address approvingAddress, bytes32 name, bytes value, uint validity, uint8 v, bytes32 r, bytes32 s
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

    function _setAttribute(address _did, bytes32 _name, bytes _value, uint _validity) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.setAttribute(_did, _name, _value, _validity);
    }

    function revokeAttribute(bytes32 name, bytes value) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _revokeAttribute(einToDID[ein], name, value);
    }

    function revokeAttributeDelegated(
        address approvingAddress, bytes32 name, bytes value, uint8 v, bytes32 r, bytes32 s
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

    function _revokeAttribute(address _did, bytes32 _name, bytes _value) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.revokeAttribute(_did, _name, _value);
    }
}
