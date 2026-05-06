// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title Phase5DemoToken
/// @notice Fixed-supply 6-decimal ERC20 used by the phase 5 demo flow.
contract Phase5DemoToken is ERC20 {
    uint8 private constant TOKEN_DECIMALS = 6;

    /// @notice Deploys the demo token and mints the initial supply.
    /// @param initialHolder Recipient of the initial token supply.
    /// @param initialSupply Initial token amount in base units.
    constructor(address initialHolder, uint256 initialSupply) ERC20("Beav3r Demo USD", "bUSDT") {
        _mint(initialHolder, initialSupply);
    }

    /// @notice Returns the token decimal precision.
    /// @return Decimal precision used by the token.
    function decimals() public pure override returns (uint8) {
        return TOKEN_DECIMALS;
    }
}
