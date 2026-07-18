# Oriel contracts — security audit scope & threat model

Status: **pre-mainnet.** Contracts are deployed on testnets only (Ethereum Sepolia,
Base Sepolia). This document scopes a security review, records the trust model, and
lists the invariants an external audit (or `/code-review ultra`) must prove. It
accompanies the `test/OrielRegistrySecurity.t.sol` + `test/OrielRegistryInvariant.t.sol`
suites added alongside it.

## 1. What the registry is

`OrielRegistry` is the on-chain trust root: a curator approves an operation on a
capability contract, and the registry **binds** that approval to the capability's
`codehash`, the descriptor-core hash, the presentation-metadata hash, the category,
and the dependency-set hash, all **read from chain state at approval time**.
Runtimes pin a registry by its own code hash and then trust `isApproved` /
`entryAt` / `operationApproval`. Approving is therefore attesting.

The registry is **immutable** (no proxy, no upgrade path) and has no ETH-handling,
no token logic, and no external value custody. The blast radius of a bug is a
**false attestation** (a runtime trusts a capability it should not, or fails to
trust one it should), not loss of funds.

## 2. Trust model & assumptions (READ THIS FIRST)

The registry deliberately does **not** enforce everything the protocol requires;
some guarantees are the curator's off-chain responsibility. An auditor must judge
the contracts against these boundaries, not against an assumption that the registry
is self-sufficient.

| Guarantee | Enforced by | Notes |
|---|---|---|
| Operation-id derivation is correct | **contract** (`OP_ID_MISMATCH`) | re-derived on-chain from `rawSelector`/`rawTopic0` |
| Approval binds the exact deployed `codehash` | **contract** | snapshotted at approval |
| Dependency set is code-hash-pinned + ascending | **contract** (`DEP_CODEHASH_MISMATCH`, `DEPS_UNSORTED`) | |
| A target's ops all share one codehash + category | **contract** (`CODEHASH_CHANGED`, `CATEGORY_CHANGED`) | |
| Only owner governs; only curators curate | **contract** (`onlyOwner`, `onlyCurator`) | |
| **§8.4 opcode conformance** (no DELEGATECALL/SELFDESTRUCT/CREATE/CREATE2/CALLCODE) | **OFF-CHAIN curator** | the registry binds the code hash but does not scan opcodes on-chain. Conformance is the curator's job (bitVerse curation console + the vendored §8.4 scanner). |
| The capability is genuinely **immutable** (non-metamorphic) | **OFF-CHAIN curator** (via §8.4) + **consumers** | see F-2 |
| The approved `core` matches the capability's self-declaration | **OFF-CHAIN curator** | see F-3 |
| Curators are honest | **operator** | a malicious curator can approve a non-conformant capability; mitigated by the audit rubric + the on-chain approval track record being the registry's reputation |

## 3. Findings & recommendations

No exploitable defect was found in `OrielRegistry` (see §4/§5). The items below are
design notes and hardening recommendations.

### F-1 (MEDIUM) — single-step ownership transfer can brick governance
`setOwner(newOwner)` transfers ownership in one step. A typo / wrong address makes
the registry ungovernable **permanently** (no approve/revoke, no way to fix — it is
immutable). Recommend a two-step transfer (`Ownable2Step`-style
`pendingOwner` + `acceptOwnership`). This is the single change most worth making
before mainnet.

### F-2 (LOW, by design) — code-hash binding assumes immutability; recommend a live re-check
The approval snapshots `codehash` at approval time. If a target is **metamorphic**
(can change code at the same address), the snapshot goes stale while `isApproved`
stays true. §8.4 (no `SELFDESTRUCT`/`CREATE2`) prevents metamorphism — but that is
enforced *off-chain*. Defence-in-depth: **runtimes/consumers should compare the
target's live `codehash` against the approval's `codeHash` at read time** and refuse
a mismatch. **Confirmed present** in the bitVerse consumer: `orielVerifiedRead`
(`server/utils/oriel/verified-read.ts`) fetches the live `codeHashOf(capability)`
and rejects a swapped/mutated capability. Any other runtime that pins this registry
MUST do the same.

### F-3 (LOW/MEDIUM, by design) — approved `core` is curator-supplied, not verified against the capability
`approveOperation` binds `hashCore(core)` where `core` is passed by the curator; the
registry re-derives only the `operationId`, not that `core` equals the capability's
own `orielOperationById(operationId).core`. A careless or compromised curator could
bind a descriptor (mutability, gas cost, schema hashes) that differs from what the
capability actually implements, and a runtime that trusts the registry's `core`
would act on the wrong contract. Options: (a) have `approveOperation` cross-check
`core` against `orielOperationById`; or (b) document that consumers must. Recommend
(a) if the extra approval-time call is acceptable.

### F-4 (INFO) — dead internal helpers
Slither flags `OrielCapabilityBase._addDependency` and
`OrielSnapshotEmitter._commitSnapshot` as unused. Confirm they are intended
extension points for subclasses (make `internal`) or remove them.

### F-5 (INFO) — Slither: 0 true positives
`slither .` reports 9 findings, all non-issues in context: `weak-prng` / `timestamp`
on the example **time-oracle** capabilities (`block.timestamp` is their input, not a
randomness source), the intentional discard of the presentation-metadata array in
`approveOperation` (`unused-return`), and cosmetic `too-many-digits`. No action.

### Confirmed strengths (no action)
- **Reentrancy is structurally dead.** `orielCategory()`/`orielDependencies()` are
  `view` in `IOrielCapability`, so the registry calls the (untrusted) target via
  **STATICCALL** — a re-entrant state write reverts. Independently, `onlyCurator`
  blocks a target (msg.sender ≠ curator) from re-entering approve/revoke. Proven in
  `test_reentrantDependenciesCallReverts`.
- **Enumeration integrity is fuzz-verified.** 128k randomized approve/revoke calls
  vs a ghost model, 0 violations (`OrielRegistryInvariant.t.sol`).
- Solc 0.8.24 checked arithmetic; array `- 1` sites are all guarded by a prior
  `require` that the length ≥ 1.

## 4. Invariants an audit / formal pass must prove

1. `isApproved(t) == (operationCount(t) > 0)` for all `t`.
2. `t` appears in the target enumeration (`entryAt`) **iff** `isApproved(t)`, exactly
   once (no duplicates, no gaps).
3. `entryCount() == |{ t : isApproved(t) }|` after any sequence of approve/revoke.
4. `revokeOperation` removes exactly the named op; the swap-pop never corrupts a
   sibling op's index nor a sibling target's index.
5. Only `owner` can `setOwner`/`addCurator`/`removeCurator`; only `owner`+curators can
   `approve`/`revoke`; a curator cannot escalate (add another curator).
6. Every stored `Approval.codeHash == target.codehash` at approval time, and all ops
   on one target share one `codeHash`/`category`.
7. No re-entrancy path mutates registry state during a target callback.

(1)–(6) are exercised by the added suites; a formal/audit pass should generalize (1)–(4).

## 5. Test coverage added

- `test/OrielRegistryInvariant.t.sol` — stateful invariant (ghost-model) fuzzing of
  the enumeration/approval consistency the directory + watcher depend on.
- `test/OrielRegistrySecurity.t.sol` — code-hash pinning (`CODEHASH_CHANGED` via
  `vm.etch`), category drift (`CATEGORY_CHANGED`), multi-op / multi-target revoke
  swap-pop, governance guards (zero-owner, non-owner, curator no-escalation), and the
  reentrancy-blocked proof.

Reproduce: `forge test` (invariant depth is Foundry-default 256×500). Static:
`slither . --filter-paths "lib/|test/|script/"`.

## 6. Out of scope (for this pass)

- Curator honesty / key management (operational; the audit rubric + reputation model
  cover it).
- RPC / indexer trust and the off-chain §8.4 scanner (reviewed separately in
  bitVerse: `shared/oriel/opcode-scan.ts`, `orielVerifiedRead`).
- The example capabilities' economic/game design (they are read-only oracles/beacons;
  reviewed for opcode conformance + no value custody only).
- Mainnet economic parameters / gas-cost model (a mainnet-gate item per the plan).
