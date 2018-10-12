const AddressSet = artifacts.require('./AddressSet/AddressSet.sol')
const AddressSetSample = artifacts.require('./testing/AddressSetSample.sol')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')

const ProviderSample = artifacts.require('./testing/ProviderSample.sol')
const ResolverSample = artifacts.require('./testing/ResolverSample.sol')

module.exports = async function (deployer) {
  deployer.deploy(AddressSet)

  deployer.link(AddressSet, AddressSetSample)
  deployer.deploy(AddressSetSample)

  deployer.link(AddressSet, IdentityRegistry)
  await deployer.deploy(IdentityRegistry)

  const identityRegistry = await IdentityRegistry.deployed()
  deployer.deploy(ProviderSample, identityRegistry.address)
  deployer.deploy(ResolverSample, identityRegistry.address)
}
