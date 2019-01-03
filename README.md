## ERC-1484 Reference Implementation
[![Build Status](https://travis-ci.org/hydrogen-dev/ERC-1484.svg?branch=master)](https://travis-ci.org/hydrogen-dev/ERC-1484)
[![Coverage Status](https://coveralls.io/repos/github/hydrogen-dev/ERC-1484/badge.svg?branch=master)](https://coveralls.io/github/hydrogen-dev/ERC-1484?branch=master)

This repo contains the reference implementation for [ERC-1484](https://github.com/ethereum/EIPs/issues/1495). The full text of ERC-1484 is available in [.md format](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1484.md) and on [the Ethereum EIPs website](https://eips.ethereum.org/EIPS/eip-1484).

Feedback on this proposal is welcomed in [the official discussion forum](https://github.com/ethereum/EIPs/issues/1495). To contribute to or make suggestions about the reference implementation, please [open a PR](https://github.com/hydrogen-dev/ERC-1484/pulls) in this repo.

## Contract Deployments
Live deployments of the current implementation are available at the following addresses:

| Network      | Address                                                                                                                         |
| --           | --                                                                                                                              |
| Mainnet (1)  | [`0xE65fB5C8AEb0305D3A1dB0BE2297f3E00B26E8c5`](https://etherscan.io/address/0xe65fb5c8aeb0305d3a1db0be2297f3e00b26e8c5)         |
| Ropsten (3)  | [`0x7191A2aD4F6f25E4C2ab6C7B2B9f7cb90905A6cB`](https://ropsten.etherscan.io/address/0x7191a2ad4f6f25e4c2ab6c7b2b9f7cb90905a6cb) |
| Rinkeby (4)  | [`0xa7ba71305bE9b2DFEad947dc0E5730BA2ABd28EA`](https://rinkeby.etherscan.io/address/0xa7ba71305be9b2dfead947dc0e5730ba2abd28ea) |
| Kovan   (42) | [`0xe0507a63E40Ce227CbF2ed7273a01066bAFE667B`](https://kovan.etherscan.io/address/0xe0507a63e40ce227cbf2ed7273a01066bafe667b)   |


## File Guide
This repo contains:

- The [`Identity Registry` reference implementation](./contracts/IdentityRegistry.sol).
- A 100% coverage [test suite](./test).
- A sample [`Provider`](./contracts/samples/Provider.sol) and [`Resolver`](.contracts/samples/Resolver.sol).
- [Best Practices](./best-practices) explaining and extending various aspects of ERC-1484.
- Example [`Providers`](./contracts/examples/Providers) and [`Resolvers`](./contracts/examples/Resolvers). These include an [ERC-725 Resolver](./contracts/examples/Resolvers/ERC725), an [ERC-1056 Resolver](./contracts/examples/Resolvers/ERC1056), and a [Meta-Transactions Provider](./contracts/examples/Providers/MetaTransactions).


## Running Tests Locally
- Install dependencies: `npm install`
- Build contracts: `npm run build`
- In one terminal tab, spin up a development blockchain: `npm run chain`
- In another terminal tab, run the test suite: `npm test`
