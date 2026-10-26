# Oriel Contract C4

The advanced model in the [Oriel Contract series](../../README.md), containing the existing Solidity reference implementations for **Oriel** — *an open protocol for artwork that perceives the chain.*

Spec + test vectors: [oriel-art/oriel-spec](https://github.com/oriel-art/oriel-spec).

C4 currently provides protocol infrastructure: registries, capabilities, and a snapshot mixin. It is not yet a standalone generative-art mint contract. Existing Solidity component names and behavior are retained.

All commands and code paths below are relative to the repository root.

## Contents

| Path | Contents |
|---|---|
| `src/c4/types/OrielTypes.sol` | Appendix A structs (canonical field order for hashing — erratum E1) |
| `src/c4/interfaces/` | `IOrielCapability`, `IOrielRegistry`, `IOrielRegistryIndex`, `IOrielWritable`, `IOrielSnapshotEvents` |
| `src/c4/libraries/` | `OrielConstants` (domains, categories, mutability codes), `OrielOperationId` (§7.8), `OrielSchemaHash` (§7.9), `OrielDescriptorHash` (E10), `OrielDependencyHash` (E9) |
| `src/c4/registry/OrielRegistry.sol` | Reference registry: approves by reading the chain at approval time (re-derives operation ids, snapshots code hashes, reads the category, computes the dependency-set hash on-chain). Immutable; role-gated (owner Safe + curators); supersets Appendix A with per-target operation enumeration (E6) |
| `src/c4/registry/OrielRegistryIndex.sol` | Cross-chain discovery index (§8.5) — discovery only, never authority |
| `src/c4/capability/OrielCapabilityBase.sol` | Descriptor storage + enumeration + self-consistency checks; passes §8.4 itself |
| `src/c4/capability/examples/` | The public-good seeds — see below |
| `src/c4/snapshot/OrielSnapshotEmitter.sol` | Mint-contract mixin emitting the §9.2 atomic commitment |
| `script/c4/Deploy.s.sol` | Testnet deployment script |
| `vectors/c4/` | Vendored verbatim from oriel-spec — the cross-language parity fixture |
| `test/c4/` | Vector parity (the CI gate), registry behavior, capability behavior |

## The example capabilities

Each doubles as a per-category template; every descriptor is declared on-chain by the contract itself and re-verified by the registry at approval time.

| Capability | Category | Trust model |
|---|---|---|
| `BasefeeOracle` | Data | Deterministic per block. The spec's "Secure Minimum" scenario. |
| `LunarOracle` | Data | **Keeperless**: mean lunar phase as a pure function of block time (apparent phase deviates up to ~15 h — documented). |
| `BlockClock` | Temporal | Fixed epochs; permissionless `checkpoint()` keeper poke emits `EpochAdvanced`. |
| `DailyBeacon` | Randomness | One value per UTC day from `prevrandao` + parent blockhash. Aesthetic-grade; proposer-biasable within known bounds; sequencer-provided on OP-stack L2s. |
| `CivicLedger` | State | Shared grid; unrestricted reads, enforced write policy with advisory `canWrite` mirror (§7.4/7.10). |

Deployment records: `deployments/c4/`. Security review scope: [audit scope](security/audit-scope.md).

## Build

```bash
forge build
forge test --match-path 'test/c4/*.t.sol' -vvv
```

`cbor_metadata = false` and `bytecode_hash = "none"` are deliberate: deployed bytecode is exactly what conformance scanners scan (erratum E8).

## Deploy (testnets)

```bash
export ORIEL_OWNER=0xYourSafe   # optional; defaults to the deployer
forge script script/c4/Deploy.s.sol --rpc-url "$RPC_URL" --private-key "$DEPLOYER_KEY" --broadcast
```

## License

MIT OR Apache-2.0. Contributions require a DCO sign-off (`git commit -s`) — see [CONTRIBUTING.md](../../CONTRIBUTING.md).
