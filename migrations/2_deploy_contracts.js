var SafeMath = artifacts.require('zeppelin-solidity/contracts/math/SafeMath.sol');

var LotteryLib = artifacts.require('./LotteryLib.sol');
var LotteryStorageLib = artifacts.require('./LotteryStorageLib.sol');
var PayoutBacklogLib = artifacts.require('./PayoutBacklogLib.sol');

var PayoutBacklogStorage = artifacts.require('./PayoutBacklogStorage.sol');
var LotteryGame = artifacts.require("./LotteryGame.sol");
var LotteryResultGenerator = artifacts.require("./LotteryResultGenerator.sol");
var LotteryResultGeneratorTest = artifacts.require("./LotteryResultGeneratorTest.sol");

let settings = require('../settings.json');

module.exports = function(deployer) {
  deployer.deploy(SafeMath);
  deployer.link(SafeMath, [LotteryGame, PayoutBacklogLib]);
  deployer.deploy(LotteryLib);
  deployer.link(LotteryLib, [LotteryStorageLib, LotteryGame]);
  deployer.deploy(LotteryStorageLib);
  deployer.link(LotteryStorageLib, LotteryGame);
  deployer.deploy(PayoutBacklogLib);
  deployer.link(PayoutBacklogLib, PayoutBacklogStorage);

  deployer.deploy(PayoutBacklogStorage).then(function() {
    return deployer.deploy(LotteryGame, PayoutBacklogStorage.address, settings.ticketPriceEth, settings.ticketPriceYolo,
    settings.payoutValues, settings.payoutPeriods).then(function() {
      return deployer.deploy(LotteryResultGenerator, LotteryGame.address);
    });
  });
};
