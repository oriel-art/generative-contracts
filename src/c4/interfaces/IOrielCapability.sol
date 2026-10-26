// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {OperationDescriptorCore, OperationMetadata, DependencyCore, DependencyMetadata} from "../types/OrielTypes.sol";

/// @notice Capability base interface (Oriel 0.7, Appendix A).
interface IOrielCapability {
    function orielCategory() external view returns (bytes32);
    function orielVersion() external view returns (string memory);
    function orielDescription() external view returns (string memory);
    function orielOperationCount() external view returns (uint256);
    function orielOperationAt(uint256 index)
        external
        view
        returns (OperationDescriptorCore memory, OperationMetadata memory);
    function orielOperationById(bytes32 operationId)
        external
        view
        returns (OperationDescriptorCore memory, OperationMetadata memory);
    function orielDependencies()
        external
        view
        returns (DependencyCore[] memory, DependencyMetadata[] memory);
}
