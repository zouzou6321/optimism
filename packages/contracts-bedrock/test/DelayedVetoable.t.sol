// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { CommonTest } from "./CommonTest.t.sol";
import { DelayedVetoable } from "../src/L1/DelayedVetoable.sol";

contract DelayedVetoable_Init is CommonTest {
    event InitiatorChanged(address previousInitiator, address newInitiator);
    event VetoerChanged(address previousVetoer, address newVetoer);
    event Initiated(bytes32 indexed callHash, bytes data);
    event Vetoed(bytes32 indexed callHash, bytes data);
    event Forwarded(bytes32 indexed callHash, bytes data);

    address initiator = alice;
    address vetoer = bob;
    address target = address(0xabba);
    uint256 delay = 100;

    DelayedVetoable delayedVetoable;

    function setUp() public override {
        super.setUp();
        delayedVetoable = new DelayedVetoable(initiator, vetoer, target, delay);
    }
}

contract DelayedVetoable_Getters_Test is DelayedVetoable_Init {
    // todo: write a more generic invariant test for this functionality.
    function test_vetoer_getter_succeeds() external {
        vm.prank(alice);
        assertEq(vetoer, delayedVetoable.vetoer());
        vm.prank(bob);
        assertEq(vetoer, delayedVetoable.vetoer());
    }
    function test_initiator_getter_succeeds() external {
        vm.prank(alice);
        assertEq(initiator, delayedVetoable.initiator());
        vm.prank(bob);
        assertEq(initiator, delayedVetoable.initiator());
    }
    function test_target_getter_succeeds() external {
        vm.prank(alice);
        assertEq(target, delayedVetoable.target());
        vm.prank(bob);
        assertEq(target, delayedVetoable.target());
    }
    function test_delay_getter_succeeds() external {
        vm.prank(alice);
        assertEq(delay, delayedVetoable.delay());
        vm.prank(bob);
        assertEq(delay, delayedVetoable.delay());
    }
}

contract DelayedVetoable_Getters_TestFail is DelayedVetoable_Init {
    // tests that the getters forward when the call is not an admin.
}

