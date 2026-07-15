# oriel-contracts

Solidity reference implementations for **Oriel** — *an open protocol for artwork that perceives the chain.*

Spec + test vectors: [oriel-art/oriel-spec](https://github.com/oriel-art/oriel-spec).

## Contents

| Path | Contents |
|---|---|
| `src/types/OrielTypes.sol` | Appendix A structs (canonical field order for hashing — erratum E1) |
| `src/interfaces/` | `IOrielCapability`, `IOrielRegistry`, `IOrielRegistryIndex`, `IOrielWritable`, `IOrielSnapshotEvents` |
| `src/libraries/` | `OrielConstants` (domains + categories), `OrielOperationId` (§7.8 derivation), `OrielSchemaHash` (§7.9) |
| `vectors/` | Vendored verbatim from oriel-spec — the cross-language parity fixture |
| `test/Vectors.t.sol` | Solidity ↔ spec vector parity (the CI gate) |

Coming next (Phase 1): the reference `OrielRegistry` (approval-time chain reads), `OrielCapabilityBase` + capability templates, public-good seeds (`LunarOracle`, `DailyBeacon`), and the snapshot emitter/attestation contracts.

## Build

```bash
forge build
forge test -vvv
```

Capability builds keep `cbor_metadata = false` and `bytecode_hash = "none"` so deployed bytecode is exactly what conformance scanners scan (erratum E8).

## License

MIT OR Apache-2.0. Contributions require a DCO sign-off (`git commit -s`) — see [CONTRIBUTING.md](CONTRIBUTING.md).
