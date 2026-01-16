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
contract TruePick is VRFConsumerBaseV2Plus,AutomationCompatibleInterface {
    ///////////////////////////////
    ///// type decleration ////////
    //////////////////////////////
    enum LotteryState {
        OPEN,
        CALCULATING,
        ENDED
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
    uint32 private constant NUMBER_WORDS =1; // choosing one single no.
    uint16 private constant REQUEST_CONFIRMATION_LIMIT = 3;

    uint256 private s_intervalTime;
    mapping(address => PlayerState) private s_playerStateTrack; // track the player state
    mapping(address => uint256) private s_playerDeposited; // track player deposited in Game
    mapping(address => uint256) private s_userGussed; // track played guessed number
    address private s_lotteryOperator;
    uint256 private s_entranceFee;
    uint256 private s_guessingRange;
    LotteryState private s_lotteryState;

    uint256 public s_requestId;
    uint256[] public s_allRequests;
    uint256 public s_resultValue;

    ////////////////////////////////
    /////////// Events /////////////
    ////////////////////////////////
    event GuessedSubmitted(address indexed, uint256 , uint256);
    event GameStarted(address indexed , uint256);
    event RequestIdGenerated(uint256);
    event GuessSubmitted(address indexed ,uint256 , uint256);

    ///////////////////////////////
    /////////// error /////////////
    ////////////////////////////////
    error TruePick__GameAlreadyStarted();
    error TruePick__GameNotStarted();
    error TruePick__AmountIsLess();
    error TruePick__PlayerAlreadyGussed();
    error TruePick__NotAuthorized();
    error TruePick__GameAlreadyEnded();
    error TruePick__UpkeepNotRequired(uint256 , uint256, uint256);
    error TruePick__GameNotEnded();
    error TruePick__UserIsNotPlayer();
    error TruePick__TransferredFailed();
    error TruePick__YouLostBetterLuckNextTime(uint256 resultValue , uint256 userGussed);
    ////////////////////////////////
    ///////// modifiers ////////////
    /////////////////////////////////
    modifier onlyLotteryOperator {
        if(msg.sender != s_lotteryOperator){
            revert TruePick__NotAuthorized();
        }
        _;
    }
    
    /////////////////////////////////
    /////// constructor ////////////
    ////////////////////////////////
    constructor(address _vrfCoordinator,uint256 _subscriptionId,uint32 _callbackgasLimit,bytes32 _keyHash) VRFConsumerBaseV2Plus(_vrfCoordinator){
        i_subscriptionId = _subscriptionId;
        i_callbackgasLimit = _callbackgasLimit;
        i_keyHash = _keyHash;
    }

    function startLottery(uint256 _entranceFee , uint256 _intervalTime, uint256 _guessingRange) public {
        if(s_lotteryState != LotteryState.ENDED){
            revert TruePick__GameAlreadyStarted();
        }
        s_entranceFee = _entranceFee;
        s_intervalTime = block.timestamp + _intervalTime;
        s_lotteryOperator = msg.sender;
        s_lotteryState = LotteryState.OPEN;
        s_guessingRange = _guessingRange;
        emit GameStarted(msg.sender , _intervalTime);
    }

    function enterGame(uint256 _numberGussed) public payable {
        if(s_lotteryState != LotteryState.OPEN) {
            revert TruePick__GameNotStarted();
        }
        if(msg.value < s_entranceFee){
            revert TruePick__AmountIsLess();
        }
        if(s_playerStateTrack[msg.sender] != PlayerState.NONE){
            revert TruePick__PlayerAlreadyGussed();
        }
        s_playerDeposited[msg.sender] = msg.value;

        s_playerStateTrack[msg.sender] = PlayerState.ENTERED;
        s_userGussed[msg.sender] = _numberGussed;
        emit GuessSubmitted(msg.sender ,msg.value, _numberGussed);
    }

    function checkUpkeep(bytes memory) public override returns(bool, bytes memory){
        bool isOpen = s_lotteryState == LotteryState.OPEN;
        bool timePassed = block.timestamp > s_intervalTime;
        bool hasBalance = address(this).balance > 0;
        bool checkUpkeepBoolVal = (isOpen && timePassed && hasBalance);
        return(checkUpkeepBoolVal , "0x0");
    }
    
    function performUpkeep(bytes calldata performData) external override {
        (bool upkeepNeeded , ) = checkUpkeep("");
        if(!upkeepNeeded){
            revert TruePick__UpkeepNotRequired(address(this).balance,uint256(s_lotteryState),s_intervalTime);
        }
        s_lotteryState = LotteryState.CALCULATING;
        s_requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION_LIMIT,
                callbackGasLimit: i_callbackgasLimit,
                numWords: NUMBER_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        s_allRequests.push(s_requestId);
        emit RequestIdGenerated(s_requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        require(requestId == s_requestId, "Not a valid RequestId");
        s_lotteryState = LotteryState.ENDED;
        s_resultValue = (randomWords[0] % s_guessingRange) + 1 ;
    }

    function getWinner() public {
        if(s_lotteryState != LotteryState.ENDED) {
            revert TruePick__GameNotEnded();
        }
        if(s_playerStateTrack[msg.sender] != PlayerState.ENTERED){
            revert TruePick__UserIsNotPlayer();
        }
        if(s_userGussed[msg.sender] != s_resultValue){
            revert TruePick__YouLostBetterLuckNextTime(s_resultValue , s_userGussed[msg.sender]);
        }
        (bool success,) = payable(msg.sender).call{value : address(this).balance}("");
        if(!success){
            revert TruePick__TransferredFailed();
        }
    }

}