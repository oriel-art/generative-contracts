# Contributing

All commits must be signed off (`git commit -s`), certifying the [DCO 1.1](https://developercertificate.org/). We use DCO rather than a CLA deliberately.

- C4 protocol interface changes require a spec-side OIP or erratum in [oriel-spec](https://github.com/oriel-art/oriel-spec) first — this repo implements, it does not define.
- `vectors/c4/` is vendored from oriel-spec and never hand-edited here.
- All PRs must pass `forge test`.

## Contract series

Use **Oriel Contract C1**, **Oriel Contract C2**, and so on for model names. Keep each model’s source, tests, scripts, deployment records, vectors, and documentation in the matching `cN/` subdirectory under each top-level folder. C1–C3 are reserved; their designs are still to be defined. The existing advanced implementation belongs to C4.
