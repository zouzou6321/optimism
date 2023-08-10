// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract DelayedVetoable {
    // All state variables are internal to ensure that getter functions do not
    // interfere with the forwarding of calls.

    // can be modified
    address internal _vetoer;

    // can be modified
    address internal _initiator;

    // not updated after initial deployment
    address internal _target;

    // not updated after initial deployment
    uint256 internal _delay;

    mapping(bytes32 => uint256) internal _queuedAt;

    event InitiatorChanged(address previousInitiator, address newInitiator);

    event VetoerChanged(address previousVetoer, address newVetoer);

    event Initiated(bytes32 indexed callHash, bytes data);
    event Vetoed(bytes32 indexed callHash, bytes data);
    event Forwarded(bytes32 indexed callHash, bytes data);

    modifier forwardCallIfNotAdmin() {
        if (msg.sender == _vetoer || msg.sender == _initiator || msg.sender == address(0)) {
            _;
        } else {
            // This WILL halt the call frame on completion.
            _handleCall();
        }
    }

    /// @notice Sets the initial initiator during contract deployment.
    /// @param initiator Address of the initiator.
    /// @param vetoer Address of the vetoer.
    /// @param target Address of the target contract.
    /// @param delay Time to sleep before forwarding the call.
    constructor(address initiator, address vetoer, address target, uint256 delay) {
        _changeInitiator(initiator);
        _changeVetoer(vetoer);
        _target = target;
        _delay = delay;
    }

    /// @notice Gets the initiator
    /// @return Initiator address.
    function initiator() public forwardCallIfNotAdmin returns (address) {
        return _initiator;
    }

    //// @notice Queries the vetoer address.
    /// @return Vetoer address.
    function vetoer() public forwardCallIfNotAdmin returns (address) {
        return _vetoer;
    }


    //// @notice Queries the target address.
    /// @return Target address.
    function target() public forwardCallIfNotAdmin returns (address) {
        return _target;
    }

    /// @notice Gets the delay
    /// @return Delay address.
    function delay() public forwardCallIfNotAdmin returns (uint256) {
        return _delay;
    }

    /// @notice Changes the initiator of the contract.
    /// @param initiator New initiator of the contract.
    function changeInitiator(address initiator) forwardCallIfNotAdmin external {
        _changeInitiator(initiator);
    }

    /// @notice Changes the initiator of the contract.
    /// @param initiator New initiator of the contract.
    function _changeInitiator(address initiator) internal {
        address previous = _initiator;
        _initiator = initiator;
        emit InitiatorChanged(previous, _initiator);
    }

    /// @notice Changes the vetoer of the contract.
    /// @param vetoer New vetoer of the contract.
    function changeVetoer(address vetoer) forwardCallIfNotAdmin external {
        _changeVetoer(vetoer);
    }

    /// @notice Changes the vetoer of the contract.
    /// @param vetoer New vetoer of the contract.
    function _changeVetoer(address vetoer) internal {
        address previous = _vetoer;
        _vetoer = vetoer;
        emit VetoerChanged(previous, vetoer);
    }

    // Do we even need a receive on this? Probably worth including.
    // slither-disable-next-line locked-ether
    receive() external payable {
        // Proxy call by default.
        _handleCall();
    }

    // slither-disable-next-line locked-ether
    fallback() external payable {
        // Proxy call by default.
        _handleCall();
    }

    /// @notice Queues up the call to be forwarded.
    // What should this return?
    // Should it return an enum or something first to indicate which branch was taken?
    function _handleCall() internal {
        bytes32 callHash = keccak256(msg.data);
        if (msg.sender == _vetoer) {
            // _vetoer is expected to pass in the same calldata as the original call.
            // we can update this to support a hash too tho.
            // delete the call to prevent replays
            delete _queuedAt[callHash];
            emit Vetoed(callHash, msg.data);
        } else if(msg.sender == _initiator) {
            // queue up the call
            _queuedAt[callHash] = block.timestamp;
            emit Initiated(callHash, msg.data);
        } else {
            // anyone can attempt to forward an already queued call.
            uint256 queuedAt = _queuedAt[callHash];
            if(queuedAt + _delay >= block.timestamp) {
                // sufficient time has passed.
                // Delete the call to prevent replays
                delete _queuedAt[callHash]; // alternatively use a nonce based system
                // Forward the call
                emit Forwarded(callHash, msg.data);
                (bool success, bytes memory returnData) = _target.call(msg.data);
            }
        }
    }
}
