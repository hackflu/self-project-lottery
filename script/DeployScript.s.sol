// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HelperConfig} from "./HelperConfig.s.sol";
import {Script,console} from "forge-std/Script.sol";
import {Subscription,FundSubscription,AddConsumer} from "./Integeration.s.sol";
import {TruePick} from "../src/TruePick.sol";

contract DeployScript is Script {
    function run() public returns(TruePick , HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        uint256 _subId; // for the on-chain

        // createSubscriptionId
        if(config.subscriptionId == 0  && config.chainId == 11155111){
            Subscription subscription = new Subscription();
            _subId = subscription.createSubscription(helperConfig);
        }

        // fund the subscriptionId
        FundSubscription fundSubscription = new FundSubscription();
        if(config.chainId == 11155111){
            fundSubscription.createFundSubscription(helperConfig, _subId);
        }else{
            fundSubscription.createFundSubscription(helperConfig, config.subscriptionId);
        }
        console.log("The current account is ", config.account);
        console.log("vrfCoord address generated : ",config.vrfCoordinator);
        console.log("Subid generated :",config.subscriptionId);

        // deploy the contract
        vm.startBroadcast(config.account);
        TruePick truePick = new TruePick(config.vrfCoordinator,config.subscriptionId,config.callbackgasLimit,config.keyHash);
        vm.stopBroadcast();
        
        // add to addConusmer
        AddConsumer addConsumerContract = new AddConsumer();
        addConsumerContract.addConsumer(address(truePick), helperConfig);

        return(truePick , helperConfig);
    }
}