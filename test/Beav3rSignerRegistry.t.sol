// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Beav3rSignerRegistry} from "../src/Beav3rSignerRegistry.sol";

contract Beav3rSignerRegistryTest is Test {
    Beav3rSignerRegistry internal registry;

    address internal owner = makeAddr("owner");
    address internal registrar = makeAddr("registrar");
    address internal nextRegistrar = makeAddr("nextRegistrar");
    address internal other = makeAddr("other");
    address internal account = makeAddr("account");
    address internal signer = makeAddr("signer");
    bytes32 internal keyId = keccak256(bytes("beav3r-server"));

    function setUp() public {
        registry = new Beav3rSignerRegistry(owner, registrar);
    }

    function testOwnerCanSetSigner() public {
        vm.prank(owner);
        registry.setSigner(account, keyId, signer);

        assertEq(registry.getSigner(account, keyId), signer);
    }

    function testRegistrarCanSetSigner() public {
        vm.prank(registrar);
        registry.setSigner(account, keyId, signer);

        assertEq(registry.getSigner(account, keyId), signer);
    }

    function testUnauthorizedAccountCannotSetSigner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Beav3rSignerRegistry.UnauthorizedRegistrar.selector, other));
        registry.setSigner(account, keyId, signer);
    }

    function testSetSignerRejectsZeroAddress() public {
        vm.prank(registrar);
        vm.expectRevert(Beav3rSignerRegistry.InvalidSigner.selector);
        registry.setSigner(account, keyId, address(0));
    }

    function testOwnerCanDisableSigner() public {
        vm.startPrank(owner);
        registry.setSigner(account, keyId, signer);
        registry.disableSigner(account, keyId);
        vm.stopPrank();

        assertEq(registry.getSigner(account, keyId), address(0));
    }

    function testRegistrarCanDisableSigner() public {
        vm.prank(registrar);
        registry.setSigner(account, keyId, signer);

        vm.prank(registrar);
        registry.disableSigner(account, keyId);

        assertEq(registry.getSigner(account, keyId), address(0));
    }

    function testUnauthorizedAccountCannotDisableSigner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Beav3rSignerRegistry.UnauthorizedRegistrar.selector, other));
        registry.disableSigner(account, keyId);
    }

    function testOwnerCanRotateRegistrar() public {
        vm.prank(owner);
        registry.setRegistrar(nextRegistrar);

        assertEq(registry.registrar(), nextRegistrar);

        vm.prank(nextRegistrar);
        registry.setSigner(account, keyId, signer);

        assertEq(registry.getSigner(account, keyId), signer);
    }

    function testNonOwnerCannotRotateRegistrar() public {
        vm.prank(registrar);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, registrar));
        registry.setRegistrar(nextRegistrar);
    }

    function testSetRegistrarRejectsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(Beav3rSignerRegistry.InvalidRegistrar.selector);
        registry.setRegistrar(address(0));
    }

    function testOwnerCanTransferOwnership() public {
        vm.prank(owner);
        registry.transferOwnership(other);

        assertEq(registry.owner(), other);

        vm.prank(other);
        registry.setSigner(account, keyId, signer);

        assertEq(registry.getSigner(account, keyId), signer);
    }
}
