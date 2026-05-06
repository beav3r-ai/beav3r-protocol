// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ECDSA
} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Beav3rTypes} from "./Beav3rTypes.sol";

/// @title Beav3rVerifierLib
/// @notice Computes EIP-712 hashes and recovers signers for Beav3r execution authorizations.
library Beav3rVerifierLib {
    // These constants define onchain protocol v1 signing semantics.
    bytes32 internal constant EXECUTION_AUTHORIZATION_TYPEHASH = keccak256(
        "ExecutionAuthorization(bytes32 actionHash,address account,address executor,uint256 chainId,uint256 nonce,uint256 expiresAt,bytes32 keyId)"
    );
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant DOMAIN_NAME_HASH = keccak256(bytes("Beav3rExecutionAuthorization"));
    bytes32 internal constant DOMAIN_VERSION_HASH = keccak256(bytes("1"));

    /// @notice Computes the EIP-712 domain separator for an executor on a chain.
    /// @param chainId Chain id bound to the authorization.
    /// @param verifyingContract Executor address used as the verifying contract.
    /// @return Domain separator used for authorization digests.
    function computeDomainSeparator(uint256 chainId, address verifyingContract) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, DOMAIN_NAME_HASH, DOMAIN_VERSION_HASH, chainId, verifyingContract)
        );
    }

    /// @notice Computes the EIP-712 struct hash for an execution authorization.
    /// @param auth Authorization payload to hash.
    /// @return Struct hash encoded into the final digest.
    function computeStructHash(Beav3rTypes.ExecutionAuthorization calldata auth) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EXECUTION_AUTHORIZATION_TYPEHASH,
                auth.actionHash,
                auth.account,
                auth.executor,
                auth.chainId,
                auth.nonce,
                auth.expiresAt,
                auth.keyId
            )
        );
    }

    /// @notice Computes the EIP-712 digest signed by a trusted Beav3r signer.
    /// @param auth Authorization payload to hash.
    /// @return Digest used for ECDSA recovery.
    function computeDigest(Beav3rTypes.ExecutionAuthorization calldata auth) internal pure returns (bytes32) {
        bytes32 domainSeparator = computeDomainSeparator(auth.chainId, auth.executor);
        bytes32 structHash = computeStructHash(auth);
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    /// @notice Recovers the signer from an execution authorization digest.
    /// @param digest EIP-712 digest signed by the authorization signer.
    /// @param signature Signature over the authorization digest.
    /// @return Signer recovered from the signature, or zero when recovery fails.
    function recoverSigner(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecoverCalldata(digest, signature);
        if (err != ECDSA.RecoverError.NoError) {
            return address(0);
        }
        return recovered;
    }
}
