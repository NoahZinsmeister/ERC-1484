const Web3 = require('web3')
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const { sign, verifyIdentity } = require('../../common.js')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const MetaTransactionsProvider = artifacts.require('./examples/Providers/MetaTransactions/MetaTransactionsProvider.sol')

const instances = {}

var user
contract('Testing ERC1056 Resolver', function (accounts) {
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
    instances.MetaTransactionsProvider = await MetaTransactionsProvider.new(instances.IdentityRegistry.address)
  })

  user = users[0]
  it('Identity created', async function () {
    const timestamp = Math.round(new Date() / 1000) - 1
    const permissionString = web3.utils.soliditySha3(
      '0x19', '0x00', instances.IdentityRegistry.address,
      'I authorize the creation of an Identity on my behalf.',
      user.address, user.address, instances.MetaTransactionsProvider.address, { t: 'address[]', v: [] }, timestamp
    )
    const permission = await sign(permissionString, user.address, user.private)

    await instances.MetaTransactionsProvider.createIdentityDelegated(
      user.address, user.address, [], permission.v, permission.r, permission.s, timestamp
    )
    user.identity = web3.utils.toBN(1)

    await verifyIdentity(user.identity, instances.IdentityRegistry, {
      recoveryAddress:     user.address,
      associatedAddresses: [user.address],
      providers:           [instances.MetaTransactionsProvider.address],
      resolvers:           []
    })
  })

  it('Can call via proxy for self', async function () {
    const methodID = web3.utils.soliditySha3('identityExists(uint256)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`

    await instances.MetaTransactionsProvider.callViaProxy(
      instances.IdentityRegistry.address, data, false, { from: user.address }
    )
  })

  it('Can call via proxy for self via external', async function () {
    const methodID = web3.utils.soliditySha3('identityExists(uint256)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`

    await instances.MetaTransactionsProvider.callViaProxy(
      instances.IdentityRegistry.address, data, true, { from: user.address }
    )
  })

  it('Can call via proxy delegated via external', async function () {
    const methodID = web3.utils.soliditySha3('identityExists(uint256)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`

    const permissionString = web3.utils.soliditySha3(
      '0x19', '0x00', instances.MetaTransactionsProvider.address,
      'I authorize this call.', user.identity, instances.IdentityRegistry.address, data, false, 0
    )
    const permission = await sign(permissionString, user.address, user.private)

    await instances.MetaTransactionsProvider.callViaProxyDelegated(
      user.address, instances.IdentityRegistry.address, data, false,
      permission.v, permission.r, permission.s
    )
  })
})
