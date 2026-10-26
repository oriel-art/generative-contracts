// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {OperationDescriptorCore} from "../types/OrielTypes.sol";

/// @notice Descriptor-core hashing (Oriel 0.7 section 7.8, erratum E10).
/// @dev Preimage = abi.encode(core) as a single static argument: 14 in-place
///      32-byte words in Appendix A field order. Registry approval binds to it;
///      metadata changes never affect it.
library OrielDescriptorHash {
    function hashCore(OperationDescriptorCore memory core) internal pure returns (bytes32) {
        return keccak256(abi.encode(core));
    }
}
