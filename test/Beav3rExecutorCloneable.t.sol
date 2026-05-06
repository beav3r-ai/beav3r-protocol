// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Beav3rSignerRegistry} from "../src/Beav3rSignerRegistry.sol";
import {Beav3rAuthorizationVerifier} from "../src/Beav3rAuthorizationVerifier.sol";
import {Beav3rExecutorCloneable} from "../src/Beav3rExecutorCloneable.sol";
import {Beav3rTypes} from "../src/libraries/Beav3rTypes.sol";

contract Recorder {
    uint256 public lastNumber;
    uint256 public callCount;
    address public lastSender;

    function record(uint256 number) external payable returns (bytes32) {
        lastNumber = number;
        callCount += 1;
        lastSender = msg.sender;
        return keccak256(abi.encode(number, callCount));
    }
}

contract Reverter {
    error DownstreamFailure(uint256 code);

    function failWithCustomError(uint256 code) external pure {
        revert DownstreamFailure(code);
    }
}

contract Beav3rExecutorCloneableTest is Test {
    bytes32 internal constant KEY_ID = keccak256(bytes("beav3r-server"));

    event AuthorizedExecution(
        address indexed account, address indexed target, uint256 indexed nonce, bytes32 actionHash
    );

    Beav3rSignerRegistry internal registry;
    Beav3rAuthorizationVerifier internal verifier;
    Beav3rExecutorCloneable internal executor;
    Recorder internal recorder;
    Reverter internal reverter;

    uint256 internal authorityPk;
    address internal authoritySigner;
    address internal account;
    uint256 internal chainId;

    function setUp() public {
        registry = new Beav3rSignerRegistry(address(this), address(this));
        verifier = new Beav3rAuthorizationVerifier(address(registry));
        executor = new Beav3rExecutorCloneable();
        recorder = new Recorder();
        reverter = new Reverter();

        authorityPk = 0xA11CE;
        authoritySigner = vm.addr(authorityPk);
        account = makeAddr("account");
        chainId = block.chainid;

        executor.initialize(address(verifier), account);
        registry.setSigner(account, KEY_ID, authoritySigner);
    }

    function testInitializeRevertsAlreadyInitialized() public {
        vm.expectRevert(Beav3rExecutorCloneable.AlreadyInitialized.selector);
        executor.initialize(address(verifier), account);
    }

    function testInitializeRevertsInvalidVerifier() public {
        Beav3rExecutorCloneable freshExecutor = new Beav3rExecutorCloneable();

        vm.expectRevert(Beav3rExecutorCloneable.InvalidVerifier.selector);
        freshExecutor.initialize(address(0), account);
    }

    function testInitializeRevertsInvalidOwner() public {
        Beav3rExecutorCloneable freshExecutor = new Beav3rExecutorCloneable();

        vm.expectRevert(Beav3rExecutorCloneable.InvalidOwner.selector);
        freshExecutor.initialize(address(verifier), address(0));
    }

    function testExecuteWithAuthRevertsWhenUninitialized() public {
        Beav3rExecutorCloneable freshExecutor = new Beav3rExecutorCloneable();
        bytes memory data = abi.encodeCall(Recorder.record, (1));
        Beav3rTypes.ExecutionAuthorization memory auth = Beav3rTypes.ExecutionAuthorization({
            actionHash: bytes32(uint256(1)),
            account: account,
            executor: address(freshExecutor),
            chainId: block.chainid,
            nonce: 1,
            expiresAt: block.timestamp + 1 hours,
            keyId: KEY_ID
        });

        vm.expectRevert(Beav3rExecutorCloneable.Uninitialized.selector);
        freshExecutor.executeWithAuth(address(recorder), 0, data, auth, "");
    }

    function testSuccessfulAuthorizedExecution() public {
        (Beav3rTypes.ExecutionAuthorization memory auth, bytes memory signature, bytes memory data) =
            buildAuthorization(1, 777, false);

        vm.expectEmit(true, true, true, true, address(executor));
        emit AuthorizedExecution(account, address(recorder), 1, auth.actionHash);

        bytes memory result = executor.executeWithAuth(address(recorder), 0, data, auth, signature);

        assertEq(recorder.lastNumber(), 777);
        assertEq(recorder.callCount(), 1);
        assertEq(recorder.lastSender(), address(executor));
        assertTrue(executor.isNonceUsed(account, 1));
        assertEq(result.length, 32);
    }

    function testWrongSignerReverts() public {
        (Beav3rTypes.ExecutionAuthorization memory auth,, bytes memory data) = buildAuthorization(2, 888, false);
        address wrongSigner = vm.addr(0xB0B);
        bytes memory wrongSignature = signWithKey(0xB0B, auth);

        vm.expectRevert(
            abi.encodeWithSelector(Beav3rExecutorCloneable.UnauthorizedSigner.selector, wrongSigner, authoritySigner)
        );
        executor.executeWithAuth(address(recorder), 0, data, auth, wrongSignature);
    }

    function testWrongActionHashReverts() public {
        (Beav3rTypes.ExecutionAuthorization memory auth, bytes memory signature, bytes memory data) =
            buildAuthorization(3, 999, false);
        auth.actionHash = bytes32(uint256(auth.actionHash) ^ 1);

        vm.expectRevert();
        executor.executeWithAuth(address(recorder), 0, data, auth, signature);
    }

    function testExpiredArtifactReverts() public {
        (Beav3rTypes.ExecutionAuthorization memory auth, bytes memory signature, bytes memory data) =
            buildAuthorization(4, 123, false);
        vm.warp(auth.expiresAt);

        vm.expectRevert(
            abi.encodeWithSelector(
                Beav3rExecutorCloneable.AuthorizationExpired.selector, auth.expiresAt, block.timestamp
            )
        );
        executor.executeWithAuth(address(recorder), 0, data, auth, signature);
    }

    function testWrongExecutorReverts() public {
        (Beav3rTypes.ExecutionAuthorization memory auth, bytes memory signature, bytes memory data) =
            buildAuthorization(5, 456, false);
        auth.executor = makeAddr("other-executor");
        signature = signWithKey(authorityPk, auth);

        vm.expectRevert(
            abi.encodeWithSelector(Beav3rExecutorCloneable.InvalidExecutor.selector, auth.executor, address(executor))
        );
        executor.executeWithAuth(address(recorder), 0, data, auth, signature);
    }

    function testWrongAccountReverts() public {
        (Beav3rTypes.ExecutionAuthorization memory auth, bytes memory signature, bytes memory data) =
            buildAuthorization(6, 654, false);
        address wrongAccount = makeAddr("wrong-account");
        auth.account = wrongAccount;
        signature = signWithKey(authorityPk, auth);

        vm.expectRevert(abi.encodeWithSelector(Beav3rExecutorCloneable.InvalidAccount.selector, account, wrongAccount));
        executor.executeWithAuth(address(recorder), 0, data, auth, signature);
    }

    function testReplayViaNonceReuseReverts() public {
        (Beav3rTypes.ExecutionAuthorization memory auth, bytes memory signature, bytes memory data) =
            buildAuthorization(7, 654, false);

        executor.executeWithAuth(address(recorder), 0, data, auth, signature);

        vm.expectRevert(abi.encodeWithSelector(Beav3rExecutorCloneable.NonceAlreadyUsed.selector, account, uint256(7)));
        executor.executeWithAuth(address(recorder), 0, data, auth, signature);
    }

    function testInvalidChainIdReverts() public {
        (Beav3rTypes.ExecutionAuthorization memory auth, bytes memory signature, bytes memory data) =
            buildAuthorization(8, 7777, false);
        auth.chainId = chainId + 1;
        signature = signWithKey(authorityPk, auth);

        vm.expectRevert(
            abi.encodeWithSelector(Beav3rExecutorCloneable.InvalidChainId.selector, auth.chainId, block.chainid)
        );
        executor.executeWithAuth(address(recorder), 0, data, auth, signature);
    }

    function testExecutionFailedPropagatesRevertData() public {
        bytes memory data = abi.encodeCall(Reverter.failWithCustomError, (42));
        uint256 nonce = 9;
        uint256 expiresAt = block.timestamp + 1 hours;
        Beav3rTypes.ExecutionAuthorization memory auth = Beav3rTypes.ExecutionAuthorization({
            actionHash: verifier.computeActionHash(
                account, address(reverter), 0, data, chainId, nonce, expiresAt, address(executor)
            ),
            account: account,
            executor: address(executor),
            chainId: chainId,
            nonce: nonce,
            expiresAt: expiresAt,
            keyId: KEY_ID
        });
        bytes memory signature = signWithKey(authorityPk, auth);
        bytes memory expectedRevertData = abi.encodeWithSelector(Reverter.DownstreamFailure.selector, 42);

        vm.expectRevert(abi.encodeWithSelector(Beav3rExecutorCloneable.ExecutionFailed.selector, expectedRevertData));
        executor.executeWithAuth(address(reverter), 0, data, auth, signature);
    }

    function buildAuthorization(uint256 nonce, uint256 valueToRecord, bool expired)
        internal
        view
        returns (Beav3rTypes.ExecutionAuthorization memory auth, bytes memory signature, bytes memory data)
    {
        data = abi.encodeCall(Recorder.record, (valueToRecord));
        uint256 expiresAt = expired ? block.timestamp - 1 : block.timestamp + 1 hours;

        auth = Beav3rTypes.ExecutionAuthorization({
            actionHash: verifier.computeActionHash(
                account, address(recorder), 0, data, chainId, nonce, expiresAt, address(executor)
            ),
            account: account,
            executor: address(executor),
            chainId: chainId,
            nonce: nonce,
            expiresAt: expiresAt,
            keyId: KEY_ID
        });

        signature = signWithKey(authorityPk, auth);
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
