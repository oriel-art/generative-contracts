// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {DependencyCore} from "../types/OrielTypes.sol";

/// @notice Dependency-set hashing (Oriel 0.7 section 8.4, erratum E9).
/// @dev Preimage = abi.encode(deps) as a single dynamic-array argument
///      (leading 0x20 offset word + length + elements), elements canonically
///      ordered by strictly ascending target.
library OrielDependencyHash {
    function hashDependencies(DependencyCore[] memory deps) internal pure returns (bytes32) {
        return keccak256(abi.encode(deps));
    }

    function requireAscending(DependencyCore[] memory deps) internal pure {
        for (uint256 i = 1; i < deps.length; i++) {
            require(deps[i].target > deps[i - 1].target, "DEPS_UNSORTED");
        }
    }
}
