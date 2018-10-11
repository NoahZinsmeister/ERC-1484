## ERC TBD Reference Implementation and Examples

This folder contains the reference implementation for ERC xxx. It also contains a test suite, as well as examples of smart contracts that leverage the identity protocol via the Identity Registry.

## To Run Locally
- Install dependencies: `npm install`
- Build contracts: `npm run build`
- In one terminal tab, spin up a development blockchain: `npm run chain`
- In another terminal tab, run the test suite: `npm test`

NOTE: Due to an apparent bug in Truffle, tests intermittently fail with pre-deployment errors after running a clean build. This problem can be solved by changing one or more contract files, so that the test command triggers a re-compile before running. While frustrating, adding and removing whitespace is an easy fix to this bug.