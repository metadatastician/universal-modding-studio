<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->

# Universal Modding Studio Component Readiness Assessment

**Standard:** [Component Readiness Grades (CRG) v2.0](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)
**Assessed:** 2026-07-25 (re-assessed for the profile realignment; previous
assessment 2026-07-22)
**Assessor:** Claude (PR E of the staged lineage migration), from real local runs
and the repo's CI workflows — evidence over intuition, no aspirational grading.

**Current Grade:** D

## Summary

| Component | Grade | Release stage | Evidence summary | Last assessed |
|---|---|---|---|---|
| Profile SDK (`crates/ums-profile-sdk`) | C | Alpha-stable | 12 tests cover registration, malformed ID/version rejection, reflection, fixtures, deterministic adapter behavior, duplicate refusal, two-way profile isolation, IDApTIK compiler execution through `packageCompiler`, explicit Slavia no-compiler behaviour, unknown-profile refusal and rejection of an unsupported declared compiler version. The SDK hosts the CLI and is the sole repository-public profile surface; the implementation crate is non-publishable. A direct `cargo package -p ums-profile-sdk` probe currently rejects the internal path dependency, so standalone registry publication is not claimed. | 2026-08-29 |
| IDApTIK edit compatibility engine (`crates/ums-ai-edit`, Rust/Crusoe) | C | Alpha-stable | 65 tests (miniKanren kernel, verbs, six runtime relations, deterministic replay and explicit profile dispatch) + sample replay, gated by `rust-ci.yml` with `clippy -D warnings`. | 2026-08-29 |
| Package/DLC bridge (`crates/ums-dlc` + `schemas/`) | C | Alpha-stable | 39 tests; validates all in-tree artifacts, legacy-manifest compatibility, v1→v2 migration and capability declarations. | 2026-07-25 |
| Chronicles of Slavia profile | D | Design fixture | Reflection and isolation are tested against a minimal Zone A fixture; no UMS compiler, loader or runtime integration exists. | 2026-07-25 |
| Enaction adapter | X | Designed only | Typed preview seam and request schema exist; no real adapter or loader exists. | 2026-07-25 |
| Generation source of truth (`config/*.ncl`) | C | Alpha-stable | `config-check` typechecks every source AND requires all three `config/bad/bad_*.ncl` negative fixtures to be rejected; `gen-check` diffs generated artifacts and fails when `nickel` is absent rather than skipping. Gated by `config-gen.yml`. | 2026-07-22 |
| Zig FFI (`ffi/zig/`) | D | Compatibility FFI | 24 integration tests are CI-gated and Zig 0.14.0 is pinned. Unified-hexadeca integration and the Idris2-to-generated-header chain remain incomplete; no canonical `unified-hexadeca-api` implementation is currently locatable, so compliance is not claimed or approximated. | 2026-08-29 |
| Licence hygiene gate | C | Alpha-stable | Three steps, each negative-tested: a planted MPL header, a truncated LICENSE and an unattributed JSON file each make it fail. Polarity inverted with the AGPL relicence. | 2026-07-22 |
| Idris2 ABI (`abi/`) | C | Beta | All 17 modules typecheck under `idris-ci.yml`, including `ProvenBridge`. Raw JSON extraction is private; the exported parser admits only `ValidatedLevel` values after all four `Dec` procedures construct their witnesses. The extractor executable checks full-section decoding, malformed input, and a planted rejection for each witness class. Zig parser/representation parity remains unproved. No `believe_me`, `postulate` or `assert_total`. Caveat: CI builds against a `proven` with `Proven.SafeMath.Proofs` removed, disclosed in `scripts/proven-min.ipkg`. | 2026-08-29 |
| SPARK/GNATprove reference model (`spark/`) | X | — | Does not exist. Decided in ADR-0003 (§3) and not started; `gnatprove` is not installed on the development machine. | 2026-07-22 |
| Zig hexadeca connector | X | Blocked dependency | Does not exist. Estate reconnaissance cannot locate a canonical `unified-hexadeca-api`; Hypatia's project-local 16-transport pattern is not silently copied here. | 2026-08-29 |
| Interactive studio frontend | X | — | 0% — not started. The engine has no interactive consumer. Supersedes the former "AffineScript shell" row: IDApTIK uses Bevy, but UMS remains an independent authoring application and its portal is currently a design reference. | 2026-07-25 |
| Reversible VM (`dlc/vm/`, `.affine`) | X | — | Has never compiled. No AffineScript toolchain is wired to this repo; the `.affine` sources have never been exercised by anything, so its declared `every-instruction-has-an-inverse` guarantee has never been checked. | 2026-07-22 |

## Why Grade D — for a much narrower reason than before

CRG defines the project line as the grade of the worst deployed component. It
is still **D**, but the reason has changed completely.

The 2026-07-20 assessment was held at D by three things: the engine was Python
with no CI, the DLC schema check ran local-only, and the ABI was 16/17. **All
three are now resolved.** The engine and the validator are Rust/Crusoe, CI-gated, with
profile, engine and package negative tests demonstrating the gates can fail.

`abi/ProvenBridge.idr` landed on 2026-07-20 (`c86c84c`) and its extractors on
2026-07-21 (`a8b7663`). It has no typed holes, `idaptik-ums.ipkg` declares
`depends = proven` uncommented, and `idris-ci.yml` has been green on every run
since 2026-07-22. **The D grade was held for five days by this table, not by
the tree** — the row was never re-run after the work landed. Re-assessed
2026-08-29 against a local reproduction of the CI pipeline: 17/17 modules
typecheck, extractor/admission tests 44/44.

What remains:

- **The Idris extraction boundary is closed; cross-language parity remains
  open.** Total `Dec`-returning procedures construct witnesses for the four
  `ValidatedLevel` obligations. `ProvenBridge` keeps raw extraction private
  and exports only `parseValidatedLevelJson`; planted semantic negatives cover
  every witness class. This confirms the named Idris2 path. It does not prove
  that Zig's independently implemented parser and layouts are equivalent.
- **Not X or E:** every component above the D-line runs real, failing-able
  tests that currently pass, with documented scope.
- The X-graded components (frontends, SPARK model, hexadeca connector, VM) are
  not deployed and gate nothing — but they are why this cannot claim more than
  alpha-unstable, because the studio still has no interactive surface and the
  VM has never compiled.

**Assessment basis.** The Rust and Nickel gates were verified by local runs of
the exact commands CI executes. `rust-ci.yml` and `config-gen.yml` are new
files whose first CI execution happens when their branches reach `main`; every
workflow here filters on `pull_request: branches: [main]`, so a stacked PR
does not trigger them. Graded on measured local evidence, with that caveat
stated rather than papered over.

## Known failures and debt (kept visible on purpose)

- `governance.yml` is red on `main` — pre-existing, estate-wide (thin wrapper
  over `hyperpolymath/standards` reusables that fail at startup). Not
  repo-local; fix is upstream.
- `push-email-notify.yml` is the estate-wide never-green template.
- ~~Python is banned by the estate language policy; `ai_edit` landed as
  Python~~ — **resolved 2026-07-22.** `ai_edit/`, `scripts/validate_dlc.py`
  and both test modules are deleted; `git ls-files '*.py'` is empty. ADR-0001
  is superseded by ADR-0003.
- Two of the six hand-maintained copies of the closed vocabularies are still
  hand-written: `abi/Types.idr` and `ffi/zig/src/types.zig`. They are checked
  by tests, not generated from `config/vocab.ncl` — the obvious next extension
  of `scripts/gen.sh`.
- The UMS -> game round trip is implemented and CI-gated. A 2026-08-29 local
  run correctly rejected snapshot contract drift from runtime v2 to v3; the
  v3 contract repair is part of ADR-0018's consolidation cutover and must pass
  before the renamed repository is declared green.
- Until 2026-07-20 the Justfile's `test-all` chained five echo-stubs and
  printed "safe to merge!". Those recipes are deleted; every remaining gate
  runs real work and can fail.

## Promotion paths

- **PROJECT D → C: done, 2026-07-27.** `ProvenBridge` landed on 2026-07-20 and
  the tree and the module-count claim now agree. No descope ADR is needed:
  descoping something that works would be the wrong record.
- **PROJECT C -> B:** the Idris extraction boundary now consumes a
  `ValidatedLevel`. Remaining work is a typed Idris renderer for the UMS ABI,
  generated-header drift checks, Zig representation/parser parity, and
  integration with a canonical unified-hexadeca implementation once one
  exists. The local Idris admission result is not cross-language proof.
- **ai-edit C → B:** grow a real consumer, and close the type-6 loop so the
  proposer consults `solve()` in-process rather than across a boundary.
- **DLC bridge C -> B:** keep the implemented cross-repository round trip green
  across versioned game contract changes and add an explicit negative drift
  fixture.
- **SPARK model X → C:** add `spark/src/ums_zones.ads` per ADR-0003 §3, a
  parity test against `constraints.rs`, and a proof gate that **fails when
  `gnatprove` is absent** rather than exiting 0.
- **Frontends X → D:** start `ums-tui` (ratatui, headless so CI can drive it),
  mirroring `idaptik-tui`.
- **VM X → D:** port `dlc/vm` to Rust so it compiles at all, and make its
  `every-instruction-has-an-inverse` guarantee a round-trip property test over
  all 23 instructions, before claiming anything about reversibility.

## Machine-readable

The grade line near the top of this file (`Current Grade`) is parsed by
`just crg-grade` and `just crg-badge`; before this file existed both recipes
silently fell back to grade "X".
