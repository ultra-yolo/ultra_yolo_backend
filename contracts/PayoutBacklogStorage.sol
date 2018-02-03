pragma solidity ^0.4.19;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import './PayoutBacklogLib.sol';

/**
 * The PayoutBacklogStorage contract
 * Store backlog to ensure every winner gets paid. And info never gets lost
 */
contract PayoutBacklogStorage is Ownable {
  using PayoutBacklogLib for PayoutBacklogLib.PayoutBacklog;

  PayoutBacklogLib.PayoutBacklog payoutBacklog;

  function addPrizeToWinner(address winner, uint amount, uint period) onlyOwner {
    payoutBacklog.addPrizeToWinner(winner, amount, period);
  }
  
  /** Payout everyone in the backlog that has prizes over the threshold */
  function pay(uint threshold) onlyOwner {
    payoutBacklog.pay(threshold);
  }

  function () external payable { }

  /** helper functions to inspect the payout backlog storage */
  function getNumWinners() returns(uint) {
    return payoutBacklog.getNumWinners();
  }
  
  function getWinnerAtIndex(uint index) returns(address) {
    return payoutBacklog.getWinnerAtIndex(index);
  }
  
  function getPayoutForWinner(address winner) returns(uint, uint, uint) {
    return payoutBacklog.getPayoutForWinner(winner);
  }
  
}

