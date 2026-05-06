// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Beav3rSignerRegistry} from "../src/Beav3rSignerRegistry.sol";
import {Beav3rAuthorizationVerifier} from "../src/Beav3rAuthorizationVerifier.sol";
import {Beav3rExecutorFactory} from "../src/Beav3rExecutorFactory.sol";
import {Beav3rExecutorCloneable} from "../src/Beav3rExecutorCloneable.sol";
import {Beav3rTypes} from "../src/libraries/Beav3rTypes.sol";

contract RecorderV2 {
    uint256 public lastNumber;
    address public lastSender;

    function record(uint256 number) external {
        lastNumber = number;
        lastSender = msg.sender;
    }
}

contract Beav3rExecutorFactoryTest is Test {
    bytes32 internal constant KEY_ID = keccak256(bytes("beav3r-server"));

    Beav3rSignerRegistry internal registry;
    Beav3rAuthorizationVerifier internal verifier;
    Beav3rExecutorFactory internal factory;
    RecorderV2 internal recorder;

    uint256 internal authorityPk;
    address internal authoritySigner;
    address internal owner;

    function setUp() public {
        registry = new Beav3rSignerRegistry(address(this), address(this));
        verifier = new Beav3rAuthorizationVerifier(address(registry));
        factory = new Beav3rExecutorFactory(address(verifier));
        recorder = new RecorderV2();

        authorityPk = 0xA11CE;
        authoritySigner = vm.addr(authorityPk);
        owner = makeAddr("owner");
        registry.setSigner(owner, KEY_ID, authoritySigner);
    }

    function testConstructorRevertsForZeroVerifier() public {
        vm.expectRevert(Beav3rExecutorFactory.InvalidVerifier.selector);
        new Beav3rExecutorFactory(address(0));
    }

    function testProvisionCloneAndExecute() public {
        address executorAddr = factory.provisionExecutor(owner);
        Beav3rExecutorCloneable executor = Beav3rExecutorCloneable(payable(executorAddr));

        bytes memory data = abi.encodeCall(RecorderV2.record, (4242));
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuth(executorAddr, data);

        bytes32 digest = verifier.computeDigest(auth);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authorityPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        executor.executeWithAuth(address(recorder), 0, data, auth, signature);
        assertEq(recorder.lastNumber(), 4242);
        assertEq(recorder.lastSender(), executorAddr);
    }

    function testProvisionedCloneRevertsForInvalidAccount() public {
        address executorAddr = factory.provisionExecutor(owner);
        Beav3rExecutorCloneable executor = Beav3rExecutorCloneable(payable(executorAddr));

        address wrongAccount = makeAddr("wrong-account");
        bytes memory data = abi.encodeCall(RecorderV2.record, (777));
        Beav3rTypes.ExecutionAuthorization memory auth = buildAuth(executorAddr, data);
        auth.account = wrongAccount;

        vm.expectRevert(abi.encodeWithSelector(Beav3rExecutorCloneable.InvalidAccount.selector, owner, wrongAccount));
        executor.executeWithAuth(address(recorder), 0, data, auth, "");
    }

    function testProvisionExecutorRevertsForZeroOwner() public {
        vm.expectRevert(Beav3rExecutorFactory.InvalidOwner.selector);
        factory.provisionExecutor(address(0));
    }

    function buildAuth(address executorAddr, bytes memory data)
        internal
        view
        returns (Beav3rTypes.ExecutionAuthorization memory)
    {
        uint256 nonce = 1;
        uint256 expiresAt = block.timestamp + 1 hours;
        return Beav3rTypes.ExecutionAuthorization({
            actionHash: verifier.computeActionHash(
                owner, address(recorder), 0, data, block.chainid, nonce, expiresAt, executorAddr
            ),
            account: owner,
            executor: executorAddr,
            chainId: block.chainid,
            nonce: nonce,
            expiresAt: expiresAt,
            keyId: KEY_ID
        });
    }
}
