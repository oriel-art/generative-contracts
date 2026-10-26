// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {OrielCapabilityBase} from "../OrielCapabilityBase.sol";
import {IOrielWritable} from "../../interfaces/IOrielWritable.sol";
import {OrielConstants} from "../../libraries/OrielConstants.sol";
import {OrielSchemaHash} from "../../libraries/OrielSchemaHash.sol";

/// @notice State capability: a shared civic grid. Unrestricted reads, governed
///         writes (bounds, one claim per address per day, first-come cells),
///         with the advisory canWrite pre-check mirroring the enforced policy
///         (section 7.4/7.10). The Civilization-scenario substrate.
contract CivicLedger is OrielCapabilityBase, IOrielWritable {
    int32 public constant GRID_RADIUS = 1024;
    uint256 public constant CLAIM_INTERVAL = 86400;
    uint8 public constant MAX_BUILDING_TYPE = 8;

    bytes4 internal constant CLAIM_SELECTOR = bytes4(keccak256("claim(int32,int32,uint8)"));

    struct Cell {
        address builder;
        uint8 buildingType;
        uint64 claimedAt;
    }

    mapping(int32 => mapping(int32 => Cell)) private _cells;
    mapping(address => uint256) private _lastClaimDayPlusOne;
    uint256 public claimCount;

    event CellClaimed(address indexed builder, int32 x, int32 y, uint8 buildingType);

    constructor()
        OrielCapabilityBase(
            OrielConstants.CATEGORY_STATE,
            "0.1.0",
            "Shared civic grid: bounded coordinates, first-come cells, one claim per address per UTC day. canWrite is advisory; the contract enforces."
        )
    {
        _addOperation(
            _callCore(
                CLAIM_SELECTOR,
                OrielConstants.MUTABILITY_NONPAYABLE,
                OrielSchemaHash.schemaHash("(int32,int32,uint8)"),
                OrielSchemaHash.schemaHash("()"),
                0,
                0,
                96,
                120_000,
                5
            ),
            _meta("claim", "Claim an empty cell. Enforced: bounds, building type 1-8, empty cell, one claim per day.")
        );
        _addOperation(
            _callCore(
                bytes4(keccak256("cellAt(int32,int32)")),
                OrielConstants.MUTABILITY_VIEW,
                OrielSchemaHash.schemaHash("(int32,int32)"),
                OrielSchemaHash.schemaHash("(address,uint8,uint64)"),
                0,
                96,
                64,
                60_000,
                0
            ),
            _meta("cellAt", "Builder, building type, and claim time of a cell (zeroes if unclaimed).")
        );
        _addOperation(
            _callCore(
                bytes4(keccak256("claimCount()")),
                OrielConstants.MUTABILITY_VIEW,
                OrielSchemaHash.schemaHash("()"),
                OrielSchemaHash.schemaHash("(uint256)"),
                0,
                32,
                0,
                50_000,
                0
            ),
            _meta("claimCount", "Total number of claimed cells.")
        );
        _addOperation(
            _eventCore(
                keccak256("CellClaimed(address,int32,int32,uint8)"),
                OrielSchemaHash.schemaHash("(address)"),
                OrielSchemaHash.schemaHash("(int32,int32,uint8)"),
                10,
                128
            ),
            _meta("CellClaimed", "Emitted on every successful claim.")
        );
    }

    function claim(int32 x, int32 y, uint8 buildingType) external {
        (bool ok, string memory reason) = _check(msg.sender, x, y, buildingType);
        require(ok, reason);
        _cells[x][y] = Cell({builder: msg.sender, buildingType: buildingType, claimedAt: uint64(block.timestamp)});
        _lastClaimDayPlusOne[msg.sender] = block.timestamp / CLAIM_INTERVAL + 1;
        claimCount++;
        emit CellClaimed(msg.sender, x, y, buildingType);
    }

    function cellAt(int32 x, int32 y) external view returns (address builder, uint8 buildingType, uint64 claimedAt) {
        Cell storage cell = _cells[x][y];
        return (cell.builder, cell.buildingType, cell.claimedAt);
    }

    /// @inheritdoc IOrielWritable
    function canWrite(address actor, bytes4 selector, bytes calldata args)
        external
        view
        returns (bool allowed, string memory reason)
    {
        if (selector != CLAIM_SELECTOR) return (false, "UNKNOWN_SELECTOR");
        if (args.length != 96) return (false, "BAD_ARGS_LENGTH");
        (int32 x, int32 y, uint8 buildingType) = abi.decode(args, (int32, int32, uint8));
        return _check(actor, x, y, buildingType);
    }

    function _check(address actor, int32 x, int32 y, uint8 buildingType)
        internal
        view
        returns (bool, string memory)
    {
        if (x < -GRID_RADIUS || x > GRID_RADIUS || y < -GRID_RADIUS || y > GRID_RADIUS) {
            return (false, "OUT_OF_BOUNDS");
        }
        if (buildingType == 0 || buildingType > MAX_BUILDING_TYPE) return (false, "BAD_BUILDING_TYPE");
        if (_cells[x][y].builder != address(0)) return (false, "CELL_TAKEN");
        if (_lastClaimDayPlusOne[actor] == block.timestamp / CLAIM_INTERVAL + 1) return (false, "RATE_LIMITED");
        return (true, "");
    }
}
