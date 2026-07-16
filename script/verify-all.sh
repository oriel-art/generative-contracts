#!/usr/bin/env bash
# Verify all deployed Oriel contracts on Etherscan-family explorers.
# One Etherscan V2 key covers every chain.
#
# Usage: ETHERSCAN_API_KEY=... ./script/verify-all.sh
set -uo pipefail
: "${ETHERSCAN_API_KEY:?set ETHERSCAN_API_KEY}"

DEPLOYER=0x4384D6116b126eBC76a31228AE71aA31F3f1c0E7
REG_ARGS=$(cast abi-encode "constructor(string,address)" "Oriel Registry (bitVerse)" $DEPLOYER)
IDX_ARGS=$(cast abi-encode "constructor(string,address)" "Oriel Registry Index" $DEPLOYER)
CLOCK_ARGS=$(cast abi-encode "constructor(uint256)" 86400)

verify() { # chain address path:name [constructor-args]
  local chain=$1 addr=$2 target=$3 args=${4:-}
  local extra=()
  [ -n "$args" ] && extra=(--constructor-args "$args")
  echo "--- $chain $target $addr"
  forge verify-contract "$addr" "$target" --chain "$chain" \
    --etherscan-api-key "$ETHERSCAN_API_KEY" --watch "${extra[@]}" \
    || echo "FAILED: $chain $addr"
}

# ---- Ethereum Sepolia (11155111) ----
verify sepolia 0x8C554748Ae2f50AA72C3d2B36b4E1617a332199d src/registry/OrielRegistry.sol:OrielRegistry "$REG_ARGS"
verify sepolia 0x0a34231BdE1EBa90BF051E23a7121446Fe10e63A src/registry/OrielRegistryIndex.sol:OrielRegistryIndex "$IDX_ARGS"
verify sepolia 0x45b37d204BB74B8743C8c22ee9baf84a370E0F36 src/capability/examples/BasefeeOracle.sol:BasefeeOracle
verify sepolia 0xAAC99360D63Ad29Db6760714083aC695d80e2188 src/capability/examples/LunarOracle.sol:LunarOracle
verify sepolia 0xfEf6AC423FDE9F9aC22A454AAAF7bd08Ad51e86D src/capability/examples/BlockClock.sol:BlockClock "$CLOCK_ARGS"
verify sepolia 0xF1025a2b90546714Cf3EC81d58ab85F90974ca23 src/capability/examples/DailyBeacon.sol:DailyBeacon
verify sepolia 0x84020731a636edD066297fD42681441a50366583 src/capability/examples/CivicLedger.sol:CivicLedger

# ---- Base Sepolia (84532) ----
verify base-sepolia 0x0a34231BdE1EBa90BF051E23a7121446Fe10e63A src/registry/OrielRegistry.sol:OrielRegistry "$REG_ARGS"
verify base-sepolia 0x45b37d204BB74B8743C8c22ee9baf84a370E0F36 src/registry/OrielRegistryIndex.sol:OrielRegistryIndex "$IDX_ARGS"
verify base-sepolia 0xAAC99360D63Ad29Db6760714083aC695d80e2188 src/capability/examples/BasefeeOracle.sol:BasefeeOracle
verify base-sepolia 0xfEf6AC423FDE9F9aC22A454AAAF7bd08Ad51e86D src/capability/examples/LunarOracle.sol:LunarOracle
verify base-sepolia 0xF1025a2b90546714Cf3EC81d58ab85F90974ca23 src/capability/examples/BlockClock.sol:BlockClock "$CLOCK_ARGS"
verify base-sepolia 0x84020731a636edD066297fD42681441a50366583 src/capability/examples/DailyBeacon.sol:DailyBeacon
verify base-sepolia 0x1e668103cb6610d07c4eDce64dCCf0F844df762A src/capability/examples/CivicLedger.sol:CivicLedger

echo "done."
