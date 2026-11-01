# DepartureDesk documentation

This directory separates shipped architecture, accepted product decisions, implementation plans, operations, design guidance, scenarios, and historical material.

## Authority order

When documents conflict, use this order:

1. The [Product Specification](spec/README.md), including its decision log. The master copy is a Google Doc; [`spec/product-specification.md`](spec/product-specification.md) is a read-only snapshot of it.
2. The [first-slice charter](planning/first-slice/first-slice-charter.md) for the scope of Slice 1 and Slice 1b, and the fixture, demonstration cases and technical baseline it sets.
3. Accepted architecture decision records in [`adr/`](adr/README.md) for the technical decision they govern, unless a decision log entry or a later ADR supersedes them.
4. Current operational and interface documentation.

An Agreed rule in the specification does not authorize implementation. Only a rule cited by the active charter, or added to it by a decision log entry that names the charter, is in scope. `AGENTS.md` defines the boundary and contributor rules.

The [MVP requirements](planning/departure-desk-mvp.md), the [Commercial Domain Decision Register](planning/commercial-domain-decision-register.md) and the [roadmap](planning/roadmap.md) are Superseded by the specification and the charter. The M1–M4 milestone and slice plans describe how shipped code was built; they are not authority for new work.

## Document status

| Status | Meaning |
| --- | --- |
| Accepted | Governing decision or plan. Changes require an explicit amendment or superseding document. |
| Shipped | Planning-document word for accepted behavior that is in the application. |
| Implemented | Same meaning as Shipped, used in architecture documents. |
| Draft | Open for review and not implementation authority. |
| Superseded | Retained decision history; a named later authority controls. |
| Archived | Historical and non-normative. Do not implement from it. |

Every normative or planning document should state its status near the top. Historical documents under [`archive/`](archive/README.md) are archived regardless of an older status written inside them.

## Current map

| Area | Purpose |
| --- | --- |
| [`spec/`](spec/README.md) | Product Specification snapshot and pending decision log entries. Product authority. |
| [`planning/first-slice/first-slice-charter.md`](planning/first-slice/first-slice-charter.md) | The active slice: scope, fixture, demonstration cases and build plan. |
| [`architecture/current-state.md`](architecture/current-state.md) | What exists in the application now. |
| [`adr/`](adr/README.md) | Durable architectural decisions, including superseded history. |
| [`planning/README.md`](planning/README.md) | Where the product stands. Slice-level status. |
| [`planning/departure-desk-mvp.md`](planning/departure-desk-mvp.md) | Superseded MVP requirements. History only. |
| [`planning/commercial-domain-decision-register.md`](planning/commercial-domain-decision-register.md) | Superseded commercial and financial rules. History only. |
| [`planning/roadmap.md`](planning/roadmap.md) | Superseded milestone sequence. The charter lists the next slices. |
| [`planning/drafts/README.md`](planning/drafts/README.md) | Open drafts and history. Not implementation authority. |
| [`planning/fixtures/README.md`](planning/fixtures/README.md) | Supplier Composition fixture register. Draft fixtures do not authorize implementation. |
| [`operations/`](operations/) | Executable operational and production guidance. |
| [`ui/`](ui/) | Current visual and interaction contracts. |
| [`palette.md`](palette.md) | Harbor & Waypoint brand palette. |
| [`terminology.md`](terminology.md) | Current canonical product vocabulary. |
| [`scenarios/`](scenarios/) | Representative departures used to test model generality. |
| [`licenses/`](licenses/) | Notices for bundled fonts and icons. |
| [`archive/`](archive/README.md) | Non-normative v0.02 and earlier material. |

## Maintenance rules

- Keep shipped behavior distinct from planned behavior.
- Link to a governing document instead of copying it into another file.
- Preserve superseded ADRs in `adr/`; archive obsolete implementation plans elsewhere.
- A status or authorization change is recorded in `docs/planning/README.md`. The plan's own header stays the authority for the scope that plan established. Do not restate that standing in the roadmap or in `AGENTS.md`.
- Update `AGENTS.md` only when the unauthorized boundary changes.
- Change a product rule in the specification first, with a decision log entry, then re-export the snapshot. Never copy rule text into another document; cite the rule ID.
- Do not place secrets, real traveler data, or production credentials in documentation or scenarios.
