// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

/// @notice Chain-local registry interface (Oriel 0.7, Appendix A / §8).
/// @dev A registry MUST reside on the same chain as the capabilities it
///      approves (§8.2). Approval binds to contract address, code hash,
///      per-operation descriptor core hash, category, and (for writes,
///      SHOULD) presentation metadata hash (§8.3).
interface IOrielRegistry {
    function isOperationApproved(address target, bytes32 operationId) external view returns (bool);

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
        );

    /// @dev True iff at least one operation is currently approved for `target` (erratum E6).
    function isApproved(address target) external view returns (bool);
    function categoryOf(address target) external view returns (bytes32);
    function codeHashOf(address target) external view returns (bytes32);

    function entryCount() external view returns (uint256);
    function entryAt(uint256 index) external view returns (address);

    function registryName() external view returns (string memory);
    function registryChainId() external view returns (uint256);

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
}
