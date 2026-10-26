// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

/// @notice Cross-chain discovery index (Oriel 0.7, Appendix A / §8.5).
///         Discovery only — authoritative approval is chain-local.
interface IOrielRegistryIndex {
    function isRegistryListed(uint256 chainId, address registry) external view returns (bool);
    function registryCount() external view returns (uint256);
    function registryAt(uint256 index) external view returns (uint256 chainId, address registry);
    function indexName() external view returns (string memory);

    event RegistryListed(uint256 indexed chainId, address indexed registry, string name);
    event RegistryDelisted(uint256 indexed chainId, address indexed registry, string reason);
}
