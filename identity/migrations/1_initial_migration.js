const AddressSet = artifacts.require('./AddressSet/AddressSet.sol')
const AddressSetExample = artifacts.require('./examples/AddressSetExample.sol')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const ProviderExample = artifacts.require('./examples/ProviderExample.sol')
const ResolverExample = artifacts.require('./examples/ResolverExample.sol')

module.exports = async function (deployer) {
  await deployer.deploy(AddressSet)
  await deployer.link(AddressSet, AddressSetExample)
  await deployer.link(AddressSet, IdentityRegistry)

  await deployer.deploy(AddressSetExample)

  await deployer.deploy(IdentityRegistry)

  const identityRegistryInstance = await IdentityRegistry.deployed()
  await deployer.deploy(ProviderExample, identityRegistryInstance.address)
  await deployer.deploy(ResolverExample, identityRegistryInstance.address)
}
