## ERC-725 Resolver Implementation for ERC-1484

This is a sample implementation of ERC-725 being used as a `Resolver` for 1484 `Identities`. The `Resolver` allows users to create a new 725, or link an existing one to their EIN. All `Resolver` functions must be called directly by `Identities`, but in a more robust system, this could be done through providers to help make 725 more user-friendly.
