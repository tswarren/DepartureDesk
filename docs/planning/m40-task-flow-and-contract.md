# M4.0 — Task flow and contract

**Status:** Accepted 2026-09-20. Documentation and task-flow gate only. It adds no Package, Service Offer, price, or other M4 table, model, route, or placeholder.

**Parent:** [M4 — Offers and pricing](m4-offers-and-pricing.md)  
**ADR:** [ADR 0014](../adr/0014-client-offers-publication-and-supply-compatibility.md)

## Purpose

M4.0 is the documentation gate before production M4A domain code. It walks the four-step Staff path with Celebrity and Vineyard sketches, records the friction contract M4E will measure, and closes remaining authority that ADR 0014 left to this slice.

It is not implementation authority for M4A–M4E.

## Verified documentation base

| Fact | Value |
| --- | --- |
| Pinned documentation base | `ea6d63e875d917415da061e7b1a64b382c5f91a1` (`ea6d63e`) |
| Base description | Merge of M3F acceptance and hardening (PR #109) on `main`; M3 complete |
| Authority Accept | M4 parent, ADR 0014, and this gate Accepted 2026-09-20 |

Production M4A+ branches must start from this pinned SHA (or a later `main` that remains a descendant of it) after this gate is Accepted. Coding slices must reconfirm required CI on the branch tip; this document does not substitute a later M4A correctness QC.

## Four-step Staff path

An ordinary Supplier-backed offer uses these steps. No independent service catalog and no formula builder on the ordinary path.

1. **Add from Supplier planning.** Pick an Item or Occurrence; prefill source, provider, category, dates, currency, known capacity, and relevant cost context. On-request, Agency-fulfilled, or externally fulfilled services start from an explicit fulfillment choice. Drafting may begin before Arrangement activation and on a draft Departure.
2. **Price the service.** Start with a suitable fixed, per-person, per-resource/night, or occupancy pattern. Reveal component ordering, alternative source groups, and special rates only when needed.
3. **Optionally make a Package.** Add included and optional services, define any choice, select bundled or service-sum price, and add one Package-wide payment schedule. Package-only services publish with the Package.
4. **Review and publish once.** Combined review of Client price, choices, Sales enabled, computed eligibility with reasons, dates, terms, and optional indicative margin. Publication requires an **active** Departure and, for M3-backed pins, **activated** source definitions.

### Celebrity Beyond sketch

Ledger labels follow [M3F.0](m3f-acceptance-and-hardening.md#fixture-ledger). Invent no unresolved worksheet facts.

| Step | Ordinary path | Notes |
| --- | --- | --- |
| 1 | Add the O1 cabin from the Celebrity sailing Item/Occurrence. Prefill cruise category, 2027-11-06–13 dates, contracting/provider Celebrity, USD, and known block capacity. | Confirmed sailing composition. Optional Hilton/transfer/excursion/dining remain separate services or Package add-ons; do not invent Client prices from M3C cost components. |
| 2 | Price at resource/service occupancy positions (first/second/additional). Advanced percentage/tax components stay disclosed. | General MVP occupancy rule. M3C O1 amounts are Supplier cost, not Client price. |
| 3 | Optional Package: cruise included; hotel, transfers, and excursion remain optional or standalone. | No cruise-specific subclass. |
| 4 | Publish on an active Departure after Arrangement activation. Temporary cabin shortage is a live **Unavailable** or quantity warning, not a publication blocker. | Sales enabled distinct from computed eligibility. |

### Vineyard Tour sketch

| Step | Ordinary path | Notes |
| --- | --- | --- |
| 1 | Add coach, lodging, tasting, lunches, and Standard/Deluxe dinner from their Supplier Items. Prefill June 5–7 2027 operating window and 30-seat coach capacity. | Confirmed scenario shape. Hotel A/B sequence stays **shape-only**; do not invent nights or properties. Dinner remains two Items, not a Supplier-side choice. |
| 2 | Price a bundled Package. Offer the named single-occupancy Package-price variant derived from the base per-person Package price. | MVP occupancy exception. Vineyard 100% supplement is **illustrative**, not a confirmed Client rate. Do not invent the base Package price. |
| 3 | Package includes coach, lodging shape, tasting, and lunches. Dinner is an exactly-one choice template (Standard included, Deluxe surcharged **shape**). | No invented dinner rates or independent dinner capacity limits. Choice template must survive onto M5 Client Trip Service with or without a Package. |
| 4 | Indicative margin for the shared coach cost either shows an explicit enrollment assumption and is labeled scenario economics, or remains unknown. | Do not subtract the whole coach cost from one hypothetical sale. |

## Friction contract

M4E measures the shipped Staff journey against this baseline. Do not invent field counts here.

| Ordinary-path rule | M4E proof |
| --- | --- |
| One publication action for a package-only service | No second publish click or independent catalog task |
| Prefill from the selected Item/Occurrence | No re-entry of provider, dates, category, or currency already known on the source |
| No formula builder | Typed patterns first; advanced components only when needed |
| Progressive disclosure | Multi-source bindings, sales caps, and complex percentage bases stay off the default form |
| Hard errors in context | Invalid review recovers on the same combined review without discarding entered values |
| Sales enabled vs computed state | One Staff intent control; a separate Selectable now / On request / Unavailable reason |

## Hard failures versus warnings

There is **no Administrator publication override** in the initial contract. Never reuse `override_supplier_planning_terms`.

**Hard failures** (publication rejected; no partial manifest):

- Cross-Agency or cross-Departure identifier; unauthorized ID returns not found
- Client price currency other than Departure `operating_currency`
- Version, lock, or idempotency conflict that would split a published graph
- M3-backed pin to a draft Arrangement version or missing activated child definition
- Publication while the Departure is not `active`
- Invalid choice structure or no structurally valid min/max combination
- Missing required source binding

**Publish with disclosure** (not blockers; live preview explains):

- Unknown or incomplete M3 cost (indicative margin unknown, never zero)
- Temporary numeric Pool shortage
- On-request or externally fulfilled basis (unconfirmed supply)
- Enrollment-unknown shared fixed-cost margin
- Unused invalid alternative while another eligible member is selected

## Viewer margin

Viewers with `view_departures` read published Client-facing price, terms, Sales enabled, and computed eligibility. Indicative margin and Supplier cost context are Staff/Administrator (`manage_departures`) only. The first UI slice must not expose margin on Viewer branches.

## Closed by this gate and ADR 0014

- No generated Package or Service Offer references in M4. Durable links use UUIDs; Staff identify records by Departure, name, and version.
- Successor comparison uses the ADR 0014 field boundary. `copied_from` is lineage, not equality.
- Derived offer-review state; no stored M4 Needs-attention projection by default.
- Offer drafts may exist on a draft Departure; publication requires an active Departure and, where M3-backed, activated source definitions.

## Out of scope

- Migrations, models, routes, controllers, or views
- Offer panels in [docs/ui/interface-contract.md](../ui/interface-contract.md)
- Client Trip, Hold, Allocation, Charge, Receipt, Traveler, or Communication records
- Inventing Vineyard Package price, dinner rates, hotel nights, or Celebrity Client fares from Supplier cost components

## Exit

M4.0 is satisfied when this document, the M4 parent, and ADR 0014 are Accepted together. Production M4 implementation begins only with an accepted M4A slice from the pinned base (or a descendant) under that slice's contract.
