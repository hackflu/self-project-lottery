// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {TruePick} from "../../src/TruePick.sol";
import {DeployScript} from "../../script/DeployScript.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract TrustPickTest is Test {
    HelperConfig public helper;
    TruePick public truePick;
    DeployScript public deploy;

    uint256 subscriptionId;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    address account;
    uint256 chainId;
    address linkToken;

    function setUp() public {
        deploy = new DeployScript();
        (truePick, helper) = deploy.run();

        HelperConfig.NetworkConfig memory config = helper.getConfig();
        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        vrfCoordinatorV2_5 = config.vrfCoordinator;
        account = config.account;
        chainId = config.chainId;
        linkToken = config.link;
        callbackGasLimit = config.callbackgasLimit;
    }

}