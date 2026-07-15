// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {OrielRegistry} from "../src/registry/OrielRegistry.sol";
import {OrielRegistryIndex} from "../src/registry/OrielRegistryIndex.sol";
import {BasefeeOracle} from "../src/capability/examples/BasefeeOracle.sol";
import {LunarOracle} from "../src/capability/examples/LunarOracle.sol";
import {BlockClock} from "../src/capability/examples/BlockClock.sol";
import {DailyBeacon} from "../src/capability/examples/DailyBeacon.sol";
import {CivicLedger} from "../src/capability/examples/CivicLedger.sol";

/// Usage:
///   forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $DEPLOYER_KEY --broadcast
/// Set ORIEL_OWNER to the Safe address that should govern the registry/index
/// (defaults to the deployer when unset).
contract Deploy is Script {
    function run() external {
        address configuredOwner = vm.envOr("ORIEL_OWNER", address(0));
        vm.startBroadcast();
        address owner = configuredOwner == address(0) ? msg.sender : configuredOwner;

        OrielRegistry registry = new OrielRegistry("Oriel Registry (bitVerse)", owner);
        OrielRegistryIndex index = new OrielRegistryIndex("Oriel Registry Index", owner);
        BasefeeOracle basefee = new BasefeeOracle();
        LunarOracle lunar = new LunarOracle();
        BlockClock clock = new BlockClock(86400);
        DailyBeacon beacon = new DailyBeacon();
        CivicLedger civic = new CivicLedger();

        vm.stopBroadcast();

        console2.log("chainId           ", block.chainid);
        console2.log("owner             ", owner);
        console2.log("OrielRegistry     ", address(registry));
        console2.log("OrielRegistryIndex", address(index));
        console2.log("BasefeeOracle     ", address(basefee));
        console2.log("LunarOracle       ", address(lunar));
        console2.log("BlockClock        ", address(clock));
        console2.log("DailyBeacon       ", address(beacon));
        console2.log("CivicLedger       ", address(civic));
    }
}
