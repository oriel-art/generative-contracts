// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {OrielCapabilityBase} from "../OrielCapabilityBase.sol";
import {OrielConstants} from "../../libraries/OrielConstants.sol";
import {OrielSchemaHash} from "../../libraries/OrielSchemaHash.sol";

/// @notice Temporal capability: fixed-length epochs with a permissionless
///         keeper poke that emits an event once per epoch (the Live-profile
///         subscription demo).
contract BlockClock is OrielCapabilityBase {
    uint256 public immutable epochSeconds;
    uint256 public lastCheckpointedEpoch;

    event EpochAdvanced(uint256 indexed epoch, uint256 timestamp);

    constructor(uint256 epochSeconds_)
        OrielCapabilityBase(
            OrielConstants.CATEGORY_TEMPORAL,
            "0.1.0",
            "Fixed-length epochs from block time. checkpoint() is a permissionless keeper poke emitting EpochAdvanced once per epoch."
        )
    {
        require(epochSeconds_ > 0, "ZERO_EPOCH");
        epochSeconds = epochSeconds_;

        bytes32 inSchemaEmpty = OrielSchemaHash.schemaHash("()");
        bytes32 outSchemaU256 = OrielSchemaHash.schemaHash("(uint256)");

        _addOperation(
            _callCore(
                bytes4(keccak256("currentEpoch()")),
                OrielConstants.MUTABILITY_VIEW,
                inSchemaEmpty,
                outSchemaU256,
                0,
                32,
                0,
                50_000,
                0
            ),
            _meta("currentEpoch", "Current epoch number (timestamp / epochSeconds).")
        );
        _addOperation(
            _callCore(
                bytes4(keccak256("nextEpochAt()")),
                OrielConstants.MUTABILITY_VIEW,
                inSchemaEmpty,
                outSchemaU256,
                0,
                32,
                0,
                50_000,
                0
            ),
            _meta("nextEpochAt", "Timestamp at which the next epoch begins.")
        );
        _addOperation(
            _callCore(
                bytes4(keccak256("checkpoint()")),
                OrielConstants.MUTABILITY_NONPAYABLE,
                inSchemaEmpty,
                OrielSchemaHash.schemaHash("()"),
                0,
                0,
                0,
                80_000,
                60
            ),
            _meta("checkpoint", "Permissionless keeper poke; emits EpochAdvanced once per epoch.")
        );
        _addOperation(
            _eventCore(
                keccak256("EpochAdvanced(uint256,uint256)"),
                OrielSchemaHash.schemaHash("(uint256)"),
                OrielSchemaHash.schemaHash("(uint256)"),
                1, // maxEventRate: at most one per epoch in practice
                64
            ),
            _meta("EpochAdvanced", "Emitted at most once per epoch by checkpoint().")
        );
    }

    function currentEpoch() public view returns (uint256) {
        return block.timestamp / epochSeconds;
    }

    function nextEpochAt() external view returns (uint256) {
        return (currentEpoch() + 1) * epochSeconds;
    }

    function checkpoint() external {
        uint256 epoch = currentEpoch();
        require(epoch > lastCheckpointedEpoch, "EPOCH_NOT_ADVANCED");
        lastCheckpointedEpoch = epoch;
        emit EpochAdvanced(epoch, block.timestamp);
    }
}
