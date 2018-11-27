const { sign, verifyIdentity } = require('../../common.js')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const ExternalProxy = artifacts.require('./examples/Providers/MetaTransactions/ExternalProxy.sol')
const MetaTransactionsProvider = artifacts.require('./examples/Providers/MetaTransactions/MetaTransactionsProvider.sol')

const instances = {}

var user
contract('Testing MetaTransactions Provider', function (accounts) {
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
      user.address,
      user.address,
      { t: 'address[]', v: [instances.MetaTransactionsProvider.address] },
      { t: 'address[]', v: [] },
      timestamp
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

  it('Can call via proxy for self -- FAIL call', async function () {
    const methodID = web3.utils.soliditySha3('getEIN(address)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`
    const destination = instances.IdentityRegistry.address

    await instances.MetaTransactionsProvider.callViaProxy(destination, data, false, { from: user.address })
      .then(() => assert.fail('call was successful', 'transaction should fail'))
      .catch(error => assert.include(
        error.message, 'Call was not successful.', 'wrong rejection reason'
      ))
  })

  it('Can call via proxy for self via external', async function () {
    const methodID = web3.utils.soliditySha3('identityExists(uint256)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`
    const destination = instances.IdentityRegistry.address

    await instances.MetaTransactionsProvider.callViaProxy(destination, data, true, { from: user.address })
  })

  it('Can call via proxy delegated via external', async function () {
    const methodID = web3.utils.soliditySha3('identityExists(uint256)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`
    const destination = instances.IdentityRegistry.address

    const permissionString = web3.utils.soliditySha3(
      '0x19', '0x00', instances.MetaTransactionsProvider.address,
      'I authorize this call.', user.identity, destination, data, true, 0
    )
    const permission = await sign(permissionString, user.address, user.private)

    await instances.MetaTransactionsProvider.callViaProxyDelegated(
      user.address, destination, data, true, permission.v, permission.r, permission.s
    )
  })

  it('Can call via proxy delegated via external -- FAIL signature', async function () {
    const methodID = web3.utils.soliditySha3('identityExists(uint256)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`
    const destination = instances.IdentityRegistry.address

    const permissionString = web3.utils.soliditySha3(
      '0x19', '0x00', instances.MetaTransactionsProvider.address,
      'I DO NOT authorize this call.', user.identity, destination, data, false, 0
    )
    const permission = await sign(permissionString, user.address, user.private)

    await instances.MetaTransactionsProvider.callViaProxyDelegated(
      user.address, destination, data, true, permission.v, permission.r, permission.s
    )
      .then(() => assert.fail('call was successful', 'transaction should fail'))
      .catch(error => assert.include(error.message, 'Permission denied.', 'wrong rejection reason'))
  })

  it('Can call via external proxy -- FAIL', async function () {
    const externalProxyAddress = await instances.MetaTransactionsProvider.externalProxyDirectory.call(user.identity)
    instances.ExternalProxy = await ExternalProxy.at(externalProxyAddress)

    const methodID = web3.utils.soliditySha3('identityExists(uint256)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`
    const destination = instances.IdentityRegistry.address

    await instances.ExternalProxy.forwardCall(destination, data)
      .then(() => assert.fail('call was successful', 'transaction should fail'))
      .catch(error => assert.include(
        error.message, 'Caller is not allowed.', 'wrong rejection reason'
      ))
  })

  it('Can call via proxy for self -- FAIL provider', async function () {
    await instances.IdentityRegistry.removeProviders(
      [instances.MetaTransactionsProvider.address], { from: user.address }
    )

    const methodID = web3.utils.soliditySha3('getEIN(address)').substring(0, 10)
    const argument = '0000000000000000000000000000000000000000000000000000000000000045'
    const data = `${methodID}${argument}`
    const destination = instances.IdentityRegistry.address

    await instances.MetaTransactionsProvider.callViaProxy(destination, data, false, { from: user.address })
      .then(() => assert.fail('call was successful', 'transaction should fail'))
      .catch(error => assert.include(
        error.message, 'This Provider is not set for the given EIN.', 'wrong rejection reason'
      ))
  })
})
