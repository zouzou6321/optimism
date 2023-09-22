// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Testing utilities
import { SystemConfig_Initializer } from "./CommonTest.t.sol";

// Libraries
import { Constants } from "src/libraries/Constants.sol";
import { Types } from "src/libraries/Types.sol";

// Target contract dependencies
import { ResourceMetering } from "src/L1/ResourceMetering.sol";
import { Proxy } from "src/universal/Proxy.sol";

// Target contract
import { SystemConfig } from "src/L1/SystemConfig.sol";

contract SystemConfig_Initialize_Test is SystemConfig_Initializer {
    /// @dev Tests that initailization sets the correct values.
    function test_initialize_values_succeeds() external {
        assertEq(sysConf.l1CrossDomainMessenger(), l1CrossDomainMessenger);
        assertEq(sysConf.l1ERC721Bridge(), l1ERC721Bridge);
        assertEq(sysConf.l1StandardBridge(), l1StandardBridge);
        assertEq(sysConf.l2OutputOracle(), l2OutputOracle);
        assertEq(sysConf.optimismPortal(), optimismPortal);
        assertEq(sysConf.optimismMintableERC20Factory(), optimismMintableERC20Factory);
        assertEq(sysConf.batchInbox(), batchInbox);
        assertEq(sysConf.owner(), alice);
        assertEq(sysConf.overhead(), overhead);
        assertEq(sysConf.scalar(), scalar);
        assertEq(sysConf.batcherHash(), batcherHash);
        assertEq(sysConf.gasLimit(), gasLimit);
        assertEq(sysConf.unsafeBlockSigner(), unsafeBlockSigner);
        // Depends on start block being set to 0 in `initialize`
        assertEq(sysConf.startBlock(), block.number);
        // Depends on `initialize` being called with defaults
        ResourceMetering.ResourceConfig memory cfg = Constants.DEFAULT_RESOURCE_CONFIG();
        ResourceMetering.ResourceConfig memory actual = sysConf.resourceConfig();
        assertEq(actual.maxResourceLimit, cfg.maxResourceLimit);
        assertEq(actual.elasticityMultiplier, cfg.elasticityMultiplier);
        assertEq(actual.baseFeeMaxChangeDenominator, cfg.baseFeeMaxChangeDenominator);
        assertEq(actual.minimumBaseFee, cfg.minimumBaseFee);
        assertEq(actual.systemTxMaxGas, cfg.systemTxMaxGas);
        assertEq(actual.maximumBaseFee, cfg.maximumBaseFee);
    }

    /// @dev Ensures that the start block override can be used to set the start block.
    function test_initialize_startBlockOverride_succeeds() external {
        uint256 startBlock = 100;

        // Wipe out the initialized slot so the proxy can be initialized again
        vm.store(address(sysConf), bytes32(0), bytes32(0));

        assertEq(sysConf.startBlock(), block.number);
        // the startBlock slot is 106, wipe it out
        vm.store(address(sysConf), bytes32(uint256(106)), bytes32(0));
        assertEq(sysConf.startBlock(), 0);

        vm.prank(multisig);
        Proxy(payable(address(sysConf))).upgradeToAndCall(
            address(systemConfigImpl),
            abi.encodeCall(
                SystemConfig.initialize,
                (
                    alice, // _owner,
                    supConf, // _superchainConfig
                    overhead, // _overhead,
                    scalar, // _scalar,
                    batcherHash, // _batcherHash
                    gasLimit, // _gasLimit,
                    unsafeBlockSigner, // _unsafeBlockSigner,
                    Constants.DEFAULT_RESOURCE_CONFIG(), // _config,
                    startBlock, // _startBlock
                    batchInbox, // _batchInbox
                    SystemConfig.Addresses({ // _addresses
                        l1CrossDomainMessenger: l1CrossDomainMessenger,
                        l1ERC721Bridge: l1ERC721Bridge,
                        l1StandardBridge: l1StandardBridge,
                        l2OutputOracle: l2OutputOracle,
                        optimismPortal: optimismPortal,
                        optimismMintableERC20Factory: optimismMintableERC20Factory
                    })
                )
            )
        );
        assertEq(sysConf.startBlock(), startBlock);
    }

    /// @dev Ensures that the events are emitted during initialization.
    function test_initialize_events_succeeds() external {
        // Wipe out the initialized slot so the proxy can be initialized again
        vm.store(address(sysConf), bytes32(0), bytes32(0));
        vm.store(address(sysConf), bytes32(uint256(106)), bytes32(0));
        assertEq(sysConf.startBlock(), 0);

        // The order depends here
        vm.expectEmit(true, true, true, true, address(sysConf));
        emit ConfigUpdate(0, SystemConfig.UpdateType.BATCHER, abi.encode(batcherHash));
        vm.expectEmit(true, true, true, true, address(sysConf));
        emit ConfigUpdate(0, SystemConfig.UpdateType.GAS_CONFIG, abi.encode(overhead, scalar));
        vm.expectEmit(true, true, true, true, address(sysConf));
        emit ConfigUpdate(0, SystemConfig.UpdateType.GAS_LIMIT, abi.encode(gasLimit));
        vm.expectEmit(true, true, true, true, address(sysConf));
        emit ConfigUpdate(0, SystemConfig.UpdateType.UNSAFE_BLOCK_SIGNER, abi.encode(unsafeBlockSigner));

        vm.prank(multisig);
        Proxy(payable(address(sysConf))).upgradeToAndCall(
            address(systemConfigImpl),
            abi.encodeCall(
                SystemConfig.initialize,
                (
                    alice, // _owner,
                    supConf, // _superchainConfig
                    overhead, // _overhead,
                    scalar, // _scalar,
                    batcherHash, // _batcherHash
                    gasLimit, // _gasLimit,
                    unsafeBlockSigner, // _unsafeBlockSigner,
                    Constants.DEFAULT_RESOURCE_CONFIG(), // _config,
                    0, // _startBlock
                    batchInbox, // _batchInbox
                    SystemConfig.Addresses({ // _addresses
                        l1CrossDomainMessenger: l1CrossDomainMessenger,
                        l1ERC721Bridge: l1ERC721Bridge,
                        l1StandardBridge: l1StandardBridge,
                        l2OutputOracle: l2OutputOracle,
                        optimismPortal: optimismPortal,
                        optimismMintableERC20Factory: optimismMintableERC20Factory
                    })
                )
            )
        );
    }
}

contract SystemConfig_Initialize_TestFail is SystemConfig_Initializer {
    /// @dev Tests that initialization reverts if the gas limit is too low.
    function test_initialize_lowGasLimit_reverts() external {
        uint64 minimumGasLimit = sysConf.minimumGasLimit();

        // Wipe out the initialized slot so the proxy can be initialized again
        vm.store(address(sysConf), bytes32(0), bytes32(0));
        vm.prank(multisig);
        // The call to initialize reverts due to: "SystemConfig: gas limit too low"
        // but the proxy revert message bubbles up.
        vm.expectRevert("Proxy: delegatecall to new implementation contract failed");
        Proxy(payable(address(sysConf))).upgradeToAndCall(
            address(systemConfigImpl),
            abi.encodeCall(
                SystemConfig.initialize,
                (
                    alice, // _owner,
                    supConf, // _superchainConfig
                    2100, // _overhead,
                    1000000, // _scalar,
                    bytes32(hex"abcd"), // _batcherHash,
                    minimumGasLimit - 1, // _gasLimit,
                    address(1), // _unsafeBlockSigner,
                    Constants.DEFAULT_RESOURCE_CONFIG(), // _config,
                    0, // _startBlock
                    address(0), // _batchInbox
                    SystemConfig.Addresses({ // _addresses
                        l1CrossDomainMessenger: address(0),
                        l1ERC721Bridge: address(0),
                        l1StandardBridge: address(0),
                        l2OutputOracle: address(0),
                        optimismPortal: address(0),
                        optimismMintableERC20Factory: address(0)
                    })
                )
            )
        );
    }

    /// @dev Tests that initialization fails when the start block override is used
    ///      when the start block has already been set.
    function test_initialize_startBlock_reverts() external {
        // wipe out initialized slot so we can initialize again
        vm.store(address(sysConf), bytes32(0), bytes32(0));
        // the startBlock slot is 106, set it to something non zero
        vm.store(address(sysConf), bytes32(uint256(106)), bytes32(uint256(block.number)));

        // Initialize with a non zero start block, should see a revert
        vm.prank(multisig);
        // The call to initialize reverts due to: "SystemConfig: cannot override an already set start block"
        // but the proxy revert message bubbles up.
        vm.expectRevert("Proxy: delegatecall to new implementation contract failed");
        Proxy(payable(address(sysConf))).upgradeToAndCall(
            address(systemConfigImpl),
            abi.encodeCall(
                SystemConfig.initialize,
                (
                    alice, // _owner,
                    supConf, // _superchainConfig
                    overhead, // _overhead,
                    scalar, // _scalar,
                    batcherHash, // _batcherHash
                    gasLimit, // _gasLimit,
                    unsafeBlockSigner, // _unsafeBlockSigner,
                    Constants.DEFAULT_RESOURCE_CONFIG(), // _config,
                    1, // _startBlock
                    batchInbox, // _batchInbox
                    SystemConfig.Addresses({ // _addresses
                        l1CrossDomainMessenger: l1CrossDomainMessenger,
                        l1ERC721Bridge: l1ERC721Bridge,
                        l1StandardBridge: l1StandardBridge,
                        l2OutputOracle: l2OutputOracle,
                        optimismPortal: optimismPortal,
                        optimismMintableERC20Factory: optimismMintableERC20Factory
                    })
                )
            )
        );
    }
}

contract SystemConfig_Setters_TestFail is SystemConfig_Initializer {
    /// @dev Tests that `setBatcherHash` reverts if the caller is not the owner.
    function test_setSequencer_notOwner_reverts() external {
        vm.expectRevert("Ownable: caller is not the owner");
        Types.SequencerKeys memory sequencer =
            Types.SequencerKeys({ batcherHash: bytes32(uint256(0)), unsafeBlockSigner: address(0) });
        sysConf.setSequencer(sequencer);
    }

    /// @dev Tests that `setGasConfig` reverts if the caller is not the owner.
    function test_setGasConfig_notOwner_reverts() external {
        vm.expectRevert("Ownable: caller is not the owner");
        sysConf.setGasConfig(0, 0);
    }

    /// @dev Tests that `setGasLimit` reverts if the caller is not the owner.
    function test_setGasLimit_notOwner_reverts() external {
        vm.expectRevert("Ownable: caller is not the owner");
        sysConf.setGasLimit(0);
    }

    /// @dev Tests that `setResourceConfig` reverts if the caller is not the owner.
    function test_setResourceConfig_notOwner_reverts() external {
        ResourceMetering.ResourceConfig memory config = Constants.DEFAULT_RESOURCE_CONFIG();
        vm.expectRevert("Ownable: caller is not the owner");
        sysConf.setResourceConfig(config);
    }

    /// @dev Tests that `setResourceConfig` reverts if the min base fee
    ///      is greater than the maximum allowed base fee.
    function test_setResourceConfig_badMinMax_reverts() external {
        ResourceMetering.ResourceConfig memory config = ResourceMetering.ResourceConfig({
            maxResourceLimit: 20_000_000,
            elasticityMultiplier: 10,
            baseFeeMaxChangeDenominator: 8,
            systemTxMaxGas: 1_000_000,
            minimumBaseFee: 2 gwei,
            maximumBaseFee: 1 gwei
        });
        vm.prank(sysConf.owner());
        vm.expectRevert("SystemConfig: min base fee must be less than max base");
        sysConf.setResourceConfig(config);
    }

    /// @dev Tests that `setResourceConfig` reverts if the baseFeeMaxChangeDenominator
    ///      is zero.
    function test_setResourceConfig_zeroDenominator_reverts() external {
        ResourceMetering.ResourceConfig memory config = ResourceMetering.ResourceConfig({
            maxResourceLimit: 20_000_000,
            elasticityMultiplier: 10,
            baseFeeMaxChangeDenominator: 0,
            systemTxMaxGas: 1_000_000,
            minimumBaseFee: 1 gwei,
            maximumBaseFee: 2 gwei
        });
        vm.prank(sysConf.owner());
        vm.expectRevert("SystemConfig: denominator must be larger than 1");
        sysConf.setResourceConfig(config);
    }

    /// @dev Tests that `setResourceConfig` reverts if the gas limit is too low.
    function test_setResourceConfig_lowGasLimit_reverts() external {
        uint64 gasLimit = sysConf.gasLimit();

        ResourceMetering.ResourceConfig memory config = ResourceMetering.ResourceConfig({
            maxResourceLimit: uint32(gasLimit),
            elasticityMultiplier: 10,
            baseFeeMaxChangeDenominator: 8,
            systemTxMaxGas: uint32(gasLimit),
            minimumBaseFee: 1 gwei,
            maximumBaseFee: 2 gwei
        });
        vm.prank(sysConf.owner());
        vm.expectRevert("SystemConfig: gas limit too low");
        sysConf.setResourceConfig(config);
    }

    /// @dev Tests that `setResourceConfig` reverts if the elasticity multiplier
    ///      and max resource limit are configured such that there is a loss of precision.
    function test_setResourceConfig_badPrecision_reverts() external {
        ResourceMetering.ResourceConfig memory config = ResourceMetering.ResourceConfig({
            maxResourceLimit: 20_000_000,
            elasticityMultiplier: 11,
            baseFeeMaxChangeDenominator: 8,
            systemTxMaxGas: 1_000_000,
            minimumBaseFee: 1 gwei,
            maximumBaseFee: 2 gwei
        });
        vm.prank(sysConf.owner());
        vm.expectRevert("SystemConfig: precision loss with target resource limit");
        sysConf.setResourceConfig(config);
    }
}

contract SystemConfig_Setters_Test is SystemConfig_Initializer {
    /// @dev Tests that `setBatcherHash` updates the batcher hash successfully.
    function testFuzz_setBatcherHash_succeeds(Types.SequencerKeys calldata sequencer) external {
        // Add to the allowed sequencers list
        vm.prank(supConf.owner());
        supConf.addSequencer(sequencer);

        vm.expectEmit(true, true, true, true);
        emit ConfigUpdate(0, SystemConfig.UpdateType.UNSAFE_BLOCK_SIGNER, abi.encode(sequencer.unsafeBlockSigner));
        vm.expectEmit(true, true, true, true);
        emit ConfigUpdate(0, SystemConfig.UpdateType.BATCHER, abi.encode(sequencer.batcherHash));

        vm.prank(sysConf.owner());
        sysConf.setSequencer(sequencer);
        assertEq(sysConf.batcherHash(), sequencer.batcherHash);
        assertEq(sysConf.unsafeBlockSigner(), sequencer.unsafeBlockSigner);
    }

    /// @dev Tests that `setGasConfig` updates the overhead and scalar successfully.
    function testFuzz_setGasConfig_succeeds(uint256 newOverhead, uint256 newScalar) external {
        vm.expectEmit(true, true, true, true);
        emit ConfigUpdate(0, SystemConfig.UpdateType.GAS_CONFIG, abi.encode(newOverhead, newScalar));

        vm.prank(sysConf.owner());
        sysConf.setGasConfig(newOverhead, newScalar);
        assertEq(sysConf.overhead(), newOverhead);
        assertEq(sysConf.scalar(), newScalar);
    }

    /// @dev Tests that `setGasLimit` updates the gas limit successfully.
    function testFuzz_setGasLimit_succeeds(uint64 newGasLimit) external {
        uint64 minimumGasLimit = sysConf.minimumGasLimit();
        newGasLimit = uint64(bound(uint256(newGasLimit), uint256(minimumGasLimit), uint256(type(uint64).max)));

        vm.expectEmit(true, true, true, true);
        emit ConfigUpdate(0, SystemConfig.UpdateType.GAS_LIMIT, abi.encode(newGasLimit));

        vm.prank(sysConf.owner());
        sysConf.setGasLimit(newGasLimit);
        assertEq(sysConf.gasLimit(), newGasLimit);
    }
}
