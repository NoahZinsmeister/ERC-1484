module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      websockets: true
    },
    coverage: {
      host: 'localhost',
      port: 8555,
      network_id: '*',
      gas: 0xfffffffffff,
      gasPrice: 0x01,
      websockets: true
    }
  },
  compilers: {
    solc: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      version: './node_modules/solc'
    }
  }
}
