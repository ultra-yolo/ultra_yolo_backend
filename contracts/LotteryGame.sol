pragma solidity ^0.4.19;

import './ERC223ReceivingContract.sol';
import './PayoutBacklogStorage.sol';

import './LotteryStorageLib.sol';
import './LotteryLib.sol';

import 'zeppelin-solidity/contracts/lifecycle/TokenDestructible.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract LotteryGame is ERC223ReceivingContract, TokenDestructible {
  using LotteryStorageLib for LotteryStorageLib.LotteryStorage;
  using LotteryLib for LotteryLib.Lottery;
  using SafeMath for uint256;

  event LogNonUILotteryEntry(address indexed player, bytes lottery);
  event LogUIConfirmEntry(address indexed player, byte[6] lottery);
  event LogLotteryResult(byte[6] result);
  event LogPrizeWinners(uint indexed prizeIndex, address[] winners);
  event LogLotteryEntry(byte[6] entry);

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
  /** lottery placeholder variable */
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
    * @param _payoutBacklogStorageAddress jackpot address to distribute funds from
    * @param _ticketPriceEth ticket price in eth for people buying lottery in eth
    * @param _ticketPriceYolo ticket price in YOLO token for people buying via YOLO token
    * @param _payoutValues prizes in eth for grand prize to smallest prizes
    * @param _payoutPeriods number of weeks it takes to distribute prizes to winners. 1 measn distribute at once
  **/
  function LotteryGame(address _payoutBacklogStorageAddress, uint _ticketPriceEth, uint _ticketPriceYolo, uint[5] _payoutValues, uint[5] _payoutPeriods) {
    payoutBacklogStorage = PayoutBacklogStorage(_payoutBacklogStorageAddress);
    ticketPriceEth = _ticketPriceEth;
    ticketPriceYolo = _ticketPriceYolo;
    payoutValues = _payoutValues;
    payoutPeriods = _payoutPeriods;
  }

  /** lottery entry through non-ui channels. ie:  */
  function () external payable {
    require(msg.value >= ticketPriceEth);
    LogNonUILotteryEntry(msg.sender, msg.data);
    lotteryStorage.enterLottery(lottery, msg.data, msg.sender);
  }

  /** lottery entry through ui */
  function enterLottery(byte[6] entry, bool fromWebUI) public payable {
    require(msg.value >= ticketPriceEth);
    if (fromWebUI) {
      /** necessary for entries passed through web3 but not metamask or remix */
      for (uint i = 0; i < 6; i++) {
        entry[i] = (entry[i] >> 4);
      }
    }
    lotteryStorage.enterLottery(lottery, entry, msg.sender);
    LogUIConfirmEntry(msg.sender, entry);
  }

  /** notification of lottery result */
  function receiveResult(byte[6] result) public onlyResultGenerator {
    LogLotteryResult(result);
    processResult(result);
  }

  /** internal helper function */
  function processResult(byte[6] result) internal {
    for (uint i = 0; i < lotteryStorage.numLotteries(); i++) {
      LotteryLib.Lottery storage entry = lotteryStorage.lotteries[i];
      uint prizeIndex = getPrizeIndex(entry, result);
      if (prizeIndex <= 4) {
        address[] memory prizeWinners = lotteryStorage.getWinners(entry);
        LogPrizeWinners(prizeIndex, prizeWinners);
        LogLotteryEntry(entry.ticket);
        addPrizesToBacklog(prizeWinners, prizeIndex);
      }
    }
    payoutBacklogStorage.pay(payoutThreshold);
  }

  function addPrizesToBacklog(address[] prizeWinners, uint prizeIndex) internal {
    uint numPrizeWinners = prizeWinners.length;
    if (numPrizeWinners > 0) {  // check shouldn't be necessary, for extra safety
      uint payoutAmount = payoutValues[prizeIndex].div(payoutPeriods[prizeIndex]).div(numPrizeWinners);
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

  function resetPayoutStorage(address _payoutBacklogStorageAddress) onlyOwner public {
    payoutBacklogStorage = PayoutBacklogStorage(_payoutBacklogStorageAddress);
  }

  function resetPayoutStorageOwnership() onlyOwner public {
    payoutBacklogStorage.transferOwnership(owner);
  }
  
  function tokenFallback(address _from, uint _value, bytes _data) public {
    require(_value > ticketPriceYolo);
    LogNonUILotteryEntry(_from, _data);
    lotteryStorage.enterLottery(lottery, _data, msg.sender);
  }

  /** helper functions to read contents of the game */
  function getNumLotteries() public returns(uint) {
    return lotteryStorage.numLotteries();
  }
  
  function getLotteryAtIndex(uint index) public returns(byte[6]) {
    LotteryLib.Lottery memory entry = lotteryStorage.getLottery(index);
    return entry.ticket;
  }
  
  function getPlayerAddressesAtIndex(uint index) public returns(address[]) {
    LotteryLib.Lottery storage entry = lotteryStorage.lotteries[index];
    address[] memory prizeWinners = lotteryStorage.getWinners(entry);
    return prizeWinners;
  }

}
