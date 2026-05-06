# Beav3r Onchain Protocol V1

This directory is the canonical machine-readable source for the frozen onchain execution authorization protocol.

- `protocol.json` defines the frozen EIP-712 domain, authorization struct, action hash fields, key ID derivation, replay model, and executor entrypoint.
- `golden-vectors.json` defines reference inputs and expected hashes/signatures that server, SDK, and contract implementations must match.

The executor entrypoint is implemented by provisioned `Beav3rExecutorCloneable`
instances. `Beav3rExecutorFactory` is Beav3r-operated provisioning
infrastructure and is not part of the signed authorization payload.
