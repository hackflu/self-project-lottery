// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @title Lottery contract
/// @author HackFlu
/// @notice Participate by submitting a guess with ETH.
/// If your guess is correct when the game ends, you receive most of the pooled ETH.
/// @dev Time-bound ETH guessing game where participants stake native ETH.
/// The correct guess receives 90% of the total pool; the remaining 10% is retained by the contract.
contract TruePick is VRFConsumerBaseV2Plus AutomationCompatibelInterface {
    ///////////////////////////////
    ///// type decleration ////////
    //////////////////////////////
    enum LotteryState {
        OPEN,
        ENDED,
    }
    enum PlayerState {
        NONE,
        ENTERED
    }
    /////////////////////////////////
    /////// state variable /////////
    ////////////////////////////////
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackgasLimit;
    uint256 private immutable i_intervalTime;
    uint32 private constant NUMBER_WORDS =1; // choosing one single no.
    uint16 private constant REQUEST_CONFIRMATION_LIMIT = 3;

    address[] private s_players; // track no of user.
    mapping(address => PlayerState) private s_playerStateTrack;
    mapping(address => uint256) private s_playerDeposited;
    
    uint256 private i_entranceFee;

    LotteryState public s_lootteryState;
    PlayerState public s_playerState;

    ////////////////////////////////
    /////////// Events /////////////
    ///////////////////////////////
    event GuessedSubmitted();

    ///////////////////////////////
    /////////// error /////////////
    ////////////////////////////////
    error TruePick__AlreadyStarted();
    error TruePick__GameNotStarted();
    error TruePick__AmountIsLess();
    error TruePick__PlayerAlreadyGussed();
    
    /////////////////////////////////
    /////// constructor ////////////
    ////////////////////////////////
    constructor(address _vrfCoordinator,_subscriptionId,_callbackgasLimit,_keyHash,_intervalTime) VRFConsumerBaseV2Plus(_vrfCoordinator){
        i_subscriptionId = _subscriptionId;
        i_callbackgasLimit = _callbackgasLimit;
        i_keyHash = _keyHash;
        i_intervalTime = _intervalTime;
    }

    function startLottery(uint256 _entranceFee) public {
        if(lotteryState != LotteryState.ENDED){
            revert TruePick__AlreadyStarted();
        }
        i_entrancefee = _entranceFee;
        lotteryState = LotteryState.OPEN; 
    }

    function enterTheGame() public payable {
        if(lottertState != LotteryState.OPEN) {
            revert TruePick__GameNotStarted();
        }
        if(msg.value < i_entraceFee){
            revert TruePick__AmountIsLess();
        }
        if(s_playerState == PlayerState.ENTERED){
            revert TruePick__PlayerAlreadyGussed();
        }
        playerDeposited[msg.sender] = msg.value;
        s_players.push(payablemsg.sender);
        s_playerStateTrack[msg.sender] = s_playerState.ENTERED;
        emit GuessSubmitted(msg.sender ,msg.value, gussedValue);
    }
}