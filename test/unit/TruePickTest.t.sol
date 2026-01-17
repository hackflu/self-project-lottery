// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {TruePick} from "../../src/TruePick.sol";
import {DeployScript} from "../../script/DeployScript.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

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

    uint256 entranceFee = 1 ether;
    uint256 intervalTime = 2 days;
    uint256 guessingRange = 100;

    address gameOperator = makeAddr("gameOperator");
    address player1 = makeAddr("palyer1");
    address player2 = makeAddr("player2");

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

    ///////////////////////////////////
    ////////// startGame /////////////
    //////////////////////////////////
    function test_startGame() public {
        vm.startPrank(gameOperator);
        truePick.startGame(entranceFee, intervalTime, guessingRange);
        uint256 gameState = truePick.getCurrentGameState();
        uint256 intervalTimeFixed = truePick.getIntervalTime();
        uint256 guessingRangeSet = truePick.getGuessingRange();
        assertEq(gameState, 2);
        assertEq(intervalTime , intervalTimeFixed - block.timestamp);
        assertEq(guessingRange , guessingRangeSet);
        vm.stopPrank();
    }

    function test_startGameEvent() public {
        vm.startPrank(gameOperator);
        vm.expectEmit(true, false, false, true,address(truePick));
        emit TruePick.GameStarted(gameOperator ,intervalTime);
        truePick.startGame(entranceFee, intervalTime, guessingRange);
        address currentOwner = truePick.getCurrentGameOperator();
        assertEq(currentOwner, gameOperator);
        vm.stopPrank();
    }

    function test_startGameWithTest() public {
        vm.startPrank(gameOperator);
        truePick.startGame(entranceFee,intervalTime,guessingRange);
        uint256 currentState = truePick.getCurrentGameState();
        vm.stopPrank();

        assertEq(currentState , uint256(TruePick.GameState.OPEN));

        vm.startPrank(gameOperator);
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__GameAlreadyStarted.selector));
        truePick.startGame(entranceFee, intervalTime, guessingRange);
        vm.stopPrank();
    }

    modifier replicateStartGame {
        vm.startPrank(gameOperator);
        truePick.startGame(entranceFee,intervalTime, guessingRange);
        vm.stopPrank();
        _;
    }


    /////////////////////////////////////
    ////////// enterGame ///////////////
    ////////////////////////////////////
    function test_enterGame() public replicateStartGame {
        hoax(player1 , 10 ether);
        truePick.enterGame{value : 1 ether}(10);
        uint256 playerGussed = truePick.getPlayerGuessed(player1);
        uint256 state = truePick.getPlayerState(player1);
        assertEq(playerGussed, 10);
        assertEq(state , 1);
    }

    function test_enterGameWhenNotStarted() public {
        hoax(player1 , 10 ether);
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__GameNotStarted.selector));
        truePick.enterGame{value : 1 ether}(10);
    }

    function test_enterGameWithLessAmount() public replicateStartGame {
        hoax(player1 ,10 ether);
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__AmountIsLess.selector));
        truePick.enterGame{value : 0.5 ether}(1);
    }

    function test_enterGameWithErrorPlayerAlreadyGussed() public replicateStartGame {
        hoax(player1 , 10 ether);
        truePick.enterGame{value : 1 ether}(1);
        uint256 currentPlayerState = truePick.getPlayerState(player1);

        assertEq(currentPlayerState , uint256(TruePick.PlayerState.ENTERED));

        hoax(player1 , 10 ether);
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__PlayerAlreadyGussed.selector));
        truePick.enterGame{value : 1 ether}(2);
    }

    function test_enterGameTestEvent() public replicateStartGame {
        hoax(player1 , 10 ether);
        vm.expectEmit(true, false, false, true,address(truePick));
        emit TruePick.GuessSubmitted(player1 , 1 ether, 10);
        truePick.enterGame{value : 1 ether}(10);
    }

    modifier replicateEnterGame {
        hoax(player1 , 10 ether);
        truePick.enterGame{value : 1 ether}(10);

        hoax(player2, 10 ether);
        truePick.enterGame{value : 1 ether}(10);
        _;
    }
    //////////////////////////////////////
    ////////// checkUpkeep //////////////
    /////////////////////////////////////
    function test_checkUpkeep() public replicateStartGame replicateEnterGame {
        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.number + 1);

        (bool checkUpkeep , ) = truePick.checkUpkeep("");
        assert(checkUpkeep);
        assert(address(truePick).balance > 0);
        assert(block.timestamp + intervalTime < block.timestamp + intervalTime + 1);
    }

    ///////////////////////////////////
    ////////// performUpKeep //////////
    //////////////////////////////////
    function test_performUpKeep() public replicateStartGame replicateEnterGame {
        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.number + 1);

        truePick.performUpkeep("");
        uint256 gameState = truePick.getCurrentGameState();
        uint256 allRequestsLength = truePick.getAllRequest();
        assertEq(gameState , uint256(TruePick.GameState.CALCULATING));
        assertEq(allRequestsLength , 1);
    }

    function test_performUpKeepWithCheckUpkeepFalse() public {
        uint256 gameState = truePick.getCurrentGameState();
        uint256 _intervalTime = truePick.getIntervalTime();
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__UpkeepNotRequired.selector, address(truePick).balance ,gameState, _intervalTime));
        truePick.performUpkeep("");
    }

    function test_performUpKeepWithEvent() public replicateStartGame replicateEnterGame {
        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        truePick.performUpkeep("");
        uint256 currentStateDuringPerformUpkeep = truePick.getCurrentGameState();
        assertEq(currentStateDuringPerformUpkeep, uint256(TruePick.GameState.CALCULATING));
        uint256 requestId = truePick.getRequestId();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        console.log("log length : ",logs.length);
        console.log("requeted Id " ,requestId);

        bytes32 topicSig = keccak256("RequestIdGenerated(uint256)");
        assertEq(topicSig , logs[1].topics[0]);
        console.log("the value : ",abi.decode(logs[1].data , (uint256)));
        console.log("the address emittede : ",logs[1].emitter);
        assertEq(abi.decode(logs[1].data , (uint256)) , requestId);
        assertEq(logs[1].emitter, address(truePick));
    }

    ////////////////////////////////////////
    /////// fullFillRandomWords ///////////
    ///////////////////////////////////////
    function test_fulFillRandomWords() public replicateStartGame replicateEnterGame {
        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.timestamp + 1);
        vm.startPrank(gameOperator);
        truePick.performUpkeep("");
        uint256 requestId = truePick.getRequestId();
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(requestId, address(truePick));
        uint256 latestRandomVal = truePick.getChoosedRandomValue();
        uint256 currestStateAafterChoosingValue = truePick.getCurrentGameState();
        console.log("random value : ",latestRandomVal);
        assertEq(currestStateAafterChoosingValue, uint256(TruePick.GameState.ENDED));
        vm.stopPrank();
    }

    ////////////////////////////////////////
    ///////////// getWinner ///////////////
    ////////////////////////////////////////
    function test_getWinnerWithFailedException() public replicateStartGame replicateEnterGame {
        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.timestamp + 1);
        vm.startPrank(gameOperator);
        truePick.performUpkeep("");
        uint256 requestId = truePick.getRequestId();
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(requestId, address(truePick));
        vm.stopPrank();

        uint256 latestRandomValue = truePick.getChoosedRandomValue();
        vm.startPrank(player1);
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__YouLostBetterLuckNextTime.selector, latestRandomValue,10));
        truePick.getWinner();
        vm.stopPrank();
    }


    function test_getWinner() public  {
        uint256 _guessingRange = 1;
        vm.prank(gameOperator);
        truePick.startGame(entranceFee, intervalTime, _guessingRange);

        hoax(player1 , 10 ether);
        truePick.enterGame{value : 1 ether}(1);

        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.number + 1);

        vm.startPrank(gameOperator);
        truePick.performUpkeep("");
        uint256 requestId = truePick.getRequestId();
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(requestId, address(truePick));
        vm.stopPrank();

        uint256 latestRandomValue = truePick.getChoosedRandomValue();
        uint256 totalReward = truePick.totalAmountReward();
        console.log("total reward : ",totalReward);
        assertEq(totalReward , 1000000000000000000);
        vm.startPrank(player1);
        vm.expectEmit(true, false, false, true ,address(truePick));
        emit TruePick.Winner(player1, 1000000000000000000);
        truePick.getWinner();
        assertEq(address(player1).balance , 10 ether);
        vm.stopPrank();
    }

    function test_getWinnerWhenUserNotPlayer() public replicateStartGame  {
        hoax(player1 , 10 ether);
        truePick.enterGame{value : 1 ether}(1);

        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.number + 1);

        vm.startPrank(gameOperator);
        truePick.performUpkeep("");
        uint256 requestId = truePick.getRequestId();
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(requestId, address(truePick));
        vm.stopPrank();

        vm.startPrank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__UserIsNotPlayer.selector));
        truePick.getWinner();
        vm.stopPrank();
    }

    function test_getWinnerWhenGameNotEnded() public replicateStartGame {
        vm.startPrank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__GameNotEnded.selector));
        truePick.getWinner();
        vm.stopPrank();
    }
}