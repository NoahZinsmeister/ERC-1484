const AddressSet = artifacts.require('./AddressSet/AddressSet.sol')
const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const TestAddressSet = artifacts.require('./AddressSet/TestAddressSet.sol')

module.exports = function (deployer) {
  deployer.deploy(AddressSet)
  deployer.link(AddressSet, TestAddressSet)
  deployer.link(AddressSet, IdentityRegistry)
  deployer.deploy(IdentityRegistry)
}
