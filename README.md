## ERC-1484 Reference Implementation
[![Build Status](https://travis-ci.org/hydrogen-dev/ERC-1484.svg?branch=master)](https://travis-ci.org/hydrogen-dev/ERC-1484)
[![Coverage Status](https://coveralls.io/repos/github/hydrogen-dev/ERC-1484/badge.svg?branch=master)](https://coveralls.io/github/hydrogen-dev/ERC-1484?branch=master)

This repo contains the reference implementation for [ERC-1484](https://github.com/ethereum/EIPs/issues/1495). The full text of ERC-1484 is available in [.md format](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1484.md) and on [the Ethereum EIPs website](https://eips.ethereum.org/EIPS/eip-1484).

Feedback on this proposal is welcomed in [the official discussion forum](https://github.com/ethereum/EIPs/issues/1495). To contribute to or make suggestions about the reference implementation, please [open a PR](https://github.com/hydrogen-dev/ERC-1484/pulls) in this repo.

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
