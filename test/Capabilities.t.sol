// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BasefeeOracle} from "../src/capability/examples/BasefeeOracle.sol";
import {LunarOracle} from "../src/capability/examples/LunarOracle.sol";
import {BlockClock} from "../src/capability/examples/BlockClock.sol";
import {DailyBeacon} from "../src/capability/examples/DailyBeacon.sol";
import {CivicLedger} from "../src/capability/examples/CivicLedger.sol";
import {OperationDescriptorCore, OperationMetadata} from "../src/types/OrielTypes.sol";
import {OrielConstants} from "../src/libraries/OrielConstants.sol";

contract CapabilitiesTest is Test {
    event EpochAdvanced(uint256 indexed epoch, uint256 timestamp);
    event BeaconRotated(uint256 indexed round, bytes32 value);
    event CellClaimed(address indexed builder, int32 x, int32 y, uint8 buildingType);

    bytes4 internal constant CLAIM_SELECTOR = bytes4(keccak256("claim(int32,int32,uint8)"));

    function test_basefeeOracle() public {
        BasefeeOracle oracle = new BasefeeOracle();
        vm.fee(7 gwei);
        assertEq(oracle.basefeeWei(), 7 gwei);

        assertEq(oracle.orielCategory(), OrielConstants.CATEGORY_DATA);
        assertEq(oracle.orielOperationCount(), 1);
        (OperationDescriptorCore memory core, OperationMetadata memory meta) = oracle.orielOperationAt(0);
        assertEq(bytes32(core.rawSelector), bytes32(bytes4(keccak256("basefeeWei()"))));
        assertEq(meta.name, "basefeeWei");
        (OperationDescriptorCore memory byId,) = oracle.orielOperationById(core.operationId);
        assertEq(bytes32(byId.rawSelector), bytes32(core.rawSelector));
        vm.expectRevert(bytes("UNKNOWN_OPERATION"));
        oracle.orielOperationById(bytes32(uint256(123)));
    }

    function test_lunarPhase() public {
        LunarOracle lunar = new LunarOracle();
        vm.warp(lunar.REFERENCE_NEW_MOON() + lunar.SYNODIC_MONTH_SECONDS() / 2);
        assertApproxEqAbs(lunar.phaseE6(), 500_000, 1);
        vm.warp(lunar.REFERENCE_NEW_MOON() + lunar.SYNODIC_MONTH_SECONDS() * 5);
        assertEq(lunar.phaseE6(), 0);
        assertEq(lunar.orielCategory(), OrielConstants.CATEGORY_DATA);
    }

    function test_blockClock() public {
        BlockClock clock = new BlockClock(86400);
        vm.warp(100 * 86400 + 5);
        assertEq(clock.currentEpoch(), 100);
        assertEq(clock.nextEpochAt(), 101 * 86400);

        vm.expectEmit(true, false, false, true);
        emit EpochAdvanced(100, block.timestamp);
        clock.checkpoint();
        vm.expectRevert(bytes("EPOCH_NOT_ADVANCED"));
        clock.checkpoint();

        vm.warp(101 * 86400);
        clock.checkpoint();
        assertEq(clock.lastCheckpointedEpoch(), 101);
        assertEq(clock.orielCategory(), OrielConstants.CATEGORY_TEMPORAL);
        assertEq(clock.orielOperationCount(), 4);
    }

    function test_dailyBeacon() public {
        DailyBeacon beacon = new DailyBeacon();
        vm.warp(200 * 86400 + 100);
        vm.prevrandao(bytes32(uint256(42)));

        beacon.rotate();
        (uint256 round, bytes32 value) = beacon.currentRound();
        assertEq(round, 200);
        assertTrue(value != bytes32(0));
        assertEq(beacon.valueAt(200), value);

        vm.expectRevert(bytes("ROUND_NOT_ADVANCED"));
        beacon.rotate();

        vm.warp(201 * 86400 + 100);
        vm.prevrandao(bytes32(uint256(43)));
        beacon.rotate();
        (uint256 round2, bytes32 value2) = beacon.currentRound();
        assertEq(round2, 201);
        assertTrue(value2 != value);
        assertEq(beacon.orielCategory(), OrielConstants.CATEGORY_RANDOMNESS);
    }

    function _newLedger() internal returns (CivicLedger civic, address alice) {
        civic = new CivicLedger();
        alice = address(0xA11CE);
        vm.warp(300 * 86400 + 10);
    }

    function test_civicLedger_claimAndRead() public {
        (CivicLedger civic, address alice) = _newLedger();

        (bool okPre,) = civic.canWrite(alice, CLAIM_SELECTOR, abi.encode(int32(3), int32(-4), uint8(2)));
        assertTrue(okPre, "advisory pre-check should allow");

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit CellClaimed(alice, int32(3), int32(-4), uint8(2));
        civic.claim(3, -4, 2);

        (address builder, uint8 buildingType, uint64 claimedAt) = civic.cellAt(3, -4);
        assertEq(builder, alice);
        assertEq(buildingType, 2);
        assertEq(claimedAt, uint64(block.timestamp));
        assertEq(civic.claimCount(), 1);
        assertEq(civic.orielCategory(), OrielConstants.CATEGORY_STATE);
    }

    function test_civicLedger_rateLimit() public {
        (CivicLedger civic, address alice) = _newLedger();
        vm.prank(alice);
        civic.claim(3, -4, 2);

        (bool okRate, string memory reasonRate) =
            civic.canWrite(alice, CLAIM_SELECTOR, abi.encode(int32(5), int32(5), uint8(1)));
        assertFalse(okRate);
        assertEq(reasonRate, "RATE_LIMITED");
        vm.prank(alice);
        vm.expectRevert(bytes("RATE_LIMITED"));
        civic.claim(5, 5, 1);

        vm.warp(301 * 86400 + 10);
        vm.prank(alice);
        civic.claim(5, 5, 1);
        assertEq(civic.claimCount(), 2);
    }

    function test_civicLedger_rejections() public {
        (CivicLedger civic, address alice) = _newLedger();
        vm.prank(alice);
        civic.claim(3, -4, 2);

        {
            (bool ok, string memory reason) =
                civic.canWrite(address(0xB0B), CLAIM_SELECTOR, abi.encode(int32(3), int32(-4), uint8(1)));
            assertFalse(ok);
            assertEq(reason, "CELL_TAKEN");
        }
        {
            (bool ok, string memory reason) =
                civic.canWrite(address(0xB0B), CLAIM_SELECTOR, abi.encode(int32(2000), int32(0), uint8(1)));
            assertFalse(ok);
            assertEq(reason, "OUT_OF_BOUNDS");
        }
        {
            (bool ok, string memory reason) =
                civic.canWrite(address(0xB0B), CLAIM_SELECTOR, abi.encode(int32(9), int32(9), uint8(0)));
            assertFalse(ok);
            assertEq(reason, "BAD_BUILDING_TYPE");
        }
        {
            (bool ok, string memory reason) =
                civic.canWrite(alice, bytes4(0x12345678), abi.encode(int32(1), int32(1), uint8(1)));
            assertFalse(ok);
            assertEq(reason, "UNKNOWN_SELECTOR");
        }
    }
}
