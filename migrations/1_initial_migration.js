const AddressSet = artifacts.require('./AddressSet/AddressSet.sol')
const AddressSetTest = artifacts.require('./AddressSet/AddressSetTest.sol')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')

const Provider = artifacts.require('./testing/Provider.sol')
const Resolver = artifacts.require('./testing/Resolver.sol')

module.exports = async function (deployer) {
  deployer.deploy(AddressSet)
  deployer.link(AddressSet, AddressSetTest)
  deployer.deploy(AddressSetTest)

  deployer.link(AddressSet, IdentityRegistry)
  await deployer.deploy(IdentityRegistry)

  const identityRegistry = await IdentityRegistry.deployed()
  deployer.deploy(Provider, identityRegistry.address)
  deployer.deploy(Resolver, identityRegistry.address)
}
