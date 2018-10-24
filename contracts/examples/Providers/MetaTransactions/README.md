## Meta Transactions

This example `MetaTransactionProxyProvider` sketches out a design for sending meta-transactions on behalf of `Identities`. Though what follows is a subset of the full, robust functionality offered by a 1484 `Identity`, it accurately represents a fully functioning meta-transactional flow.

1. When signing up a new user, the `MetaTransactionProvider` assigns them an address and requests a 1484 sign-up signature from this address.
2. The `Provider` then calls `mintIdentityDelegated` to assign the user an `EIN`.
3. Now, the `Provider` may pass appropriate signatures to `callViaProxy` to forward calls to arbitrary smart contracts.
4. Users may also call `callViaProxy` directly if they have access to an address associated with their `EIN`.
5. Calls are either forwarded directly from the `MetaTransactionProvider` address, if `viaExternal` is set to `false`, or through a per-`EIN` `ExternalProxy` contract otherwise. See below for an explanation.

### Through an `ExternalProxy`
Forwarding calls through individual `ExternalProxy` contracts is powerful in that it facilitates meta-transactions with existing dApps. From the point of view of the dApp, this `ExternalProxy` is the user's unique identity, and they don't know how the user is actually accessing `MetaTransactionProvider`. This provides full backwards compatibility with existing dApps.

However, it can be slightly limiting, in that it does not work with `Resolvers` that permission functions on 1484 `AssociatedAddresses` or `Providers`. In the case of `AssociatedAddresses`, since each `EIN`'s `ExternalProxy` contract is not an `AssociatedAddress`, nor can it be added as one since it cannot sign messages, the user is stuck. We can of course add the `ExternalProxy` as a `Provider`, but this feels fairly roundabout.

### Directly from `MetaTransactionProvider`
Luckily, in cases like the above, calls can instead be made directly from the `MetaTransactionProvider`, which *is natively a `Provider`*. This is accomplished by setting `viaExternal` to `false`. This means that `Resolvers` recieve all transactions from the same address, so:
- The `EIN` **must** be passed through as an argument to all function calls in the `data` argument (or else dApps have no way of knowing which `EIN` the `Provider` is calling on behalf of)
- `Resolvers` should be actively encouraged to allow `Providers` to call functions on behalf of `EINs` who've added them if they wish their logic to work for Providers ``


Which pattern you use depends on the particular `Resolver` or dApp in question, but in either case all calls are routed through the `MetaTransactionProvider`, and can be triggered by any `AssociatedAddress` of an `EIN`.

### References
- [https://github.com/ConsenSys/eth-signer](https://github.com/ConsenSys/eth-signer)
- [https://github.com/uport-project/uport-identity](https://github.com/uport-project/uport-identity)
