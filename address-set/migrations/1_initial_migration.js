const AddressSet = artifacts.require('./AddressSet.sol')
const Test = artifacts.require('./Test.sol')

module.exports = function (deployer) {
  deployer.deploy(AddressSet)
  deployer.link(AddressSet, Test)
  deployer.deploy(Test)
}
