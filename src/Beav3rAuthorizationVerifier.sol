// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBeav3rSignerRegistry} from "./interfaces/IBeav3rSignerRegistry.sol";
import {Beav3rActionHashLib} from "./libraries/Beav3rActionHashLib.sol";
import {Beav3rTypes} from "./libraries/Beav3rTypes.sol";
import {Beav3rVerifierLib} from "./libraries/Beav3rVerifierLib.sol";

/// @title Beav3rAuthorizationVerifier
/// @notice Verifies Beav3r execution authorization signatures against the signer registry.
/// @dev The registry supplies the trusted signer for an `(account, keyId)` pair. The verifier computes the
///      protocol digest and reports whether the recovered signer matches the registered signer.
contract Beav3rAuthorizationVerifier {
    error InvalidRegistry();

    struct VerificationResult {
        bool isValid;
        address recoveredSigner;
        address trustedSigner;
        bytes32 digest;
    }

    IBeav3rSignerRegistry public immutable SIGNER_REGISTRY;

    /// @notice Deploys the verifier with the signer registry used for trust resolution.
    /// @param signerRegistryAddress Address of the registry consulted during verification.
    constructor(address signerRegistryAddress) {
        if (signerRegistryAddress == address(0)) {
            revert InvalidRegistry();
        }
        SIGNER_REGISTRY = IBeav3rSignerRegistry(signerRegistryAddress);
    }

    /// @notice Computes the action hash for a concrete target call.
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
    ) external pure returns (bytes32) {
        return Beav3rActionHashLib.computeActionHash(account, to, value, data, chainId, nonce, expiresAt, executor);
    }

    /// @notice Computes the EIP-712 digest for an execution authorization.
    /// @param auth Authorization payload to hash.
    /// @return Digest signed by the trusted Beav3r signer.
    function computeDigest(Beav3rTypes.ExecutionAuthorization calldata auth) external pure returns (bytes32) {
        return Beav3rVerifierLib.computeDigest(auth);
    }

    /// @notice Verifies that an execution authorization signature matches the registry signer.
    /// @param auth Authorization payload containing the account, key id, action hash, executor, chain, nonce, and expiry.
    /// @param signature Signature over the authorization digest.
    /// @return result Recovered signer, trusted signer, digest, and validity flag.
    function verifyExecutionAuthorization(Beav3rTypes.ExecutionAuthorization calldata auth, bytes calldata signature)
        external
        view
        returns (VerificationResult memory result)
    {
        result.digest = Beav3rVerifierLib.computeDigest(auth);
        result.recoveredSigner = Beav3rVerifierLib.recoverSigner(result.digest, signature);
        result.trustedSigner = SIGNER_REGISTRY.getSigner(auth.account, auth.keyId);
        result.isValid = result.recoveredSigner != address(0) && result.trustedSigner != address(0)
            && result.recoveredSigner == result.trustedSigner;
    }
}
