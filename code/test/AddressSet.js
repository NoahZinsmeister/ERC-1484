const AddressSetTesting = artifacts.require('./testing/AddressSetTesting.sol')

let allAccounts
let setInstance
async function verify (expectedLength, expectedMembers) {
  // check length
  const length = await setInstance.length.call()
  assert.equal(length, expectedLength, 'Set has unexpected length')
  // check membership
  const members = await setInstance.members.call()
  assert.deepEqual(members.sort(), expectedMembers.sort(), 'Set has unexpected members')
  // check contains
  await Promise.all(allAccounts.map(async member => {
    const contains = await setInstance.contains.call(member)
    if (expectedMembers.includes(member)) {
      assert.isTrue(contains, `Unexpectedly does not contain ${member}`)
    } else {
      assert.isNotTrue(contains, `Unexpectedly contains ${member}`)
    }
  }))
}

async function insert (accounts) {
  for (const account of accounts) {
    await setInstance.insert(account)
  }
}

async function remove (accounts) {
  for (const account of accounts) {
    await setInstance.remove(account)
  }
}

contract('Testing AddressSet', function (accounts) {
  allAccounts = accounts

  it('Testing contract deployed', async function () {
    setInstance = await AddressSetTesting.new()
  })

  it('Set initialized correctly', async function () {
    await verify(0, [])
  })

  it('Member added correctly', async function () {
    await insert(accounts.slice(0, 1))
    await verify(1, accounts.slice(0, 1))
  })

  it('Member removed correctly', async function () {
    await remove(accounts.slice(0, 1))
    await verify(0, [])
  })

  it('Member re-added correctly', async function () {
    await insert(accounts.slice(0, 1))
    await verify(1, accounts.slice(0, 1))
  })

  it('Other members added correctly', async function () {
    await insert(accounts.slice(1))
    await verify(accounts.length, accounts)
  })

  it('Other members removed correctly', async function () {
    await remove(accounts)
    await verify(0, [])
  })
})
