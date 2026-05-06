// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IBeav3rSignerRegistry} from "./interfaces/IBeav3rSignerRegistry.sol";

/// @title Beav3rSignerRegistry
/// @notice Owner-governed registry of trusted Beav3r signing keys by account and key id.
/// @dev The verifier reads this registry to decide whether a recovered authorization signer is trusted.
contract Beav3rSignerRegistry is Ownable, IBeav3rSignerRegistry {
    error InvalidRegistrar();
    error InvalidSigner();
    error UnauthorizedRegistrar(address account);

    event RegistrarConfigured(address indexed registrar);
    event SignerConfigured(address indexed account, bytes32 indexed keyId, address indexed signer);
    event SignerDisabled(address indexed account, bytes32 indexed keyId);

    /// @notice Operational account allowed to configure trusted signer mappings.
    address public registrar;

    // Trusted signer lookup by account and key id.
    mapping(address account => mapping(bytes32 keyId => address signer)) private signers;

    modifier onlyRegistrarOrOwner() {
        if (msg.sender != owner() && msg.sender != registrar) {
            revert UnauthorizedRegistrar(msg.sender);
        }
        _;
    }

    /// @notice Deploys the registry with an owner and operational registrar.
    /// @param initialOwner Owner allowed to rotate the registrar and perform emergency signer management.
    /// @param initialRegistrar Operational account allowed to configure and disable signers.
    constructor(address initialOwner, address initialRegistrar) Ownable(initialOwner) {
        _setRegistrar(initialRegistrar);
    }

    /// @notice Rotates the operational registrar.
    /// @param newRegistrar New operational account allowed to configure and disable signers.
    function setRegistrar(address newRegistrar) external onlyOwner {
        _setRegistrar(newRegistrar);
    }

    /// @notice Configures a trusted signer for an account key id.
    /// @param account Actor account that owns the key id.
    /// @param keyId Key identifier used by authorization payloads.
    /// @param signer Trusted signer address for the account key id.
    function setSigner(address account, bytes32 keyId, address signer) external onlyRegistrarOrOwner {
        if (signer == address(0)) {
            revert InvalidSigner();
        }
        signers[account][keyId] = signer;
        emit SignerConfigured(account, keyId, signer);
    }

    /// @notice Disables the trusted signer for an account key id.
    /// @param account Actor account that owns the key id.
    /// @param keyId Key identifier to disable.
    function disableSigner(address account, bytes32 keyId) external onlyRegistrarOrOwner {
        delete signers[account][keyId];
        emit SignerDisabled(account, keyId);
    }

    /// @inheritdoc IBeav3rSignerRegistry
    function getSigner(address account, bytes32 keyId) external view returns (address) {
        return signers[account][keyId];
    }

    function _setRegistrar(address newRegistrar) internal {
        if (newRegistrar == address(0)) {
            revert InvalidRegistrar();
        }
        registrar = newRegistrar;
        emit RegistrarConfigured(newRegistrar);
    }
}
