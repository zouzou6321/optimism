// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract Sleep {
    // can be modified
    address internal _vetoer;

    // can be modified
    address internal _instigator;

    // not updated after initial deployment
    address internal _target;

    // not updated after initial deployment
    uint256 internal _sleepTime;

    mapping(bytes32 => uint256) internal _queuedAt;

    event AdminChanged(address previousAdmin, address newAdmin);

    modifier forwardCallIfNotAdmin() {
        if (msg.sender == _admin || msg.sender == address(0)) {
            _;
        } else {
            // This WILL halt the call frame on completion.
            _handleCall();
        }
    }

    /// @notice Sets the initial admin during contract deployment.
    /// @param $admin Address of the initial contract admin.
    /// @param $target Address of the target contract.
    /// @param $sleepTime Time to sleep before forwarding the call.
    constructor(address $admin, address $target, uint256 $sleepTime) {
        _changeAdmin($admin);
        _target = $target;
        _sleepTime = $sleepTime;
    }

    /// @notice Gets the owner of the proxy contract.
    /// @return Owner address.
    function admin() public forwardCallIfNotAdmin returns (address) {
        return _admin;
    }

    //// @notice Queries the target address.
    /// @return Target address.
    function target() public forwardCallIfNotAdmin returns (address) {
        return _target;
    }

    /// @notice Changes the admin of the contract.
    /// @param _admin New admin of the contract.
    function _changeAdmin(address _admin) internal {
        address previous = admin;
        admin = _admin;
        emit AdminChanged(previous, _admin);
    }

    // Do we even need a receive on this? Probably worth including.
    // slither-disable-next-line locked-ether
    receive() external payable {
        // Proxy call by default.
        _doProxyCall();
    }

    // slither-disable-next-line locked-ether
    fallback() external payable {
        // Proxy call by default.
        _doProxyCall();
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
        } else if(msg.sender == _instigator) {
            // queue up the call
            _queuedAt[callHash] = block.timestamp;
        } else {
            // anyone can attempt to forward an already queued call.
            uint256 queuedAt = _queuedAt[callHash];
            if(_queuedAt + _sleepTime >= block.timestamp) {
                // sufficient time has passed.
                // Delete the call to prevent replays
                delete _queuedAt[callHash];
                // Forward the call
                (bool success, bytes memory returnData) = _target.call(msg.data);
            }
        }
    }
}
