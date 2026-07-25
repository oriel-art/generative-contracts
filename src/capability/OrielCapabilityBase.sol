// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {IOrielCapability} from "../interfaces/IOrielCapability.sol";
import {
    OperationDescriptorCore,
    OperationMetadata,
    DependencyCore,
    DependencyMetadata,
    OperationKind
} from "../types/OrielTypes.sol";
import {OrielOperationId} from "../libraries/OrielOperationId.sol";

/// @notice Base implementation of IOrielCapability: descriptor storage,
///         enumeration, and self-consistency checks.
/// @dev This contract must itself satisfy section 8.4: no external library
///      calls (public Solidity libraries link via DELEGATECALL), no `new`
///      (CREATE), internal libraries only. Dependencies must be added in
///      strictly ascending target order (erratum E9).
abstract contract OrielCapabilityBase is IOrielCapability {
    bytes32 private immutable _category;
    string private _version;
    string private _description;

    OperationDescriptorCore[] private _cores;
    OperationMetadata[] private _metas;
    mapping(bytes32 => uint256) private _indexPlusOneById;

    DependencyCore[] private _depCores;
    DependencyMetadata[] private _depMetas;

    constructor(bytes32 category_, string memory version_, string memory description_) {
        require(category_ != bytes32(0), "ZERO_CATEGORY");
        _category = category_;
        _version = version_;
        _description = description_;
    }

    // ---------------- IOrielCapability ----------------

    function orielCategory() external view returns (bytes32) {
        return _category;
    }

    function orielVersion() external view returns (string memory) {
        return _version;
    }

    function orielDescription() external view returns (string memory) {
        return _description;
    }

    function orielOperationCount() external view returns (uint256) {
        return _cores.length;
    }

    function orielOperationAt(uint256 index)
        external
        view
        returns (OperationDescriptorCore memory, OperationMetadata memory)
    {
        require(index < _cores.length, "INDEX_OUT_OF_BOUNDS");
        return (_cores[index], _metas[index]);
    }

    function orielOperationById(bytes32 operationId)
        external
        view
        returns (OperationDescriptorCore memory, OperationMetadata memory)
    {
        uint256 idxPlusOne = _indexPlusOneById[operationId];
        require(idxPlusOne != 0, "UNKNOWN_OPERATION");
        return (_cores[idxPlusOne - 1], _metas[idxPlusOne - 1]);
    }

    function orielDependencies()
        external
        view
        returns (DependencyCore[] memory, DependencyMetadata[] memory)
    {
        return (_depCores, _depMetas);
    }

    // ---------------- construction helpers ----------------

    function _addOperation(OperationDescriptorCore memory core, OperationMetadata memory meta) internal {
        bytes32 derived = core.kind == OperationKind.CALL
            ? OrielOperationId.callOperationId(core.rawSelector)
            : OrielOperationId.eventOperationId(core.rawTopic0);
        require(core.operationId == derived, "OP_ID_MISMATCH");
        require(_indexPlusOneById[core.operationId] == 0, "DUPLICATE_OPERATION");
        _cores.push(core);
        _metas.push(meta);
        _indexPlusOneById[core.operationId] = _cores.length;
    }

    function _addDependency(DependencyCore memory dep, DependencyMetadata memory meta) internal {
        if (_depCores.length > 0) {
            require(dep.target > _depCores[_depCores.length - 1].target, "DEPS_UNSORTED");
        }
        _depCores.push(dep);
        _depMetas.push(meta);
    }

    function _callCore(
        bytes4 selector,
        uint8 mutability,
        bytes32 inputSchemaHash,
        bytes32 outputSchemaHash,
        uint8 privacyTier,
        uint32 maxResponseBytes,
        uint32 maxArgumentBytes,
        uint32 maxGas,
        uint32 minCallIntervalSeconds
    ) internal pure returns (OperationDescriptorCore memory) {
        return OperationDescriptorCore({
            operationId: OrielOperationId.callOperationId(selector),
            rawSelector: selector,
            rawTopic0: bytes32(0),
            kind: OperationKind.CALL,
            mutability: mutability,
            inputSchemaHash: inputSchemaHash,
            outputSchemaHash: outputSchemaHash,
            privacyTier: privacyTier,
            maxResponseBytes: maxResponseBytes,
            temporalSupport: false,
            maxEventRate: 0,
            maxArgumentBytes: maxArgumentBytes,
            maxGas: maxGas,
            minCallIntervalSeconds: minCallIntervalSeconds
        });
    }

    function _eventCore(
        bytes32 topic0,
        bytes32 indexedSchemaHash,
        bytes32 dataSchemaHash,
        uint32 maxEventRate,
        uint32 maxResponseBytes
    ) internal pure returns (OperationDescriptorCore memory) {
        return OperationDescriptorCore({
            operationId: OrielOperationId.eventOperationId(topic0),
            rawSelector: bytes4(0),
            rawTopic0: topic0,
            kind: OperationKind.EVENT,
            mutability: 0,
            inputSchemaHash: indexedSchemaHash,
            outputSchemaHash: dataSchemaHash,
            privacyTier: 0,
            maxResponseBytes: maxResponseBytes,
            temporalSupport: false,
            maxEventRate: maxEventRate,
            maxArgumentBytes: 0,
            maxGas: 0,
            minCallIntervalSeconds: 0
        });
    }

    function _meta(string memory name_, string memory description_)
        internal
        pure
        returns (OperationMetadata memory)
    {
        return OperationMetadata({
            name: name_,
            description: description_,
            inputNames: new string[](0),
            outputNames: new string[](0),
            metadataURI: ""
        });
    }
}
