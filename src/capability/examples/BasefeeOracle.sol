// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {OrielCapabilityBase} from "../OrielCapabilityBase.sol";
import {OrielConstants} from "../../libraries/OrielConstants.sol";
import {OrielSchemaHash} from "../../libraries/OrielSchemaHash.sol";

/// @notice Data capability: current block base fee. The simplest possible
///         Oriel capability — the spec's Secure Minimum scenario.
///         Deterministic per block, no dependencies, no keeper.
contract BasefeeOracle is OrielCapabilityBase {
    constructor()
        OrielCapabilityBase(
            OrielConstants.CATEGORY_DATA,
            "0.1.0",
            "Current block base fee in wei. Deterministic per block height; no dependencies, no keeper, no external feed."
        )
    {
        _addOperation(
            _callCore(
                bytes4(keccak256("basefeeWei()")),
                OrielConstants.MUTABILITY_VIEW,
                OrielSchemaHash.schemaHash("()"),
                OrielSchemaHash.schemaHash("(uint256)"),
                0, // privacyTier
                32, // maxResponseBytes
                0, // maxArgumentBytes
                50_000, // maxGas
                0 // minCallIntervalSeconds
            ),
            _meta("basefeeWei", "Base fee of the current block, in wei.")
        );
    }

    function basefeeWei() external view returns (uint256) {
        return block.basefee;
    }
}
