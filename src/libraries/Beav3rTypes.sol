// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Beav3rTypes
/// @notice Shared protocol structs used by Beav3r onchain authorization contracts.
library Beav3rTypes {
    struct ExecutionAuthorization {
        bytes32 actionHash;
        address account;
        address executor;
        uint256 chainId;
        uint256 nonce;
        uint256 expiresAt;
        bytes32 keyId;
    }
}
