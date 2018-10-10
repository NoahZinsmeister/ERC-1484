pragma solidity ^0.4.24;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/math/SafeMath.sol";
import "./AddressSet/addressSet.sol";
import "../Provider.sol";

interface ERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface SnowflakeResolver {
    function callOnSignUp() external returns (bool);
    function onSignUp(string identity, uint allowance) external returns (bool);
    function callOnRemoval() external returns (bool);
    function onRemoval(string identity) external returns(bool);
}

interface ClientRaindrop {
    function getUserByAddress(address _address) external view returns (string userName);
    function isSigned(
        address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s
    ) external pure returns (bool);
}

interface ViaContract {
    function snowflakeCall(address resolver, string identityFrom, string identityTo, uint amount, bytes _bytes) external;
    function snowflakeCall(address resolver, string identityFrom, address to, uint amount, bytes _bytes) external;
}

contract IdentityRegistry {
    function mintIdentityDelegated(string identity, address identityAddress, uint8 v, bytes32 r, bytes32 s) public;
    function identityExists(string identity) public view returns (bool);
    function getIdentity(address _address) public view returns (string identity);
    function hasIdentity(address _address) public view returns (bool);
    function addResolvers(string identity, address[] resolvers) public;
    function removeResolvers(string identity, address[] resolvers) public;
    function isResolverFor(string identity, address resolver) public view returns (bool);
    function addAddress(
        string identity,
        address approvingAddress,
        address addressToAdd,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt) public;
    function removeAddress(string identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public;
}

contract Snowflake is Ownable {
    using SafeMath for uint;
    using addressSet for addressSet._addressSet;

    // hydro token wrapper variable
    mapping (string => uint) internal deposits;

    // signature variables
    uint signatureTimeout;
    mapping (bytes32 => bool) signatureLog;

    // lookup mappings -- accessible only by wrapper functions
    mapping (string => mapping (address => uint)) internal resolverAllowances;
    mapping (address => string) internal addressDirectory;
    mapping (bytes32 => string) internal initiatedAddressClaims;

    // admin/contract variables
    address public clientRaindropAddress;
    address public hydroTokenAddress;

    addressSet._addressSet resolverWhitelist;

    IdentityRegistry registry;

    constructor (address identityRegistryAddress) public {
        setSignatureTimeout(27000);
        registry = IdentityRegistry(identityRegistryAddress);
    }

    // checks whether the given address is owned by a token (does not throw)
    function hasToken(address _address) public view returns (bool) {
        return registry.hasIdentity(msg.sender);
    }

    // enforces that a particular address has a token
    modifier _hasToken(address _address, bool check) {
        require(hasToken(_address) == check, "The transaction sender does not have an Identity token.");
        _;
    }

    function stringsEqual(string memory first, string memory second) public pure returns (bool) {
        return keccak256(abi.encodePacked(first)) == keccak256(abi.encodePacked(second));
    }

    // set the signature timeout
    function setSignatureTimeout(uint newTimeout) public {
        require(newTimeout >= 1800, "Timeout must be at least 30 minutes.");
        require(newTimeout <= 604800, "Timeout must be less than a week.");
        signatureTimeout = newTimeout;
    }

    // set the raindrop and hydro token addresses
    function setAddresses(address hydroToken) public onlyOwner {
        hydroTokenAddress = hydroToken;
    }

    function mintIdentityDelegated(string identity, address identityAddress, uint8 v, bytes32 r, bytes32 s) public {
        registry.mintIdentityDelegated(identity, identityAddress, v, r, s);
    }

    function addResolvers(address[] resolvers, uint[] withdrawAllowances) public _hasToken(msg.sender, true) {
        _addResolvers(registry.getIdentity(msg.sender), resolvers, withdrawAllowances);
    }

    function addResolversDelegated(
        address _address, address[] resolvers, uint[] withdrawAllowances, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) public
    {
        string memory identity = registry.getIdentity(_address);
        require(registry.identityExists(identity), "Must initiate claim for a valid identity");
        // solium-disable-next-line security/no-block-members
        require(timestamp.add(signatureTimeout) > block.timestamp, "Message was signed too long ago.");

        require(
            registry.isSigned(
                _address,
                keccak256(abi.encodePacked("Add Resolvers", resolvers, withdrawAllowances, timestamp)),
                v, r, s
            ),
            "Permission denied."
        );

        _addResolvers(identity, resolvers, withdrawAllowances);
    }

    function _addResolvers(
        string identity, address[] resolvers, uint[] withdrawAllowances
    ) internal {
        require(resolvers.length == withdrawAllowances.length, "Malformed inputs.");

        for (uint i; i < resolvers.length; i++) {
            require(!registry.isResolverFor(identity, resolvers[i]), "Identity has already set this resolver.");

            SnowflakeResolver snowflakeResolver = SnowflakeResolver(resolvers[i]);
            resolverAllowances[identity][resolvers[i]] = withdrawAllowances[i];
            if (snowflakeResolver.callOnSignUp()) {
                require(
                    snowflakeResolver.onSignUp(identity, withdrawAllowances[i]),
                    "Sign up failure."
                );
            }
            emit ResolverAdded(identity, resolvers[i], withdrawAllowances[i]);
        }

        registry.addResolvers(identity, resolvers);
    }

    function removeResolvers(address[] resolvers, bool force) public _hasToken(msg.sender, true) {
        string memory identity = registry.getIdentity(msg.sender)

        for (uint i; i < resolvers.length; i++) {
            require(registry.isResolverFor(identity, resolvers[i]), "Snowflake has not set this resolver.");

            delete resolverAllowances[identity][resolvers[i]];
            if (!force) {
                SnowflakeResolver snowflakeResolver = SnowflakeResolver(resolvers[i]);
                if (snowflakeResolver.callOnRemoval()) {
                    require(
                        snowflakeResolver.onRemoval(identity),
                        "Removal failure."
                    );
                }
            }
            emit ResolverRemoved(identity, resolvers[i]);
        }

        registry.removeResolvers(identity, resolvers);
    }

    function changeResolverAllowances(address[] resolvers, uint[] withdrawAllowances)
        public _hasToken(msg.sender, true)
    {
        _changeResolverAllowances(registry.getIdentity(msg.sender), resolvers, withdrawAllowances);
    }

    function changeResolverAllowancesDelegated(
        address _address, address[] resolvers, uint[] withdrawAllowances, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) public
    {
        string memory identity = registry.getIdentity(_address);
        require(registry.identityExists(identity), "Must add Resolver for a valid identity");

        bytes32 _hash = keccak256(
            abi.encodePacked("Change Resolver Allowances", resolvers, withdrawAllowances, timestamp)
        );

        require(signatureLog[_hash] == false, "Signature was already submitted");
        signatureLog[_hash] = true;

        require(registry.isSigned(_address, _hash, v, r, s), "Permission denied.");

        _changeResolverAllowances(identity, resolvers, withdrawAllowances);
    }

    function _changeResolverAllowances(string identity, address[] resolvers, uint[] withdrawAllowances) internal {
        require(resolvers.length == withdrawAllowances.length, "Malformed inputs.");

        for (uint i; i < resolvers.length; i++) {
            require(registry.isResolverFor(identity, resolvers[i]), "Identity has not set this resolver.");
            resolverAllowances[identity][resolvers[i]] = withdrawAllowances[i];
            emit ResolverAllowanceChanged(identity, resolvers[i], withdrawAllowances[i]);
        }
    }

    // check resolver allowances (does not throw)
    function getResolverAllowance(string identity, address resolver) public view returns (uint withdrawAllowance) {
        return resolverAllowances[identity][resolver];
    }

    function addAddress(
        string identity,
        address approvingAddress,
        address addressToAdd,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt
    ) public {
        IdentityRegistry registry = IdentityRegistry(identityRegistryAddress);
        registry.addAddress(identity, approvingAddress, addressToAdd, v, r, s, salt);
    }

    function removeAddress(string identity, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public {
        IdentityRegistry registry = IdentityRegistry(identityRegistryAddress);
        registry.removeAddress(identity, addressToRemove, v, r, s, salt);
    }

    // allow contract to receive HYDRO tokens
    function receiveApproval(address sender, uint amount, address _tokenAddress, bytes _bytes) public {
        require(msg.sender == _tokenAddress, "Malformed inputs.");
        require(_tokenAddress == hydroTokenAddress, "Sender is not the HYDRO token smart contract.");

        address recipient;
        if (_bytes.length == 20) {
            assembly { // solium-disable-line security/no-inline-assembly
                recipient := div(mload(add(add(_bytes, 0x20), 0)), 0x1000000000000000000000000)
            }
        } else {
            recipient = sender;
        }
        require(hasToken(recipient), "Invalid token recipient");

        ERC20 hydro = ERC20(_tokenAddress);
        require(hydro.transferFrom(sender, address(this), amount), "Unable to transfer token ownership.");

        string memory recipientIdentity = registry.getIdentity(recipient);
        deposits[recipientIdentity] = deposits[recipientIdentity].add(amount);

        emit SnowflakeDeposit(recipientIdentity, sender, amount);
    }

    function snowflakeBalance(string identity) public view returns (uint) {
        return deposits[identity];
    }

    // transfer snowflake balance from one snowflake holder to another
    function transferSnowflakeBalance(string identityTo, uint amount) public _hasToken(msg.sender, true) {
        _transfer(registry.getIdentity(msg.sender), identityTo, amount);
    }

    // withdraw Snowflake balance to an external address
    function withdrawSnowflakeBalance(address to, uint amount) public _hasToken(msg.sender, true) {
        _withdraw(registry.getIdentity(msg.sender), to, amount);
    }

    // allows resolvers to transfer allowance amounts to other snowflakes (throws if unsuccessful)
    function transferSnowflakeBalanceFrom(string identityFrom, string identityTo, uint amount) public {
        handleAllowance(identityFrom, amount);
        _transfer(identityFrom, identityTo, amount);
    }

    // allows resolvers to withdraw allowance amounts to external addresses (throws if unsuccessful)
    function withdrawSnowflakeBalanceFrom(string identityFrom, address to, uint amount) public {
        handleAllowance(identityFrom, amount);
        _withdraw(identityFrom, to, amount);
    }

    // allows resolvers to send withdrawal amounts to arbitrary smart contracts 'to' identitys (throws if unsuccessful)
    function withdrawSnowflakeBalanceFromVia(
        string identityFrom, address via, string identityFrom, uint amount, bytes _bytes
    ) public {
        handleAllowance(identityFrom, amount);
        _withdraw(identityFrom, via, amount);
        ViaContract viaContract = ViaContract(via);
        viaContract.snowflakeCall(msg.sender, identityFrom, identityTo, amount, _bytes);
    }

    // allows resolvers to send withdrawal amounts 'to' addresses via arbitrary smart contracts
    function withdrawSnowflakeBalanceFromVia(
        string identityFrom, address via, address to, uint amount, bytes _bytes
    ) public {
        handleAllowance(identityFrom, amount);
        _withdraw(identityFrom, via, amount);
        ViaContract viaContract = ViaContract(via);
        viaContract.snowflakeCall(msg.sender, identityFrom, to, amount, _bytes);
    }

    function _transfer(string identityFrom, string identityTo, uint amount) internal returns (bool) {
        require(registry.identityExists(identityTo), "Must transfer to a valid identity");

        require(deposits[identityFrom] >= amount, "Cannot withdraw more than the current deposit balance.");
        deposits[identityFrom] = deposits[identityFrom].sub(amount);
        deposits[identityTo] = deposits[identityTo].add(amount);

        emit SnowflakeTransfer(identityFrom, identityTo, amount);
    }

    function _withdraw(string identityFrom, address to, uint amount) internal {
        require(to != address(this), "Cannot transfer to the Snowflake smart contract itself.");

        require(deposits[identityFrom] >= amount, "Cannot withdraw more than the current deposit balance.");
        deposits[identityFrom] = deposits[identityFrom].sub(amount);
        ERC20 hydro = ERC20(hydroTokenAddress);
        require(hydro.transfer(to, amount), "Transfer was unsuccessful");
        emit SnowflakeWithdraw(to, amount);
    }

    function handleAllowance(string identityFrom, uint amount) internal {
        require(registry.identityExists(identityFrom), "Must call alloance for a valid identity.");

        // check that resolver-related details are correct
        require(registry.isResolverFor(identityFrom, msg.sender), "Resolver has not been set by from tokenholder.");

        if (resolverAllowances[identityFrom][msg.sender] < amount) {
            emit InsufficientAllowance(identityFrom, msg.sender, resolverAllowances[identityFrom][msg.sender], amount);
            require(false, "Insufficient Allowance");
        }

        resolverAllowances[identityFrom][msg.sender] = resolverAllowances[identityFrom][msg.sender].sub(amount);
    }

    // events
    event SnowflakeMinted(string identity);

    event ResolverWhitelisted(address indexed resolver);

    event ResolverAdded(string identity, address resolver, uint withdrawAllowance);
    event ResolverAllowanceChanged(string identity, address resolver, uint withdrawAllowance);
    event ResolverRemoved(string identity, address resolver);

    event SnowflakeDeposit(string identity, address from, uint amount);
    event SnowflakeTransfer(string identityFrom, string identityTo, uint amount);
    event SnowflakeWithdraw(address to, uint amount);
    event InsufficientAllowance(
        string identity, address indexed resolver, uint currentAllowance, uint requestedWithdraw
    );

    event AddressClaimed(address indexed _address, string identity);
    event AddressUnclaimed(address indexed _address, string identity);
}
