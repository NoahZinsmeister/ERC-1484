const { sign, verifyIdentity } = require('../../common.js')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const BurnerProvider = artifacts.require('./examples/Providers/Burner/BurnerProvider.sol')

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
const instances = {}

let user
let dummyPerpetualProvider
contract('Testing Burner Provider', function (accounts) {
  const users = [
    {
      address: accounts[1],
      private: '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    }
  ]

  it('contracts deployed', async () => {
    instances.IdentityRegistry = await IdentityRegistry.new()
    instances.BurnerProvider = await BurnerProvider.new(instances.IdentityRegistry.address)
    dummyPerpetualProvider = await instances.BurnerProvider.dummyPerpetualResolver.call()
  })

  user = users[0]
  it('Identity burned', async function () {
    const timestamp = Math.round(new Date() / 1000) - 1
    const createPermissionString = web3.utils.soliditySha3(
      '0x19', '0x00', instances.IdentityRegistry.address,
      'I authorize the creation of an Identity on my behalf.',
      ZERO_ADDRESS,
      user.address,
      { t: 'address[]', v: [] },
      { t: 'address[]', v: [dummyPerpetualProvider] },
      timestamp
    )
    const createPermission = await sign(createPermissionString, user.address, user.private)

    user.identity = web3.utils.toBN(1)

    const removePermissionString = web3.utils.soliditySha3(
      '0x19', '0x00', instances.IdentityRegistry.address,
      'I authorize removing this address from my Identity.',
      user.identity, user.address, timestamp
    )
    const removePermission = await sign(removePermissionString, user.address, user.private)

    await instances.BurnerProvider.burnIdentity(
      user.address,
      [createPermission.v, removePermission.v],
      [createPermission.r, removePermission.r],
      [createPermission.s, removePermission.s],
      [timestamp, timestamp]
    )

    await verifyIdentity(user.identity, instances.IdentityRegistry, {
      recoveryAddress:     ZERO_ADDRESS,
      associatedAddresses: [],
      providers:           [],
      resolvers:           [dummyPerpetualProvider]
    })
  })
})
