const { sign, verifyIdentity, defaultErrorMessage } = require('../common')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const Provider = artifacts.require('./samples/Provider.sol')
const Resolver = artifacts.require('./samples/Resolver.sol')

const privateKeys = [
  '0x2665671af93f210ddb5d5ffa16c77fcf961d52796f2b2d7afd32cc5d886350a8',
  '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff',
  '0xccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
]

// convenience variables
const instances = {}
let accountsPrivate
let identity

contract('Testing Sample Provider and Resolver', function (accounts) {
  accountsPrivate = accounts.map((account, i) => { return { address: account, private: privateKeys[i] } })

  identity = {
    recoveryAddress:     accountsPrivate[0],
    associatedAddresses: accountsPrivate.slice(1, 3)
  }

  describe('Deploying Contracts', function () {
    it('IdentityRegistry contract deployed', async function () {
      instances.IdentityRegistry = await IdentityRegistry.new()
    })

    it('Provider contract deployed', async function () {
      instances.Provider = await Provider.new(instances.IdentityRegistry.address)
    })

    it('Resolver contract deployed', async function () {
      instances.Resolver = await Resolver.new(instances.IdentityRegistry.address)
      identity.resolver = instances.Resolver.address
    })
  })

  describe('Testing Provider', function () {
    it('Identity can be created', async function () {
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        identity.recoveryAddress.address,
        identity.associatedAddresses[0].address,
        { t: 'address[]', v: [instances.Provider.address] },
        { t: 'address[]', v: [identity.resolver] },
        timestamp
      )
      const permission = await sign(
        permissionString, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
      )
      await instances.Provider.createIdentityDelegated(
        identity.recoveryAddress.address, identity.associatedAddresses[0].address, [identity.resolver],
        permission.v, permission.r, permission.s, timestamp
      )
      identity.identity = web3.utils.toBN(1)

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address).slice(0, 1),
        providers:           [instances.Provider.address],
        resolvers:           [identity.resolver]
      })
    })

    it('provider can add other addresses', async function () {
      const address = identity.associatedAddresses[1]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionStringApproving = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize adding this address to my Identity.',
        identity.identity,
        address.address,
        timestamp
      )

      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize being added to this Identity.',
        identity.identity,
        address.address,
        timestamp
      )

      const permissionApproving = await sign(
        permissionStringApproving, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
      )
      const permission = await sign(permissionString, address.address, address.private)

      await instances.Provider.addAssociatedAddressDelegated(
        identity.associatedAddresses[0].address, address.address,
        [permissionApproving.v, permission.v],
        [permissionApproving.r, permission.r],
        [permissionApproving.s, permission.s],
        [timestamp, timestamp]
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(associatedAddress => associatedAddress.address),
        providers:           [instances.Provider.address],
        resolvers:           [identity.resolver]
      })
    })

    it('provider can remove addresses', async function () {
      const address = identity.associatedAddresses[1]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize removing this address from my Identity.',
        identity.identity,
        address.address,
        timestamp
      )

      const permission = await sign(permissionString, address.address, address.private)

      await instances.Provider.removeAssociatedAddressDelegated(
        address.address, permission.v, permission.r, permission.s, timestamp
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address).slice(0, 1),
        providers:           [instances.Provider.address],
        resolvers:           [identity.resolver]
      })
    })

    it('can add a provider', async function () {
      await instances.Provider.addProvidersFor(
        accounts.slice(-1), { from: identity.associatedAddresses[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address).slice(0, 1),
        providers:           [instances.Provider.address].concat(accounts.slice(-1)),
        resolvers:           [identity.resolver]
      })
    })

    it('identity can remove a provider', async function () {
      await instances.Provider.removeProvidersFor(
        accounts.slice(-1), { from: identity.associatedAddresses[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address).slice(0, 1),
        providers:           [instances.Provider.address],
        resolvers:           [identity.resolver]
      })
    })

    it('provider can remove resolvers', async function () {
      await instances.Provider.removeResolversFor(
        [identity.resolver],
        { from: identity.associatedAddresses[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address).slice(0, 1),
        providers:           [instances.Provider.address],
        resolvers:           []
      })
    })

    it('provider can trigger recovery address change', async function () {
      await instances.Provider.triggerRecoveryAddressChangeFor(
        accounts.slice(-1)[0],
        { from: identity.associatedAddresses[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     accounts.slice(-1)[0],
        associatedAddresses: identity.associatedAddresses.map(address => address.address).slice(0, 1),
        providers:           [instances.Provider.address],
        resolvers:           []
      })
    })
  })

  describe('Testing Resolver', function () {
    it('resolver cannot be used when not set', async function () {
      await instances.Resolver.setEmailAddress('test@test.test', { from: identity.associatedAddresses[0].address })
        .then(() => assert.fail('email address was set', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'The calling identity does not have this resolver set.', 'wrong rejection reason'
        ))

      const emailAddress = await instances.Resolver.getEmail(identity.identity)
      assert.equal(emailAddress, '', 'Unexpected email address.')
    })

    it('once added, email address can be set and read', async function () {
      await instances.Provider.addResolversFor(
        [identity.resolver],
        { from: identity.associatedAddresses[0].address }
      )

      await instances.Resolver.setEmailAddress('test@test.test', { from: identity.associatedAddresses[0].address })

      const emailAddress = await instances.Resolver.getEmail(identity.identity)
      assert.equal(emailAddress, 'test@test.test', 'Unexpected email address.')
    })

    it('cannot access email addresses for non-existent EINs', async function () {
      await instances.Resolver.getEmail(100)
        .then(() => assert.fail('email address was read', 'transaction should fail'))
        .catch(error => {
          if (error.message !== defaultErrorMessage) {
            assert.include(
              error.message, 'The referenced identity does not exist.', 'wrong rejection reason'
            )
          }
        })
    })
  })
})
