## ERC xxx Reference Implementation and Examples

This repo contains the reference implementation for ERC xxx. The text of the ERC is in [ERC.md](./ERC.md).

It also contains a test suite, as well as examples of smart contracts that leverage the protocol defined in the ERC.

This ERC is currently being tracked at [PR 1484](https://github.com/ethereum/EIPs/pull/1484) in [ethereum/EIPs](https://github.com/ethereum/EIPs).

## To Run Locally
- Install dependencies: `npm install`
- Build contracts: `npm run build`
- In one terminal tab, spin up a development blockchain: `npm run chain`
- In another terminal tab, run the test suite: `npm test`

NOTE: Due to a bug in Truffle, tests will fail with a `Deployer._preFlightCheck` error after running `npm build`. This problem can be solved by saving one or more contract files after building, so that the test command triggers a re-compile before running. While slightly frustrating, adding then removing whitespace then saving one file is an easy fix to this bug.
