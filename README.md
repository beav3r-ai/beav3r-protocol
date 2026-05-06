# beav3r-protocol

Dedicated Foundry repo for the Beav3r onchain protocol contracts.

This repo publishes the Solidity contract surface for Beav3r's onchain
authorization and executor model so integrators can inspect the contracts,
verify deployed bytecode, and understand the trust boundary around the
provisioned executor address.

Current v1 contract set:

- `Beav3rSignerRegistry`
- `Beav3rAuthorizationVerifier`
- `Beav3rExecutorCloneable`
- `Beav3rExecutorFactory`
- `demo/Beav3rTestUSDT`
- `demo/Phase5DemoToken`

The canonical v1 executor is the cloneable executor. Beav3r provisions an
executor clone for an actor account, returns that executor address, and
integrators grant downstream permissions to that returned address.

`Beav3rSignerRegistry` has two operational roles:

- owner: deployer wallet at initial deployment time; can transfer ownership and rotate the registrar
- registrar: hot operational wallet allowed to configure and disable account signer mappings

## Layout

- `src`: protocol contracts and demos
- `test`: Foundry coverage, including golden vectors
- `spec`: protocol JSON spec and vectors
- `deployments`: published deployment artifacts

## Commands

```sh
forge build
forge test
forge fmt
```

## Install

```sh
forge install beav3r-ai/beav3r-protocol
```

Then import contracts from the installed repo, for example:

```solidity
import {IBeav3rSignerRegistry} from "beav3r-protocol/src/interfaces/IBeav3rSignerRegistry.sol";
```

See [DEPLOYMENTS.md](DEPLOYMENTS.md) for the current published Base Sepolia
deployment set.
