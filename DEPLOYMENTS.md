# Beav3r Onchain Deployments

This page tracks deployed contract addresses for the Beav3r onchain verifier stack.

## Base Sepolia

- network: Base Sepolia
- chain id: `84532`
- artifact: [`deployments/base-sepolia.json`](deployments/base-sepolia.json)

### Core Verifier Stack

- `Beav3rSignerRegistry`: `0x32638Cd8f41BCd4cb3BBaDb6A6d0CBB3f57bAd7e`
- `Beav3rAuthorizationVerifier`: `0xBc63acbdaD244E0fA6fDBb5c552ED04B7F624900`

## Status

- Public docs should mirror the addresses above on `/smart-contracts`.
- Deployment transaction hashes are not available in repo broadcast artifacts for this deployment yet.
- No mainnet deployment artifact is currently published in this folder.

## Baseline Capture

- source commit: `344e839c0f2ca5d5a0d8a9a5ddec23ae9a2855f0`
- worktree dirty at capture: yes
- forge: `1.5.1-stable` (`b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2`)
- solc: `0.8.33+commit.64118f21` from Foundry artifact metadata
- evm version: `prague`
- optimizer: disabled
