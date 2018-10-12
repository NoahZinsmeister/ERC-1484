const AddressSet = artifacts.require('./AddressSet/AddressSet.sol')
const AddressSetTesting = artifacts.require('./testing/AddressSetTesting.sol')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')

module.exports = async function (deployer) {
  deployer.deploy(AddressSet)

  deployer.link(AddressSet, AddressSetTesting)
  deployer.deploy(AddressSetTesting)

  deployer.link(AddressSet, IdentityRegistry)
  deployer.deploy(IdentityRegistry)
}
