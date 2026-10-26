// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {OrielConstants} from "./OrielConstants.sol";

/// @notice Operation-id derivation (Oriel 0.7 §7.8).
library OrielOperationId {
    /// @dev For calls: keccak256(abi.encode(CALL_DOMAIN, bytes32(uint256(uint32(selector))))).
    function callOperationId(bytes4 selector) internal pure returns (bytes32) {
        return keccak256(abi.encode(OrielConstants.CALL_DOMAIN, bytes32(uint256(uint32(selector)))));
    }

    /// @dev For events: keccak256(abi.encode(EVENT_DOMAIN, topic0)).
    function eventOperationId(bytes32 topic0) internal pure returns (bytes32) {
        return keccak256(abi.encode(OrielConstants.EVENT_DOMAIN, topic0));
    }
}
