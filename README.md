# oriel-contracts

Solidity reference implementations for **Oriel** — *an open protocol for artwork that perceives the chain.*

Spec + test vectors: [oriel-art/oriel-spec](https://github.com/oriel-art/oriel-spec).

## Contents

| Path | Contents |
|---|---|
| `src/types/OrielTypes.sol` | Appendix A structs (canonical field order for hashing — erratum E1) |
| `src/interfaces/` | `IOrielCapability`, `IOrielRegistry`, `IOrielRegistryIndex`, `IOrielWritable`, `IOrielSnapshotEvents` |
| `src/libraries/` | `OrielConstants` (domains, categories, mutability codes), `OrielOperationId` (§7.8), `OrielSchemaHash` (§7.9), `OrielDescriptorHash` (E10), `OrielDependencyHash` (E9) |
| `src/registry/OrielRegistry.sol` | Reference registry: approves by reading the chain at approval time (re-derives operation ids, snapshots code hashes, reads the category, computes the dependency-set hash on-chain). Immutable; role-gated (owner Safe + curators); supersets Appendix A with per-target operation enumeration (E6) |
| `src/registry/OrielRegistryIndex.sol` | Cross-chain discovery index (§8.5) — discovery only, never authority |
| `src/capability/OrielCapabilityBase.sol` | Descriptor storage + enumeration + self-consistency checks; passes §8.4 itself |
| `src/capability/examples/` | The public-good seeds — see below |
| `src/snapshot/OrielSnapshotEmitter.sol` | Mint-contract mixin emitting the §9.2 atomic commitment |
| `script/Deploy.s.sol` | Testnet deployment script |
| `vectors/` | Vendored verbatim from oriel-spec — the cross-language parity fixture |
| `test/` | Vector parity (the CI gate), registry behavior, capability behavior |

## The example capabilities

Each doubles as a per-category template; every descriptor is declared on-chain by the contract itself and re-verified by the registry at approval time.

| Capability | Category | Trust model |
|---|---|---|
| `BasefeeOracle` | Data | Deterministic per block. The spec's "Secure Minimum" scenario. |
| `LunarOracle` | Data | **Keeperless**: mean lunar phase as a pure function of block time (apparent phase deviates up to ~15 h — documented). |
| `BlockClock` | Temporal | Fixed epochs; permissionless `checkpoint()` keeper poke emits `EpochAdvanced`. |
| `DailyBeacon` | Randomness | One value per UTC day from `prevrandao` + parent blockhash. Aesthetic-grade; proposer-biasable within known bounds; sequencer-provided on OP-stack L2s. |
| `CivicLedger` | State | Shared grid; unrestricted reads, enforced write policy with advisory `canWrite` mirror (§7.4/7.10). |

## Build

```bash
forge build
forge test -vvv
```

`cbor_metadata = false` and `bytecode_hash = "none"` are deliberate: deployed bytecode is exactly what conformance scanners scan (erratum E8).

## Deploy (testnets)

```bash
export ORIEL_OWNER=0xYourSafe   # optional; defaults to the deployer
forge script script/Deploy.s.sol --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" --broadcast
```

## License

MIT OR Apache-2.0. Contributions require a DCO sign-off (`git commit -s`) — see [CONTRIBUTING.md](CONTRIBUTING.md).
