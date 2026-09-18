# ADR 0012: Arrangement activation, Reservation history, and Supplier confirmation evidence

- Status: Accepted. Implemented by shipped [M3D](../planning/m3d-activation-reservations-confirmations.md). Sole-editable-draft is the shipped rule after M3D.3 remediation.
- Date: 2026-09-17
- Decision owners: DepartureDesk maintainers
- Parent: [M3 — Supplier planning](../planning/m3-supplier-planning.md)
- Architecture: [ADR 0008](0008-supplier-arrangement-version-topology.md), [ADR 0009](0009-supplier-contracting-and-service-provider-roles.md), [ADR 0010](0010-supplier-capacity-ledger-and-projection.md), and [ADR 0011](0011-supplier-cost-definitions-and-forecast-evaluation.md)
- Prerequisite: [M3D.0](../planning/m3d0-planning-workspace-compression.md) must be Accepted and shipped before any production activation, Reservation, confirmation, effective-capacity, or commitment-opening implementation. There is no waiver.
- Implementing slice: [M3D](../planning/m3d-activation-reservations-confirmations.md)

## Context

M3A shipped stable Supplier Arrangement, Item, Occurrence, and Resource identities with editable exact-version definitions. ADR 0008 requires activated versions to become immutable and successor drafts to copy the governing graph without live inheritance. M3B shipped Capacity Pool definitions plus an immutable event ledger and rebuildable projection, but only M3D may establish effective capacity. M3C shipped estimate and contracted cost definitions plus deterministic forecasts, but only M3D may make an exact version effective.

M3D must therefore perform one consequential boundary safely:

- prove that one exact version is structurally, operationally, and commercially ready;
- preserve which alternative cost stages and capacity definitions became effective;
- record the Agency activation separately from Supplier confirmation evidence;
- establish newly effective numeric capacity;
- preserve Reservations and Supplier responses without reinterpreting them after a successor activates; and
- open a commitment only when an explicit activated rule and authoritative confirmation facts fully determine it.

These requirements must not force Staff to manage persistence artifacts manually. The domain may be rigorous while the interface remains a small set of previewed workflows.

## Decision

This ADR governs Arrangement activation manifests, successor copying, Supplier Reservation history, Supplier confirmation evidence, and the M3D confirmation-triggered commitment core. Its implementing slice is Accepted M3D, but production implementation remains gated on Accepted-and-shipped M3D.0 without waiver.

### Activation is one atomic boundary with distinct facts

First and successor activation are explicit commands. Each succeeds only while the Departure is `active` and the target Arrangement version is the sole editable draft for its Arrangement. Shipped commands do not yet satisfy this target rule for successors: M3D.3 must replace `version_number == 1` selection before successor editing is exposed.

One transaction records distinct but related facts:

1. the Agency activation of the exact Arrangement version;
2. immutable Supplier confirmation evidence for the Arrangement;
3. an immutable activation manifest;
4. first `established` capacity events for every newly activated numeric Pool;
5. explicit links from the confirmation to the consequences it supports; and
6. any commitment whose activated deterministic trigger is fully resolved by the confirmation.

Failure of any required consequence rolls back the entire activation. Activation is not inferred from Departure status, a confirmation number, a cost readiness flag, or a capacity event.

Successor activation locks and validates both predecessor and target versions, marks the predecessor `superseded`, then marks the target `activated`, then updates the Arrangement governing-version pointer. Activate-then-supersede is forbidden. A single-statement transition is permitted only when the one-current-activated unique index observes a valid final state. Any later failed consequence rolls back the complete transition.

Capacity establishment and commitment opening run as already-locked internal operations inside the one activation transaction. Activation may not invoke public M3B or commitment commands that reacquire locks or emit independent success audits. One durable idempotency result and one Arrangement-subject success audit cover the activation and all consequences.

Activation becomes governing immediately at the successful transaction's recorded instant. M3D does not schedule or backdate version activation.

The Arrangement governing-version pointer is required when the Arrangement is active. M3E decides whether an ended Arrangement retains that pointer.

### Immutable activation manifest

Every successful activation creates one immutable manifest for one exact Arrangement version. The manifest records:

- Agency, Departure, Arrangement, and exact version;
- predecessor activated version when this is a successor activation;
- activating actor and timestamp;
- the Supplier confirmation used;
- structural, capacity, cost, and trigger coverage attestations;
- every selected cost source and exact selected definition;
- whether each selected cost definition is contracted or provisional estimate;
- every included Pool definition and any establishment event created by this activation; and
- every confirmation-triggered commitment created atomically.

The manifest references authoritative version records; it does not copy component formulas, rounded forecast output, Pool definitions, or capacity quantities into competing snapshots. The exact version is immutable after activation. Explicit manifest selections exist where resolution involved an alternative or produced a consequence.

### Cost selection at activation

For each cost source, activation selects the complete forecast-ready contracted definition when present; otherwise it selects the complete forecast-ready estimate. Stages are never blended.

Ready estimates are a supported ordinary activation path. The activation preview lists every provisional source and why no contracted stage was selected. Staff must explicitly acknowledge that list. No Administrator permission or free-form override reason is required.

Activation does not turn an estimate into contracted terms. A later contracted replacement requires a successor Arrangement version.

### Supplier confirmation evidence

A Supplier confirmation is one immutable evidence fact. It records:

- the confirming Supplier and issuer context;
- evidence kind and date;
- channel/provenance and safe reference note;
- actor and recorded time;
- an optional external identifier; or
- an explicit confirmed-without-identifier reason.

Issuer authority is closed:

- Arrangement activation confirmation may be issued only by the Arrangement contracting Supplier.
- Reservation response confirmation may be issued only by the Reservation's immutable booking Supplier.
- A capacity consequence must additionally be compatible with the supplying Supplier of its Pool.
- A commitment opening must additionally be compatible with its explicit committed Supplier.
- No delegated issuer or generic eligible-Supplier escape exists. Any future delegation requires a later explicit contract.

A confirmation command may create new immutable evidence or explicitly link existing immutable compatible evidence. Reuse requires full ownership, exact-version, Supplier, issuer, and coverage checks for activation, Reservation responses, and every coverage link. Identifiers or timestamps alone never establish reuse. One confirmation may support several compatible consequences through explicit coverage links. Commands compute and preview proposed coverage; Staff confirms it once. The interface does not require manual row-by-row evidence wiring during the common path.

Supporting documents remain deferred. Evidence identity must remain attachment-ready without requiring later reinterpretation.

### Supplier-issued identifiers

Supplier-issued group, reservation, confirmation, policy, and similar identifiers are qualified facts, not DepartureDesk references and not globally unique.

An identifier records Supplier, issuer context, identifier type, display value, normalized value, and stable owning Arrangement or Reservation. Confirmation events link to existing identifier facts or create them with evidence.

Reuse on the same stable owner is allowed. A matching normalized Supplier/type/context identifier on another owner produces an access-safe duplicate warning and requires explicit confirmation to continue. Only an identifier type proven contractually unique may receive a hard uniqueness constraint.

Correction appends a replacement row with `supersedes_id` pointing at the prior current identifier. Application code does not UPDATE prior identifier columns; a database trigger stamps `superseded_at` on the prior row when the successor inserts. Current means `superseded_at IS NULL`.

### Successor copying

Creating a successor copies the current activated version into one independent editable draft. Stable Arrangement, Item, Occurrence, Resource, and Capacity Pool identities are reused where the concept continues. Version-specific definitions receive new identity and explicit predecessor lineage. Removed concepts are omitted; new concepts receive new stable identities.

M3D.3 must make shipped M3A–M3C behavior successor-compatible before successor editing is exposed. Every affected mutation must resolve the sole editable draft instead of `version_number == 1`, distinguish an initial draft from an active Arrangement with a successor, route through the exact selected draft version, and evaluate forecasts and readiness against that exact version. The remediation preserves version-1 behavior before a successor exists and proves activated and superseded definitions remain immutable.

Exact copied cost definitions retain forecast readiness and contracted-attestation provenance only while their complete readiness fingerprint remains equivalent. A consequential edit invalidates the affected readiness and its dependents. There is no live inheritance.

Capacity history is never copied. A carried stable Pool keeps its existing event ledger and projection. A new numeric Pool in the successor receives its one `established` event only when that successor activates. A successor may omit a numeric Pool only under ADR 0010's zero-balance, no-pending-event, and clean-reconciliation rules.

Reservation history, confirmations, capacity events, and commitments are not copied or silently retargeted.

### Reservation identity, revisions, and scope

A Supplier Reservation is one stable Supplier-facing booking made under one Arrangement. It is not the Arrangement itself and is never a Client booking, Hold, Allocation, or fulfillment record.

Each Reservation has independent version-owned revisions. A revision contains one or more ordered scope rows. Each scope row targets exactly one of:

- the whole Arrangement version;
- one Arrangement Item;
- one Service Occurrence;
- one Supplier Resource; or
- one Capacity Pool.

Every target belongs to the same Agency, Departure, Arrangement, and exact version. A scope may carry an optional positive whole requested quantity in a compatible declared M3 capacity basis. Nonnumeric or qualitative requests may omit quantity.

A planned revision may be prepared against a draft Arrangement version. It is internal intent only and may not be requested until that exact version activates. Requesting freezes that revision's Supplier-facing content.

Successor activation does not move a Reservation. If revised terms should govern unresolved work, Staff creates an explicit Reservation revision under the successor. Earlier requests and responses retain their predecessor-version provenance.

### Immutable Reservation events and derived state

Supplier-facing request and response history is append-only. Events record exact revision, affected scope rows, actor, occurrence/recorded time, communication context, and idempotency identity.

Supplier responses may affect scopes independently. Outcomes are:

- `confirmed`, which may record a compatible quantity different from the requested quantity and requires confirmation evidence;
- `declined`; or
- `counterproposed`, which retains response provenance but does not confirm scope, change capacity, open a commitment, or constitute confirmation evidence. Acceptance requires an explicit Reservation revision and later confirmation.

Withdrawal and cancellation are explicit Agency events with reasons; they create no automatic capacity or financial consequence.

The Reservation header state is a derived projection over the latest effective outcome for each scope. It may distinguish planned, requested, partially resolved/confirmed, confirmed, declined, withdrawn, and cancelled presentation, and it exposes counterproposed scopes distinctly rather than forcing them into partially confirmed. The projection is not competing history and must be rebuildable from immutable events.

The common interface defaults a response to all pending scopes and exposes per-scope outcomes only when needed.

### Explicit capacity consequence

A Reservation confirmation never consumes Client demand and never changes capacity merely because it contains a quantity.

When the Supplier response also changes known Supplier supply, the confirmation command may explicitly and atomically append a named ADR 0010 capacity event. The confirmation must be issued by the Reservation's immutable booking Supplier and additionally be compatible with the Pool supplying Supplier. The preview identifies Pool, event type, quantity, effective date, and projection effect. The capacity event remains independently queryable, immutable, version-provenanced, and subject to every M3B evidence, chronology, reconciliation, locking, and idempotency invariant.

### Explicit commitment trigger definitions

M3D introduces version-owned commitment trigger definitions rather than inferring exposure from costs, minimums, guarantees, confirmed quantities, or capacity.

A trigger definition identifies:

- `arrangement_confirmation` or `reservation_confirmation`;
- exact applicable scope;
- explicit `committed_supplier_id`;
- a closed quantity and/or monetary authority shape;
- authoritative source definitions or confirmation inputs;
- currency where monetary;
- a description of the contractual commitment; and
- completeness evidence used by activation.

Supported M3D shapes are deliberately constrained:

- fixed confirmed quantity;
- confirmed quantity supplied by the response;
- fixed contracted amount;
- confirmed amount supplied by the response; and
- contracted unit rate multiplied by an authoritative confirmed quantity.

M3D does not add a generic formula language. A monetary rule may reference only a named `supplier_charge` amount or unit-rate component in a forecast-ready contracted definition, or require an amount explicitly confirmed by the Supplier. Expected commission and informational allocation are never commitment authority. It may not convert an estimate into a commitment amount.

The committed Supplier must be the Arrangement contracting Supplier, an applicable effective Provider, or the charging Supplier named by the contracted monetary authority. At opening, the command checks trigger eligibility, confirmation compatibility with that Supplier, and cost authority together. The immutable opening copies the committed Supplier snapshot from the trigger.

### Narrow confirmation-triggered commitment core

When confirmation fully resolves an activated trigger, the command explicitly and atomically creates one immutable commitment-opening record. It preserves exact version, scope, committed Supplier snapshot, quantity and/or amount, currency, calculation provenance, trigger definition, confirmation, actor, time, and idempotency identity.

Every `arrangement_confirmation` trigger must fully resolve during activation or activation fails. Coverage attestation cannot coexist with an unresolved activation trigger.

A `reservation_confirmation` may preserve truthful Supplier confirmation when the response omits an externally authoritative input. It creates no placeholder commitment and exposes a derived unresolved-trigger condition for M3E. If all authoritative inputs are complete, failure to create the required commitment fails the enclosing transaction. If only quantity is authoritative, M3D may create a quantity commitment while forecast cost remains estimated; estimates never provide monetary commitment authority.

M3D adds no manual commitment command or post-opening lifecycle. It does add the minimal ordinary Supplier-inactivation blocker for every unresolved commitment it can open, keyed by the immutable committed Supplier snapshot. Forced inactivation preserves openings and performs no disposal, release, reassignment, or other disposition. M3E adds manual opening, disposition and terminal rules that cease blocking, deposit requirements, Deadline workflow, exposure, needs-attention acknowledgment, and normal Arrangement ending.

### Interaction compression

Persistence rigor does not imply one user action per record. M3D presents four primary workflows:

1. **Activate Arrangement:** one checklist, confirmation evidence section, conditional provisional-cost acknowledgment, consequence preview, and final action.
2. **Create successor:** copy the current version, edit modified facts, resolve invalidated readiness, and activate.
3. **Request Supplier booking:** one Reservation form with a default scope and progressive disclosure for additional scopes.
4. **Record Supplier response:** one form defaulting to pending scopes with conditional capacity and commitment consequence preview.

The system generates manifests, coverage links, readiness lineage, derived Reservation state, and result associations. Staff do not manage those persistence artifacts directly.

M3D may provide a combined **Record existing confirmed booking** workflow for an already-existing booking under an active Arrangement. It atomically creates the Reservation, exact revision, applicable request context, response, confirmation evidence, and explicit consequences without requiring artificial intermediate clicks. It is not an ordinary post-departure historical-correction path.

## Consequences

### Positive

- Activation is reproducible without duplicating the full version graph.
- Supplier confirmation, capacity establishment, and deterministic commitment opening cannot drift across partial transactions.
- Successor versions preserve history and remain practical to prepare.
- Multi-scope and partially confirmed bookings do not require artificial duplicate Reservations.
- Evidence is recorded once and reused only through explicit coverage after full ownership, exact-version, Supplier, issuer, and coverage checks.
- Internal rigor is compressed into a small number of Staff workflows.

### Costs

- Persistence requires manifests, selections, immutable evidence, Reservation revisions/scopes/events, trigger definitions, and a narrow commitment-opening record.
- Successor copying must handle several shipped definition families transactionally.
- Derived Reservation state and duplicate-identifier warnings require bounded operational queries.
- M3E must extend the commitment core without rewriting M3D openings.

## Alternatives rejected

### Treat activated version alone as the complete manifest

Rejected. Cost-stage selection and activation consequences would be re-derived later and could become ambiguous as code changes.

### Copy every activated fact into a duplicate snapshot graph

Rejected. The exact version is already immutable; copying formulas and definitions would create competing truth.

### Treat activation as Supplier confirmation

Rejected. Agency governance and Supplier evidence have different meanings even when recorded atomically.

### Retarget Reservations automatically on successor activation

Rejected. It would reinterpret requests and confirmations under terms that did not govern them.

### Require one Reservation per scope

Rejected. One Supplier-facing booking may cover several services or occurrences and receive a partial response.

### Infer capacity from confirmed quantity

Rejected. Reservation quantity and Supplier supply are distinct facts; capacity requires an explicit event.

### Infer commitments from cost or capacity terms

Rejected. Minimums, guarantees, forecasts, and capacity do not by themselves prove that contractual exposure opened.

### Use estimates as monetary commitment authority

Rejected. A planning forecast is not a contractual monetary fact.

### Expose every persistence record as a separate Staff workflow

Rejected. It would preserve technical distinctions by imposing avoidable operational friction.

## Implementation boundary

This ADR is Accepted. Accepted M3D places activation, successor copying, Reservations, confirmations, Staff-facing capacity controls, explicit confirmation capacity consequences, trigger definitions, and the narrow confirmation-triggered commitment core into scope after M3D.0 is Accepted and shipped. M3D.3 successor compatibility remediation must land before successor editing is exposed.

M3D.6 proves the M3D slice only. M3F owns milestone-wide M3A–M3E acceptance and the M3 parent exit gate.

Normal Arrangement ending, manual commitment opening and disposition, deposit requirements, Deadlines, exposure, the formal needs-attention catalog, Supplier Obligations, Payments, Client demand, fulfillment, Cancellation Cases, file uploads, and Communications remain later work.
