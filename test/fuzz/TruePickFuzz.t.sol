// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {TruePick} from "../../src/TruePick.sol";
import {Test,console} from "forge-std/Test.sol";
import {
    VRFCoordinatorV2_5Mock
} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DeployScript} from "../../script/DeployScript.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract TruePickFuzz is Test {
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

    function test_startGameFuzz(uint256 _entranceFee , uint256 _intervalTime , uint256 _guessingRange) public {
        _entranceFee = bound(_entranceFee , 1, type(uint256).max);
        _intervalTime = bound(_intervalTime , 1 , type(uint64).max);
        _guessingRange = bound(_guessingRange , 1, type(uint256).max);
        
        vm.startPrank(gameOperator);
        truePick.startGame(_entranceFee, _intervalTime, _guessingRange);
        uint256 intervalTimeFixed = truePick.getIntervalTime();
        uint256 guessingRangeSet = truePick.getGuessingRange();
        uint256 getEntranceFee = truePick.getEntranceFee();
        assertEq(_intervalTime , intervalTimeFixed - block.timestamp);
        assertEq(_guessingRange , guessingRangeSet);
        assertEq(getEntranceFee , _entranceFee);

    }
    modifier replicateStartGame() {
        vm.startPrank(gameOperator);
        truePick.startGame(entranceFee, intervalTime, guessingRange);
        vm.stopPrank();
        _;
    }

    function test_enterGameWithFuzz(uint256 _numberGussed) public  replicateStartGame{
        _numberGussed = bound(_numberGussed , 1 , guessingRange);
        hoax(player1, 10 ether);
        truePick.enterGame{value : 1 ether}(_numberGussed);
        uint256 playerGussed = truePick.getPlayerGuessed(player1);
        assertEq(playerGussed ,_numberGussed);
    }

    function test_StartAndEnter(uint256 _entranceFee,uint256 _numberGussed,uint256 _guessingRange) public {
        _entranceFee = bound(_entranceFee , 1, type(uint256).max);
        _guessingRange = bound(_guessingRange , 1, type(uint256).max);
        _numberGussed = bound(_numberGussed , 1 , _guessingRange);


        vm.startPrank(gameOperator);
        truePick.startGame(_entranceFee, intervalTime, _guessingRange);
        vm.stopPrank();

        hoax(player1, _entranceFee);
        truePick.enterGame{value : _entranceFee}(_numberGussed);
        uint256 playerGussed = truePick.getPlayerGuessed(player1);
        assertEq(playerGussed ,_numberGussed);
    }

    function test_enterGameFuzz(uint256 _numberGussed , uint256 _amount) public replicateStartGame {
        _numberGussed = bound(_numberGussed , guessingRange + 1, type(uint256).max);
        _amount = bound(_amount ,1 ether , entranceFee);

        hoax(player1 , _amount);
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__GussedNumOutOfRange.selector));
        truePick.enterGame{value : _amount}(_numberGussed);
    }

    function test_enterGameWhenNotStarted(uint256 _numberGussed , uint256 _amount) public {
        _numberGussed = bound(_numberGussed , 1 , guessingRange);
        _amount = bound(_amount , 1, entranceFee);

        hoax(player1 , _amount);
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__GameNotStarted.selector));
        truePick.enterGame{value : _amount}(_numberGussed);
    }

    function test_checkUpkeepFuzz(uint256 _initalTime) public replicateStartGame {
        _initalTime = bound(_initalTime , 0 , intervalTime - 1);
        hoax(player1 , 10 ether);
        truePick.enterGame{value : entranceFee}(10);

        vm.warp(block.timestamp + _initalTime);
        
        (bool checkUpKeepData , )=truePick.checkUpkeep("");
        assertFalse(checkUpKeepData);
    }

    function test_getWinnerFuzz(uint256 _winnerGuess) public replicateStartGame {
        _winnerGuess = (_winnerGuess % guessingRange) + 1;

        // first player guess
        hoax(player1 , 1 ether);
        truePick.enterGame{value : 1 ether}(_winnerGuess);

        // second player guess
        hoax(player2 , 1 ether);
        vm.expectRevert(abi.encodeWithSelector(TruePick.TruePick__NumberAlreadyTaken.selector));
        truePick.enterGame{value : 1 ether}(_winnerGuess);
        console.log("value : ",_winnerGuess);
        vm.warp(block.timestamp + intervalTime + 1);
        vm.roll(block.timestamp + 1);

        vm.startPrank(gameOperator);
        truePick.performUpkeep("");
        uint256 requestId = truePick.getRequestId();
        uint256[] memory words = new uint256[](1);
        words[0] = _winnerGuess - 1;
        console.log("result before : ",words[0]);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWordsWithOverride(requestId, address(truePick),words);
        uint256 result = truePick.getChoosedRandomValue();
        console.log("result after : ",result);
        vm.stopPrank();

        vm.prank(player1);
        truePick.getWinner();
        console.log("The Player 1 Balance : ",player1.balance);

        vm.prank(player2);
        
        truePick.getWinner();
        console.log("The player 2 Balance : ",player2.balance);
    }

}
    