const Web3 = require('web3')
const web3 = new Web3(Web3.givenProvider)

const { sign, verifyIdentity, timeTravel } = require('./common')

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')

const privateKeys = [
  '0x2665671af93f210ddb5d5ffa16c77fcf961d52796f2b2d7afd32cc5d886350a8',
  '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff',
  '0xccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954',
  '0xfdf12368f9e0735dc01da9db58b1387236120359024024a31e611e82c8853d7f',
  '0x44e02845db8861094c519d72d08acb7435c37c57e64ec5860fb15c5f626cb77c',
  '0x12093c3cd8e0c6ceb7b1b397724cd82c4d84f81263f56a44f11d8bd3a61ffccb',
  '0xf65450adda73b32e056ed24246d8d370e49fc88b427f96f37bbf23f6b132b93b',
  '0x34a1f9ed996709f629d712d5b267d23f37be82bf8003a023264f71005f6486e6',
  '0x1711e5c516428d875c14dac234f36bbf3b4622aeac00566483a8087ed5a97297',
  '0xce5e2ea9c47caba88b3421d75023bd8c359e2aaf897e519a10a256d931028ca1'
]

// convenience variables
const instances = {}
let accountsPrivate
let identity
let oldAssociatedAddresses
let newRecoveryAddress

contract('Testing Identity', function (accounts) {
  accountsPrivate = accounts.map((account, i) => { return { address: account, privateKey: privateKeys[i] } })

  identity = {
    recoveryAddress:     accountsPrivate[0],
    associatedAddresses: accountsPrivate.slice(1, 4),
    providers:           accountsPrivate.slice(4, 5),
    resolvers:           []
  }

  describe('Deploying Contracts', function () {
    it('IdentityRegistry contract deployed', async function () {
      instances.IdentityRegistry = await IdentityRegistry.new()
    })
  })

  describe('Testing Identity Registry', function () {
    it('Signatures verify correctly', async function () {
      let messageHash = web3.utils.soliditySha3('shh')
      for (const account of accountsPrivate) {
        for (const method of ['prefixed', 'unprefixed']) {
          const signature = await sign(messageHash, account.address, account.privateKey, method)
          const isSigned = await instances.IdentityRegistry.isSigned(
            account.address, messageHash, signature.v, signature.r, signature.s
          )
          assert.isTrue(isSigned, 'Signature could not be verified.')
        }
      }
    })

    it('Identity can be minted', async function () {
      // test user minting
      const mintedIdentity = await instances.IdentityRegistry.mintIdentity.call(
        identity.recoveryAddress.address, identity.providers[0].address, [],
        { from: identity.associatedAddresses[0].address }
      )
      assert.isTrue(mintedIdentity.eq(web3.utils.toBN(1)), 'Unexpected identity token user')

      // test delegated minting
      const permissionString = web3.utils.soliditySha3(
        'Mint',
        instances.IdentityRegistry.address,
        identity.recoveryAddress.address,
        identity.associatedAddresses[0].address,
        identity.providers[0].address,
        { t: 'address[]', v: [] }
      )
      const permission = await sign(
        permissionString, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
      )
      const mintedIdentityDelegated = await instances.IdentityRegistry.mintIdentityDelegated.call(
        identity.recoveryAddress.address, identity.associatedAddresses[0].address, [],
        permission.v, permission.r, permission.s,
        { from: identity.providers[0].address }
      )
      assert.isTrue(mintedIdentityDelegated.eq(web3.utils.toBN(1)), 'Unexpected identity token delegated')
    })

    it('Identity minted', async function () {
      await instances.IdentityRegistry.mintIdentity(
        identity.recoveryAddress.address, identity.providers[0].address, [],
        { from: identity.associatedAddresses[0].address }
      )

      identity.identity = web3.utils.toBN(1)

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address).slice(0, 1),
        providers:           identity.providers.map(provider => provider.address),
        resolvers:           []
      })
    })

    it('provider can add other addresses', async function () {
      for (const address of [identity.associatedAddresses[1], identity.associatedAddresses[2], accountsPrivate[5]]) {
        const salt = Math.round(new Date() / 1000)
        const permissionString = web3.utils.soliditySha3(
          'Add Address',
          instances.IdentityRegistry.address,
          identity.identity,
          address.address,
          salt
        )

        const permissionApproving = await sign(
          permissionString, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
        )
        const permission = await sign(
          permissionString, address.address, address.private
        )

        await instances.IdentityRegistry.addAddress(
          identity.identity, address.address, identity.associatedAddresses[0].address,
          [permissionApproving.v, permission.v],
          [permissionApproving.r, permission.r],
          [permissionApproving.s, permission.s],
          salt,
          { from: identity.providers[0].address }
        )

        let associatedAddresses
        if (address.address === identity.associatedAddresses[1].address) {
          associatedAddresses = identity.associatedAddresses.map(address => address.address).slice(0, 2)
        } else if (address.address === identity.associatedAddresses[2].address) {
          associatedAddresses = identity.associatedAddresses.map(address => address.address).slice(0, 3)
        } else {
          associatedAddresses = identity.associatedAddresses.map(address => address.address).slice(0, 3)
            .concat(address.address)
        }

        await verifyIdentity(identity.identity, instances.IdentityRegistry, {
          recoveryAddress:     identity.recoveryAddress.address,
          associatedAddresses: associatedAddresses,
          providers:           identity.providers.map(provider => provider.address),
          resolvers:           []
        })
      }
    })

    it('provider can remove addresses', async function () {
      const address = accountsPrivate[5]
      const salt = Math.round(new Date() / 1000)
      const permissionString = web3.utils.soliditySha3(
        'Remove Address',
        instances.IdentityRegistry.address,
        identity.identity,
        address.address,
        salt
      )

      const permission = await sign(
        permissionString, address.address, address.private
      )

      await instances.IdentityRegistry.removeAddress(
        identity.identity, address.address, permission.v, permission.r, permission.s, salt,
        { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address),
        providers:           identity.providers.map(provider => provider.address),
        resolvers:           []
      })
    })

    it('identity can add a provider', async function () {
      const provider = accountsPrivate[6]

      await Promise.all(identity.associatedAddresses.map(({ address }) => {
        return instances.IdentityRegistry.addProviders.call(
          [provider.address],
          { from: address }
        )
      }))

      const salt = Math.round(new Date() / 1000)
      const permissionString = web3.utils.soliditySha3(
        'Add Providers',
        instances.IdentityRegistry.address,
        identity.identity,
        { t: 'address[]', v: [provider.address] },
        salt
      )
      const permission = await sign(
        permissionString, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
      )

      await instances.IdentityRegistry.addProviders(
        identity.identity, [provider.address], identity.associatedAddresses[0].address,
        permission.v, permission.r, permission.s, salt,
        { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address),
        providers:           identity.providers.map(provider => provider.address).concat(provider.address),
        resolvers:           []
      })
    })

    it('identity can remove a provider', async function () {
      const provider = accountsPrivate[6]

      await Promise.all(identity.associatedAddresses.map(({ address }) => {
        return instances.IdentityRegistry.removeProviders.call(
          [provider.address],
          { from: address }
        )
      }))

      const salt = Math.round(new Date() / 1000)
      const permissionString = web3.utils.soliditySha3(
        'Remove Providers',
        instances.IdentityRegistry.address,
        identity.identity,
        { t: 'address[]', v: [provider.address] },
        salt
      )
      const permission = await sign(
        permissionString, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
      )

      await instances.IdentityRegistry.removeProviders(
        identity.identity, [provider.address], identity.associatedAddresses[0].address,
        permission.v, permission.r, permission.s, salt,
        { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress: identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address),
        providers: identity.providers.map(provider => provider.address),
        resolvers: []
      })
    })

    it('provider can add resolvers', async function () {
      const resolver = accountsPrivate[7]

      await instances.IdentityRegistry.addResolvers(
        identity.identity,
        [resolver.address],
        { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress: identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address),
        providers: identity.providers.map(provider => provider.address),
        resolvers: [resolver.address]
      })
    })

    it('provider can remove resolvers', async function () {
      const resolver = accountsPrivate[7]

      await instances.IdentityRegistry.removeResolvers(
        identity.identity,
        [resolver.address],
        { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress: identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address),
        providers: identity.providers.map(provider => provider.address),
        resolvers: []
      })
    })
  })

  describe('Testing Recovery Process', function () {
    it('Can initiate change in recovery address', async function () {
      newRecoveryAddress = accountsPrivate[8]

      await instances.IdentityRegistry.initiateRecoveryAddressChange(
        identity.identity, newRecoveryAddress.address, { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     newRecoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(associatedAddress => associatedAddress.address),
        providers:           identity.providers.map(provider => provider.address),
        resolvers:           []
      })
    })

    let newAssociatedAddress
    let newAssociatedAddressPermission
    it('New recovery address cannot trigger recovery', async function () {
      newAssociatedAddress = accountsPrivate[9]
      const permissionString = web3.utils.soliditySha3(
        'Recover', instances.IdentityRegistry.address, identity.identity, newAssociatedAddress.address
      )
      newAssociatedAddressPermission = await sign(
        permissionString, newAssociatedAddress.address, newAssociatedAddress.private
      )

      await instances.IdentityRegistry.triggerRecovery(
        identity.identity, newAssociatedAddress.address,
        newAssociatedAddressPermission.v, newAssociatedAddressPermission.r, newAssociatedAddressPermission.s,
        { from: newRecoveryAddress.address }
      )
        .then(() => assert.fail('new recovery address triggered recovery', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Only the recently removed recovery address can initiate a recovery.', 'wrong rejection reason'
        ))
    })

    it('Cannot initiate another change in recovery address yet', async function () {
      await instances.IdentityRegistry.initiateRecoveryAddressChange(
        identity.identity, identity.recoveryAddress.address, { from: identity.providers[0].address }
      )
        .then(() => assert.fail('able to change recovery address', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Pending change of recovery address has not timed out.', 'wrong rejection reason'
        ))
    })

    it('After 2 weeks, old recovery address cannot trigger recovery', async function () {
      await timeTravel(60 * 60 * 24 * 14 + 1)
      await instances.IdentityRegistry.triggerRecovery(
        identity.identity, newAssociatedAddress.address,
        newAssociatedAddressPermission.v, newAssociatedAddressPermission.r, newAssociatedAddressPermission.s,
        { from: identity.recoveryAddress.address }
      )
        .then(() => assert.fail('old recovery address triggered recovery', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Only the current recovery address can initiate a recovery.', 'wrong rejection reason'
        ))
    })

    it('Can initiate another change in recovery address', async function () {
      await instances.IdentityRegistry.initiateRecoveryAddressChange(
        identity.identity, identity.recoveryAddress.address, { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(associatedAddress => associatedAddress.address),
        providers:           identity.providers.map(provider => provider.address),
        resolvers:           []
      })
    })

    it('Recently removed recovery address can trigger recovery', async function () {
      instances.IdentityRegistry
        .RecoveryTriggered()
        .once('data', event => {
          oldAssociatedAddresses = event.returnValues.oldAssociatedAddresses
        })

      await instances.IdentityRegistry.triggerRecovery(
        identity.identity, newAssociatedAddress.address,
        newAssociatedAddressPermission.v, newAssociatedAddressPermission.r, newAssociatedAddressPermission.s,
        { from: newRecoveryAddress.address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     newRecoveryAddress.address,
        associatedAddresses: [newAssociatedAddress.address],
        providers:           [],
        resolvers:           []
      })
    })
  })

  describe('Testing Poison Pill', function () {
    it('Any of the recently removed address can trigger poison pill', async function () {
      await Promise.all(oldAssociatedAddresses.map(address => {
        const indexOf = oldAssociatedAddresses.indexOf(address)

        const firstChunk = oldAssociatedAddresses.slice(0, indexOf)
        const lastChunk = oldAssociatedAddresses.slice(indexOf + 1)

        return instances.IdentityRegistry.triggerPoisonPill.call(
          identity.identity, firstChunk, lastChunk, true, { from: address }
        )
      }))
    })

    it('Triggering poison pill on an identity works as expected', async function () {
      const indexOf = oldAssociatedAddresses.indexOf(identity.associatedAddresses[1].address)

      const firstChunk = oldAssociatedAddresses.slice(0, indexOf)
      const lastChunk = oldAssociatedAddresses.slice(indexOf + 1)

      await instances.IdentityRegistry.triggerPoisonPill(
        identity.identity, firstChunk, lastChunk, true, { from: identity.associatedAddresses[1].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     newRecoveryAddress.address,
        associatedAddresses: [],
        providers:           [],
        resolvers:           []
      })
    })
  })
})
