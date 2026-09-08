<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->

# Universal Modding Studio agent instructions

- Preserve repository history, formal machinery, generated sources, DLC and
  provenance. Never recreate the repository to rename it.
- The product is Universal Modding Studio (UMS). IDApTIK and Chronicles of
  Slavia are profiles, not aliases for the core.
- This is the sole active UMS implementation repository. Do not recreate a
  fast/stable split by copying shared crates into a second repository.
- IDApTIK is the primary executable target and may move quickly inside
  `profiles/idaptik`, its compatibility facades and its round-trip tests.
  Chronicles of Slavia is the second-profile abstraction test. Do not broaden
  the core for hypothetical games; promote a concept only after a second real
  profile demonstrates the shared shape.
- Keep game nouns and doctrine under `profiles/<profile-id>` or an explicit
  compatibility facade. Do not put PBX, security ranks, the Rift, living
  taxis, remedies or heroine-specific vocabulary in universal namespaces.
- A promotion moves ownership behind a host-neutral interface in this tree;
  it is not a file copy between repositories. Record the evidence and affected
  profiles in an ADR when moving a game concept into shared code.
- Rust components follow the estate's Rust/Crusoe policy. Cross-language seams
  follow Idris2 ABI -> Zig unified-hexadeca FFI -> generated C header. Any
  future BEAM-hosted native computation uses SNIFs, never raw NIFs.
- Confirm proof claims against their named checker and property. Types,
  declarations, generated artefacts, workflows and scaffolding are not proof;
  record missing deciders, extraction links and parity tests as explicit gaps.
- `config/*.ncl` remains the source of truth for the working IDApTIK registry.
  Run `just gen`; never hand-edit generated profile JSON or generated
  `crates/ums-ai-edit/src/vocab.rs`.
- Add a crate only with real implementation and tests. Prefer staged
  compatibility re-exports to a mass move.
- Label guarantees accurately: machine-checked, runtime-validated, tested,
  designed or aspirational.
- Before claiming completion run generation drift, Rust format/clippy/tests,
  DLC validation, Zig/Idris gates where available, and repository identity
  searches.
- The separate `metadatastician/chronicles-of-slavia` repository is the
  authority for Slavia design.
