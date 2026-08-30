<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->

# Universal Modding Studio architecture

Universal Modding Studio is an independent authoring, generation, validation
and packaging platform for game worlds, systems, agents, narratives and rules.

It is one modular codebase with an intentionally uneven profile sequence:

1. IDApTIK is the primary executable target and fast proving lane.
2. Chronicles of Slavia is the second-profile abstraction test.
3. Further games are added only after the first two reveal a stable shared
   boundary.

The universal core is therefore narrow but not speculative. Commonality is
earned by two real profiles; it is not created by renaming an IDApTIK concept
or predicting what an unknown future game might need.

## Dependency direction

```text
studio/CLI/LLM interface
        |
        v
host-neutral orchestration, IR, edit, solver, validation and package seams
        |
        v
ums-profile-sdk  <--- sole public profile surface
        |
        +---- ums-profiles (internal compiler implementation)
        |
        +---- profiles/idaptik/v1
        |          |
        |          +---- IDApTIK package/runtime contracts
        |
        +---- profiles/slavia/v1
                   |
                   +---- future Slavia package/runtime contracts

optional preview adapter: UMS model -> profile translation -> Enaction contract
released runtime: compiled game package -> game loader/runtime
```

The core never depends on a game profile. `ums-profile-sdk` is the sole public
profile abstraction inside this repository. It resolves executable services only when a registered
descriptor declares the exact supported contract; `ums-profiles` remains a
non-publishable implementation crate. The `ums-profile` CLI is hosted by the
SDK package and uses that resolution path. A simulation adapter depends on host-neutral model/trace contracts
and a profile-supplied translation; it does not own game ontology. Enaction
Engine does not depend on the UMS application. Released games do not load the
editor UI.

Forbidden cycles:

- UMS Core → IDApTIK or Slavia ontology;
- UMS Core → Enaction Engine;
- Enaction Engine → UMS application;
- profile SDK → a particular profile;
- adapter → hard-coded PBX, Rift, taxi, remedy or security concepts;
- released game → studio frontend.

## Staged physical layout

The destination layout is `apps/studio`, narrow `crates/ums-*` capabilities,
`profiles`, `adapters`, `schemas`, `docs` and `tests/roundtrip`. This change
creates only one new crate because it already has real code and tests:
`ums-profile-sdk`.

The working engine and bridge remain in `ums-ai-edit` and `ums-dlc` while their
interfaces are separated. They are compatibility facades, not evidence that
the destination crate split is complete. Empty aspirational crates are
forbidden.

## Change lanes

All lanes live in this repository and share one history:

- **IDApTIK proving lane:** profile vocabulary, compiler behavior, fixtures and
  the executable game round trip. It may change quickly while its versioned
  package contract remains explicit.
- **Slavia abstraction lane:** a bounded second profile that either validates
  a host-neutral seam or demonstrates that an IDApTIK concept must remain in
  its profile.
- **Shared UMS lane:** the profile SDK, host-neutral orchestration and package
  protocol. Promotion here requires executable evidence from at least two real
  profiles, or a foundational concern that is game-independent by definition
  (identity, provenance, deterministic encoding and similar mechanics).

Promotion changes ownership behind an interface in this tree. It does not copy
an implementation into a slower-moving repository. Rejection is also useful:
if Slavia has no corresponding concept, the IDApTIK implementation stays in
its profile or compatibility facade.

## Estate interoperation policy

Rust components are Rust/Crusoe components. Cross-language FFI seams follow the
estate chain: an Idris2 ABI module owns the contract, Zig implements the
unified-hexadeca-compatible FFI, and C headers are generated rather than
handwritten. The seam's assurance is bounded by its weaker Zig side even when
the Idris2 contract contains checked proofs.

UMS has Idris2 ABI modules and a Zig FFI. Its complete current Zig C-export
surface is generated from the typechecked Idris2 declaration model and checked
for layout, discriminant, function-shape and compiled-symbol parity. The chain
is still not fully integrated because no canonical `unified-hexadeca-api`
implementation can be located in the estate. Hypatia's project-local sixteen-transport connector is reference
material, not an authoritative filesystem or stream abstraction. Zig's direct
`std.fs` and `std.io` calls are therefore ordinary implementation dependencies,
not evidence either for or against compliance with an unavailable API. These
are recorded gaps, not proof or compliance claims.

UMS has no BEAM runtime. If a future Elixir/BEAM adapter needs native compute,
it must use the estate SNIF WebAssembly sandbox and never a raw NIF. This rule
does not make SNIF a present dependency.

Proof claims name the checked module, property and checker evidence. A
typechecking declaration, generated header, Zig scaffold or CI workflow does
not by itself prove its intended invariant. Existing confirmed proof claims
remain scoped; unimplemented deciders, extraction obligations and parity tests
remain explicit debt.

`abi/Representation.idr` now owns the bounded `LevelData` capacities and
semantic admission predicates used before `ValidatedLevel` construction. Its
dependent results prove source-value preservation for successful refinement
and canonical round-trip for optional payloads and the closed `ItemKind` sum.
This is not a proof of the subsequent full Zig fixed-array copy, pointer
lifetime, auxiliary multiplayer records or foreign byte layout; those gaps are
itemised in `docs/ABI-REPRESENTATION.adoc`.

The shared corpus described in `docs/ABI-PARITY.adoc` gives bounded tested
agreement between Idris2 admission and the exported Zig JSON endpoint. The
separate `docs/ABI-ROUNDTRIP.adoc` corpus confirms complete active-field
C-struct round-tripping. Neither closes universal parser equivalence or raw
layout proof. The Idris2 renderer and generated-header parity gates described
in `docs/ABI-HEADER.adoc` test the complete current C-export surface; they do
not turn its representation or semantics into a cross-platform theorem.
Unified-hexadeca integration remains unstarted.

## Host-neutral model boundary

The universal layer may represent:

- stable identity, components, composition, state and events;
- space, time, agency, perception, knowledge, goals and relationships;
- affect and narrative relationships;
- asset and presentation references;
- constraints, tests, provenance, diffs and immutable edit history;
- package kinds and namespaced capabilities.

It may not define a game's nouns or doctrine. PBX, anti-hackers, keycards,
security tiers and IDApTIK alert doctrine belong to the IDApTIK profile. The
Rift, living taxis, remedies and Slavia's heroine influences belong to the
Chronicles of Slavia profile.

## Current executable path

```text
Nickel IDApTIK vocabulary + verbs
        -> generated Rust registry + generated profile reflection
        -> ums-ai-edit relational apply/solve
        -> IDApTIK constraints
        -> ums-dlc manifest and payload validation
        -> package fixture
```

The inputs are immutable and each successful edit produces a new state.
Finite-domain values may be solved; identifiers and geometry are refused when
the caller has not supplied them. Existing DLC remains valid.

The tested IDApTIK production round trip is:

```text
validated UMS model
    -> IDApTIK profile compiler
    -> package bytes
    -> real IDApTIK loader
    -> canonical game model
    -> exported/observed equivalence assertion
```

See `docs/ROUNDTRIP-STATUS.adoc`.

## Guarantee vocabulary

- **machine-checked**: accepted by the named type/proof checker;
- **runtime-validated**: evaluated by a runtime contract;
- **tested**: exercised by executable tests;
- **designed**: contract exists but is not implemented end to end;
- **aspirational**: intended future behavior without a completed contract.

miniKanren constraints are runtime relations. Idris2 typechecking is
machine-checked only for the modules and claims actually accepted by Idris2.
