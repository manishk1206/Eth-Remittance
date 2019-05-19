const Remittance = artifacts.require("Remittance");

module.exports = function(deployer) {
  deployer.deploy(Remittance, 604800, true); // _maxTime = 7 days = 604800 seconds, _state = true i.e running
};
