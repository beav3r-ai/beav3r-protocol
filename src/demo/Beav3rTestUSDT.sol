// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title Beav3rTestUSDT
/// @notice Mintable 6-decimal ERC20 used for Beav3r local and demo flows.
contract Beav3rTestUSDT is ERC20, Ownable {
    uint8 private constant TOKEN_DECIMALS = 6;

    /// @notice Deploys the demo token with an owner authorized to mint.
    /// @param initialOwner Owner allowed to mint test tokens.
    constructor(address initialOwner) ERC20("Beav3r Test USDT", "bUSDT") Ownable(initialOwner) {}

    /// @notice Returns the token decimal precision.
    /// @return Decimal precision used by the token.
    function decimals() public pure override returns (uint8) {
        return TOKEN_DECIMALS;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
