## Building a Resolver

Because of the open-ended nature of resolvers, it can be daunting to begin writing one. Below are some hints to get you started.

### Enforcing `isResolver`
While not strictly necessary, resolvers are *strongly recommended* to enforce that calling `EINs` have set your `Resolver` via code that looks something like the following:

```solidity
  require(identityRegistry.isResolverFor(ein, address(this)), "The EIN has not set this resolver.");
```

While Resolvers are of course free to let anyone they wish interact with their smart contract, they should, in most cases, restrict use to `Identities` who currently have their address set as a `Resolver`. This is helpful so that front-ends can know which Resolvers a given entity has set, and can also facilitate inter-`Resolver` logic.

### Permissioning
There are several routes a `Resolver` could take when choosing how to let `Identities` interact with their smart contracts. `Resolvers` are recommended to implement one or more of the best practices outlined below.

Before diving in, let's first sketch out an `updateInformation` function that we want to call. Say it modifies data associated with an `Identity`.

```solidity
// perform the desired operations on the EIN's Identity
function updateInformation(...) ... {
  ...
}
```

Obviously, we have to be careful about who can call this function, and how calls are permissioned to affect the data of `Identities`.

#### 1. Allow `Identities` to call functions directly
The first and simplest option is to allow any `associatedAddress` of an identity to call `updateInformation` by simply looking up their `EIN` from the 1484 registry via `getEIN`. All further operations can now use that `EIN`.

```solidity
function updateInformation(...) public {
  uint ein = identityRegistry.getEIN(msg.sender);
  ...
}
```

#### 2. Allow `Providers` to call functions on behalf of `Identities`
Some users, though, might not want to interact with our `Resolver` directly. They might instead prefer to do so through a `Provider`. In this case, we want to allow a `Provider` to call `updateInformation` _on behalf of_ an EIN. For this not to be an anti-pattern, we must:

- Ensure that any time we receive a call from a `Provider` on behalf of an `EIN`, the `EIN` in question has actually set this `Provider`. This is easily achieved by code that looks something like the following:

```solidity
function updateInformation(uint ein, ...) public {
  require(identityRegistry.isProviderFor(ein, msg.sender));
  ...;
}
```

- Be convinced that `Providers` have appropriately permissioned _their_ smart contracts so that we can trust that the calls we receive actually represent the intent of the `EIN`. (For example, a `public` function that triggers `EIN`-specific logic on your `Resolver` will probably be abused!) To this point, it is often enough to trust that `Providers` are treating permissions appropriately (see [BuildingProviders.md](./BuildingProviders.md) for `Provider` best practices around this issue). Cases where `Providers` may not be operating as securely as possibly can be chalked up to user error, and plausibly don't have to be handled by individual `Resolvers`. However, if a `Resolver` wishes to use only a trusted subset of `Providers`, or utilize the functionality of one particular `Provider`, they are of course free to do so with code that looks something like the following:

```solidity
function updateInformation(uint ein, ...) public {
  require(msg.sender == 0x...); // ensure that the calling address is e.g. a pre-determined whitelisted Provider
  require(identityRegistry.isProviderFor(ein, msg.sender));
  ...;
}
```

#### 3. (**Not Recommended**) Allow third parties to submit permission signatures on behalf of `Identities`
This is an anti-pattern for a `Resolver`, and is not recommended. For cases in which it's absolutely necessary, refer to the [BuildingProviders.md](./BuildingProviders.md) best practices.

#### 4. (**Not Recommended**) Allow `Resolver` owners to call `onlyOwner` functions on behalf of `Identities`
This is an anti-pattern for a `Resolver`. For cases in which it's absolutely necessary, `onlyOwner` calls may be made like so:

```solidity
function updateInformation(uint ein, ...) public onlyOwner() {
  ...;
}
```
