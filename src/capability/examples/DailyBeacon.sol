// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {OrielCapabilityBase} from "../OrielCapabilityBase.sol";
import {OrielConstants} from "../../libraries/OrielConstants.sol";
import {OrielSchemaHash} from "../../libraries/OrielSchemaHash.sol";

/// @notice Randomness capability: one entropy value per UTC day, rotated by a
///         permissionless keeper.
/// @dev Trust model (stated per section 7.3): entropy = keccak256(prevrandao,
///      parent blockhash, round). On L1, prevrandao is RANDAO output — biasable
///      by proposers within known bounds. On OP-stack L2s it is
///      sequencer-provided. Suitable for aesthetic seeding; NOT suitable for
///      high-value randomness. Rotation requires one keeper transaction per day;
///      a missed day simply extends the previous round (artwork sees a stale
///      round id and can react).
contract DailyBeacon is OrielCapabilityBase {
    uint256 public constant ROUND_SECONDS = 86400;

    uint256 public lastRound;
    mapping(uint256 => bytes32) public valueAt;

    event BeaconRotated(uint256 indexed round, bytes32 value);

    constructor()
        OrielCapabilityBase(
            OrielConstants.CATEGORY_RANDOMNESS,
            "0.1.0",
            "One entropy value per UTC day from prevrandao + parent blockhash. Aesthetic-grade randomness; see trust model."
        )
    {
        _addOperation(
            _callCore(
                bytes4(keccak256("rotate()")),
                OrielConstants.MUTABILITY_NONPAYABLE,
                OrielSchemaHash.schemaHash("()"),
                OrielSchemaHash.schemaHash("()"),
                0,
                0,
                0,
                90_000,
                3600
            ),
            _meta("rotate", "Permissionless daily rotation; reverts until the UTC day advances.")
        );
        _addOperation(
            _callCore(
                bytes4(keccak256("currentRound()")),
                OrielConstants.MUTABILITY_VIEW,
                OrielSchemaHash.schemaHash("()"),
                OrielSchemaHash.schemaHash("(uint256,bytes32)"),
                0,
                64,
                0,
                50_000,
                0
            ),
            _meta("currentRound", "Latest rotated round id and its value.")
        );
        _addOperation(
            _callCore(
                bytes4(keccak256("valueAt(uint256)")),
                OrielConstants.MUTABILITY_VIEW,
                OrielSchemaHash.schemaHash("(uint256)"),
                OrielSchemaHash.schemaHash("(bytes32)"),
                0,
                32,
                32,
                50_000,
                0
            ),
            _meta("valueAt", "Entropy value of a given round id (zero if never rotated).")
        );
        _addOperation(
            _eventCore(
                keccak256("BeaconRotated(uint256,bytes32)"),
                OrielSchemaHash.schemaHash("(uint256)"),
                OrielSchemaHash.schemaHash("(bytes32)"),
                1,
                64
            ),
            _meta("BeaconRotated", "Emitted once per successful daily rotation.")
        );
    }

    function rotate() external {
        uint256 round = block.timestamp / ROUND_SECONDS;
        require(round > lastRound, "ROUND_NOT_ADVANCED");
        bytes32 value = keccak256(abi.encode(block.prevrandao, blockhash(block.number - 1), round));
        lastRound = round;
        valueAt[round] = value;
        emit BeaconRotated(round, value);
    }

    function currentRound() external view returns (uint256 round, bytes32 value) {
        return (lastRound, valueAt[lastRound]);
    }
}
