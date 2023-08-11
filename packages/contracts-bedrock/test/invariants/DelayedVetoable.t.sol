// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Test } from "forge-std/Test.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Vm } from "forge-std/Vm.sol";
import { DelayedVetoable } from "../../src/L1/DelayedVetoable.sol";

contract DelayedVetoable_Succeeds_Invariants is StdInvariant, Test {
    DelayedVetoable delayedVetoable;
    DelayedVetoable_Actor initiator;
    DelayedVetoable_Actor vetoer;

    // The address that delayedVetoable will call to
    address dvTarget;

    function setUp() public {
        initiator = new DelayedVetoable_Actor(vm, delayedVetoable);

        vetoer = new DelayedVetoable_Actor(vm, delayedVetoable);




        delayedVetoable = new DelayedVetoable({
            initiator:
            vetoer:
            target:
            delay:
        })


        // Set the caller to this contract
        targetSender(address(this));

        // Target the safe caller actor.
        targetContract(address(actor));

    }

    /// @custom:invariant Calls from a non-admin are always forwarded, regardless of whether or not
    ///                   a function selector is matched.
    function invariant_nonAdminCall_isForwarded_succeeds() public {

    }

    /// @custom:invariant Calls from an admin that match a selector in the abi
    function invariant_adminCallUnmatched_isForwarded_succeeds() public {
    }

    /// @custom:invariant Calls from an admin that match a selector in the abi
    function invariant_adminCallMatched_isNotForwarded_succeeds() public {
    }
}

contract DelayedVetoable_Actor {
    DelayedVetoable delayedVetoable;

    constructor(VM vm, DelayedVetoable delayedVetoable_) {
        delayedVetoable = delayedVetoable_;
    }

    function callAbiFunction() external {

    }

    function callNonAbiFunction() external {

    }
}
