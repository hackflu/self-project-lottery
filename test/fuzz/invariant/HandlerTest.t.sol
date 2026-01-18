// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {TruePick} from "../../../src/TruePick.sol";

contract Handler is Test {
    TruePick truePick;
    bool gameCheck;

    constructor(TruePick _truePick) {
        truePick = _truePick;
    }

    function startGame(
        uint256 _entranceFee,
        uint256 _interval,
        uint256 _guessingRange
    ) public {
        if (gameCheck) return;
        _entranceFee = bound(_entranceFee, 0.01 ether, 1 ether);
        _interval = bound(_interval, 1 minutes, 1 days);
        _guessingRange = bound(_guessingRange, 1, 100);
        truePick.startGame(_entranceFee, _interval, _guessingRange);

        gameCheck = true;
    }

    function enterGame(uint256 guess) public {
        if (!gameCheck) return;
        uint256 fee = truePick.getEntranceFee();
        uint256 range = truePick.getGuessingRange();
        if (range == 0) return;

        guess = bound(guess, 1, range);

        vm.deal(address(this), fee);
        truePick.enterGame{value: fee}(guess);
        gameCheck = false;
    }
}
