// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Beav3rAuthorizationVerifier} from "../src/Beav3rAuthorizationVerifier.sol";
import {Beav3rSignerRegistry} from "../src/Beav3rSignerRegistry.sol";
import {Beav3rTypes} from "../src/libraries/Beav3rTypes.sol";

contract OnchainProtocolGoldenVectorsTest is Test {
    string internal constant GOLDEN_VECTORS_PATH = "spec/onchain/v1/golden-vectors.json";

    struct GoldenVector {
        address account;
        address target;
        address executor;
        uint256 chainId;
        uint256 nonce;
        uint256 expiresAt;
        bytes data;
        bytes32 actionHash;
        bytes32 digest;
        bytes32 keyId;
        bytes32 dataHash;
        address signer;
        bytes signature;
    }

    function testVerifierMatchesOnchainV1GoldenVector() public {
        GoldenVector memory vector = _loadGoldenVector();

        assertEq(keccak256(vector.data), vector.dataHash);

        Beav3rSignerRegistry registry = new Beav3rSignerRegistry(address(this), address(this));
        Beav3rAuthorizationVerifier verifier = new Beav3rAuthorizationVerifier(address(registry));
        registry.setSigner(vector.account, vector.keyId, vector.signer);

        assertEq(
            verifier.computeActionHash(
                vector.account,
                vector.target,
                0,
                vector.data,
                vector.chainId,
                vector.nonce,
                vector.expiresAt,
                vector.executor
            ),
            vector.actionHash
        );

        Beav3rTypes.ExecutionAuthorization memory auth = Beav3rTypes.ExecutionAuthorization({
            actionHash: vector.actionHash,
            account: vector.account,
            executor: vector.executor,
            chainId: vector.chainId,
            nonce: vector.nonce,
            expiresAt: vector.expiresAt,
            keyId: vector.keyId
        });

        assertEq(verifier.computeDigest(auth), vector.digest);

        Beav3rAuthorizationVerifier.VerificationResult memory result =
            verifier.verifyExecutionAuthorization(auth, vector.signature);
        assertTrue(result.isValid);
        assertEq(result.digest, vector.digest);
        assertEq(result.recoveredSigner, vector.signer);
        assertEq(result.trustedSigner, vector.signer);
    }

    function _loadGoldenVector() internal view returns (GoldenVector memory vector) {
        string memory json = vm.readFile(GOLDEN_VECTORS_PATH);
        string memory path = ".vectors[0]";

        vector.account = vm.parseJsonAddress(json, string.concat(path, ".request.account"));
        vector.target = vm.parseJsonAddress(json, string.concat(path, ".request.to"));
        vector.executor = vm.parseJsonAddress(json, string.concat(path, ".request.executor"));
        vector.chainId = vm.parseJsonUint(json, string.concat(path, ".request.chainId"));
        vector.nonce = vm.parseJsonUint(json, string.concat(path, ".request.nonce"));
        vector.expiresAt = vm.parseJsonUint(json, string.concat(path, ".request.expiresAt"));
        vector.data = vm.parseJsonBytes(json, string.concat(path, ".request.data"));
        vector.actionHash = vm.parseJsonBytes32(json, string.concat(path, ".expected.actionHash"));
        vector.digest = vm.parseJsonBytes32(json, string.concat(path, ".expected.digest"));
        vector.keyId = vm.parseJsonBytes32(json, string.concat(path, ".expected.keyIdHash"));
        vector.dataHash = vm.parseJsonBytes32(json, string.concat(path, ".expected.dataHash"));
        vector.signer = vm.parseJsonAddress(json, string.concat(path, ".signerAddress"));
        vector.signature = vm.parseJsonBytes(json, string.concat(path, ".artifact.signature"));
    }
}
