// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Beav3rAuthorizationVerifier} from "./Beav3rAuthorizationVerifier.sol";
import {IBeav3rExecutor} from "./interfaces/IBeav3rExecutor.sol";
import {Beav3rTypes} from "./libraries/Beav3rTypes.sol";
import {Beav3rActionHashLib} from "./libraries/Beav3rActionHashLib.sol";

/// @title Beav3rCustomExecutorBase
/// @notice Abstract executor base for projects that want custom authorized execution logic.
abstract contract Beav3rCustomExecutorBase is IBeav3rExecutor {
    error AlreadyInitialized();
    error Uninitialized();
    error InvalidVerifier();
    error InvalidOwner();
    error InvalidChainId(uint256 expected, uint256 actual);
    error InvalidExecutor(address expected, address actual);
    error InvalidAccount(address expected, address actual);
    error AuthorizationExpired(uint256 expiresAt, uint256 currentTimestamp);
    error ActionHashMismatch(bytes32 expected, bytes32 actual);
    error UnauthorizedSigner(address recoveredSigner, address trustedSigner);
    error NonceAlreadyUsed(address account, uint256 nonce);

    event Initialized(address indexed verifier, address indexed owner);
    event AuthorizedExecution(
        address indexed account, address indexed target, uint256 indexed nonce, bytes32 actionHash
    );
    event VerifiedExecutionCountIncreased(address indexed account, uint256 indexed nonce, uint256 newCount);

    Beav3rAuthorizationVerifier public verifier;
    address public intendedOwner;
    uint256 public verifiedExecutionCount;
    bool public initialized;
    mapping(address account => mapping(uint256 nonce => bool used)) private usedNonces;

    function initialize(address verifierAddress, address ownerAddress) external {
        if (initialized) {
            revert AlreadyInitialized();
        }
        if (verifierAddress == address(0)) {
            revert InvalidVerifier();
        }
        if (ownerAddress == address(0)) {
            revert InvalidOwner();
        }
        verifier = Beav3rAuthorizationVerifier(verifierAddress);
        intendedOwner = ownerAddress;
        initialized = true;
        emit Initialized(verifierAddress, ownerAddress);
    }

    receive() external payable {}

    function isNonceUsed(address account, uint256 nonce) external view returns (bool) {
        return usedNonces[account][nonce];
    }

    function executeWithAuth(
        address to,
        uint256 value,
        bytes calldata data,
        Beav3rTypes.ExecutionAuthorization calldata auth,
        bytes calldata signature
    ) external payable returns (bytes memory result) {
        if (!initialized) {
            revert Uninitialized();
        }
        if (auth.chainId != block.chainid) {
            revert InvalidChainId(auth.chainId, block.chainid);
        }
        if (auth.executor != address(this)) {
            revert InvalidExecutor(auth.executor, address(this));
        }
        if (auth.account != intendedOwner) {
            revert InvalidAccount(intendedOwner, auth.account);
        }
        if (block.timestamp >= auth.expiresAt) {
            revert AuthorizationExpired(auth.expiresAt, block.timestamp);
        }

        bytes32 computedActionHash = Beav3rActionHashLib.computeActionHash(
            auth.account, to, value, data, auth.chainId, auth.nonce, auth.expiresAt, auth.executor
        );
        if (computedActionHash != auth.actionHash) {
            revert ActionHashMismatch(auth.actionHash, computedActionHash);
        }
        if (usedNonces[auth.account][auth.nonce]) {
            revert NonceAlreadyUsed(auth.account, auth.nonce);
        }

        Beav3rAuthorizationVerifier.VerificationResult memory verification =
            verifier.verifyExecutionAuthorization(auth, signature);
        if (!verification.isValid) {
            revert UnauthorizedSigner(verification.recoveredSigner, verification.trustedSigner);
        }

        usedNonces[auth.account][auth.nonce] = true;
        result = _executeAuthorized(to, value, data);

        verifiedExecutionCount += 1;
        emit VerifiedExecutionCountIncreased(auth.account, auth.nonce, verifiedExecutionCount);
        emit AuthorizedExecution(auth.account, to, auth.nonce, auth.actionHash);
        return result;
    }

    /// @notice Project-defined final execution path.
    /// @dev Called only after all Beav3r authorization checks pass (signer trust, account/executor binding, expiry, nonce replay, and action hash).
    ///      Implementations can route to custom logic (for example, token keeper or treasury modules).
    function _executeAuthorized(address to, uint256 value, bytes calldata data)
        internal
        virtual
        returns (bytes memory result);
}
