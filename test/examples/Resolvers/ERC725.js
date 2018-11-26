const { verifyIdentity } = require('../../common.js')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const ERC725 = artifacts.require('./examples/Resolvers/ERC725/ERC725RegistryResolver.sol')

const instances = {}

contract('Testing ERC725 Resolver', function (accounts) {
  const users = [
    {
      address: accounts[1],
      private: '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    },
    {
      address: accounts[2],
      private: '0xccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
    }
  ]

  it('contracts deployed', async () => {
    instances.IdentityRegistry = await IdentityRegistry.new()
    instances.ERC725 = await ERC725.new(instances.IdentityRegistry.address)
  })

  describe('Create Snowflake', async () => {
    it('Identity created', async function () {
      const user = users[0]
      const otherGuy = users[1]

      await instances.IdentityRegistry.createIdentity(
        user.address, [user.address], [instances.ERC725.address], { from: user.address }
      )

      await instances.IdentityRegistry.createIdentity(
        otherGuy.address, [otherGuy.address], [instances.ERC725.address], { from: otherGuy.address }
      )

      user.identity = web3.utils.toBN(1)
      otherGuy.identity = web3.utils.toBN(2)

      await verifyIdentity(user.identity, instances.IdentityRegistry, {
        recoveryAddress:     user.address,
        associatedAddresses: [user.address],
        providers:           [user.address],
        resolvers:           [instances.ERC725.address]
      })
    })
  })

  describe('All 725 logic', async () => {
    const user = users[0]
    const otherGuy = users[1]
    let claimAddress

    it('725 mint', async function () {
      await instances.ERC725.create725({ from: user.address })
    })

    it('725 create FAIL', async function () {
      await instances.ERC725.create725({ from: user.address })
        .then(() => assert.fail('able to create again', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'You already have a 725', 'wrong rejection reason'
        ))
    })

    it('725 get', async function () {
      claimAddress = await instances.ERC725.get725(1, { from: user.address })
    })

    it('725 remove', async function () {
      await instances.ERC725.remove725({ from: user.address })
    })

    it('725 claim', async function () {
      const success = await instances.ERC725.claim725.call(claimAddress, { from: user.address })
      assert.equal(success, true)
      await instances.ERC725.claim725(claimAddress, { from: user.address })
    })

    it('725 claim FAIL', async function () {
      await instances.ERC725.claim725(claimAddress, { from: user.address })
        .then(() => assert.fail('able to create again', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'You already have a 725', 'wrong rejection reason'
        ))
    })

    it('725 claim FAIL 2', async function () {
      await instances.ERC725.create725({ from: otherGuy.address })
      claimAddress = await instances.ERC725.get725(2, { from: user.address })

      await instances.ERC725.remove725({ from: user.address })

      const success = await instances.ERC725.claim725.call(claimAddress, { from: user.address })
      assert.equal(success, false)
    })
  })
})
