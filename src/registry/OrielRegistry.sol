// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {IOrielRegistry} from "../interfaces/IOrielRegistry.sol";
import {IOrielCapability} from "../interfaces/IOrielCapability.sol";
import {OperationDescriptorCore, OperationKind, DependencyCore} from "../types/OrielTypes.sol";
import {OrielOperationId} from "../libraries/OrielOperationId.sol";
import {OrielDescriptorHash} from "../libraries/OrielDescriptorHash.sol";
import {OrielDependencyHash} from "../libraries/OrielDependencyHash.sol";

/// @notice Reference chain-local registry (Oriel 0.7 section 8).
/// @dev Approves by READING THE CHAIN AT APPROVAL TIME: derivation of the
///      operation id is re-checked, the capability code hash is snapshotted,
///      the category is read from the capability, and the dependency set hash
///      is computed on-chain from orielDependencies() — curator input cannot
///      desynchronize from chain state. The registry itself is immutable
///      (no proxy); runtimes pin it by code hash.
///
///      Supersets the Appendix A interface with per-target operation
///      enumeration (erratum E6).
contract OrielRegistry is IOrielRegistry {
    // Governance change types (erratum E5)
    bytes32 public constant OWNER_CHANGED = keccak256("OWNER_CHANGED");
    bytes32 public constant CURATOR_ADDED = keccak256("CURATOR_ADDED");
    bytes32 public constant CURATOR_REMOVED = keccak256("CURATOR_REMOVED");

    string private _name;
    address public owner;
    mapping(address => bool) public isCurator;

    struct Approval {
        bytes32 descriptorCoreHash;
        bytes32 presentationMetadataHash;
        bytes32 codeHash;
        bytes32 dependencySetHash;
        bytes32 category;
        uint256 approvedAt;
    }

    mapping(address => mapping(bytes32 => Approval)) private _approvals;
    mapping(address => mapping(bytes32 => uint256)) private _opIndexPlusOne;
    mapping(address => bytes32[]) private _opIdsByTarget;

    address[] private _targets;
    mapping(address => uint256) private _targetIndexPlusOne;
    mapping(address => bytes32) private _categoryByTarget;
    mapping(address => bytes32) private _codeHashByTarget;

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyCurator() {
        require(msg.sender == owner || isCurator[msg.sender], "NOT_CURATOR");
        _;
    }

    constructor(string memory name_, address owner_) {
        require(owner_ != address(0), "ZERO_OWNER");
        _name = name_;
        owner = owner_;
        emit GovernanceChanged(OWNER_CHANGED, owner_);
    }

    // ---------------- governance ----------------

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
        emit GovernanceChanged(OWNER_CHANGED, newOwner);
    }

    function addCurator(address curator) external onlyOwner {
        require(!isCurator[curator], "ALREADY_CURATOR");
        isCurator[curator] = true;
        emit GovernanceChanged(CURATOR_ADDED, curator);
    }

    function removeCurator(address curator) external onlyOwner {
        require(isCurator[curator], "NOT_A_CURATOR");
        isCurator[curator] = false;
        emit GovernanceChanged(CURATOR_REMOVED, curator);
    }

    // ---------------- curation ----------------

    function approveOperation(
        address target,
        OperationDescriptorCore calldata core,
        bytes32 presentationMetadataHash
    ) external onlyCurator {
        require(target.code.length > 0, "NO_CODE");
        require(_opIndexPlusOne[target][core.operationId] == 0, "ALREADY_APPROVED");

        bytes32 derived = core.kind == OperationKind.CALL
            ? OrielOperationId.callOperationId(core.rawSelector)
            : OrielOperationId.eventOperationId(core.rawTopic0);
        require(derived == core.operationId, "OP_ID_MISMATCH");

        bytes32 codeHash = target.codehash;
        bytes32 category = IOrielCapability(target).orielCategory();
        require(category != bytes32(0), "ZERO_CATEGORY");

        (DependencyCore[] memory deps,) = IOrielCapability(target).orielDependencies();
        OrielDependencyHash.requireAscending(deps);
        for (uint256 i = 0; i < deps.length; i++) {
            require(deps[i].target.code.length > 0, "DEP_NO_CODE");
            require(deps[i].target.codehash == deps[i].codeHash, "DEP_CODEHASH_MISMATCH");
        }
        bytes32 dependencySetHash = OrielDependencyHash.hashDependencies(deps);

        if (_targetIndexPlusOne[target] == 0) {
            _targets.push(target);
            _targetIndexPlusOne[target] = _targets.length;
            _categoryByTarget[target] = category;
            _codeHashByTarget[target] = codeHash;
        } else {
            require(_codeHashByTarget[target] == codeHash, "CODEHASH_CHANGED");
            require(_categoryByTarget[target] == category, "CATEGORY_CHANGED");
        }

        bytes32 descriptorCoreHash = OrielDescriptorHash.hashCore(core);
        _approvals[target][core.operationId] = Approval({
            descriptorCoreHash: descriptorCoreHash,
            presentationMetadataHash: presentationMetadataHash,
            codeHash: codeHash,
            dependencySetHash: dependencySetHash,
            category: category,
            approvedAt: block.timestamp
        });
        _opIdsByTarget[target].push(core.operationId);
        _opIndexPlusOne[target][core.operationId] = _opIdsByTarget[target].length;

        emit OperationApproved(
            target, core.operationId, descriptorCoreHash, presentationMetadataHash, category, codeHash
        );
    }

    function revokeOperation(address target, bytes32 operationId, string calldata reason) external onlyCurator {
        uint256 idxPlusOne = _opIndexPlusOne[target][operationId];
        require(idxPlusOne != 0, "NOT_APPROVED");

        bytes32[] storage ids = _opIdsByTarget[target];
        uint256 lastIdx = ids.length - 1;
        if (idxPlusOne - 1 != lastIdx) {
            bytes32 moved = ids[lastIdx];
            ids[idxPlusOne - 1] = moved;
            _opIndexPlusOne[target][moved] = idxPlusOne;
        }
        ids.pop();
        delete _opIndexPlusOne[target][operationId];
        delete _approvals[target][operationId];

        if (ids.length == 0) {
            uint256 tIdxPlusOne = _targetIndexPlusOne[target];
            uint256 tLast = _targets.length - 1;
            if (tIdxPlusOne - 1 != tLast) {
                address movedTarget = _targets[tLast];
                _targets[tIdxPlusOne - 1] = movedTarget;
                _targetIndexPlusOne[movedTarget] = tIdxPlusOne;
            }
            _targets.pop();
            delete _targetIndexPlusOne[target];
            delete _categoryByTarget[target];
            delete _codeHashByTarget[target];
        }

        emit OperationRevoked(target, operationId, reason);
    }

    // ---------------- views (Appendix A) ----------------

    function isOperationApproved(address target, bytes32 operationId) external view returns (bool) {
        return _opIndexPlusOne[target][operationId] != 0;
    }

    function operationApproval(address target, bytes32 operationId)
        external
        view
        returns (
            bytes32 descriptorCoreHash,
            bytes32 presentationMetadataHash,
            bytes32 codeHash,
            bytes32 dependencySetHash,
            bytes32 category,
            uint256 approvedAt
        )
    {
        Approval storage a = _approvals[target][operationId];
        require(a.approvedAt != 0, "NOT_APPROVED");
        return (
            a.descriptorCoreHash,
            a.presentationMetadataHash,
            a.codeHash,
            a.dependencySetHash,
            a.category,
            a.approvedAt
        );
    }

    function isApproved(address target) external view returns (bool) {
        return _opIdsByTarget[target].length > 0;
    }

    function categoryOf(address target) external view returns (bytes32) {
        return _categoryByTarget[target];
    }

    function codeHashOf(address target) external view returns (bytes32) {
        return _codeHashByTarget[target];
    }

    function entryCount() external view returns (uint256) {
        return _targets.length;
    }

    function entryAt(uint256 index) external view returns (address) {
        require(index < _targets.length, "INDEX_OUT_OF_BOUNDS");
        return _targets[index];
    }

    function registryName() external view returns (string memory) {
        return _name;
    }

    function registryChainId() external view returns (uint256) {
        return block.chainid;
    }

    // ---------------- superset enumeration (erratum E6) ----------------

    function operationCount(address target) external view returns (uint256) {
        return _opIdsByTarget[target].length;
    }

    function operationAt(address target, uint256 index) external view returns (bytes32) {
        require(index < _opIdsByTarget[target].length, "INDEX_OUT_OF_BOUNDS");
        return _opIdsByTarget[target][index];
    }
}
