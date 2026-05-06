// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Beav3rActionHashLib} from "../src/libraries/Beav3rActionHashLib.sol";
import {Beav3rTypes} from "../src/libraries/Beav3rTypes.sol";
import {Beav3rVerifierLib} from "../src/libraries/Beav3rVerifierLib.sol";

contract Beav3rProtocolLibraryHarness {
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

    function computeDomainSeparator(uint256 chainId, address verifyingContract) external pure returns (bytes32) {
        return Beav3rVerifierLib.computeDomainSeparator(chainId, verifyingContract);
    }

    function computeStructHash(Beav3rTypes.ExecutionAuthorization calldata auth) external pure returns (bytes32) {
        return Beav3rVerifierLib.computeStructHash(auth);
    }

    function computeDigest(Beav3rTypes.ExecutionAuthorization calldata auth) external pure returns (bytes32) {
        return Beav3rVerifierLib.computeDigest(auth);
    }

    function recoverSigner(bytes32 digest, bytes calldata signature) external pure returns (address) {
        return Beav3rVerifierLib.recoverSigner(digest, signature);
    }
}

contract Beav3rProtocolLibrariesTest is Test {
    bytes32 internal constant EXECUTION_AUTHORIZATION_TYPEHASH = keccak256(
        "ExecutionAuthorization(bytes32 actionHash,address account,address executor,uint256 chainId,uint256 nonce,uint256 expiresAt,bytes32 keyId)"
    );
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant DOMAIN_NAME_HASH = keccak256(bytes("Beav3rExecutionAuthorization"));
    bytes32 internal constant DOMAIN_VERSION_HASH = keccak256(bytes("1"));

    Beav3rProtocolLibraryHarness internal harness;

    address internal account = makeAddr("account");
    address internal target = makeAddr("target");
    address internal executor = makeAddr("executor");
    bytes32 internal keyId = keccak256(bytes("beav3r-server"));
    bytes internal data = abi.encodeWithSignature("record(uint256)", 123);
    uint256 internal chainId = 84532;
    uint256 internal nonce = 42;
    uint256 internal expiresAt = 1_900_000_000;

    function setUp() public {
        harness = new Beav3rProtocolLibraryHarness();
    }

    function testActionHashMatchesProtocolEncoding() public view {
        bytes32 expected =
            keccak256(abi.encode(account, target, 7, keccak256(data), chainId, nonce, expiresAt, executor));

        bytes32 actual = harness.computeActionHash(account, target, 7, data, chainId, nonce, expiresAt, executor);

        assertEq(actual, expected);
    }

    function testActionHashChangesWhenCalldataChanges() public view {
        bytes32 original = harness.computeActionHash(account, target, 0, data, chainId, nonce, expiresAt, executor);
        bytes memory changedData = abi.encodeWithSignature("record(uint256)", 456);

        bytes32 changed =
            harness.computeActionHash(account, target, 0, changedData, chainId, nonce, expiresAt, executor);

        assertTrue(changed != original);
    }

    function testVerifierDigestMatchesManualEIP712Digest() public view {
        bytes32 actionHash = harness.computeActionHash(account, target, 0, data, chainId, nonce, expiresAt, executor);
        Beav3rTypes.ExecutionAuthorization memory auth = Beav3rTypes.ExecutionAuthorization({
            actionHash: actionHash,
            account: account,
            executor: executor,
            chainId: chainId,
            nonce: nonce,
            expiresAt: expiresAt,
            keyId: keyId
        });

        bytes32 domainSeparator =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, DOMAIN_NAME_HASH, DOMAIN_VERSION_HASH, chainId, executor));
        bytes32 structHash = keccak256(
            abi.encode(
                EXECUTION_AUTHORIZATION_TYPEHASH, actionHash, account, executor, chainId, nonce, expiresAt, keyId
            )
        );
        bytes32 expectedDigest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        assertEq(harness.computeDomainSeparator(chainId, executor), domainSeparator);
        assertEq(harness.computeStructHash(auth), structHash);
        assertEq(harness.computeDigest(auth), expectedDigest);
    }

    function testRecoverSignerReturnsSignerForValidSignature() public view {
        uint256 pk = 0xA11CE;
        address signer = vm.addr(pk);
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuth();
        bytes32 digest = harness.computeDigest(auth);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(harness.recoverSigner(digest, signature), signer);
    }

    function testRecoverSignerReturnsZeroForMalformedSignature() public view {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuth();
        bytes32 digest = harness.computeDigest(auth);

        assertEq(harness.recoverSigner(digest, hex"1234"), address(0));
    }

    function buildAuth() internal view returns (Beav3rTypes.ExecutionAuthorization memory auth) {
        bytes32 actionHash = harness.computeActionHash(account, target, 0, data, chainId, nonce, expiresAt, executor);
        auth = Beav3rTypes.ExecutionAuthorization({
            actionHash: actionHash,
            account: account,
            executor: executor,
            chainId: chainId,
            nonce: nonce,
            expiresAt: expiresAt,
            keyId: keyId
        });
    }
}
