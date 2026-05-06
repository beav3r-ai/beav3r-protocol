// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Beav3rActionHashLib
/// @notice Computes the protocol action hash for Beav3r-authorized target calls.
library Beav3rActionHashLib {
    /// @notice Computes the hash that binds an authorization to a specific target call.
    /// @param account Actor account bound to the authorization.
    /// @param to Target contract address.
    /// @param value Native token value included in the target call.
    /// @param data Calldata included in the target call.
    /// @param chainId Chain id bound to the authorization.
    /// @param nonce Replay-protection nonce.
    /// @param expiresAt Timestamp at which the authorization is no longer valid.
    /// @param executor Executor address that must perform the call.
    /// @return Action hash committed into the signed authorization payload.
    function computeActionHash(
        address account,
        address to,
        uint256 value,
        bytes calldata data,
        uint256 chainId,
        uint256 nonce,
        uint256 expiresAt,
        address executor
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, to, value, keccak256(data), chainId, nonce, expiresAt, executor));
    }
}
