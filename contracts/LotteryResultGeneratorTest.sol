pragma solidity ^0.4.19;

import './LotteryGame.sol';

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

/**
 * The LotteryResultGeneratorTest
 */
contract LotteryResultGeneratorTest is Ownable {
  uint constant MODULO = 12;
  uint constant NUM_LOTTERY_DIGITS = 6;

  LotteryGame public lotteryGame;
  byte[6] public lotteryResult;

  function LotteryResultGeneratorTest(address _lotteryGameAddress) {
    lotteryGame = LotteryGame(_lotteryGameAddress);
  }

  function resetGameAddress(address _lotteryGameAddress) onlyOwner public {
    lotteryGame = LotteryGame(_lotteryGameAddress);
  }

  /** maybe add mapping for a,b,c */
  function notifyGameForTesting(string result) onlyOwner public {
    for (uint i = 0; i < NUM_LOTTERY_DIGITS; i++) {
      byte resultByte = byte((uint(bytes(result)[i]) % MODULO) + 1);
      lotteryResult[i] = resultByte;
    }
    lotteryGame.receiveResult(lotteryResult);
  }

}

