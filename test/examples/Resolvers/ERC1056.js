const { sign, verifyIdentity } = require('../../common.js')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const EthereumDIDRegistry = artifacts.require('./_testing/examples/Resolvers/ERC1056/EthereumDIDRegistry.sol')
const ERC1056 = artifacts.require('./examples/Resolvers/ERC1056/ERC1056.sol')

const instances = {}

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
    instances.EthereumDIDRegistry = await EthereumDIDRegistry.new()
    instances.ERC1056 = await ERC1056.new(instances.IdentityRegistry.address, instances.EthereumDIDRegistry.address)
  })

  describe('Create Identity', async () => {
    it('Identity created', async function () {
      const user = users[0]

      await instances.IdentityRegistry.createIdentity(
        user.address, [user.address], [instances.ERC1056.address], { from: user.address }
      )

      user.identity = web3.utils.toBN(1)

      await verifyIdentity(user.identity, instances.IdentityRegistry, {
        recoveryAddress:     user.address,
        associatedAddresses: [user.address],
        providers:           [user.address],
        resolvers:           [instances.ERC1056.address]
      })
    })
  })

  describe('initialize', async () => {
    const user = users[0]
    const delegate = users[1]
    const randomBytes = web3.utils.soliditySha3('random')
    const name = web3.utils.soliditySha3('name')
    const value = '0x01'

    it('change owner -- FAIL', async function () {
      await instances.ERC1056.changeOwner(user.address, { from: user.address })
        .then(() => assert.fail('able to change owner', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'This EIN has not been initialized', 'wrong rejection reason'))
    })

    it('add delegate -- FAIL', async function () {
      await instances.ERC1056.addDelegate(randomBytes, delegate.address, 10000, { from: user.address })
        .then(() => assert.fail('able to change owner', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'This EIN has not been initialized', 'wrong rejection reason'))
    })

    it('remove delegate -- FAIL', async function () {
      await instances.ERC1056.revokeDelegate(randomBytes, delegate.address, { from: user.address })
        .then(() => assert.fail('able to change owner', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'This EIN has not been initialized', 'wrong rejection reason'))
    })

    it('add attribute -- FAIL', async function () {
      await instances.ERC1056.setAttribute(name, value, 10000, { from: user.address })
        .then(() => assert.fail('able to change owner', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'This EIN has not been initialized', 'wrong rejection reason'))
    })

    it('remove attribute -- FAIL', async function () {
      await instances.ERC1056.revokeAttribute(name, value, { from: user.address })
        .then(() => assert.fail('able to change owner', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'This EIN has not been initialized', 'wrong rejection reason'))
    })

    it('1056 owner changed', async function () {
      const user = users[0]

      const initializePermission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.EthereumDIDRegistry.address,
        0, user.address, 'changeOwner', instances.ERC1056.address
      )

      const permission = await sign(initializePermission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.initialize(user.address, permission.v, permission.r, permission.s, { from: user.address })
    })
  })

  describe('initialize FAIL', async () => {
    it('already initialized', async function () {
      const user = users[0]

      const initializePermission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.EthereumDIDRegistry.address,
        0, user.address, 'changeOwner', instances.ERC1056.address
      )

      const permission = await sign(initializePermission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.initialize(user.address, permission.v, permission.r, permission.s, { from: user.address })
        .then(() => assert.fail('able to initialize', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'This EIN has already been initialized', 'wrong rejection reason'
        ))
    })
  })

  describe('change owner', async () => {
    const user = users[0]

    it('change owner', async function () {
      await instances.ERC1056.changeOwner(instances.ERC1056.address, { from: user.address })
    })

    it('change owner signed', async function () {
      let nonce = await instances.ERC1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'changeOwnerDelegated', instances.ERC1056.address, nonce
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.changeOwnerDelegated(
        user.address, instances.ERC1056.address, signature.v, signature.r, signature.s, { from: user.address }
      )
    })

    it('change owner signed FAIL', async function () {
      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'changeOwnerDelegated', instances.ERC1056.address, 10000
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.changeOwnerDelegated(
        user.address, instances.ERC1056.address, signature.v, signature.r, signature.s, { from: user.address }
      )
        .then(() => assert.fail('able to initialize', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Function execution is incorrectly signed.', 'wrong rejection reason'
        ))
    })
  })

  describe('delegates normal', async () => {
    const user = users[0]
    const delegate = users[1]
    const randomBytes = web3.utils.soliditySha3('random')

    it('add delegate', async function () {
      await instances.ERC1056.addDelegate(randomBytes, delegate.address, 10000, { from: user.address })
    })

    it('remove delegate', async function () {
      await instances.ERC1056.revokeDelegate(randomBytes, delegate.address, { from: user.address })
    })
  })

  describe('delegates signed', async () => {
    const user = users[0]
    const delegate = users[1]
    const randomBytes = web3.utils.soliditySha3('random')

    it('add delegate signed', async function () {
      let nonce = await instances.ERC1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'addDelegateDelegated',
        { t: 'bytes32', v: randomBytes }, delegate.address, 100000, nonce
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.addDelegateDelegated(
        user.address, randomBytes, delegate.address, 100000, signature.v, signature.r, signature.s,
        { from: user.address }
      )
    })

    it('add delegate signed FAIL', async function () {
      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'addDelegateDelegated', { t: 'bytes32', v: randomBytes }, delegate.address, 100000, 10000
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.addDelegateDelegated(
        user.address, randomBytes, delegate.address, 100000, signature.v, signature.r, signature.s,
        { from: user.address }
      )
        .then(() => assert.fail('able to initialize', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Function execution is incorrectly signed.', 'wrong rejection reason'
        ))
    })

    it('revoke delegate signed', async function () {
      let nonce = await instances.ERC1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'revokeDelegateDelegated',
        { t: 'bytes32', v: randomBytes },
        delegate.address,
        nonce
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.revokeDelegateDelegated(
        user.address, randomBytes, delegate.address, signature.v, signature.r, signature.s, { from: user.address }
      )

      nonce = await instances.ERC1056.actionNonce(user.identity)

      assert.equal(nonce.valueOf(), 3)
    })

    it('revoke delegate signed FAIL', async function () {
      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'revokeDelegateDelegated', { t: 'bytes32', v: randomBytes }, delegate.address, 10000
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.revokeDelegateDelegated(
        user.address, randomBytes, delegate.address, signature.v, signature.r, signature.s, { from: user.address }
      )
        .then(() => assert.fail('able to initialize', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Function execution is incorrectly signed.', 'wrong rejection reason'
        ))
    })
  })

  describe('attributes normal', async () => {
    const user = users[0]
    const name = web3.utils.soliditySha3('name')
    const value = '0x01'

    it('add attribute', async function () {
      await instances.ERC1056.setAttribute(name, value, 10000, { from: user.address })
    })

    it('remove attribute', async function () {
      await instances.ERC1056.revokeAttribute(name, value, { from: user.address })
    })
  })

  describe('attributes signed', async () => {
    const user = users[0]
    const name = web3.utils.soliditySha3('name')
    const value = '0x01'

    it('set attribute signed', async function () {
      let nonce = await instances.ERC1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'setAttributeDelegated', { t: 'bytes32', v: name }, { t: 'bytes', v: value }, 100000, nonce
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.setAttributeDelegated(
        user.address, name, value, 100000, signature.v, signature.r, signature.s, { from: user.address }
      )
    })

    it('set attribute signed FAIL', async function () {
      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'setAttributeDelegated', { t: 'bytes32', v: name }, { t: 'bytes', v: value }, 100000, 100000
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.setAttributeDelegated(
        user.address, name, value, 100000, signature.v, signature.r, signature.s, { from: user.address }
      )
        .then(() => assert.fail('able to initialize', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Function execution is incorrectly signed.', 'wrong rejection reason'
        ))
    })

    it('revoke attribute signed', async function () {
      let nonce = await instances.ERC1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'revokeAttributeDelegated', { t: 'bytes32', v: name }, { t: 'bytes', v: value }, nonce
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.revokeAttributeDelegated(
        user.address, name, value, signature.v, signature.r, signature.s, { from: user.address }
      )

      nonce = await instances.ERC1056.actionNonce(user.identity)

      assert.equal(nonce.valueOf(), 5)
    })

    it('revoke attribute signed FAIL', async function () {
      const permission = web3.utils.soliditySha3(
        '0x19', '0x00', instances.ERC1056.address,
        'revokeAttributeDelegated', { t: 'bytes32', v: name }, { t: 'bytes', v: value }, 10000
      )

      const signature = await sign(permission, user.address, user.private, 'unprefixed')

      await instances.ERC1056.revokeAttributeDelegated(
        user.address, name, value, signature.v, signature.r, signature.s, { from: user.address }
      )
        .then(() => assert.fail('able to initialize', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Function execution is incorrectly signed.', 'wrong rejection reason'
        ))
    })
  })
})
