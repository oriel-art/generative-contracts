// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

/// @notice Domain-separation and category constants (Oriel 0.7, Appendix C + section 7.8),
///         plus the reference mutability encoding (erratum E10).
/// @dev Values are asserted against vectors/oriel-vectors.json in test/Vectors.t.sol.
library OrielConstants {
    // Operation-id domain separators (section 7.8)
    bytes32 internal constant CALL_DOMAIN = keccak256("ORIEL_CALL");
    bytes32 internal constant EVENT_DOMAIN = keccak256("ORIEL_EVENT");

    // Category constants (Appendix C)
    bytes32 internal constant CATEGORY_DATA = keccak256("ORIEL_DATA");
    bytes32 internal constant CATEGORY_TEMPORAL = keccak256("ORIEL_TEMPORAL");
    bytes32 internal constant CATEGORY_RANDOMNESS = keccak256("ORIEL_RANDOMNESS");
    bytes32 internal constant CATEGORY_STATE = keccak256("ORIEL_STATE");
    bytes32 internal constant CATEGORY_COMPUTATION = keccak256("ORIEL_COMPUTATION");
    bytes32 internal constant CATEGORY_MESSAGING = keccak256("ORIEL_MESSAGING");
    bytes32 internal constant CATEGORY_REGISTRY = keccak256("ORIEL_REGISTRY");

    // Reference mutability encoding for OperationDescriptorCore.mutability (erratum E10)
    uint8 internal constant MUTABILITY_PURE = 0;
    uint8 internal constant MUTABILITY_VIEW = 1;
    uint8 internal constant MUTABILITY_NONPAYABLE = 2;
    uint8 internal constant MUTABILITY_PAYABLE = 3;
}
