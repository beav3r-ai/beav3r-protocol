# Beav3r Protocol

Dedicated Foundry repo for the Beav3r onchain protocol contracts.

Smart contracts documentation: https://docs.beav3r.ai/smart-contracts
Onchain demo script: https://github.com/beav3r-ai/beav3r-demo/blob/main/onchain-example.mjs

This repo publishes the Solidity contract surface for the Beav3r onchain
authorization and executor model. It exists for contract inspection, deployed
bytecode verification, and trust-boundary clarity around the provisioned
executor address.

Current v1 contract set:

- `Beav3rSignerRegistry`
- `Beav3rAuthorizationVerifier`
- `Beav3rExecutorCloneable`
- `Beav3rExecutorFactory`

`Beav3rAuthorizationVerifier` is the trust bridge between Beav3r approvals and
onchain execution. It resolves the trusted signer for an `(account, keyId)`
pair from `Beav3rSignerRegistry`, recomputes the EIP-712 digest for the
authorization payload, and proves that the submitted signature came from the
registered signer for that account.

The canonical v1 executor is the cloneable executor. Beav3r provisions an
executor clone for an actor account, returns that executor address, and
integrators grant downstream permissions to that returned address.

Normal integrations do not need to call or import these contracts directly.
Beav3r operates the registry, verifier, and factory. Integrators usually only
need the provisioned executor address that downstream contracts trust or
whitelist.

`Beav3rSignerRegistry` has two operational roles:

- owner: deployer wallet at initial deployment time; can transfer ownership and rotate the registrar
- registrar: hot operational wallet allowed to configure and disable account signer mappings

## Layout

- `src`: protocol contracts
- `test`: Foundry coverage, including golden vectors
- `spec`: protocol JSON spec and vectors
- `deployments`: published deployment artifacts

## Commands

```sh
forge build
forge test
forge fmt
```

## Deployments

### Base Sepolia

| Field | Value |
| --- | --- |
| Network | Base Sepolia |
| Chain ID | `84532` |
| Signer Registry | [`0x32638Cd8f41BCd4cb3BBaDb6A6d0CBB3f57bAd7e`](https://sepolia.basescan.org/address/0x32638Cd8f41BCd4cb3BBaDb6A6d0CBB3f57bAd7e) |
| Authorization Verifier | [`0xBc63acbdaD244E0fA6fDBb5c552ED04B7F624900`](https://sepolia.basescan.org/address/0xBc63acbdaD244E0fA6fDBb5c552ED04B7F624900) |

No mainnet deployment is published yet.

See [DEPLOYMENTS.md](DEPLOYMENTS.md) and
[`deployments/base-sepolia.json`](deployments/base-sepolia.json) for the
current published deployment artifact and baseline capture.
