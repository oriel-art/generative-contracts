// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrielRegistry} from "../../src/c4/registry/OrielRegistry.sol";
import {IOrielCapability} from "../../src/c4/interfaces/IOrielCapability.sol";
import {
    OperationDescriptorCore,
    OperationMetadata,
    DependencyCore,
    DependencyMetadata,
    OperationKind
} from "../../src/c4/types/OrielTypes.sol";
import {OrielConstants} from "../../src/c4/libraries/OrielConstants.sol";
import {OrielOperationId} from "../../src/c4/libraries/OrielOperationId.sol";

/// Minimal conformant capability (category DATA, no dependencies).
contract InvMockCap is IOrielCapability {
    function orielCategory() external pure returns (bytes32) {
        return OrielConstants.CATEGORY_DATA;
    }

    function orielVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function orielDescription() external pure returns (string memory) {
        return "";
    }

    function orielOperationCount() external pure returns (uint256) {
        return 0;
    }

    function orielOperationAt(uint256) external pure returns (OperationDescriptorCore memory, OperationMetadata memory) {
        revert("NONE");
    }

    function orielOperationById(bytes32) external pure returns (OperationDescriptorCore memory, OperationMetadata memory) {
        revert("NONE");
    }

    function orielDependencies() external pure returns (DependencyCore[] memory d, DependencyMetadata[] memory m) {
        d = new DependencyCore[](0);
        m = new DependencyMetadata[](0);
    }
}

/// Drives random approve/revoke sequences and maintains a ghost model of what
/// SHOULD be approved. The invariant contract compares the registry to the ghost.
contract Handler is Test {
    OrielRegistry public registry;
    address[] public caps;

    mapping(address => uint256) public ghostOpCount;
    mapping(address => mapping(bytes32 => bool)) public ghostApproved;
    address[] internal _everTargets;
    mapping(address => bool) internal _seen;

    constructor(OrielRegistry registry_, address[] memory caps_) {
        registry = registry_;
        caps = caps_;
    }

    function everTargets() external view returns (address[] memory) {
        return _everTargets;
    }

    function _core(bytes4 selector) internal pure returns (OperationDescriptorCore memory core) {
        core.rawSelector = selector;
        core.kind = OperationKind.CALL;
        core.operationId = OrielOperationId.callOperationId(selector);
    }

    function approve(uint256 capSeed, uint32 selSeed) external {
        address cap = caps[capSeed % caps.length];
        bytes4 sel = bytes4(selSeed);
        bytes32 opId = OrielOperationId.callOperationId(sel);
        if (ghostApproved[cap][opId]) return; // would revert ALREADY_APPROVED

        registry.approveOperation(cap, _core(sel), bytes32(0));

        ghostApproved[cap][opId] = true;
        ghostOpCount[cap]++;
        if (!_seen[cap]) {
            _seen[cap] = true;
            _everTargets.push(cap);
        }
    }

    function revoke(uint256 capSeed, uint32 selSeed) external {
        address cap = caps[capSeed % caps.length];
        bytes4 sel = bytes4(selSeed);
        bytes32 opId = OrielOperationId.callOperationId(sel);
        if (!ghostApproved[cap][opId]) return; // would revert NOT_APPROVED

        registry.revokeOperation(cap, opId, "");

        ghostApproved[cap][opId] = false;
        ghostOpCount[cap]--;
    }
}

contract OrielRegistryInvariantTest is Test {
    OrielRegistry internal registry;
    Handler internal handler;

    function setUp() public {
        registry = new OrielRegistry("Invariant Registry", address(this));

        address[] memory caps = new address[](4);
        for (uint256 i = 0; i < caps.length; i++) {
            caps[i] = address(new InvMockCap());
        }
        handler = new Handler(registry, caps);
        registry.addCurator(address(handler)); // handler drives curation

        targetContract(address(handler));
    }

    /// The registry's per-target and global enumeration always agrees with the
    /// ghost model, no matter the approve/revoke sequence.
    function invariant_enumerationMatchesGhost() public view {
        address[] memory targets = handler.everTargets();
        uint256 expectedEntries = 0;
        for (uint256 i = 0; i < targets.length; i++) {
            uint256 gc = handler.ghostOpCount(targets[i]);
            assertEq(registry.operationCount(targets[i]), gc, "operationCount != ghost");
            assertEq(registry.isApproved(targets[i]), gc > 0, "isApproved != (ghost>0)");
            if (gc > 0) expectedEntries++;
        }
        assertEq(registry.entryCount(), expectedEntries, "entryCount != distinct approved targets");
    }

    /// The target enumeration is a duplicate-free set, and every entry is approved.
    function invariant_entriesDistinctAndApproved() public view {
        uint256 n = registry.entryCount();
        for (uint256 i = 0; i < n; i++) {
            address t = registry.entryAt(i);
            assertTrue(registry.isApproved(t), "enumerated target not approved");
            for (uint256 j = i + 1; j < n; j++) {
                assertTrue(t != registry.entryAt(j), "duplicate in target enumeration");
            }
        }
    }
}
