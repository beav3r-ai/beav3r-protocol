// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Phase5DemoToken} from "../src/demo/Phase5DemoToken.sol";
import {Beav3rTestUSDT} from "../src/demo/Beav3rTestUSDT.sol";

contract Phase5DemoTokenTest is Test {
    function testConstructorMintsInitialSupplyAndSetsDecimalsToSix() public {
        address initialHolder = makeAddr("initial-holder");
        uint256 initialSupply = 123_456_789;

        Phase5DemoToken token = new Phase5DemoToken(initialHolder, initialSupply);

        assertEq(token.decimals(), 6);
        assertEq(token.balanceOf(initialHolder), initialSupply);
        assertEq(token.totalSupply(), initialSupply);
    }
}

contract Beav3rTestUSDTTest is Test {
    function testDecimalsIsSix() public {
        Beav3rTestUSDT token = new Beav3rTestUSDT(address(this));

        assertEq(token.decimals(), 6);
    }

    function testOnlyOwnerCanMint() public {
        address owner = makeAddr("owner");
        address nonOwner = makeAddr("non-owner");
        address recipient = makeAddr("recipient");

        Beav3rTestUSDT token = new Beav3rTestUSDT(owner);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        token.mint(recipient, 1);
    }

    function testMintUpdatesRecipientBalanceAndTotalSupply() public {
        address owner = makeAddr("owner");
        address recipient = makeAddr("recipient");
        uint256 amount = 50_000_000;

        Beav3rTestUSDT token = new Beav3rTestUSDT(owner);

        vm.prank(owner);
        token.mint(recipient, amount);

        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.totalSupply(), amount);
    }
}
