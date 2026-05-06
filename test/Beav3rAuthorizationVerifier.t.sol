// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Beav3rAuthorizationVerifier} from "../src/Beav3rAuthorizationVerifier.sol";
import {Beav3rSignerRegistry} from "../src/Beav3rSignerRegistry.sol";
import {Beav3rTypes} from "../src/libraries/Beav3rTypes.sol";

contract Beav3rAuthorizationVerifierTest is Test {
    bytes32 internal constant KEY_ID = keccak256(bytes("beav3r-server"));
    bytes32 internal constant OTHER_KEY_ID = keccak256(bytes("other-key"));

    Beav3rSignerRegistry internal registry;
    Beav3rAuthorizationVerifier internal verifier;

    uint256 internal authorityPk;
    address internal authoritySigner;
    address internal account;
    address internal target;
    address internal executor;
    bytes internal callData;

    function setUp() public {
        registry = new Beav3rSignerRegistry(address(this), address(this));
        verifier = new Beav3rAuthorizationVerifier(address(registry));

        authorityPk = 0xA11CE;
        authoritySigner = vm.addr(authorityPk);
        account = makeAddr("account");
        target = makeAddr("target");
        executor = makeAddr("executor");
        callData = abi.encodeWithSignature("record(uint256)", 123);

        registry.setSigner(account, KEY_ID, authoritySigner);
    }

    function testConstructorRevertsForZeroRegistry() public {
        vm.expectRevert(Beav3rAuthorizationVerifier.InvalidRegistry.selector);
        new Beav3rAuthorizationVerifier(address(0));
    }

    function testVerifyExecutionAuthorizationAcceptsRegisteredSigner() public {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuthorization(1);
        bytes memory signature = signWithKey(authorityPk, auth);

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, signature);

        assertTrue(result.isValid);
        assertEq(result.recoveredSigner, authoritySigner);
        assertEq(result.trustedSigner, authoritySigner);
        assertEq(result.digest, verifier.computeDigest(auth));
    }

    function testVerifyExecutionAuthorizationRejectsWrongSigner() public {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuthorization(2);
        uint256 wrongPk = 0xB0B;
        address wrongSigner = vm.addr(wrongPk);
        bytes memory signature = signWithKey(wrongPk, auth);

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, signature);

        assertFalse(result.isValid);
        assertEq(result.recoveredSigner, wrongSigner);
        assertEq(result.trustedSigner, authoritySigner);
    }

    function testVerifyExecutionAuthorizationRejectsUnregisteredKey() public {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuthorization(3);
        auth.keyId = OTHER_KEY_ID;
        bytes memory signature = signWithKey(authorityPk, auth);

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, signature);

        assertFalse(result.isValid);
        assertEq(result.recoveredSigner, authoritySigner);
        assertEq(result.trustedSigner, address(0));
    }

    function testVerifyExecutionAuthorizationRejectsMalformedSignature() public {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuthorization(4);

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, hex"1234");

        assertFalse(result.isValid);
        assertEq(result.recoveredSigner, address(0));
        assertEq(result.trustedSigner, authoritySigner);
    }

    function testVerifyExecutionAuthorizationRejectsTamperedActionHash() public {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuthorization(5);
        bytes memory signature = signWithKey(authorityPk, auth);
        auth.actionHash = bytes32(uint256(auth.actionHash) ^ 1);

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, signature);

        assertFalse(result.isValid);
        assertNotEq(result.recoveredSigner, authoritySigner);
        assertEq(result.trustedSigner, authoritySigner);
    }

    function testVerifyExecutionAuthorizationRejectsTamperedChainId() public {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuthorization(6);
        bytes memory signature = signWithKey(authorityPk, auth);
        auth.chainId = block.chainid + 1;

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, signature);

        assertFalse(result.isValid);
        assertNotEq(result.recoveredSigner, authoritySigner);
        assertEq(result.trustedSigner, authoritySigner);
    }

    function testVerifyExecutionAuthorizationRejectsTamperedExecutorDomain() public {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuthorization(7);
        bytes memory signature = signWithKey(authorityPk, auth);
        auth.executor = makeAddr("other-executor");

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, signature);

        assertFalse(result.isValid);
        assertNotEq(result.recoveredSigner, authoritySigner);
        assertEq(result.trustedSigner, authoritySigner);
    }

    function testVerifyExecutionAuthorizationRejectsTamperedExpiry() public {
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuthorization(8);
        bytes memory signature = signWithKey(authorityPk, auth);
        auth.expiresAt += 1;

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, signature);

        assertFalse(result.isValid);
        assertNotEq(result.recoveredSigner, authoritySigner);
        assertEq(result.trustedSigner, authoritySigner);
    }

    function buildAuthorization(uint256 nonce) internal view returns (Beav3rTypes.ExecutionAuthorization memory auth) {
        uint256 expiresAt = block.timestamp + 1 hours;

        auth = Beav3rTypes.ExecutionAuthorization({
            actionHash: verifier.computeActionHash(
                account, target, 0.25 ether, callData, block.chainid, nonce, expiresAt, executor
            ),
            account: account,
            executor: executor,
            chainId: block.chainid,
            nonce: nonce,
            expiresAt: expiresAt,
            keyId: KEY_ID
        });
    }

    function signWithKey(uint256 signerPk, Beav3rTypes.ExecutionAuthorization memory auth)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = verifier.computeDigest(auth);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
