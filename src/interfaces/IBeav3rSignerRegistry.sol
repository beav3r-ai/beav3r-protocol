// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IBeav3rSignerRegistry
/// @notice Read interface for resolving trusted Beav3r signer addresses.
interface IBeav3rSignerRegistry {
    /// @notice Returns the trusted signer for an account key id.
    /// @param account Actor account that owns the key id.
    /// @param keyId Key identifier encoded in an authorization payload.
    /// @return Signer address trusted for the account key id, or zero when disabled or unset.
    function getSigner(address account, bytes32 keyId) external view returns (address);
}
