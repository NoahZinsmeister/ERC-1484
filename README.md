## ERC-1484 Reference Implementation

This repo contains the reference implementation for [ERC-1484](https://github.com/ethereum/EIPs/issues/1495). The full text of ERC-1484 is available in [.md format](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1484.md) and on [the Ethereum EIPs website](https://eips.ethereum.org/EIPS/eip-1484).

Feedback on this proposal is welcomed in [the official discussion forum](https://github.com/ethereum/EIPs/issues/1495). To contribute to or make suggestions about the reference implementation, please [open a PR](https://github.com/hydrogen-dev/ERC-1484/pulls) in this repo.

In addition to the [`Identity Registry` reference implementation](./contracts/IdentityRegistry.sol), this repo also contains a [full test suite](./test), as well as a sample [`Provider`](./samples/Provider) and [`Resolver`](./samples/Resolver).

## Deployments
*FOR TESTING PURPOSES ONLY*, an `Identity Registry` contract has been deployed on the Rinkeby testnet. This will not be the final address.

|Network        |Address|
|---------------|-------|
|Rinkeby (id: 4)|[0x8d37E9744887a4673CaEA1fd524d0FED7Edb1c23](https://rinkeby.etherscan.io/address/0x8d37e9744887a4673caea1fd524d0fed7edb1c23)|


## Running Tests Locally
- Install dependencies: `npm install`
- Build contracts: `npm run build`
- In one terminal tab, spin up a development blockchain: `npm run chain`
- In another terminal tab, run the test suite: `npm test`
