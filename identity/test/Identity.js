const Web3 = require('web3')
const ethUtil = require('ethereumjs-util')
const web3 = new Web3(Web3.givenProvider)

const IdentityRegistry = artifacts.require('./IdentityRegistry.sol')
const ProviderExample = artifacts.require('./examples/ProviderExample.sol')

function sign (messageHash, address, privateKey, method) {
  return new Promise(resolve => {
    if (method === 'unprefixed') {
      let signature = ethUtil.ecsign(
        Buffer.from(ethUtil.stripHexPrefix(messageHash), 'hex'),
        Buffer.from(ethUtil.stripHexPrefix(privateKey), 'hex')
      )
      signature.r = ethUtil.bufferToHex(signature.r)
      signature.s = ethUtil.bufferToHex(signature.s)
      signature.v = parseInt(ethUtil.bufferToHex(signature.v))
      resolve(signature)
    } else {
      web3.eth.sign(messageHash, address)
        .then(concatenatedSignature => {
          let strippedSignature = ethUtil.stripHexPrefix(concatenatedSignature)
          let signature = {
            r: ethUtil.addHexPrefix(strippedSignature.substr(0, 64)),
            s: ethUtil.addHexPrefix(strippedSignature.substr(64, 64)),
            v: parseInt(ethUtil.addHexPrefix(strippedSignature.substr(128, 2))) + 27
          }
          resolve(signature)
        })
    }
  })
}

const accountsPrivate = [
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
const identifiers = [
  '💧💧💧',
  '💧💧💧💧',
  '💧💧💧💧💧',
  '💧💧💧💧💧💧',
  '💧💧💧💧💧💧💧',
  '💧💧💧💧💧💧💧💧',
  '💧💧💧💧💧💧💧💧💧',
  '💧💧💧💧💧💧💧💧💧💧',
  '💧💧💧💧💧💧💧💧💧💧💧',
  '💧💧💧💧💧💧💧💧💧💧💧💧'
]
const instances = {}

contract('Testing Identity', function (accounts) {
  const identities = accounts.map((_, i) => {
    return {
      address: accounts[i],
      private: accountsPrivate[i],
      identifiers: identifiers[i]
    }
  })

  describe('Deploying Contracts', function () {
    it('IdentityRegistry contract deployed', async function () {
      instances.IdentityRegistry = await IdentityRegistry.new()
    })

    it('Provider Example contract deployed', async function () {
      instances.ProviderExample = await ProviderExample.new(instances.IdentityRegistry)
    })
  })

  describe('Testing IdentityRegistry in isolation', function () {
    it('Signatures verify correctly', async function () {
      let messageHash = web3.utils.soliditySha3('shh')
      for (const identity of identities) {
        for (const method in ['prefixed', 'unprefixed']) {
          const signature = await sign(messageHash, identity.address, identity.private, method)
          const isSigned = await instances.IdentityRegistry.isSigned.call(
            identity.address, messageHash, signature.v, signature.r, signature.s
          )
          assert.isTrue(isSigned, 'Signature could not be verified.')
        }
      }
    })
  })
})
