// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {OrielRegistry} from "../src/registry/OrielRegistry.sol";
import {IOrielCapability} from "../src/interfaces/IOrielCapability.sol";
import {OperationDescriptorCore, OperationMetadata} from "../src/types/OrielTypes.sol";

/// Curator dogfood: enumerate every operation each capability declares
/// on-chain and approve it through the registry (which re-derives ids,
/// snapshots code hashes, and hashes dependencies itself).
///
/// Usage:
///   ORIEL_REGISTRY=0x... ORIEL_SEEDS=0xA,0xB,0xC \
///   forge script script/ApproveSeeds.s.sol --rpc-url $RPC_URL --private-key $CURATOR_KEY --broadcast
contract ApproveSeeds is Script {
    function run() external {
        OrielRegistry registry = OrielRegistry(vm.envAddress("ORIEL_REGISTRY"));
        address[] memory seeds = vm.envAddress("ORIEL_SEEDS", ",");

        vm.startBroadcast();
        for (uint256 i = 0; i < seeds.length; i++) {
            IOrielCapability capability = IOrielCapability(seeds[i]);
            uint256 operationCount = capability.orielOperationCount();
            for (uint256 j = 0; j < operationCount; j++) {
                (OperationDescriptorCore memory core, OperationMetadata memory meta) =
                    capability.orielOperationAt(j);
                if (registry.isOperationApproved(seeds[i], core.operationId)) continue;
                registry.approveOperation(seeds[i], core, bytes32(0));
                console2.log("approved", seeds[i], meta.name);
            }
        }
        vm.stopBroadcast();
    }
}
