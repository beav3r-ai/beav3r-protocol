// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Clones} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Beav3rExecutorCloneable} from "./Beav3rExecutorCloneable.sol";

/// @title Beav3rExecutorFactory
/// @notice Beav3r-operated provisioning contract for trusted executor clones.
/// @dev Integrators trust the provisioned executor address. The factory stays in the repo and deployment records
///      so clone provenance is verifiable, but it is not the downstream integration surface.
contract Beav3rExecutorFactory {
    error InvalidOwner();
    error InvalidVerifier();

    address public immutable implementation;
    address public immutable verifier;

    event ExecutorProvisioned(address indexed owner, address indexed executor);

    /// @notice Deploys the factory and its clone implementation.
    /// @param verifierAddress Verifier assigned to all provisioned clones.
    constructor(address verifierAddress) {
        if (verifierAddress == address(0)) {
            revert InvalidVerifier();
        }
        verifier = verifierAddress;
        implementation = address(new Beav3rExecutorCloneable());
    }

    /// @notice Provisions a trusted executor clone for an actor account.
    /// @param owner Actor account that authorizations must reference.
    /// @return executor Address of the initialized clone.
    function provisionExecutor(address owner) external returns (address executor) {
        if (owner == address(0)) {
            revert InvalidOwner();
        }
        executor = Clones.clone(implementation);
        Beav3rExecutorCloneable(payable(executor)).initialize(verifier, owner);
        emit ExecutorProvisioned(owner, executor);
    }
}
