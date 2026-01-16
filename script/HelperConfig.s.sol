// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Script} from "forge-std/Script.sol";

abstract contract DefaultNetworkConfig {
    uint96 constant BASE_FEE = 1e17;
    uint96 constant GAS_PRICE = 1e9;
    int256 constant WEI_PER_UNIT_LINK = 1e18;
    address constant DEFAULT_ADDRESS = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38; // default address used by the foundry while test
}

contract HelperConfig is Script, DefaultNetworkConfig{
    struct NetworkConfig{
        uint256 subscriptionId;
        address vrfCoordinator;
        bytes32 keyHash;
        uint32 callbackgasLimit;
        address account;
        address link;
        uint256 chainId;
    }

    mapping(uint256 => NetworkConfig) public networkConfig;

    constructor() {
        if(block.chainid == 11155111){
            networkConfig[block.chainid] = getSepoliaNetworkConfig();
        }else{
            networkConfig[block.chainid] = getAnvilNetworkConfig();
        }
    }

    function getConfig() public returns(NetworkConfig memory){
        return networkConfig[block.chainid];
    }

    function getSepoliaNetworkConfig() internal returns(NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            subscriptionId: 0,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackgasLimit: 500000,
            account: 0x0E6A032eD498633a1FB24b3FA96bF99bBBE4B754,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            chainId: 11155111
        });
    }

    function getAnvilNetworkConfig() internal returns(NetworkConfig memory anvilNetworkConfig){
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfmockCoordinator = new VRFCoordinatorV2_5Mock(BASE_FEE , GAS_PRICE ,WEI_PER_UNIT_LINK);
        uint256 subId = vrfmockCoordinator.createSubscription();
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            subscriptionId: subId,
            vrfCoordinator: address(vrfmockCoordinator),
            keyHash: 0x0000000000000000000000000000000000000000000000000000000000000000,
            callbackgasLimit: 5000000,
            account: DEFAULT_ADDRESS,
            link: address(0),
            chainId: 31337
        });
        vm.deal(anvilNetworkConfig.account, 100 ether);
    }
}