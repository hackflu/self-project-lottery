// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {
    IVRFCoordinatorV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {
    LinkTokenInterface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {
    VRFCoordinatorV2_5Mock
} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "@foundry-devops/DevOpsTools.sol";

contract Subscription is Script {
    function createSubscription(
        HelperConfig _helperConfig
    ) public returns (uint256 subId) {
        HelperConfig.NetworkConfig memory config = _helperConfig.getConfig();
        vm.startBroadcast(config.account);
        subId = IVRFCoordinatorV2Plus(config.vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
    }
    function run() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = createSubscription(helperConfig);
        return subId;
    }
}

contract FundSubscription is Script {
    error Integeration__InsufficientBalance();

    uint256 FUND_AMOUNT = 10 ether; /// 1000000000000000000 = 1 LINK

    function createFundSubscription(
        HelperConfig _helperConfig,
        uint256 _subId
    ) public {
        HelperConfig.NetworkConfig memory config = _helperConfig.getConfig();
        console.log("Funding to the Subscription ID");
        if (config.chainId == 31337) {
            vm.startBroadcast(config.account);
            VRFCoordinatorV2_5Mock(config.vrfCoordinator).fundSubscription(
                _subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
            console.log("Funded to the Local Anvil");
        } else {
            vm.startBroadcast(config.account);
            uint256 currentBalance = LinkTokenInterface(config.link).balanceOf(
                config.account
            );
            if (currentBalance < FUND_AMOUNT) {
                revert Integeration__InsufficientBalance();
            }
            LinkTokenInterface(config.link).transferAndCall(
                config.vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(_subId)
            );
            vm.stopBroadcast();
            console.log("Funded to the Sepolia Testnet");
        }
    }

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        createFundSubscription(helperConfig, subscriptionId);
    }
}
contract AddConsumer is Script {
    function addConsumer(
        address mostRecentlyDeployed,
        HelperConfig _helperConfig
    ) public {
        HelperConfig.NetworkConfig memory config = _helperConfig.getConfig();
        if (config.chainId == 11155111) {
            vm.startBroadcast(config.account);
            IVRFCoordinatorV2Plus(config.vrfCoordinator).addConsumer(
                config.subscriptionId,
                mostRecentlyDeployed
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(config.account);
            VRFCoordinatorV2_5Mock(config.vrfCoordinator).addConsumer(
                config.subscriptionId,
                mostRecentlyDeployed
            );
            vm.stopBroadcast();
        }
    }
    function run() public {
        address contractAddress = DevOpsTools.get_most_recent_deployment(
            "TruePick",
            block.chainid
        );
        HelperConfig helperConfig = new HelperConfig();
        addConsumer(contractAddress , helperConfig);
    }
}
