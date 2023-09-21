// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// @title PeripheryDeployConfig
/// @notice Represents the configuration required to deploy the periphery contracts. It is expected
///         to read the file from JSON. A future improvement would be to have fallback
///         values if they are not defined in the JSON themselves.
contract PeripheryDeployConfig is Script {
    string internal _json;

    address public faucetAdmin;
    address public faucetDrippieOwner;
    uint256 public faucetDripV1Value;
    uint256 public faucetDripV1Interval;
    uint256 public faucetDripV1Threshold;

    constructor(string memory _path) {
        console.log("PeripheryDeployConfig: reading file %s", _path);
        try vm.readFile(_path) returns (string memory data) {
            _json = data;
        } catch {
            console.log("Warning: unable to read config. Do not deploy unless you are not using config.");
            return;
        }

        faucetAdmin = stdJson.readAddress(_json, "$.faucetAdmin");
        faucetDrippieOwner = stdJson.readAddress(_json, "$.faucetDrippieOwner");
        faucetDripV1Value = stdJson.readUint(_json, "$.faucetDripV1Value");
        faucetDripV1Interval = stdJson.readUint(_json, "$.faucetDripV1Interval");
        faucetDripV1Threshold = stdJson.readUint(_json, "$.faucetDripV1Threshold");
    }
}
