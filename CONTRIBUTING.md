# Contributing

All commits must be signed off (`git commit -s`), certifying the [DCO 1.1](https://developercertificate.org/). We use DCO rather than a CLA deliberately.

- Interface changes require a spec-side OIP or erratum in [oriel-spec](https://github.com/oriel-art/oriel-spec) first — this repo implements, it does not define.
- `vectors/` is vendored from oriel-spec and never hand-edited here.
- All PRs must pass `forge test`.
