// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {OrielCapabilityBase} from "../OrielCapabilityBase.sol";
import {OrielConstants} from "../../libraries/OrielConstants.sol";
import {OrielSchemaHash} from "../../libraries/OrielSchemaHash.sol";

/// @notice Data capability: mean lunar phase, derived purely from block time.
/// @dev Trust model: this is the MEAN synodic phase (constant-period model,
///      reference new moon 2000-01-06T18:14Z, synodic month 2551443 s). The
///      apparent phase can deviate by up to ~15 hours due to orbital
///      eccentricity. No keeper, no external feed, no dependencies — the
///      strongest possible availability guarantee, at documented precision.
contract LunarOracle is OrielCapabilityBase {
    uint256 public constant REFERENCE_NEW_MOON = 947182440; // 2000-01-06T18:14:00Z
    uint256 public constant SYNODIC_MONTH_SECONDS = 2551443; // 29.530590 days

    constructor()
        OrielCapabilityBase(
            OrielConstants.CATEGORY_DATA,
            "0.1.0",
            "Mean lunar phase from block time. Constant-period model; apparent phase may deviate up to ~15h. Keeperless."
        )
    {
        _addOperation(
            _callCore(
                bytes4(keccak256("phaseE6()")),
                OrielConstants.MUTABILITY_VIEW,
                OrielSchemaHash.schemaHash("()"),
                OrielSchemaHash.schemaHash("(uint256)"),
                0,
                32,
                0,
                60_000,
                0
            ),
            _meta("phaseE6", "Mean lunar phase in millionths [0, 1e6): 0 = new moon, 500000 = full moon.")
        );
    }

    function phaseE6() external view returns (uint256) {
        return ((block.timestamp - REFERENCE_NEW_MOON) % SYNODIC_MONTH_SECONDS) * 1_000_000 / SYNODIC_MONTH_SECONDS;
    }
}
