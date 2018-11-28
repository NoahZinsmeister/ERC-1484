## Burner

This example `BurnerProvider` sketches out a design for allowing identities to be created and immediately neutered after adding a resolver. This allows 1484 identities to be programatically created and linked to an arbitrary address, while ensuring that this link will exist into perpetuity (and nothing else). The resolver can be a smart contract/address/identity protocol implementation/proxy/etc. that implements any arbitrary logic, that nonetheless is tied to a 1484 Identity.
