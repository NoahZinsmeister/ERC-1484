## ERC-1484 Reference Implementation

This repo contains the reference implementation for [ERC-1484](https://github.com/ethereum/EIPs/issues/1495). The full text of ERC-1484 is available in [.md format](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1484.md) and on [the Ethereum EIPs website](https://eips.ethereum.org/EIPS/eip-1484).

Feedback on this proposal is welcomed in [the official discussion forum](https://github.com/ethereum/EIPs/issues/1495). To contribute to or make suggestions about the reference implementation, please [open a PR](https://github.com/hydrogen-dev/ERC-1484/pulls) in this repo.

In addition to the [`Identity Registry` reference implementation](./contracts/IdentityRegistry.sol), this repo also contains a [full test suite](./test), as well as a sample [`Provider`](./samples/Provider) and [`Resolver`](./samples/Resolver).

## Running Tests Locally
- Install dependencies: `npm install`
- Build contracts: `npm run build`
- Address Truffle bug: `touch contracts/IdentityRegistry.sol`
- In one terminal tab, spin up a development blockchain: `npm run chain`
- In another terminal tab, run the test suite: `npm test`

NOTE: Due to [a bug in Truffle](https://github.com/trufflesuite/truffle/issues/1341), tests will fail with a `Deployer._preFlightCheck` error after running `npm run build`. This problem can be solved by saving one or more contract files after building, so that the test command triggers a re-compile before running. While slightly frustrating, running `touch contracts/IdentityRegistry.sol` (or adding then removing whitespace to `contracts/IdentityRegistry.sol` then saving) after building is an easy fix to this bug.
