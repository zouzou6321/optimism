// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Test } from "forge-std/Test.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Vm } from "forge-std/Vm.sol";
import { DelayedVetoable } from "../../src/L1/DelayedVetoable.sol";

contract DelayedVetoable_Succeeds_Invariants is StdInvariant, Test {
    DelayedVetoable delayedVetoable;
    DelayedVetoable_Actor initiatorActor;
    DelayedVetoable_Actor vetoerActor;

    // The address that delayedVetoable will call to
    address dvTarget;

    function setUp() public {
        initiatorActor = new DelayedVetoable_Actor(vm, delayedVetoable);
        vetoerActor = new DelayedVetoable_Actor(vm, delayedVetoable);





        delayedVetoable = new DelayedVetoable({
            initiator: address(initiatorActor),
            vetoer: address(vetoerActor),
            target: address(0xabba),
            delay: 100
        });


        // Set the caller to this contract
        targetSender(address(this));

        // Target the safe caller actor.
        targetContract(address(initiatorActor));
        targetContract(address(vetoerActor));

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
    Vm vm;

    constructor(Vm vm, DelayedVetoable delayedVetoable_) {
        delayedVetoable = delayedVetoable_;
    }

    function callAbiFunction() external {

    }

    function callNonAbiFunction() external {

    }
}
