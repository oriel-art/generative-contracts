// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

/// @notice Core protocol types, verbatim from Oriel 0.7 Appendix A.
/// @dev Field order of OperationDescriptorCore is CANONICAL for hashing
///      (erratum E1): descriptorCoreHash = keccak256(abi.encode(core)).

enum OperationKind {
    CALL,
    EVENT
}

struct OperationDescriptorCore {
    bytes32 operationId;
    bytes4 rawSelector;
    bytes32 rawTopic0;
    OperationKind kind;
    uint8 mutability;
    bytes32 inputSchemaHash;
    bytes32 outputSchemaHash;
    uint8 privacyTier;
    uint32 maxResponseBytes;
    bool temporalSupport;
    uint32 maxEventRate;
    uint32 maxArgumentBytes;
    uint32 maxGas;
    uint32 minCallIntervalSeconds;
}

struct OperationMetadata {
    string name;
    string description;
    string[] inputNames;
    string[] outputNames;
    string metadataURI; // content-addressed
}

struct DependencyCore {
    address target;
    bytes32 codeHash;
}

struct DependencyMetadata {
    string purpose;
}

struct PresentationRecord {
    string canonicalSignature;
    string displayName;
    string[] inputFieldNames;
    string[] inputFieldDescriptions;
    uint8 riskClass;
    bytes32 fullMetadataHash;
}
