// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrielConstants} from "../src/libraries/OrielConstants.sol";
import {OrielOperationId} from "../src/libraries/OrielOperationId.sol";
import {OrielSchemaHash} from "../src/libraries/OrielSchemaHash.sol";

/// @notice Solidity <-> spec vector parity. The JSON under vectors/ is vendored
///         verbatim from oriel-spec; these tests are the cross-language gate.
contract VectorsTest is Test {
    string internal json;

    function setUp() public {
        json = vm.readFile("vectors/oriel-vectors.json");
    }

    function _b32(string memory path) internal view returns (bytes32) {
        return vm.parseJsonBytes32(json, path);
    }

    function test_domains() public view {
        assertEq(OrielConstants.CALL_DOMAIN, _b32(".domains.call.value"), "call domain vs vectors");
        assertEq(OrielConstants.EVENT_DOMAIN, _b32(".domains.event.value"), "event domain vs vectors");
    }

    function test_categories() public view {
        assertEq(OrielConstants.CATEGORY_DATA, _b32(".categories.data.value"));
        assertEq(OrielConstants.CATEGORY_TEMPORAL, _b32(".categories.temporal.value"));
        assertEq(OrielConstants.CATEGORY_RANDOMNESS, _b32(".categories.randomness.value"));
        assertEq(OrielConstants.CATEGORY_STATE, _b32(".categories.state.value"));
        assertEq(OrielConstants.CATEGORY_COMPUTATION, _b32(".categories.computation.value"));
        assertEq(OrielConstants.CATEGORY_MESSAGING, _b32(".categories.messaging.value"));
        assertEq(OrielConstants.CATEGORY_REGISTRY, _b32(".categories.registry.value"));
    }

    function test_callOperationId() public view {
        bytes4 selector = bytes4(keccak256("read(bytes32)"));
        assertEq(selector, bytes4(0x61da1439), "read(bytes32) selector");
        assertEq(
            OrielOperationId.callOperationId(selector),
            _b32(".operationIds.readCall.value"),
            "call opId vs vectors"
        );
    }

    function test_eventOperationId() public view {
        bytes32 topic0 = keccak256("OrielEvent(bytes32,uint256,bytes)");
        assertEq(topic0, _b32(".operationIds.orielEvent.topic0"), "event topic0 vs vectors");
        assertEq(
            OrielOperationId.eventOperationId(topic0),
            _b32(".operationIds.orielEvent.value"),
            "event opId vs vectors"
        );
    }

    function test_snapshotEventTopic0() public view {
        assertEq(
            keccak256("OrielSnapshotCommitted(uint256,address,bytes32,bytes32,bytes32)"),
            _b32(".snapshotEvent.topic0"),
            "snapshot topic0 vs vectors"
        );
    }

    function test_schemaHashes() public view {
        assertEq(OrielSchemaHash.schemaHash("()"), _b32(".schemaHashes.empty.value"));
        assertEq(OrielSchemaHash.schemaHash("(bytes32)"), _b32(".schemaHashes.bytes32.value"));
        assertEq(OrielSchemaHash.schemaHash("(bytes32,uint256)"), _b32(".schemaHashes.bytes32Uint256.value"));
        assertEq(OrielSchemaHash.schemaHash("(bytes)"), _b32(".schemaHashes.bytes.value"));
        assertEq(OrielSchemaHash.schemaHash("(bytes,uint256)"), _b32(".schemaHashes.bytesUint256.value"));
        assertEq(OrielSchemaHash.schemaHash("((address,uint256),bytes32)"), _b32(".schemaHashes.nestedTuple.value"));
        assertEq(OrielSchemaHash.schemaHash("(uint256[])"), _b32(".schemaHashes.uint256Array.value"));
        assertEq(OrielSchemaHash.schemaHash("(address[3])"), _b32(".schemaHashes.address3Array.value"));
    }

    /// @dev Schema hashing must be keccak of the raw string bytes, NOT abi.encode of the string.
    function test_schemaHashIsNotAbiEncode() public pure {
        assertTrue(OrielSchemaHash.schemaHash("(bytes32,uint256)") != keccak256(abi.encode("(bytes32,uint256)")));
    }
}
