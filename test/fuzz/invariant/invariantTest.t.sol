// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployScript} from "../../../script/DeployScript.s.sol";
import {TruePick} from "../../../src/TruePick.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {Handler} from "./HandlerTest.t.sol";

contract InvariantTest is Test {
    DeployScript deploy;
    HelperConfig helper;
    TruePick truePick;
    Handler handler;
    uint256 private lastBalance;
    function setUp() public {
        deploy = new DeployScript();
        (truePick, helper) = deploy.run();
        handler = new Handler(truePick);
        targetContract(address(handler));
        lastBalance = address(truePick).balance;
    }

    function invariant_ethNeverDecreasesWhileOpenOrCalculating() public {
        uint256 currentState = truePick.getCurrentGameState();
        uint256 currentBalance = address(truePick).balance;

        if (
            currentState == uint256(TruePick.GameState.OPEN) ||
            currentState == uint256(TruePick.GameState.CALCULATING)
        ) {
            assert(currentBalance >= lastBalance);
        }
        lastBalance = currentBalance;
    }

    function invariant_GameEndAtIntervalState() public view {
        uint256 currentState = truePick.getCurrentGameState();
        uint256 intervalTime = truePick.getIntervalTime();
        if (block.timestamp <= intervalTime) {
            assert(currentState != uint256(TruePick.GameState.CALCULATING));
        }
    }

    function invariant_guessingRange() public view {
        uint256 resultValue = truePick.getChoosedRandomValue();
        if (resultValue != 0) {
            uint256 guessingRange = truePick.getGuessingRange();
            assert(resultValue > 0);
            assert(resultValue <= guessingRange);
        }
    }
}
