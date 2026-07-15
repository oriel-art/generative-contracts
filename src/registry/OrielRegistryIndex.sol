// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {IOrielRegistryIndex} from "../interfaces/IOrielRegistryIndex.sol";

/// @notice Reference cross-chain discovery index (Oriel 0.7 section 8.5).
///         Discovery only — authoritative approval is always chain-local.
contract OrielRegistryIndex is IOrielRegistryIndex {
    event IndexOwnerChanged(address indexed newOwner);

    string private _name;
    address public owner;

    struct Entry {
        uint256 chainId;
        address registry;
    }

    Entry[] private _entries;
    mapping(uint256 => mapping(address => uint256)) private _indexPlusOne;

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(string memory name_, address owner_) {
        require(owner_ != address(0), "ZERO_OWNER");
        _name = name_;
        owner = owner_;
    }

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        owner = newOwner;
        emit IndexOwnerChanged(newOwner);
    }

    function listRegistry(uint256 chainId, address registry, string calldata name_) external onlyOwner {
        require(registry != address(0), "ZERO_REGISTRY");
        require(_indexPlusOne[chainId][registry] == 0, "ALREADY_LISTED");
        _entries.push(Entry({chainId: chainId, registry: registry}));
        _indexPlusOne[chainId][registry] = _entries.length;
        emit RegistryListed(chainId, registry, name_);
    }

    function delistRegistry(uint256 chainId, address registry, string calldata reason) external onlyOwner {
        uint256 idxPlusOne = _indexPlusOne[chainId][registry];
        require(idxPlusOne != 0, "NOT_LISTED");
        uint256 lastIdx = _entries.length - 1;
        if (idxPlusOne - 1 != lastIdx) {
            Entry memory moved = _entries[lastIdx];
            _entries[idxPlusOne - 1] = moved;
            _indexPlusOne[moved.chainId][moved.registry] = idxPlusOne;
        }
        _entries.pop();
        delete _indexPlusOne[chainId][registry];
        emit RegistryDelisted(chainId, registry, reason);
    }

    function isRegistryListed(uint256 chainId, address registry) external view returns (bool) {
        return _indexPlusOne[chainId][registry] != 0;
    }

    function registryCount() external view returns (uint256) {
        return _entries.length;
    }

    function registryAt(uint256 index) external view returns (uint256 chainId, address registry) {
        require(index < _entries.length, "INDEX_OUT_OF_BOUNDS");
        Entry storage e = _entries[index];
        return (e.chainId, e.registry);
    }

    function indexName() external view returns (string memory) {
        return _name;
    }
}
