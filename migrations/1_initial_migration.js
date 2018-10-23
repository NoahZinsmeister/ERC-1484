const AddressSet = artifacts.require('./AddressSet/AddressSet.sol')

const AddressSetTest = artifacts.require('./AddressSet/AddressSetTest.sol')
const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')

module.exports = async function (deployer) {
  deployer.deploy(AddressSet)
  deployer.link(AddressSet, AddressSetTest)
  deployer.link(AddressSet, IdentityRegistry)
}
