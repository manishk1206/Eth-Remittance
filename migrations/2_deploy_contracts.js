const Splitter = artifacts.require("Remittance");

module.exports = function(deployer) {
  deployer.deploy(Remittance);
};
