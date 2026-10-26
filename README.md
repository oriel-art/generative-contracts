# Oriel Contracts

A series of smart contracts for generative art, named **Oriel Contract C1**, **Oriel Contract C2**, **Oriel Contract C3**, and **Oriel Contract C4**.

The C-number identifies a model in the series, with increasing capability and complexity. It is separate from a model’s release version and from the Oriel protocol version.

## The series

| Model | Status | Scope |
|---|---|---|
| Oriel Contract C1 | Planned — first to build | Starting model; requirements to be defined. |
| Oriel Contract C2 | Planned — second to build | Requirements to be defined after C1. |
| Oriel Contract C3 | Planned — third to build | Requirements to be defined after C2. |
| [Oriel Contract C4](docs/c4/README.md) | Existing advanced implementation — fourth in the series | Chain-aware protocol infrastructure: capability registry, discovery index, example capabilities, and snapshot commitments. |

The previous codebase now lives under `c4/` within each project folder. C1–C3 are reserved model names; no implementations have been added yet.

## Repository layout

| Path | Contents |
|---|---|
| `src/c4/` | C4 Solidity components |
| `test/c4/` | C4 behavior, security, invariant, and vector tests |
| `script/c4/` | C4 deployment, seed approval, and explorer verification scripts |
| `deployments/c4/` | Existing C4 testnet deployment records |
| `vectors/c4/` | C4 protocol test vectors |
| `docs/c4/` | C4 implementation guide and security review scope |
| `lib/` | Shared development dependencies |

Future models use the corresponding `c1/`, `c2/`, or `c3/` subdirectories. Foundry builds and tests all implemented models from the repository root.

## Build and test

```bash
forge build
forge test -vvv
```

To run only C4 tests:

```bash
forge test --match-path 'test/c4/*.t.sol' -vvv
```

See the [C4 guide](docs/c4/README.md) for its components, protocol references, and testnet deployment command.

## License

MIT OR Apache-2.0. Contributions require a DCO sign-off (`git commit -s`) — see [CONTRIBUTING.md](CONTRIBUTING.md).
