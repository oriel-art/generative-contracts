// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrielRegistry} from "../src/registry/OrielRegistry.sol";
import {IOrielCapability} from "../src/interfaces/IOrielCapability.sol";
import {
    OperationDescriptorCore,
    OperationMetadata,
    DependencyCore,
    DependencyMetadata,
    OperationKind
} from "../src/types/OrielTypes.sol";
import {OrielConstants} from "../src/libraries/OrielConstants.sol";
import {OrielOperationId} from "../src/libraries/OrielOperationId.sol";

// -------------------------------------------------------------------------
// Mocks
// -------------------------------------------------------------------------

/// A minimal conformant capability. `salt` varies the runtime bytecode (and thus
/// the codehash) across instances without changing behaviour.
contract SecMockCap is IOrielCapability {
    bytes32 private immutable _cat;
    uint256 private immutable _salt;

    constructor(bytes32 cat_, uint256 salt_) {
        _cat = cat_;
        _salt = salt_;
    }

    function salt() external view returns (uint256) {
        return _salt;
    }

    function orielCategory() external view returns (bytes32) {
        return _cat;
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

/// A capability whose self-declared category flips with block time — same codehash,
/// different category across two approvals. Exercises the CATEGORY_CHANGED guard,
/// which is otherwise unreachable (category is a function of code).
contract FlipCategoryCap is IOrielCapability {
    function orielCategory() external view returns (bytes32) {
        return block.timestamp % 2 == 0 ? OrielConstants.CATEGORY_DATA : OrielConstants.CATEGORY_STATE;
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

/// A hostile target that does NOT implement the interface honestly: its
/// orielDependencies() is state-changing and tries to re-enter approveOperation.
/// It deliberately does not inherit IOrielCapability (the interface's `view` would
/// forbid a nonpayable override — which is itself a structural defence). The
/// registry still calls it via STATICCALL (the cast type is `view`), so the
/// re-entrant state write reverts, proving the reentry path is dead at runtime even
/// for a non-conformant target. Only the two functions the registry calls during
/// approval are present.
contract ReentrantCap {
    OrielRegistry private immutable _registry;

    constructor(OrielRegistry registry_) {
        _registry = registry_;
    }

    function orielCategory() external pure returns (bytes32) {
        return OrielConstants.CATEGORY_DATA;
    }

    function orielDependencies() external returns (DependencyCore[] memory d, DependencyMetadata[] memory m) {
        // Re-entrant state-changing call — reverts under the registry's STATICCALL.
        OperationDescriptorCore memory core;
        core.rawSelector = bytes4(0xdeadbeef);
        core.kind = OperationKind.CALL;
        core.operationId = OrielOperationId.callOperationId(core.rawSelector);
        _registry.approveOperation(address(this), core, bytes32(0));
        d = new DependencyCore[](0);
        m = new DependencyMetadata[](0);
    }
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

contract OrielRegistrySecurityTest is Test {
    OrielRegistry internal registry;
    address internal owner = address(this);
    address internal stranger = address(0xBAD);

    function setUp() public {
        registry = new OrielRegistry("Sec Registry", owner);
    }

    function _callCore(bytes4 selector) internal pure returns (OperationDescriptorCore memory core) {
        core.rawSelector = selector;
        core.kind = OperationKind.CALL;
        core.operationId = OrielOperationId.callOperationId(selector);
    }

    function _approve(address target, bytes4 selector) internal {
        registry.approveOperation(target, _callCore(selector), bytes32(0));
    }

    // ---- governance guards (previously untested) ----

    function test_setOwnerZeroReverts() public {
        vm.expectRevert(bytes("ZERO_OWNER"));
        registry.setOwner(address(0));
    }

    function test_nonOwnerCannotSetOwner() public {
        vm.prank(stranger);
        vm.expectRevert(bytes("NOT_OWNER"));
        registry.setOwner(stranger);
    }

    function test_addCuratorTwiceReverts() public {
        registry.addCurator(stranger);
        vm.expectRevert(bytes("ALREADY_CURATOR"));
        registry.addCurator(stranger);
    }

    function test_removeNonCuratorReverts() public {
        vm.expectRevert(bytes("NOT_A_CURATOR"));
        registry.removeCurator(stranger);
    }

    function test_nonOwnerCannotAddCurator() public {
        // addCurator is onlyOwner — a non-owner (even a curator) cannot grant curation.
        registry.addCurator(stranger); // stranger is now a curator...
        vm.prank(stranger);
        vm.expectRevert(bytes("NOT_OWNER")); // ...but still cannot add another curator
        registry.addCurator(address(0x1234));
    }

    // ---- code-hash pinning across a target's operations ----

    function test_reApproveWithChangedCodeHashReverts() public {
        SecMockCap capA = new SecMockCap(OrielConstants.CATEGORY_DATA, 1);
        SecMockCap capB = new SecMockCap(OrielConstants.CATEGORY_DATA, 2); // different codehash, same category
        assertTrue(address(capA).codehash != address(capB).codehash);

        _approve(address(capA), bytes4(0x11111111));

        // Swap capA's code for capB's → its codehash changes but it still conforms.
        vm.etch(address(capA), address(capB).code);
        assertEq(address(capA).codehash, address(capB).codehash);

        vm.expectRevert(bytes("CODEHASH_CHANGED"));
        _approve(address(capA), bytes4(0x22222222));
    }

    function test_reApproveWithChangedCategoryReverts() public {
        FlipCategoryCap cap = new FlipCategoryCap();
        vm.warp(2); // even → CATEGORY_DATA
        _approve(address(cap), bytes4(0x11111111));
        assertEq(registry.categoryOf(address(cap)), OrielConstants.CATEGORY_DATA);

        vm.warp(3); // odd → CATEGORY_STATE; code (and codehash) unchanged
        vm.expectRevert(bytes("CATEGORY_CHANGED"));
        _approve(address(cap), bytes4(0x22222222));
    }

    // ---- reentrancy is structurally blocked (STATICCALL on the view call) ----

    function test_reentrantDependenciesCallReverts() public {
        ReentrantCap cap = new ReentrantCap(registry);
        OperationDescriptorCore memory core = _callCore(bytes4(0x11111111));
        // The STATICCALL to orielDependencies() reverts when it attempts a state write.
        vm.expectRevert();
        registry.approveOperation(address(cap), core, bytes32(0));
        // Nothing was recorded.
        assertFalse(registry.isApproved(address(cap)));
        assertEq(registry.entryCount(), 0);
    }

    // ---- multi-op / multi-target revoke swap-pop correctness ----

    function test_revokeMiddleOpKeepsEnumerationConsistent() public {
        SecMockCap cap = new SecMockCap(OrielConstants.CATEGORY_DATA, 1);
        bytes4[3] memory sels = [bytes4(0xa1a1a1a1), bytes4(0xb2b2b2b2), bytes4(0xc3c3c3c3)];
        for (uint256 i = 0; i < 3; i++) _approve(address(cap), sels[i]);
        assertEq(registry.operationCount(address(cap)), 3);

        // Revoke the middle op.
        bytes32 midOp = OrielOperationId.callOperationId(sels[1]);
        registry.revokeOperation(address(cap), midOp, "");

        assertEq(registry.operationCount(address(cap)), 2);
        assertFalse(registry.isOperationApproved(address(cap), midOp));
        // The other two remain approved and enumerable.
        assertTrue(registry.isOperationApproved(address(cap), OrielOperationId.callOperationId(sels[0])));
        assertTrue(registry.isOperationApproved(address(cap), OrielOperationId.callOperationId(sels[2])));
        bytes32 e0 = registry.operationAt(address(cap), 0);
        bytes32 e1 = registry.operationAt(address(cap), 1);
        assertTrue(e0 != midOp && e1 != midOp);
        assertTrue(e0 != e1); // no duplicate after swap-pop
        assertTrue(registry.isApproved(address(cap)));
        assertEq(registry.entryCount(), 1);
    }

    function test_revokeLastOpOfMiddleTargetSwapPopsTargets() public {
        SecMockCap capA = new SecMockCap(OrielConstants.CATEGORY_DATA, 1);
        SecMockCap capB = new SecMockCap(OrielConstants.CATEGORY_DATA, 2);
        SecMockCap capC = new SecMockCap(OrielConstants.CATEGORY_DATA, 3);
        _approve(address(capA), bytes4(0x11111111));
        _approve(address(capB), bytes4(0x22222222)); // capB is the middle target
        _approve(address(capC), bytes4(0x33333333));
        assertEq(registry.entryCount(), 3);

        // Revoke capB's only op → capB drops out of the target enumeration.
        registry.revokeOperation(address(capB), OrielOperationId.callOperationId(bytes4(0x22222222)), "");

        assertEq(registry.entryCount(), 2);
        assertFalse(registry.isApproved(address(capB)));
        assertEq(registry.categoryOf(address(capB)), bytes32(0));
        assertEq(registry.codeHashOf(address(capB)), bytes32(0));

        // capA and capC are both still enumerable exactly once, no capB.
        address e0 = registry.entryAt(0);
        address e1 = registry.entryAt(1);
        assertTrue(e0 != address(capB) && e1 != address(capB));
        assertTrue(e0 != e1);
        assertTrue(registry.isApproved(address(capA)));
        assertTrue(registry.isApproved(address(capC)));
        vm.expectRevert(bytes("INDEX_OUT_OF_BOUNDS"));
        registry.entryAt(2);
    }
}
