pragma solidity ^0.4.24;

interface IdentityRegistryInterface {
    function isSigned(
        address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s
    ) external view returns (bool);
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function getEIN(address _address) external view returns (uint ein);
    function isProviderFor(uint ein, address provider) external view returns (bool);
}

contract ForwarderInterface {
    function forwardCall(address destination, bytes memory data) public;
}

contract Forwarder is ForwarderInterface {
    function forwardCall(address destination, bytes memory data) public {
        require(destination.call(data), "Call was not successful."); // solium-disable-line security/no-low-level-calls
    }
}

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

    function forwardCall(address destination, bytes memory data) public onlyAllowedCaller() {
        super.forwardCall(destination, data);
    }
}

contract MetaTransactionsProvider is Forwarder {
    IdentityRegistryInterface identityRegistry;

    // external proxy registry and nonce tracker mapping EINs to proxies/nonces
    mapping (uint => address) public externalProxyDirectory;
    mapping (uint => uint) public nonceTracker;

    constructor (address identityRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
    }


    modifier isProviderFor(uint ein) {
        require(identityRegistry.isProviderFor(ein, address(this)), "This Provider is not set for the given EIN.");
        _;
    }

    function hasExternalProxy(uint ein) public view returns (bool) {
        return externalProxyDirectory[ein] != address(0);
    }
    

    // create identity with meta-transaction
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public returns (uint ein)
    {
        return identityRegistry.createIdentityDelegated(
            recoveryAddress, associatedAddress, resolvers, v, r, s, timestamp
        );
    }

    // internal logic for claiming an external proxy
    function claimProxy(uint ein) private {
        address externalProxy = new ExternalProxy(ein, address(this));

        // register proxy in the directoy
        externalProxyDirectory[ein] = externalProxy;
    }

    // call via proxy from msg.sender
    function callViaProxy(address destination, bytes data, bool viaExternal) public {
        callViaProxy(identityRegistry.getEIN(msg.sender), destination, data, viaExternal);
    }

    // call via proxy from approvingAddress with meta-transaction
    function callViaProxyDelegated(
        address approvingAddress, address destination, bytes data, bool viaExternal, uint8 v, bytes32 r, bytes32 s
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
                        "I authorize this call.", ein, destination, data, viaExternal, nonceTracker[ein]
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );
        nonceTracker[ein] += 1;

        callViaProxy(ein, destination, data, viaExternal);
    }

    // internal logic for calling proxy
    function callViaProxy(uint ein, address destination, bytes data, bool viaExternal) private isProviderFor(ein) {
        if (viaExternal) {
            if (!hasExternalProxy(ein)) {
                claimProxy(ein);
            }
            ForwarderInterface(externalProxyDirectory[ein]).forwardCall(destination, data);            
        } else {
            forwardCall(destination, data);
        }
    }
}
