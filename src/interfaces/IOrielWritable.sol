// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

/// @notice Write pre-check (Oriel 0.7 §7.10). Advisory only — the contract
///         MUST enforce its write policy during execution.
interface IOrielWritable {
    function canWrite(address actor, bytes4 selector, bytes calldata args)
        external
        view
        returns (bool allowed, string memory reason);
}
