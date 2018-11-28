const { sign, verifyIdentity, timeTravel, defaultErrorMessage } = require('./common')
const { getAddress, getSignature } = require('./signatures.js')
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
  accountsPrivate = accounts.map((account, i) => { return { address: account, private: privateKeys[i] } })

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

  // The modifiers are hit and pass many times in the future
  describe('Modifier FAIL Tests', function () {
    it('_hasIdentity FAIL', async function () {
      await instances.IdentityRegistry.getEIN(accountsPrivate[0].address)
        .then(() => assert.fail('got an EIN', 'transaction should fail'))
        .catch(error => {
          if (error.message !== defaultErrorMessage) {
            assert.include(
              error.message, 'The passed address does not have an identity but should.', 'wrong rejection reason'
            )
          }
        })
    })

    it('_identityExists FAIL', async function () {
      await instances.IdentityRegistry.getIdentity(1337)
        .then(() => assert.fail('got an Identity', 'transaction should fail'))
        .catch(error => {
          if (error.message !== defaultErrorMessage) {
            assert.include(
              error.message, 'The identity does not exist.', 'wrong rejection reason'
            )
          }
        })
    })
  })

  describe('Testing Identity Registry', function () {
    it('Signatures verify correctly', async function () {
      let messageHash = web3.utils.soliditySha3('shh')
      for (const account of accountsPrivate) {
        for (const method of ['prefixed', 'unprefixed']) {
          const signature = await sign(messageHash, account.address, account.private, method)
          const isSigned = await instances.IdentityRegistry.isSigned(
            account.address, messageHash, signature.v, signature.r, signature.s
          )
          assert.isTrue(isSigned, 'Signature could not be verified.')
        }
      }
    })

    it('Identity can be created', async function () {
      // test user creation
      const createdIdentity = await instances.IdentityRegistry.createIdentity.call(
        identity.recoveryAddress.address, [identity.providers[0].address], [], [],
        { from: identity.associatedAddresses[0].address }
      )
      assert.isTrue(createdIdentity.eq(web3.utils.toBN(1)), 'Unexpected identity token user')

      // test delegated creation
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        identity.recoveryAddress.address,
        identity.associatedAddresses[0].address,
        { t: 'address[]', v: [identity.providers[0].address] },
        { t: 'address[]', v: [] },
        timestamp
      )
      const permission = await sign(
        permissionString, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
      )
      const createdIdentityDelegated = await instances.IdentityRegistry.createIdentityDelegated.call(
        identity.recoveryAddress.address, identity.associatedAddresses[0].address, [identity.providers[0].address], [],
        permission.v, permission.r, permission.s, timestamp,
        { from: identity.providers[0].address }
      )
      assert.isTrue(createdIdentityDelegated.eq(web3.utils.toBN(1)), 'Unexpected identity token delegated')
    })

    it('Identity can be created FAIL -- timestamp', async function () {
      // test delegated creation
      const timestamp = Math.round(new Date() / 1000) + 1000
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        identity.recoveryAddress.address,
        identity.associatedAddresses[0].address,
        { t: 'address[]', v: [identity.providers[0].address] },
        { t: 'address[]', v: [] },
        timestamp
      )
      const permission = await sign(
        permissionString, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
      )
      await instances.IdentityRegistry.createIdentityDelegated.call(
        identity.recoveryAddress.address, identity.associatedAddresses[0].address, [identity.providers[0].address], [],
        permission.v, permission.r, permission.s, timestamp,
        { from: identity.providers[0].address }
      )
        .then(() => assert.fail('able to mint', 'transaction should fail'))
        .catch(error => {
          if (error.message !== defaultErrorMessage) {
            assert.include(
              error.message, 'Timestamp is not valid.', 'wrong rejection reason'
            )
          }
        })
    })

    it('Identity can be created FAIL -- signature', async function () {
      // test delegated creation
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'Hydro rules!!!',
        identity.recoveryAddress.address,
        identity.associatedAddresses[0].address,
        identity.providers[0].address,
        { t: 'address[]', v: [] },
        timestamp
      )
      const permission = await sign(
        permissionString, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
      )
      await instances.IdentityRegistry.createIdentityDelegated.call(
        identity.recoveryAddress.address, identity.associatedAddresses[0].address, [identity.providers[0].address], [],
        permission.v, permission.r, permission.s, timestamp,
        { from: identity.providers[0].address }
      )
        .then(() => assert.fail('able to mint', 'transaction should fail'))
        .catch(error => {
          if (error.message !== defaultErrorMessage) {
            assert.include(
              error.message, 'Permission denied.', 'wrong rejection reason'
            )
          }
        })
    })

    it('Identity created', async function () {
      await instances.IdentityRegistry.createIdentity(
        identity.recoveryAddress.address, [identity.providers[0].address], [],
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

    it('Identity created FAIL -- has an address', async function () {
      await instances.IdentityRegistry.createIdentity(
        identity.recoveryAddress.address, [identity.providers[0].address], [],
        { from: identity.associatedAddresses[0].address }
      )
        .then(() => assert.fail('got an EIN', 'transaction should fail'))
        .catch(error => {
          if (error.message !== defaultErrorMessage) {
            assert.include(
              error.message, 'The passed address has an identity but should not.', 'wrong rejection reason'
            )
          }
        })
    })

    it('provider can add other addresses FAIL -- approving signature', async function () {
      for (const address of [identity.associatedAddresses[1], identity.associatedAddresses[2], accountsPrivate[5]]) {
        const timestamp = Math.round(new Date() / 1000) - 1
        const permissionStringApproving = web3.utils.soliditySha3(
          '0x19', '0x00', instances.IdentityRegistry.address,
          'Hydro rules!!!',
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

        await instances.IdentityRegistry.addAssociatedAddressDelegated(
          identity.associatedAddresses[0].address, address.address,
          [permissionApproving.v, permission.v],
          [permissionApproving.r, permission.r],
          [permissionApproving.s, permission.s],
          [timestamp, timestamp],
          { from: identity.providers[0].address }
        )
          .then(() => assert.fail('able to set address', 'transaction should fail'))
          .catch(error => assert.include(
            error.message, 'Permission denied from approving address.', 'wrong rejection reason'
          ))
      }
    })

    it('provider can add other addresses FAIL -- adding signature', async function () {
      for (const address of [identity.associatedAddresses[1], identity.associatedAddresses[2], accountsPrivate[5]]) {
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
          'Hydro rules!!!',
          identity.identity,
          address.address,
          timestamp
        )

        const permissionApproving = await sign(
          permissionStringApproving, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
        )
        const permission = await sign(permissionString, address.address, address.private)

        await instances.IdentityRegistry.addAssociatedAddressDelegated(
          identity.associatedAddresses[0].address, address.address,
          [permissionApproving.v, permission.v],
          [permissionApproving.r, permission.r],
          [permissionApproving.s, permission.s],
          [timestamp, timestamp],
          { from: identity.providers[0].address }
        )
          .then(() => assert.fail('able to set address', 'transaction should fail'))
          .catch(error => assert.include(
            error.message, 'Permission denied from address to add.', 'wrong rejection reason'
          ))
      }
    })

    let maxAddresses
    it('provider can add other addresses -- FAIL too many', async function () {
      maxAddresses = await instances.IdentityRegistry.maxAssociatedAddresses.call()
      for (let i = 0; i < maxAddresses; i++) {
        const timestamp = Math.round(new Date() / 1000) - 1
        const permissionStringApproving = web3.utils.soliditySha3(
          '0x19', '0x00', instances.IdentityRegistry.address,
          'I authorize adding this address to my Identity.',
          identity.identity, getAddress(i), timestamp
        )

        const permissionString = web3.utils.soliditySha3(
          '0x19', '0x00', instances.IdentityRegistry.address,
          'I authorize being added to this Identity.',
          identity.identity, getAddress(i), timestamp
        )

        const permissionApproving = await sign(
          permissionStringApproving, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
        )
        const permission = await getSignature(permissionString, i)

        if (i !== maxAddresses - 1) {
          await instances.IdentityRegistry.addAssociatedAddressDelegated(
            identity.associatedAddresses[0].address, getAddress(i),
            [permissionApproving.v, permission.v],
            [permissionApproving.r, permission.r],
            [permissionApproving.s, permission.s],
            [timestamp, timestamp],
            { from: identity.providers[0].address }
          )
        } else {
          await instances.IdentityRegistry.addAssociatedAddressDelegated(
            identity.associatedAddresses[0].address, getAddress(i),
            [permissionApproving.v, permission.v],
            [permissionApproving.r, permission.r],
            [permissionApproving.s, permission.s],
            [timestamp, timestamp],
            { from: identity.providers[0].address }
          )
            .then(() => assert.fail('able to set address', 'transaction should fail'))
            .catch(error => assert.include(
              error.message, 'Too many addresses.', 'wrong rejection reason'
            ))
        }
      }
    })

    it('estimating destruction cost', async function () {
      const newAssociatedAddress = accountsPrivate[9]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize being added to this Identity via recovery.',
        identity.identity, newAssociatedAddress.address, timestamp
      )
      const newAssociatedAddressPermission = await sign(
        permissionString, newAssociatedAddress.address, newAssociatedAddress.private
      )

      const triggerRecoveryCost = await instances.IdentityRegistry.triggerRecovery.estimateGas(
        identity.identity, newAssociatedAddress.address,
        newAssociatedAddressPermission.v, newAssociatedAddressPermission.r,
        newAssociatedAddressPermission.s, timestamp,
        { from: identity.recoveryAddress.address }
      )

      assert.isBelow(triggerRecoveryCost, 2000000, 'Triggering Recovery is too expensive.')
    })

    it('provider can add other addresses -- FAIL too many cleaning up', async function () {
      const maxAddresses = await instances.IdentityRegistry.maxAssociatedAddresses.call()
      for (let i = 0; i < maxAddresses - 1; i++) {
        const timestamp = Math.round(new Date() / 1000) - 1
        const permissionString = web3.utils.soliditySha3(
          '0x19', '0x00', instances.IdentityRegistry.address,
          'I authorize removing this address from my Identity.',
          identity.identity, getAddress(i), timestamp
        )

        const permission = await getSignature(permissionString, i)

        await instances.IdentityRegistry.removeAssociatedAddressDelegated(
          getAddress(i), permission.v, permission.r, permission.s, timestamp,
          { from: identity.providers[0].address }
        )
      }
    })

    it('self could add other addresses', async function () {
      for (const address of [identity.associatedAddresses[1], identity.associatedAddresses[2], accountsPrivate[5]]) {
        const timestamp = Math.round(new Date() / 1000) - 1
        const permissionStringApproving = web3.utils.soliditySha3(
          '0x19', '0x00', instances.IdentityRegistry.address,
          'I authorize adding this address to my Identity.',
          identity.identity, address.address, timestamp
        )

        const permissionString = web3.utils.soliditySha3(
          '0x19', '0x00', instances.IdentityRegistry.address,
          'I authorize being added to this Identity.',
          identity.identity, address.address, timestamp
        )

        const permissionApproving = await sign(
          permissionStringApproving, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
        )
        const permission = await sign(permissionString, address.address, address.private)

        await instances.IdentityRegistry.addAssociatedAddress.call(
          identity.associatedAddresses[0].address, address.address,
          permission.v,
          permission.r,
          permission.s,
          timestamp,
          { from: identity.associatedAddresses[0].address }
        )

        await instances.IdentityRegistry.addAssociatedAddress.call(
          identity.associatedAddresses[0].address, address.address,
          permissionApproving.v,
          permissionApproving.r,
          permissionApproving.s,
          timestamp,
          { from: address.address }
        )
      }
    })

    it('provider can add other addresses', async function () {
      for (const address of [identity.associatedAddresses[1], identity.associatedAddresses[2], accountsPrivate[5]]) {
        const timestamp = Math.round(new Date() / 1000) - 1
        const permissionStringApproving = web3.utils.soliditySha3(
          '0x19', '0x00', instances.IdentityRegistry.address,
          'I authorize adding this address to my Identity.',
          identity.identity, address.address, timestamp
        )

        const permissionString = web3.utils.soliditySha3(
          '0x19', '0x00', instances.IdentityRegistry.address,
          'I authorize being added to this Identity.',
          identity.identity, address.address, timestamp
        )

        const permissionApproving = await sign(
          permissionStringApproving, identity.associatedAddresses[0].address, identity.associatedAddresses[0].private
        )
        const permission = await sign(permissionString, address.address, address.private)

        await instances.IdentityRegistry.addAssociatedAddressDelegated(
          identity.associatedAddresses[0].address, address.address,
          [permissionApproving.v, permission.v],
          [permissionApproving.r, permission.r],
          [permissionApproving.s, permission.s],
          [timestamp, timestamp],
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

    it('provider can remove addresses -- FAIL signature', async function () {
      const address = accountsPrivate[5]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'Hydro rules!!!',
        identity.identity,
        address.address,
        timestamp
      )

      const permission = await sign(permissionString, address.address, address.private)

      await instances.IdentityRegistry.removeAssociatedAddressDelegated(
        address.address, permission.v, permission.r, permission.s, timestamp,
        { from: identity.providers[0].address }
      )
        .then(() => assert.fail('able to remove address', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Permission denied.', 'wrong rejection reason'
        ))
    })

    it('self could remove addresses', async function () {
      const address = accountsPrivate[5]
      await instances.IdentityRegistry.removeAssociatedAddress.call({ from: address.address })
    })

    it('provider can remove addresses', async function () {
      const address = accountsPrivate[5]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize removing this address from my Identity.',
        identity.identity,
        address.address,
        timestamp
      )

      const permission = await sign(permissionString, address.address, address.private)

      await instances.IdentityRegistry.removeAssociatedAddressDelegated(
        address.address, permission.v, permission.r, permission.s, timestamp,
        { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address),
        providers:           identity.providers.map(provider => provider.address),
        resolvers:           []
      })
    })

    const provider = accountsPrivate[6]
    it('identity can add a provider itself', async function () {
      await Promise.all(identity.associatedAddresses.map(({ address }) => {
        return instances.IdentityRegistry.addProviders.call(
          [provider.address],
          { from: address }
        )
      }))
    })

    it('provider can add a provider for -- FAIL', async function () {
      await instances.IdentityRegistry.addProvidersFor(
        identity.identity, [provider.address], { from: accounts[0] }
      )
        .then(() => assert.fail('should not be able to add a provider from a non-provider', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'The identity has not set the passed provider.', 'wrong rejection reason'
        ))
    })

    it('provider can add a provider for', async function () {
      await instances.IdentityRegistry.addProvidersFor(
        identity.identity, [provider.address], { from: identity.providers[0].address }
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

      await instances.IdentityRegistry.removeProvidersFor(
        identity.identity, [provider.address], { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address),
        providers:           identity.providers.map(provider => provider.address),
        resolvers:           []
      })
    })

    it('self could add resolvers', async function () {
      const resolver = accountsPrivate[7]

      await instances.IdentityRegistry.addResolvers.call(
        [resolver.address], { from: identity.associatedAddresses[0].address }
      )
    })

    it('provider can add resolvers', async function () {
      const resolver = accountsPrivate[7]

      await instances.IdentityRegistry.addResolversFor(
        identity.identity, [resolver.address],
        { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress: identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(address => address.address),
        providers: identity.providers.map(provider => provider.address),
        resolvers: [resolver.address]
      })
    })

    it('provider could remove resolvers', async function () {
      const resolver = accountsPrivate[7]

      await instances.IdentityRegistry.removeResolvers.call(
        [resolver.address],
        { from: identity.associatedAddresses[0].address }
      )
    })

    it('provider can remove resolvers', async function () {
      const resolver = accountsPrivate[7]

      await instances.IdentityRegistry.removeResolversFor(
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
    let newAssociatedAddress
    let newAssociatedAddressPermission
    let timestamp
    let futureTimestamp
    let futureNewAssociatedAddressPermission
    const twoWeeks = 60 * 60 * 24 * 14

    it('Could recover', async function () {
      const newAssociatedAddress = accountsPrivate[9]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize being added to this Identity via recovery.',
        identity.identity, newAssociatedAddress.address, timestamp
      )
      const newAssociatedAddressPermission = await sign(
        permissionString, newAssociatedAddress.address, newAssociatedAddress.private
      )

      await instances.IdentityRegistry.triggerRecovery.call(
        identity.identity, newAssociatedAddress.address,
        newAssociatedAddressPermission.v, newAssociatedAddressPermission.r, newAssociatedAddressPermission.s, timestamp,
        { from: identity.recoveryAddress.address }
      )
    })

    it('Could trigger change in recovery address', async function () {
      newRecoveryAddress = accountsPrivate[8]

      await instances.IdentityRegistry.triggerRecoveryAddressChange.call(
        newRecoveryAddress.address, { from: identity.associatedAddresses[0].address }
      )
    })

    it('Can trigger change in recovery address', async function () {
      newRecoveryAddress = accountsPrivate[8]

      await instances.IdentityRegistry.triggerRecoveryAddressChangeFor(
        identity.identity, newRecoveryAddress.address, { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     newRecoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(associatedAddress => associatedAddress.address),
        providers:           identity.providers.map(provider => provider.address),
        resolvers:           []
      })
    })

    it('New recovery address cannot trigger recovery', async function () {
      newAssociatedAddress = accountsPrivate[9]
      timestamp = Math.round(new Date() / 1000) - 1
      futureTimestamp = timestamp + twoWeeks
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize being added to this Identity via recovery.',
        identity.identity, newAssociatedAddress.address, timestamp
      )
      newAssociatedAddressPermission = await sign(
        permissionString, newAssociatedAddress.address, newAssociatedAddress.private
      )
      const futurePermissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize being added to this Identity via recovery.',
        identity.identity, newAssociatedAddress.address, futureTimestamp
      )
      futureNewAssociatedAddressPermission = await sign(
        futurePermissionString, newAssociatedAddress.address, newAssociatedAddress.private
      )

      await instances.IdentityRegistry.triggerRecovery(
        identity.identity, newAssociatedAddress.address,
        newAssociatedAddressPermission.v, newAssociatedAddressPermission.r, newAssociatedAddressPermission.s, timestamp,
        { from: newRecoveryAddress.address }
      )
        .then(() => assert.fail('new recovery address triggered recovery', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Only the recently removed recovery address can trigger recovery.', 'wrong rejection reason'
        ))
    })

    it('Cannot trigger another change in recovery address yet', async function () {
      await instances.IdentityRegistry.triggerRecoveryAddressChangeFor(
        identity.identity, identity.recoveryAddress.address, { from: identity.providers[0].address }
      )
        .then(() => assert.fail('able to change recovery address', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Cannot trigger a change in recovery address yet', 'wrong rejection reason'
        ))
    })

    it('After 2 weeks, old recovery address cannot trigger recovery', async function () {
      await timeTravel(twoWeeks + 1)

      await instances.IdentityRegistry.triggerRecovery(
        identity.identity, newAssociatedAddress.address,
        futureNewAssociatedAddressPermission.v, futureNewAssociatedAddressPermission.r,
        futureNewAssociatedAddressPermission.s, futureTimestamp,
        { from: identity.recoveryAddress.address }
      )
        .then(() => assert.fail('old recovery address triggered recovery', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Only the current recovery address can trigger recovery.', 'wrong rejection reason'
        ))
    })

    it('Can trigger another change in recovery address', async function () {
      await instances.IdentityRegistry.triggerRecoveryAddressChangeFor(
        identity.identity, identity.recoveryAddress.address, { from: identity.providers[0].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     identity.recoveryAddress.address,
        associatedAddresses: identity.associatedAddresses.map(associatedAddress => associatedAddress.address),
        providers:           identity.providers.map(provider => provider.address),
        resolvers:           []
      })
    })

    it('Recently removed recovery address can trigger recovery -- FAIL signature', async function () {
      instances.IdentityRegistry
        .RecoveryTriggered()
        .once('data', event => {
          oldAssociatedAddresses = event.returnValues.oldAssociatedAddresses
        })

      await instances.IdentityRegistry.triggerRecovery(
        identity.identity, newAssociatedAddress.address,
        0, futureNewAssociatedAddressPermission.r,
        futureNewAssociatedAddressPermission.s, futureTimestamp,
        { from: newRecoveryAddress.address }
      )
        .then(() => assert.fail('recovery was triggered', 'transaction should fail'))
        .catch(error => assert.include(
          error.message, 'Permission denied.', 'wrong rejection reason'
        ))
    })

    it('Cannot trigger destruction', async function () {
      await instances.IdentityRegistry.triggerDestruction.call(identity.identity, [], [], true, { from: accounts[0] })
        .then(() => assert.fail('old recovery address triggered recovery', 'transaction should fail'))
        .catch(error => {
          if (error.message !== defaultErrorMessage) {
            assert.include(
              error.message, 'Recovery has not recently been triggered.', 'wrong rejection reason'
            )
          }
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
        futureNewAssociatedAddressPermission.v, futureNewAssociatedAddressPermission.r,
        futureNewAssociatedAddressPermission.s, futureTimestamp,
        { from: newRecoveryAddress.address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     newRecoveryAddress.address,
        associatedAddresses: [newAssociatedAddress.address],
        providers:           [],
        resolvers:           []
      })
    })

    it('Recently removed recovery address can trigger recovery -- FAIL too soon', async function () {
      const newAssociatedAddress = accountsPrivate[8]
      const timestamp = Math.round(new Date() / 1000) + twoWeeks - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize being added to this Identity via recovery.',
        identity.identity, newAssociatedAddress.address, timestamp
      )
      const newAssociatedAddressPermission = await sign(
        permissionString, newAssociatedAddress.address, newAssociatedAddress.private
      )

      await instances.IdentityRegistry.triggerRecovery(
        identity.identity, newAssociatedAddress.address,
        newAssociatedAddressPermission.v, newAssociatedAddressPermission.r,
        newAssociatedAddressPermission.s, timestamp,
        { from: newRecoveryAddress.address }
      )
        .then(() => assert.fail('recovery was triggered after recently recovering', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'Cannot trigger recovery yet.', 'wrong rejection reason'))
    })
  })

  describe('Testing Destruction', function () {
    it('Any of the recently removed address can trigger destruction', async function () {
      await Promise.all(oldAssociatedAddresses.map(address => {
        const indexOf = oldAssociatedAddresses.indexOf(address)

        const firstChunk = oldAssociatedAddresses.slice(0, indexOf)
        const lastChunk = oldAssociatedAddresses.slice(indexOf + 1)

        return instances.IdentityRegistry.triggerDestruction.call(
          identity.identity, firstChunk, lastChunk, true, { from: address }
        )
      }))
    })

    it('Any of the recently removed address can trigger destruction -- FAIL', async function () {
      const indexOf = oldAssociatedAddresses.indexOf(oldAssociatedAddresses[0])
      const firstChunk = oldAssociatedAddresses.slice(0, indexOf)
      const lastChunk = oldAssociatedAddresses.slice(indexOf + 1)

      await instances.IdentityRegistry.triggerDestruction.call(
        identity.identity, firstChunk, lastChunk, true, { from: accounts[0] }
      )
        .then(() => assert.fail('recovery was triggered after recently recovering', 'transaction should fail'))
        .catch(error => {
          if (error.message !== defaultErrorMessage) {
            assert.include(
              error.message,
              'Cannot destroy an EIN from an address that was not recently removed from said EIN via recovery.',
              'wrong rejection reason'
            )
          }
        })
    })

    it('Triggering destruction on an identity works as expected', async function () {
      const indexOf = oldAssociatedAddresses.indexOf(identity.associatedAddresses[1].address)

      const firstChunk = oldAssociatedAddresses.slice(0, indexOf)
      const lastChunk = oldAssociatedAddresses.slice(indexOf + 1)

      await instances.IdentityRegistry.triggerDestruction(
        identity.identity, firstChunk, lastChunk, true, { from: identity.associatedAddresses[1].address }
      )

      await verifyIdentity(identity.identity, instances.IdentityRegistry, {
        recoveryAddress:     '0x0000000000000000000000000000000000000000',
        associatedAddresses: [],
        providers:           [],
        resolvers:           []
      })
    })
  })
})
