# ADR 0014: Client offers, publication, and Supplier-source compatibility

- Status: Accepted. [M4A](../planning/m4a-service-definitions-and-sources.md), [M4B](../planning/m4b-client-pricing-and-anonymous-preview.md), and [M4C](../planning/m4c-packages-choices-and-client-terms.md) are shipped. [M4D](../planning/m4d-publication-and-live-feasibility.md) is shipped. [M4D.0](../planning/m4d0-narrow-group-departure-builder.md) is shipped. Not implementation authority for M4E until that plan is accepted.
- Date: 2026-09-20
- Decision owners: DepartureDesk maintainers
- Parent: [M4 — Offers and pricing](../planning/m4-offers-and-pricing.md)
- Task-flow gate: [M4.0](../planning/m40-task-flow-and-contract.md)
- Architecture: [ADR 0004](0004-human-readable-references.md), [ADR 0008](0008-supplier-arrangement-version-topology.md), [ADR 0010](0010-supplier-capacity-ledger-and-projection.md), [ADR 0011](0011-supplier-cost-definitions-and-forecast-evaluation.md), [ADR 0012](0012-arrangement-activation-reservations-and-confirmations.md), and [ADR 0013](0013-supplier-operational-commitments-deadlines-exposure-and-ending.md)
- Prerequisite: M3 complete at [PR #109](https://github.com/tswarren/DepartureDesk/pull/109) merge [`ea6d63e`](https://github.com/tswarren/DepartureDesk/commit/ea6d63e875d917415da061e7b1a64b382c5f91a1). Coding slices must reconfirm CI on the branch tip.

## Context

M3 supplies immutable activated Arrangement definitions, capacity history and projections, Supplier cost forecasts, confirmations, deadlines, and exposure. M4 needs to say what the Agency intends to offer to Clients without treating an Arrangement Item as a sale, a capacity projection as a Client Hold, or a Supplier cost component as Client price. A Package is optional. The ordinary Staff path should be: add from Supplier planning, price, optionally assemble a Package, then review and publish once.

Supplier Arrangements can have successor versions. Their stable Item, Occurrence, Resource, and Pool identities may continue while their exact definition rows change. A published Client offer must retain the terms it published; an unrelated Supplier revision should not force Staff to recreate every offer. Current Supplier eligibility and availability still need to be assessed when a future Client Trip selects the offer.

This ADR defines the M4 identity/version boundary, publication, source compatibility, and M5 handoff. Detailed price-component tables, all choice and schedule fields, and UI controls belong to accepted M4 slice contracts. This ADR does not authorize migrations or code.

## Decision

### 1. Identity and version topology

`Service Offer` is the Departure-owned sellable-service identity. It is distinct from a Supplier `Arrangement Item` and from a later `Client Trip Service`. `Package` is a separate, optional Departure-owned offer container. Each has a stable UUID identity and positive, monotonic version numbers; skipped numbers are retained after an abandoned successor draft. Each has at most one editable draft successor. A published version and every version-owned definition child are immutable in Rails and PostgreSQL. A successor copies the governing definition into an independent draft with exact predecessor lineage; there is no live inheritance.

A Package version pins exact Service Offer versions. A new Service Offer version does not rewrite an existing Package. A service used only inside a Package can be drafted in the Package builder and have its exact version published **in the same transaction and one Staff action** as the Package version. Staff need a separate service publication action only when selling it independently or deliberately reusing it elsewhere. Later making a package-only service independently sellable uses an explicit successor/publication path and preserves previous Package pins.

For independent selection, one published version is current per stable Package or Service Offer identity. A current Package may still pin an older immutable Service Offer version while that version remains eligible; publishing a newer standalone Service Offer version alone does not invalidate it. Retirement of the pinned version does. Earlier published versions remain available as history and to support existing exact pins, subject to their recorded lifecycle.

M4 does not issue new generated Package or Service Offer references. Staff identify these records by Departure, name, and version; durable internal links use UUIDs. If a later slice needs externally discussable generated references, it must amend [ADR 0004](0004-human-readable-references.md) with namespace, agency scope, issuance event, formatting, concurrency, and reuse rules before adding a generator.

### 2. Publication and currency

One idempotent publication command validates the entire proposed definition graph, exact same-Agency/Departure ownership, applicable currency, structural choices, source lineage, and price-rule readiness; issues exact published versions and their manifest together; and writes a bounded audit event in the same transaction. Failure leaves no partial version or manifest. An idempotent replay returns the same result and consumes no additional number or publication event. The manifest references version-owned authoritative definitions and records explicit selections or fingerprints needed to explain the decision; it is not stored in `AuditEvent.details` and does not duplicate the full graph.

Offer drafts may exist on a draft or active Departure and may start from draft Supplier planning. **Publication requires an active Departure.** **Publication of an M3-backed service requires the current activated Arrangement version and its activated exact Item/Occurrence/Resource/Pool definitions as applicable.** An editable successor draft is never the current Supplier authority. For services without an M3 Arrangement, Staff must explicitly state on-request, Agency-fulfilled, or externally fulfilled basis; no capacity or Supplier confirmation is fabricated. A stored recognized IANA zone is required when a local sales-window rule is set. Publication does not require that a numeric Pool have positive availability at that instant.

Every M4 Client price definition uses the Departure operating currency and persists minor-unit amounts in `bigint` fields. M3C already requires estimate and contracted definitions to use that same currency; M4 introduces no FX. An inconsistent currency is a hard error. A retained currency-bearing M4 price definition, including an editable draft, prevents an ordinary Departure currency change; `UpdateDeparture` and `CorrectDepartureCurrency` must extend their existing M3 freeze checks. A deliberate correction requires removing an eligible never-published draft or a later separately accepted historical correction; no command silently relabels amounts.

M4 does not post Charges or any Client or Supplier money event. The Package's bundled Client payment schedule is authoritative by default; included services add scoped service-specific conditions. A genuine conflict needs an explicit, source-traceable resolution on the Package version. The Client pricing evaluator uses its own typed roles and ordered bases; M3 Supplier cost roles and Item-scoped participant categories do not become Client price or rate categories. A bundled Package amount remains one Package price source without invented service allocation. A bundled Package may define the narrow single-occupancy price variant as Package revenue under the 2026-09-20 MVP occupancy exception; it must not also apply as a lodging or service occupancy charge for the same supplement.

### 3. Exact Supplier binding and narrow compatibility

An M3-backed binding stores the stable Arrangement and bound child identities, the **exact activated Arrangement version and relevant child definition IDs**, its declared fulfillment purpose, and which Supplier attributes the Client offer actually uses or exposes. One source is the default. Required bindings all apply; an alternative group represents one Staff-selected member for an anonymous scenario. The binding never implies a Client Hold, Allocation, Supplier Reservation, or guaranteed availability.

When an activated Supplier successor becomes current, compare only its lineage-linked definitions on which the binding depends. `copied_from` establishes predecessor lineage and never establishes equality by itself. The comparison contract has these categories:

| Result | Governing facts and consequence |
| --- | --- |
| Equivalent | Bound stable identities and normalized offer-relevant definition facts are unchanged. The offer retains its original exact published source and is eligible to use the current activated successor after a verified compatibility check. M5 records both original offer provenance and the current selected Supplier version. |
| Changed | A bound child is omitted/replaced, the effective provider or supplying Supplier changes, an exposed Occurrence schedule or zone changes, Resource semantics used by the offer change, Pool identity/mode/basis or applicable pair classification changes, or an explicitly incorporated Supplier condition changes. The affected required path is ineligible for new selection pending a reviewed offer successor. A changed alternative affects that member; another viable member can remain selectable. |
| Economic or availability only | Supplier cost definitions or expected commission change without changing Client price or bound fulfillment meaning: refresh read-only scenario economics and show a review notice. Numeric Pool quantity/events/projection change: recalculate live availability. Neither change alone requires a new offer version. |
| Unknown | Missing lineage, incomplete graph, inconsistent identity/provider mapping, or an unrecognized field used by the offer: fail closed for the affected path and require Staff review. |

The comparison uses the following field boundary for each *bound* child. Stable identity and `copied_from` lineage locate the successor definition; compare normalized typed values, not a whole Arrangement version number. A field marked conditional is a dependency only when the published offer explicitly incorporates or exposes it. M4A must record that dependency choice in the binding and prove the normalization in tests.

| Bound source | Facts that can change fulfillment meaning | Conditional Client-facing dependencies | Excluded from this comparison |
| --- | --- | --- | --- |
| Arrangement and Item | Same Agency/Departure, stable bound Item identity, presence in the current activated successor, effective contracting/provider identity; Item `category`, `other_category_label`, and `capacity_management` where they determine the promised service or supply basis | Item `name` and `description` if the offer uses live Supplier wording rather than its own published Client text | Arrangement `version_number` alone; unrelated Items; Supplier cost, deposits, deadlines, and commitments |
| Occurrence | Stable bound Occurrence identity, `status` (including cancellation), effective `service_provider_id`, `starts_on`, `ends_on`, `starts_at_local`, `ends_at_local`, and `time_zone` when the binding promises that occurrence | Occurrence `name` and `description` if incorporated into the Client promise | Unbound Occurrences and their schedules |
| Resource and pair | Stable bound Resource identity and its applicable Occurrence/Resource pair `classification`; loss or replacement of a bound Resource | Resource `name` and `description` when the offered resource category or specification depends on them | Unbound Resources and display `position` |
| Pool | Stable bound Pool identity, `inventory_mode`, `measurement_basis`, `supplying_supplier_id`, and effective time zone; applicable pair mapping | Pool `label` and `unit_label` only when promised or used to interpret the Client quantity | `proposed_opening_quantity`, evidence, display `position`, and live capacity events/projection; numeric availability belongs to live preview |

An offer owns its published Client text and terms. Copying a Supplier name into that snapshot does not silently make future Supplier wording a live dependency. A changed effective provider, promised date, bound resource meaning, inventory basis, or supplying Supplier requires review even when the display wording remains the same. An explicitly promised Supplier condition needs its own named dependency and Client-facing snapshot; no unspecified Arrangement-wide term is pulled in. Missing successor definitions, unknown comparison values, and newly introduced fulfillment-semantic fields fail closed until the comparison contract is extended. A predecessor published definition is never updated or pointed at the successor. Derived evaluation is the default; consequential Staff acknowledgments and decisions are durable.

### 4. Publication, Staff control, and computed selection state

Published definition, Staff intent, and live feasibility are separate facts. The ordinary control is **Sales enabled**. Pausing and resuming an exact published version are audited operational actions; resuming rechecks structural and source eligibility. Retirement is final for that exact version and is a secondary action. None edits its published terms. A temporary capacity shortage can make an enabled offer unavailable; when supply returns, computed availability can return without republication. The UI must make that behavior clear.

The live label is computed with a reason: **Selectable now**, **On request**, or **Unavailable**. It reads current Departure and source lifecycle, local sales dates, explicit Package and service sales limits, selected choice combination, current Pool projections, and the scenario's quantity. Numeric supply is never inferred from an unmanaged Item or a nonnumeric `on_request`/`externally_managed` Pool. An M4 on-request fulfillment basis and M3 Pool inventory mode are distinct concepts that must be mapped explicitly. An unknown cost does not become zero, and a temporary shortage does not prevent publication.

A departed Departure cannot publish a new offer or accept ordinary new M5 selection. An ended Arrangement, cancelled Occurrence, or inactive bound Supplier invalidates only a path that requires it. Every required binding must remain eligible; each alternative group needs at least one eligible selected member. Arrangement ending and ordinary Supplier inactivation **do not mutate offers** and gain no blanket M4 blocker. Their previews must disclose any published offers whose selectable paths would be lost; after the M3 action, those paths calculate as unavailable. Existing M3 commitment and capacity blockers remain independently authoritative. M4 offer-review findings are derived from the offer manifest and current M3 graph; do not extend M3E.5's closed Supplier Needs-attention catalog or add a stored M4 finding projection without measured need. A Staff acknowledgment of a consequential review remains durable.

The M4 preview is read-only, labels its observation time/snapshot, and may become stale. It neither posts capacity events nor creates Holds or Allocations. Future M5 Hold, selection, and confirmation commands recheck live facts transactionally under their accepted lock order. M4 publication is structural authority, not a promise that capacity will remain available. Publication must have at least one structurally valid min/max choice combination; current capacity of every option is not a publication prerequisite.

### 5. Choices, pricing preview, and M5 handoff

A Service Offer version owns general choice-group templates, including min/max selections and exact option definitions. This applies to standalone services and Package-included services. An M4 anonymous preview names the selected alternative Supplier path and choice options, shows Client price components and supply uncertainty, and stores no named Traveler or demand. It may calculate indicative scenario economics from M3 cost arithmetic using the **scenario's** quantities in memory; it must not persist them as M3C usage assumptions. Shared fixed costs require an explicit enrollment assumption and a scenario-economics label; otherwise margin is unknown. Supplier-collected money and earned or received commission are not inferred.

M5 must snapshot the selected Service Offer version, choice-group rules, selected options, Package version if any, Client price/terms, original Supplier provenance, and the compatible current Supplier source onto its Client Trip Service context. It must record the actual fulfillment source selected and revalidate capacity and material changes. A choice group survives onto a standalone Client Trip Service without a Package. M5 confirmation retains the accepted commercial rule: in one atomic command it revalidates terms and acknowledgment, confirms allocations, issues the Client Trip reference, and posts only Charges currently due. The roadmap booking-beta checkpoint records that minimum Charge posting; M6A expands the Client subledger. M4 introduces none of these M5 records.

### 6. Permissions, audit, and catalog integration

Use `view_departures` and `manage_departures` permission checks, with tenant-owned loading through the session-derived Agency. Viewer is read-only for Client-facing published facts. Indicative margin and Supplier cost context are Staff/Administrator (`manage_departures`) only; the first UI slice must not expose margin on Viewer branches. Staff may publish structurally valid offers and acknowledge nonblocking uncertainty. There is **no M4 Administrator publication override** in the initial contract. If a later slice establishes a concrete exception that genuinely requires override, add a new named Client-offer permission with reason/evidence and bounded effects; never reuse `override_supplier_planning_terms` or check role names in application commands. Tenant, currency, source-lineage, and published-immutability failures cannot be overridden.

Extend `AuditEvent::SUBJECT_TYPES` and `ACTIONS` in the same slice that first records Package or Service Offer create, update, publish, pause, resume, retire, and successor actions. Keep audit details bounded to identifiers, action and reason; the publication manifest and pricing graph are domain records. Extend Supplier-inactivation/Arrangement-ending preview consequences and `UpdateDeparture`/`CorrectDepartureCurrency` currency guards in the owning slice rather than relying on a later UI warning. Do not modify the M3E.5 detector catalog for Client-offer review.

## Explicit non-goals

- Client Trip, Traveler Assignment, named occupancy, Hold, Allocation, actual Supplier fulfillment, Charge, Receipt, Supplier Obligation, Payment, Cancellation Case, Communication, or document production in M4.
- A public storefront, automatic source switching, a general Supplier version diff engine, unrestricted pricing formula language, or automatic conversion from Supplier cost to Client price.
- A numeric availability count for unmanaged/on-request/external supply, or any implicit M4 capacity event.
- A generated Package/Service Offer reference, a new Administrator override, or a stored offer-review projection without a separately accepted need.

## Alternatives considered

| Alternative | Reason not selected |
| --- | --- |
| Require separate publication of every Package component | Adds a duplicate Staff task for a package-only service; joint publication preserves version identity and transactionality. |
| Rebind published offers automatically to the latest Arrangement version | Rewrites the authority a Client price and promise were based on; exact original provenance must survive. |
| Require republication for every Supplier successor | Unrelated and cost-only changes would create repeated Package work. Narrow compatibility preserves safety with less Staff friction. |
| Treat every Supplier change as compatible until Staff objects | Could sell under a changed provider, date, capacity basis, or promised condition without acknowledgment. Unknown comparisons fail closed. |
| Block publication when current capacity is exhausted | Confuses a durable offer definition with a momentary supply projection; M5 performs transactional demand control. |
| Store an M4 attention projection immediately | Adds rebuild and synchronization work before proving read performance needs it. Derive first. |
| Reuse `override_supplier_planning_terms` or Supplier cost categories | Conflates Supplier contracting authority and cost semantics with Client offer authority and price. |

## Acceptance and implementation gates

Gates 1–4 are satisfied by the 2026-09-20 Accept package. Gate 5 remains required before M4A migrations.

| # | Gate | Status |
| --- | --- | --- |
| 1 | Amend the MVP specification for the bundled-Package single-occupancy variant as Package revenue, without a duplicate service occupancy charge. Vineyard 100% remains illustrative under the M3F fixture ledger. | Satisfied. [MVP Section 5](../planning/departure-desk-mvp.md) 2026-09-20 occupancy amendment. |
| 2 | Amend the roadmap's M5 checkpoint to preserve atomic confirmation with Charges currently due; M6A expands the Client subledger. | Satisfied. [Roadmap](../planning/roadmap.md) booking-beta checkpoint. |
| 3 | Accept the M4 parent and M4.0 Staff task-flow contract. Pin the documentation base. Translate the field boundary into binding-specific normalized comparisons before implementing compatibility. | Satisfied for Accept. [M4 parent](../planning/m4-offers-and-pricing.md) and [M4.0](../planning/m40-task-flow-and-contract.md) accepted. M4A still owns comparison tests. |
| 4 | Amend `docs/terminology.md` for Service Offer and the distinction among published definition, Sales enabled, and computed eligibility. Decide Viewer margin exposure explicitly. | Satisfied. Viewer reads Client-facing published facts; indicative margin is `manage_departures` only. |
| 5 | Make one accepted slice authoritative for each migration and command. Include same-Agency and same-Departure database enforcement, Rails/PostgreSQL published-graph freeze, durable idempotency, lock-order and race proof, audit catalog extension, lifecycle interaction, money rounding, and keyboard/responsive Staff journey proof. | Open. An accepted M4A–M4E slice is required before the work it names. |

This ADR does not claim M4 is shipped.

## Clarification — M4D.0a (2026-09-21)

[M4D.0](../planning/m4d0-narrow-group-departure-builder.md) may persist draft-only **`undecided`** fulfillment on unpublished Service Offer definition versions (and retained abandoned history). That value is not a published or selectable fulfillment basis and must be rejected by publication readiness. Client timing text on a Service Offer definition is version-owned descriptive prose with no operational authority over dates, capacity, compatibility, deadlines, or money. This clarification does not authorize a second commercial aggregate, proposal distribution, or M5 records.

