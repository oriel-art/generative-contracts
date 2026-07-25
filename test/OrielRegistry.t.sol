// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrielRegistry} from "../src/registry/OrielRegistry.sol";
import {OrielRegistryIndex} from "../src/registry/OrielRegistryIndex.sol";
import {BasefeeOracle} from "../src/capability/examples/BasefeeOracle.sol";
import {LunarOracle} from "../src/capability/examples/LunarOracle.sol";
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
import {OrielDescriptorHash} from "../src/libraries/OrielDescriptorHash.sol";
import {OrielDependencyHash} from "../src/libraries/OrielDependencyHash.sol";

contract MockUnsortedDeps is IOrielCapability {
    function orielCategory() external pure returns (bytes32) {
        return keccak256("ORIEL_DATA");
    }

    function orielVersion() external pure returns (string memory) {
        return "0.0.0";
    }

    function orielDescription() external pure returns (string memory) {
        return "";
    }

    function orielOperationCount() external pure returns (uint256) {
        return 0;
    }

    function orielOperationAt(uint256)
        external
        pure
        returns (OperationDescriptorCore memory, OperationMetadata memory)
    {
        revert("NONE");
    }

    function orielOperationById(bytes32)
        external
        pure
        returns (OperationDescriptorCore memory, OperationMetadata memory)
    {
        revert("NONE");
    }

    function orielDependencies()
        external
        pure
        returns (DependencyCore[] memory deps, DependencyMetadata[] memory metas)
    {
        deps = new DependencyCore[](2);
        deps[0] = DependencyCore({target: address(0x2), codeHash: bytes32(0)});
        deps[1] = DependencyCore({target: address(0x1), codeHash: bytes32(0)});
        metas = new DependencyMetadata[](2);
    }
}

contract MockBadDepHash is IOrielCapability {
    address private immutable _depTarget;

    constructor(address depTarget_) {
        _depTarget = depTarget_;
    }

    function orielCategory() external pure returns (bytes32) {
        return keccak256("ORIEL_DATA");
    }

    function orielVersion() external pure returns (string memory) {
        return "0.0.0";
    }

    function orielDescription() external pure returns (string memory) {
        return "";
    }

    function orielOperationCount() external pure returns (uint256) {
        return 0;
    }

    function orielOperationAt(uint256)
        external
        pure
        returns (OperationDescriptorCore memory, OperationMetadata memory)
    {
        revert("NONE");
    }

    function orielOperationById(bytes32)
        external
        pure
        returns (OperationDescriptorCore memory, OperationMetadata memory)
    {
        revert("NONE");
    }

    function orielDependencies()
        external
        view
        returns (DependencyCore[] memory deps, DependencyMetadata[] memory metas)
    {
        deps = new DependencyCore[](1);
        deps[0] = DependencyCore({target: _depTarget, codeHash: keccak256("wrong")});
        metas = new DependencyMetadata[](1);
    }
}

contract OrielRegistryTest is Test {
    event OperationApproved(
        address indexed target,
        bytes32 indexed operationId,
        bytes32 descriptorCoreHash,
        bytes32 presentationMetadataHash,
        bytes32 category,
        bytes32 codeHash
    );
    event OperationRevoked(address indexed target, bytes32 indexed operationId, string reason);
    event GovernanceChanged(bytes32 changeType, address indexed newAuthority);

    OrielRegistry internal registry;
    BasefeeOracle internal basefee;
    address internal curator = address(0xC0FE);
    address internal stranger = address(0xBAD);

    function setUp() public {
        registry = new OrielRegistry("Test Registry", address(this));
        basefee = new BasefeeOracle();
    }

    function _basefeeCore() internal view returns (OperationDescriptorCore memory core) {
        (core,) = basefee.orielOperationAt(0);
    }

    function test_approveHappyPath() public {
        OperationDescriptorCore memory core = _basefeeCore();
        bytes32 expectedDescriptorHash = OrielDescriptorHash.hashCore(core);

        vm.expectEmit(true, true, false, true);
        emit OperationApproved(
            address(basefee),
            core.operationId,
            expectedDescriptorHash,
            bytes32(0),
            OrielConstants.CATEGORY_DATA,
            address(basefee).codehash
        );
        registry.approveOperation(address(basefee), core, bytes32(0));

        assertTrue(registry.isOperationApproved(address(basefee), core.operationId));
        assertTrue(registry.isApproved(address(basefee)));

        (
            bytes32 descriptorCoreHash,
            bytes32 presentationMetadataHash,
            bytes32 codeHash,
            bytes32 dependencySetHash,
            bytes32 category,
            uint256 approvedAt
        ) = registry.operationApproval(address(basefee), core.operationId);
        assertEq(descriptorCoreHash, expectedDescriptorHash);
        assertEq(presentationMetadataHash, bytes32(0));
        assertEq(codeHash, address(basefee).codehash);
        assertEq(dependencySetHash, OrielDependencyHash.hashDependencies(new DependencyCore[](0)));
        assertEq(category, OrielConstants.CATEGORY_DATA);
        assertEq(approvedAt, block.timestamp);

        assertEq(registry.entryCount(), 1);
        assertEq(registry.entryAt(0), address(basefee));
        assertEq(registry.categoryOf(address(basefee)), OrielConstants.CATEGORY_DATA);
        assertEq(registry.codeHashOf(address(basefee)), address(basefee).codehash);
        assertEq(registry.operationCount(address(basefee)), 1);
        assertEq(registry.operationAt(address(basefee), 0), core.operationId);
        assertEq(registry.registryChainId(), block.chainid);
        assertEq(registry.registryName(), "Test Registry");
    }

    function test_nonCuratorCannotApprove() public {
        OperationDescriptorCore memory core = _basefeeCore();
        vm.prank(stranger);
        vm.expectRevert(bytes("NOT_CURATOR"));
        registry.approveOperation(address(basefee), core, bytes32(0));
    }

    function test_opIdMismatchReverts() public {
        OperationDescriptorCore memory core = _basefeeCore();
        core.operationId = bytes32(uint256(1));
        vm.expectRevert(bytes("OP_ID_MISMATCH"));
        registry.approveOperation(address(basefee), core, bytes32(0));
    }

    function test_eoaTargetReverts() public {
        OperationDescriptorCore memory core = _basefeeCore();
        vm.expectRevert(bytes("NO_CODE"));
        registry.approveOperation(address(0xDEAD), core, bytes32(0));
    }

    function test_duplicateApproveReverts() public {
        OperationDescriptorCore memory core = _basefeeCore();
        registry.approveOperation(address(basefee), core, bytes32(0));
        vm.expectRevert(bytes("ALREADY_APPROVED"));
        registry.approveOperation(address(basefee), core, bytes32(0));
    }

    function test_revokeClearsEverything() public {
        OperationDescriptorCore memory core = _basefeeCore();
        registry.approveOperation(address(basefee), core, bytes32(0));

        vm.expectEmit(true, true, false, true);
        emit OperationRevoked(address(basefee), core.operationId, "test");
        registry.revokeOperation(address(basefee), core.operationId, "test");

        assertFalse(registry.isOperationApproved(address(basefee), core.operationId));
        assertFalse(registry.isApproved(address(basefee)));
        assertEq(registry.entryCount(), 0);
        assertEq(registry.operationCount(address(basefee)), 0);
        assertEq(registry.categoryOf(address(basefee)), bytes32(0));
        vm.expectRevert(bytes("NOT_APPROVED"));
        registry.operationApproval(address(basefee), core.operationId);
    }

    function test_curatorLifecycle() public {
        vm.expectEmit(false, true, false, true);
        emit GovernanceChanged(registry.CURATOR_ADDED(), curator);
        registry.addCurator(curator);

        OperationDescriptorCore memory core = _basefeeCore();
        vm.prank(curator);
        registry.approveOperation(address(basefee), core, bytes32(0));
        assertTrue(registry.isApproved(address(basefee)));

        vm.expectEmit(false, true, false, true);
        emit GovernanceChanged(registry.CURATOR_REMOVED(), curator);
        registry.removeCurator(curator);

        LunarOracle lunar = new LunarOracle();
        (OperationDescriptorCore memory lunarCore,) = lunar.orielOperationAt(0);
        vm.prank(curator);
        vm.expectRevert(bytes("NOT_CURATOR"));
        registry.approveOperation(address(lunar), lunarCore, bytes32(0));
    }

    function test_ownerTransfer() public {
        // Two-step: transfer stages a pending owner; ownership moves only on accept.
        registry.transferOwnership(curator);
        assertEq(registry.owner(), address(this));
        assertEq(registry.pendingOwner(), curator);

        vm.prank(curator);
        registry.acceptOwnership();
        assertEq(registry.owner(), curator);
        assertEq(registry.pendingOwner(), address(0));

        vm.expectRevert(bytes("NOT_OWNER"));
        registry.addCurator(stranger);
    }

    function test_unsortedDepsRevert() public {
        MockUnsortedDeps mock = new MockUnsortedDeps();
        OperationDescriptorCore memory core;
        core.rawSelector = bytes4(0x12345678);
        core.kind = OperationKind.CALL;
        core.operationId = OrielOperationId.callOperationId(core.rawSelector);
        vm.expectRevert(bytes("DEPS_UNSORTED"));
        registry.approveOperation(address(mock), core, bytes32(0));
    }

    function test_badDepCodehashReverts() public {
        MockBadDepHash mock = new MockBadDepHash(address(basefee));
        OperationDescriptorCore memory core;
        core.rawSelector = bytes4(0x12345678);
        core.kind = OperationKind.CALL;
        core.operationId = OrielOperationId.callOperationId(core.rawSelector);
        vm.expectRevert(bytes("DEP_CODEHASH_MISMATCH"));
        registry.approveOperation(address(mock), core, bytes32(0));
    }
}

contract OrielRegistryIndexTest is Test {
    event RegistryListed(uint256 indexed chainId, address indexed registry, string name);
    event RegistryDelisted(uint256 indexed chainId, address indexed registry, string reason);

    OrielRegistryIndex internal index;

    function setUp() public {
        index = new OrielRegistryIndex("Test Index", address(this));
    }

    function test_listAndDelist() public {
        vm.expectEmit(true, true, false, true);
        emit RegistryListed(8453, address(0xAAA1), "Registry A");
        index.listRegistry(8453, address(0xAAA1), "Registry A");
        index.listRegistry(1, address(0xBBB2), "Registry B");

        assertTrue(index.isRegistryListed(8453, address(0xAAA1)));
        assertEq(index.registryCount(), 2);
        (uint256 chainId, address registry) = index.registryAt(0);
        assertEq(chainId, 8453);
        assertEq(registry, address(0xAAA1));

        vm.expectEmit(true, true, false, true);
        emit RegistryDelisted(8453, address(0xAAA1), "compromised");
        index.delistRegistry(8453, address(0xAAA1), "compromised");
        assertFalse(index.isRegistryListed(8453, address(0xAAA1)));
        assertEq(index.registryCount(), 1);
        (chainId, registry) = index.registryAt(0);
        assertEq(chainId, 1);
        assertEq(registry, address(0xBBB2));
    }

    function test_onlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(bytes("NOT_OWNER"));
        index.listRegistry(1, address(0xAAA1), "x");
    }

    function test_duplicateListingReverts() public {
        index.listRegistry(1, address(0xAAA1), "x");
        vm.expectRevert(bytes("ALREADY_LISTED"));
        index.listRegistry(1, address(0xAAA1), "x");
    }

    function test_ownerTransferIsTwoStep() public {
        address newOwner = address(0xBEEF);
        index.transferOwnership(newOwner);
        assertEq(index.owner(), address(this)); // pending until accepted
        assertEq(index.pendingOwner(), newOwner);

        vm.prank(newOwner);
        index.acceptOwnership();
        assertEq(index.owner(), newOwner);

        // old owner can no longer govern
        vm.expectRevert(bytes("NOT_OWNER"));
        index.listRegistry(1, address(0xAAA1), "x");
    }
}
