// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Beav3rTypes} from "../libraries/Beav3rTypes.sol";

/// @title IBeav3rExecutor
/// @notice Interface for executor contracts that spend Beav3r onchain authorization artifacts.
interface IBeav3rExecutor {
    /// @notice Returns true when a nonce is already consumed for an account.
    function isNonceUsed(address account, uint256 nonce) external view returns (bool);

    /// @notice Verifies and executes an authorized call.
    /// @param to Target contract address.
    /// @param value Native value passed to the target call.
    /// @param data Target calldata.
    /// @param auth Signed execution authorization payload.
    /// @param signature Signature over the authorization payload.
    /// @return result Raw target call return data.
    function executeWithAuth(
        address to,
        uint256 value,
        bytes calldata data,
        Beav3rTypes.ExecutionAuthorization calldata auth,
        bytes calldata signature
    ) external payable returns (bytes memory result);
}
