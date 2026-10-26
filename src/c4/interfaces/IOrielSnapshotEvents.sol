// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

/// @notice Atomic snapshot commitment event, emitted by mint contracts (Oriel 0.7 §9.2).
/// @dev topic0 = keccak256("OrielSnapshotCommitted(uint256,address,bytes32,bytes32,bytes32)")
///      — asserted against vectors/c4/oriel-vectors.json in test/c4/Vectors.t.sol.
interface IOrielSnapshotEvents {
    event OrielSnapshotCommitted(
        uint256 indexed tokenId,
        address indexed capability,
        bytes32 indexed operationId,
        bytes32 argumentsHash,
        bytes32 resultHash
    );
}
