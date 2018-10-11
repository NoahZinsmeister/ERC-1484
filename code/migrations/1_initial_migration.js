const AddressSet = artifacts.require('./AddressSet/AddressSet.sol')
const AddressSetTesting = artifacts.require('./testing/AddressSetTesting.sol')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const ProviderTesting = artifacts.require('./testing/ProviderTesting.sol')
const ResolverTesting = artifacts.require('./testing/ResolverTesting.sol')

module.exports = async function (deployer) {
  await deployer.deploy(AddressSet)
  await deployer.link(AddressSet, AddressSetTesting)
  await deployer.link(AddressSet, IdentityRegistry)

  await deployer.deploy(AddressSetTesting)

  await deployer.deploy(IdentityRegistry)

  const identityRegistryInstance = await IdentityRegistry.deployed()
  await deployer.deploy(ProviderTesting, identityRegistryInstance.address)
  await deployer.deploy(ResolverTesting, identityRegistryInstance.address)
}
