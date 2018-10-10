const AddressSet = artifacts.require('./AddressSet/AddressSet.sol')
const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')

const AddressSetExample = artifacts.require('./examples/AddressSetExample.sol')
const ProviderExample = artifacts.require('./examples/ProviderExample.sol')

module.exports = function (deployer) {
  deployer.deploy(AddressSet)

  deployer.link(AddressSet, IdentityRegistry)
  deployer.deploy(IdentityRegistry)

  deployer.link(AddressSet, AddressSetExample)
  deployer.deploy(AddressSetExample)

  deployer.deploy(ProviderExample)
}
