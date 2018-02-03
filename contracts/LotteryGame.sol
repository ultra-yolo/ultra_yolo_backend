pragma solidity ^0.4.19;

import 'zeppelin-solidity/contracts/lifecycle/TokenDestructible.sol';

import './ERC223ReceivingContract.sol';
import './PayoutBacklogStorage.sol';

import './LotteryStorageLib.sol';
import './LotteryLib.sol';

contract LotteryGame is ERC223ReceivingContract, TokenDestructible {
  using LotteryStorageLib for LotteryStorageLib.LotteryStorage;
  using LotteryLib for LotteryLib.Lottery;

  event LogLotteryEntry(bytes lottery);
  event LogLotteryEntry(byte[6] lottery);
  event UIConfirmEntry(byte[6] lottery);

  /** ticket price in YOLO token */
  uint public ticketPriceYolo;
  /** ticket price in eth */
  uint public ticketPriceEth;
  /** prize values */
  uint[5] public payoutValues;
  /** payout period */
  uint[5] public payoutPeriods;
  /** payout backlog */
  PayoutBacklogStorage public payoutBacklogStorage;

  /** lottery ticket storage */
  LotteryStorageLib.LotteryStorage lotteryStorage;
  /** lottery */
  LotteryLib.Lottery lottery;
  /** payout threshold. since eth gas price, small prizes will be stored in the backlog
    * and distributed once it passes this threshold */
  uint public payoutThreshold;
  /** address of the lottery result generator */
  address public resultGeneratorAddress;

  modifier onlyResultGenerator() {
    if (msg.sender != resultGeneratorAddress) throw;
    _;
  }

  /**
    * constructor
  **/
  function LotteryGame(address _payoutBacklogStorageAddress, uint _ticketPriceEth, uint _ticketPriceYolo, uint[5] _payoutValues, uint[5] _payoutPeriods) {
    ticketPriceEth = _ticketPriceEth;
    ticketPriceYolo = _ticketPriceYolo;
    payoutValues = _payoutValues;
    payoutPeriods = _payoutPeriods;
    payoutBacklogStorage = PayoutBacklogStorage(_payoutBacklogStorageAddress);
  }

  function () external payable {
    require(msg.value >= ticketPriceEth);
    LogLotteryEntry(msg.data);
    lotteryStorage.enterLottery(lottery, msg.data, msg.sender);
  }

  function enterLottery(byte[6] entry, bool fromWebUI) public payable {
    require(msg.value >= ticketPriceEth);
    LogLotteryEntry(entry);
    if (fromWebUI) {
      /** necessary for entries passed through web3 but not metamask or remix */
      for (uint i = 0; i < 6; i++) {
        entry[i] = (entry[i] >> 4);
      }
    }
    lotteryStorage.enterLottery(lottery, entry, msg.sender);
    UIConfirmEntry(entry);
  }

  function receiveResult(byte[6] result) public onlyResultGenerator {
    processResult(result);
  }

  function processResult(byte[6] result) internal {
    for (uint i = 0; i < lotteryStorage.numLotteries(); i++) {
      LotteryLib.Lottery storage entry = lotteryStorage.lotteries[i];
      uint prizeIndex = getPrizeIndex(entry, result);
      if (prizeIndex <= 4) {
        address[] memory prizeWinners = lotteryStorage.getWinners(entry);
        addPrizesToBacklog(prizeWinners, prizeIndex);
      }
    }
    payoutBacklogStorage.pay(payoutThreshold);
  }

  function addPrizesToBacklog(address[] prizeWinners, uint prizeIndex) internal {
    uint numPrizeWinners = prizeWinners.length;
    if (numPrizeWinners > 0) {  // check shouldn't be necessary, for extra safety
      uint payoutAmount = (payoutValues[prizeIndex] / payoutPeriods[prizeIndex]) / numPrizeWinners;
      for (uint i = 0; i < numPrizeWinners; i++) {
        payoutBacklogStorage.addPrizeToWinner(prizeWinners[i], payoutAmount, payoutPeriods[prizeIndex]);
      }
    }
  }

  function getPrizeIndex(LotteryLib.Lottery storage entry, byte[6] result) internal returns (uint) {
    return entry.getNumNotMatching(result);
  }

  function resetPrize(uint index, uint value) public onlyOwner {
    payoutValues[index] = value;
  }

  function resetPrizePayoutPeriod(uint index, uint period) public onlyOwner {
    payoutPeriods[index] = period;
  }
  
  function setTicketPriceEth(uint _ticketPriceEth) public onlyOwner {
    ticketPriceEth = _ticketPriceEth;
  }

  function setTicketPriceYolo(uint _ticketPriceYolo) public onlyOwner {
    ticketPriceYolo = _ticketPriceYolo;
  }

  function setResultGeneratorAddress(address _resultGeneratorAddress) public onlyOwner {
    resultGeneratorAddress = _resultGeneratorAddress;
  }
  
  function setPayoutThreshold(uint _payoutThreshold) onlyOwner {
    payoutThreshold = _payoutThreshold;
  }

  /** good to have functions */
  function withdraw(uint amount) public onlyOwner {
    owner.transfer(amount);
  }

  function startNewRound() public onlyOwner {
    LotteryStorageLib.LotteryStorage storage _lotteryStorage;
    lotteryStorage = _lotteryStorage;
  }

  function tokenFallback(address _from, uint _value, bytes _data) public {
    
  }

  function getNumLotteries() returns(uint) {
    return lotteryStorage.numLotteries();
  }
  
  function getLotteryAtIndex(uint index) returns(byte[6]) {
    LotteryLib.Lottery memory entry = lotteryStorage.getLottery(index);
    LogLotteryEntry(entry.ticket);
    return entry.ticket;
  }
  
  function getPlayerAddressesAtIndex(uint index) returns(address[]) {
    LotteryLib.Lottery storage entry = lotteryStorage.lotteries[index];
    address[] memory prizeWinners = lotteryStorage.getWinners(entry);
    return prizeWinners;
  }

  function resetPayoutStorage(address _payoutBacklogStorageAddress) onlyOwner public {
    payoutBacklogStorage = PayoutBacklogStorage(_payoutBacklogStorageAddress);
  }

  function resetPayoutStorageOwnership() onlyOwner public {
    payoutBacklogStorage.transferOwnership(owner);
  }
  
}
