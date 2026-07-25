// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

/// @notice Schema hashing (Oriel 0.7 §7.9): keccak256 of the UTF-8 bytes of the
///         canonical ABI tuple string. No whitespace, canonical type names,
///         parenthesized nesting. NOT abi.encode of the string.
library OrielSchemaHash {
    function schemaHash(string memory canonicalTuple) internal pure returns (bytes32) {
        return keccak256(bytes(canonicalTuple));
    }
}
