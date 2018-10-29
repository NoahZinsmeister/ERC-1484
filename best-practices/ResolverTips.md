## Building a Resolver

Because of the open-ended nature of resolvers, it can be somewhat daunting to begin writing one. Below are some hints to get you started.

### Enforcing `isResolver`
While not strictly necessary, resolvers are *strongly recommended* to implement code that looks something like the following:

```solidity
require(identityRegistry.isResolverFor(ein, address(this)), "The EIN has not set this resolver.");
```

In words, while Resolvers are of course free to let anyone they wish interact with their smart contract, they should, in most cases, restrict use to `Identities` who currently have their address set as a resolver. This is helpful mainly for front-ends that need to know which Resolvers a given entity has set, but can also facilitate inter-Resolver logic.
