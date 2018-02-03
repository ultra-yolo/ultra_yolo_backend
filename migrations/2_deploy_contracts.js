var PayoutBacklogStorage = artifacts.require('./PayoutBacklogStorage.sol');
var LotteryGame = artifacts.require("./LotteryGame.sol");
var LotteryResultGenerator = artifacts.require("./LotteryResultGenerator.sol");

var LotteryLib = artifacts.require('./LotteryLib.sol');
var LotteryStorageLib = artifacts.require('./LotteryStorageLib.sol');
var PayoutBacklogLib = artifacts.require('./PayoutBacklogLib.sol');

let settings = require('../settings.json');

module.exports = function(deployer) {
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

  /**
  deployer.deploy(PayoutBacklogLib);
  deployer.link(PayoutBacklogLib, PayoutBacklogStorage);
  deployer.deploy(PayoutBacklogStorage);
  deployer.deploy(LotteryGame, "0x573a7dca92aefb8200a03b9fbc1fd98413b66be8", settings.ticketPriceEth, settings.ticketPriceYolo,
  settings.payoutValues, settings.payoutPeriods).then(function() {
    return deployer.deploy(LotteryResultGenerator, LotteryGame.address);
  });
  deployer.deploy(LotteryLib);
  deployer.link(LotteryLib, [LotteryStorageLib, LotteryGame]);
  deployer.deploy(LotteryStorageLib);
  deployer.link(LotteryStorageLib, LotteryGame);
  deployer.deploy(LotteryGame, "0x573a7dca92aefb8200a03b9fbc1fd98413b66be8", settings.ticketPriceEth, settings.ticketPriceYolo,
    settings.payoutValues, settings.payoutPeriods);
  */
};