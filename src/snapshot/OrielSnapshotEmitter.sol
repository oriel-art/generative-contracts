// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {IOrielSnapshotEvents} from "../interfaces/IOrielSnapshotEvents.sol";

/// @notice Mixin for mint contracts: emits the atomic snapshot commitment
///         (Oriel 0.7 section 9.2). The event alone is sufficient — inclusion
///         metadata (tx hash, block number/hash, log index) is derived by
///         runtimes and indexers from the event's position in the chain.
abstract contract OrielSnapshotEmitter is IOrielSnapshotEvents {
    function _commitSnapshot(
        uint256 tokenId,
        address capability,
        bytes32 operationId,
        bytes memory args,
        bytes memory result
    ) internal {
        emit OrielSnapshotCommitted(tokenId, capability, operationId, keccak256(args), keccak256(result));
    }
}
