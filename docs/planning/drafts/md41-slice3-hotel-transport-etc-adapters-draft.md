# M4D.1 Slice 3 — Hotel, Transportation, Activity, and Mixed-DMC Adapters

**Status:** Discovery history. Not implementation authority. `main` never accepted this draft. Successor: M4D.1 Slice 3R, which is not yet accepted.

**Prototype:** Unmerged branch `m4d1-slice3-hotel-transport-activity` (PR #156) explored this approach. That branch is prototype evidence and is not an implementation source.

**Parent authority:** [M4D.1 — Departure Composition Workspace](../m4d1-departure-composition-workspace.md). The generalized adapter approach in this draft is not the Slice 3 delivery boundary.

**Prerequisite:** Slice 2D shipped at `dc272a3` (PR #154). The earlier prerequisite, which treated Slice 2D as still unshipped, is retired with this draft.

**Outcome:** Staff can establish Hotel, Transportation, and Activity/Meal/Excursion Supplier services through typed adapters, then connect each Supplier Item to an appropriate Client Service without understanding the underlying M3/M4 graph.

Slice 3 generalizes the typed-adapter pattern proven by Cruise. It does not reproduce Cruise-specific occupancy, deposit, pricing, or scenario behavior in other service families.

---

## 1. Locked scope

### In scope

* A typed Hotel Supplier adapter.
* A typed Transportation Supplier adapter.
* A typed Activity/Meal/Excursion Supplier adapter.
* A mixed-DMC Item workspace that routes each Item to the appropriate typed adapter.
* Draft and successor editing over existing M3 Supplier Arrangement records.
* Applicable occurrence, resource, capacity, Supplier-cost, deadline, and deposit configuration.
* Create, connect-existing, and decide-later Client Service flows.
* Exact `ServiceOfferSourceBinding` creation through shipped M4 authority.
* Client-selectable options only when the Supplier Item exposes a genuine Client choice.
* Per-definition and per-Item save boundaries.
* Definition-scoped and Item-scoped compatibility detection.
* Advanced fallback for unsupported graphs.
* Shared adapter support only after at least Hotel and Transportation prove the repeated behavior.
* Derived workspace summaries and readiness findings.
* Authorization, optimistic locking, idempotency, audit, accessibility, and browser proof.

### Out of scope

* Service-family STI or new Hotel, Transportation, Activity, Meal, Excursion, or DMC aggregate tables.
* Replacing `SupplierArrangement`, `ArrangementItem`, `ArrangementOccurrence`, `SupplierResource`, `CapacityPool`, Supplier cost definitions, or Service Offers.
* A universal adapter DSL designed before two adapters prove the abstraction.
* Automatic Supplier-to-Client price copying.
* Specialized Hotel, Transportation, or Activity Client-price matrices.
* New persisted scenario types.
* Target-price, markup, target-profit, or target-margin workflows.
* Package composition redesign.
* Persisted enrollment or demand.
* Named Travelers, bookings, Holds, Allocations, Charges, Obligations, Receipts, Payments, or remittance.
* A universal tax engine or statutory tax classification.
* Combining several Supplier Items into one Client Service without an explicit Staff decision.
* Source-document storage, proposal sharing, notifications, or external Supplier integrations.

---

## 2. Domain decisions

### 2.1 Typed adapters remain application-layer adapters

Hotel, Transportation, Activity/Meal/Excursion, and mixed-DMC forms compile into the shipped generic M3 and M4 records.

Slice 3 adds no service-family persistence aggregate and no parallel evaluator. Typed adapters call or compose shipped public commands and preserve their invariants.

A typed adapter may add a narrow orchestration command when an accepted save boundary must create or update several existing records atomically. It must not duplicate capacity, cost, commitment, pricing, or publication logic.

### 2.2 Service granularity

One Client-recognizable experience normally maps to one `ServiceOffer`.

* A Hotel stay normally maps to one Hotel Service.
* A Transportation segment normally maps to one Transportation Service.
* An Activity, Meal, or Excursion normally maps to one Service.
* Several Supplier Items are never silently collapsed into one Service.
* Staff may explicitly connect several Items only when shipped M4 compatibility rules support one inseparable Client service and the Slice 3 detector can reconstruct that topology without reinterpretation.

A Supplier-only Item does not require a Service Offer.

### 2.3 Connection ownership

Each Supplier Item may be claimed by at most one intended Service Offer, following the shipped Slice 2C ownership pattern unless inspection proves a different generic invariant already exists.

Create, connect-existing, and decide-later flows must claim the Item and establish any required source binding in the same transaction.

Connect-existing accepts only an editable Service Offer graph that can safely receive the Item. A compatible already-connected graph is edited, not reconnected.

Discarding an unpublished draft releases its claim only through the shipped discard lifecycle.

### 2.4 Capacity applicability

The adapter asks whether Supplier-controlled capacity applies. It never creates a Pool merely because a service can be counted.

Capacity may be:

* blocked numeric inventory;
* on request;
* externally controlled;
* not applicable.

Examples:

* Hotel room blocks may use room-unit Pools.
* Transportation may use seat or vehicle Pools.
* Activities may use participant-place Pools when the Supplier contract controls availability.
* A contractual minimum alone does not create a Pool.
* A fixed-cost service does not require a Pool.
* An enrollment assumption is not Supplier capacity.

### 2.5 Supplier and Client economics remain separate

Supplier rates compile only to M3C Supplier cost definitions and components.

Connecting a Service does not create Client price components. A displayed illustrative Client price is labeled illustrative and remains unsaved unless Staff use an authorized Client-price command.

Slice 3 may expose the shipped generic Client-pricing destination as the next action. It does not silently copy Supplier values.

### 2.6 Deadlines and deposits

Typed templates compile to existing M3E Deadline and Deposit Requirement definitions.

Templates are creation affordances, not persisted service-family types. They do not create Hotel-, Transportation-, or Activity-specific deadline or deposit tables.

Actionable versus informational meaning, coverage, timing rules, activation materialization, successor reconciliation, and active immutability remain governed by shipped M3E and Slice 2B authority.

### 2.7 Draft, active, and successor behavior

* Draft Arrangement versions may be edited.
* Governing activated versions are read-only.
* When a compatible successor exists, mutations target the successor.
* Successor copies preserve stable Item, Occurrence, Resource, Pool, Service, binding, option, and rate-key identity where shipped graph-copy behavior permits.
* A later Arrangement successor does not silently move an exact Service Offer source binding.
* Unsupported successor graphs remain readable through Advanced setup.
* No typed save mutates an activated definition.

---

## 3. Canonical service-family shapes

### 3.1 Hotel

A typed Hotel graph may contain:

| Concept                                                     | Generic record                                    |
| ----------------------------------------------------------- | ------------------------------------------------- |
| Hotel agreement                                             | `SupplierArrangement`                             |
| Hotel stay                                                  | `ArrangementItem`                                 |
| Stay dates and local zone                                   | `ArrangementOccurrence`                           |
| Room category                                               | `SupplierResource`                                |
| Blocked/on-request rooms                                    | `CapacityPool` when applicable                    |
| Room, additional-adult, tax, fee, or other Supplier rate    | M3C cost definition/components                    |
| Option, rooming-list, deposit, or final-payment requirement | M3E definition                                    |
| Client-facing Hotel stay                                    | `ServiceOffer`                                    |
| Client-selectable room category                             | Choice option and exact source activation/binding |

The ordinary Hotel adapter supports:

* arrival and departure dates;
* IANA time zone;
* room categories;
* maximum occupancy where known;
* blocked, on-request, external, or non-applicable inventory;
* fixed, per-room, per-room-night, per-person, per-person-night, and supported percentage Supplier components;
* additional-adult or other named Supplier adjustments;
* applicable deposits and deadlines;
* one Hotel Service with room-category choices only when Clients genuinely choose among those categories.

Operational room categories that Clients cannot choose remain Supplier Resources without Client choice options.

The blocking fixture is the Smith Family pre-stay at Hilton Fort Lauderdale Marina:

* November 2–5, 2027;
* option date February 4, 2027;
* rooming list due October 18, 2027;
* additional adult `$20.00` per night;
* related `$3.20` tax as a distinct Supplier fact;
* 15% deposit on guaranteed rooms;
* final payment on the option date.

The fixture must not invent room quantities, room categories, nightly room rates, or Client prices that the accepted scenario does not supply.

### 3.2 Transportation

A typed Transportation graph normally uses one Item per operational segment.

The ordinary adapter supports:

* segment name;
* service date;
* pickup and drop-off labels;
* scheduled time and local zone when known;
* passenger, seat, or vehicle capacity when applicable;
* fixed vehicle, per-segment, per-person, or supported unit Supplier cost;
* final-count, option, cancellation, or other applicable deadlines;
* one Client Service per Client-recognizable segment by default.

A route label is presentation, not a new location or itinerary persistence model.

The blocking Smith fixture contains three independently saved segments:

| Segment        | Capacity | Supplier cost | Illustrative Client price |
| -------------- | -------: | ------------: | ------------------------: |
| Hotel → Port   |       15 |          $200 |                       $27 |
| Airport → Port |       15 |          $175 |                       $23 |
| Port → Airport |       15 |          $175 |                       $23 |

The illustrative Client prices do not become persisted Client terms in Slice 3.

### 3.3 Activity, Meal, and Excursion

Activity, Meal, and Excursion share one adapter family. The selected template affects wording and defaults, not persistence type.

The ordinary adapter supports:

* Item name and template;
* scheduled date/time and local zone;
* location text;
* participant capacity when contractually meaningful;
* fixed-group, per-person, or supported unit Supplier cost;
* contractual minimums through shipped Supplier cost semantics;
* option, cancellation, final-count, or other applicable deadlines;
* included, optional, or undecided Client intent as presentation leading to shipped Service and later Package commands.

A minimum is not automatically capacity, enrollment, or demand.

The blocking Smith fixture is Island Sightseeing:

* October 8, 2027;
* Supplier cost `$50.00` per person;
* minimum 5;
* option/cancellation date September 24, 2027;
* illustrative Client price `$57.50`;
* one optional Client Service;
* no invented participant Pool unless the Supplier contract states controlled capacity.

### 3.4 Mixed DMC

A DMC remains an ordinary Supplier Arrangement containing heterogeneous Items.

Slice 3 adds no DMC aggregate. The mixed-DMC workspace is an Item table whose rows route to Hotel, Transportation, Activity, Meal, Excursion, or Advanced handling.

Each row shows:

* Item name;
* family;
* schedule;
* capacity state;
* Supplier-cost state;
* deadline/deposit state;
* Client-Service connection state;
* exact next action;
* Advanced setup.

Each Item saves independently. An invalid row never rolls back a successfully saved sibling Item.

---

## 4. Typed compatibility and Advanced fallback

Each family has a write-free detector that evaluates the exact Arrangement version and Item graph.

A detector returns:

* `compatible?`;
* stable reason codes;
* Staff-facing reasons;
* projected typed fields;
* exact Advanced route and return target.

Detection fails closed when the graph contains, among other unsafe shapes:

* more than one record where the typed shape requires one;
* unknown or conflicting Item membership;
* unsupported occurrence topology;
* Resources or Pools whose roles cannot be reconstructed;
* mixed quantity bases that the typed editor would flatten;
* cost components, percentage bases, minimums, or shortfalls that cannot be represented without reinterpretation;
* ambiguous deadline or deposit definitions;
* incompatible activated/successor identity;
* source bindings or choices that do not match the Item;
* package-owned or otherwise immutable graphs;
* duplicate or unreachable claims.

Unsupported graphs are never normalized, deleted, or partially rewritten by the typed adapter.

The summary may remain readable while the affected definition or Item routes to Advanced.

---

## 5. Connection contract

Slice 3 ships a common connect-each-Item interaction:

1. **Create Client Service**
2. **Connect existing Client Service**
3. **Decide later**

All three modes pass through an authoritative connection command and claim the Item transactionally.

The connection command must:

* target the exact draft Service Offer version;
* preserve existing safe descriptive fields where required;
* create exact source bindings;
* create choices only for genuine Client-selectable variants;
* avoid duplicate Service Offers;
* avoid Client price creation;
* use optimistic locks;
* use create idempotency;
* audit one bounded success event;
* reject governing IDs or incompatible graphs;
* preserve the selected Arrangement version pin on later updates.

Whether Slice 3 generalizes `ConnectCruiseServiceOffer` or adds a new generic command is an Accept-time code-inspection decision. The accepted contract must name the exact public commands and must not leave example names.

---

## 6. Shared adapter support

No universal framework is created in 3A.

After Hotel and Transportation are implemented, 3C may extract support proven identical in both adapters, including:

* typed shape result vocabulary;
* draft/successor targeting;
* authorization and tenant scoping;
* Item claim and connection orchestration;
* form normalization;
* Advanced return context;
* summary-row compilation;
* idempotency and lock helpers;
* focus and recovery parameters.

Family-specific domain decisions remain in family-specific services. Shared support must not branch on a growing list of service-family strings to simulate STI.

---

## 7. Workspace interaction contract

### 7.1 Summary first

Default visits show saved information, not open forms.

Each adapter page separates:

1. Supplier service facts;
2. capacity, when applicable;
3. Supplier cost terms;
4. deadlines and deposits;
5. Client-Service connection.

The page identifies which facts are saved and which action opens an editor.

### 7.2 One editor

At most one decision region is editable at a time.

The editor opens only through an explicit action or validated query state. A successful mutation redirects `303 See Other` to the saved summary without reopening the form.

An invalid mutation renders `422 Unprocessable Entity`, preserves every submitted field and branch selection, focuses the error summary, and links errors to controls.

### 7.3 Save boundaries

* Arrangement shell saves independently.
* Each Item saves independently.
* Each capacity definition saves independently.
* Each Supplier cost definition saves independently.
* Each deadline or deposit definition saves independently.
* Each Client-Service connection saves independently.
* There is no whole-Arrangement or whole-DMC mega-save.

A failed sibling save leaves earlier successful records and unrelated rates, capacity, deadlines, deposits, and connections unchanged.

### 7.4 Status vocabulary

Use derived, plain-language states:

* Not started
* In progress
* Needs attention
* Ready
* Connected
* Decide later
* Advanced
* Governing
* Successor draft

Technical IDs, membership enums, rate keys, quantity-basis enums, and lock versions are not ordinary UI copy.

### 7.5 Authorization and layout

Every Slice 3 page and mutation requires `manage_departures`; unauthorized users receive not found.

Reuse the `dd-` interface contract and existing responsive table patterns. No new JavaScript framework is introduced.

Prove:

* keyboard-only operation;
* visible focus;
* error recovery;
* no page-level horizontal overflow;
* internal labeled table scrolling where necessary;
* 375, 768, 1280, and 1400 pixel widths.

---

## 8. Routes and services

Exact names are locked only after inspecting the shipped Slice 2D base.

The accepted plan must name:

* Hotel workspace routes and controller;
* Transportation workspace routes and controller;
* Activity workspace routes and controller;
* mixed-DMC Item workspace route and controller;
* family shape detectors;
* family workspace compilers;
* family create/update orchestration commands;
* Item connection command;
* any shared support module;
* exact existing M3/M4 commands invoked underneath.

Preferred route topology remains nested under the exact Supplier Arrangement and Item:

```text
/departures/:departure_id/arrangements/:arrangement_id/hotel
/departures/:departure_id/arrangements/:arrangement_id/transportation
/departures/:departure_id/arrangements/:arrangement_id/activities
/departures/:departure_id/arrangements/:arrangement_id/items/:item_id/...
/departures/:departure_id/arrangements/:arrangement_id/dmc-items
```

These paths are provisional. Accept must reconcile them with the shipped Cruise and Arrangement topology and name the final routes exactly.

---

## 9. Delivery sequence

### 3A — Hotel adapter

Ship:

* Hotel detector and read model;
* Hotel setup and update commands;
* occurrence, room-category, inventory, Supplier-cost, and M3E integration;
* Hotel Service connection;
* Hotel summary-first workspace;
* Hilton blocking proof.

**Exit:** Staff can establish the accepted Hilton shape and connect one Hotel Service without using generic graph editors for supported facts.

### 3B — Transportation adapter

Ship:

* Transportation detector and read model;
* segment setup and update commands;
* applicable capacity and Supplier-cost integration;
* Transportation Service connection;
* Transportation summary-first workspace;
* three-segment Smith proof.

Do not introduce a universal adapter abstraction in advance of this implementation.

**Exit:** Staff can independently establish and connect all three Smith transfer segments without sibling rollback or automatic Client pricing.

### 3C — Shared support and Activity adapter

First compare 3A and 3B. Extract only proven shared behavior.

Then ship:

* Activity/Meal/Excursion detector and read model;
* setup and update commands;
* applicable capacity, minimum, Supplier-cost, and deadline integration;
* Activity Service connection;
* Activity summary-first workspace;
* Island Sightseeing blocking proof.

**Exit:** Hotel, Transportation, and Activity use shared support only for behavior demonstrated identical by at least two adapters.

### 3D — Mixed-DMC Item workspace and closure

Ship:

* mixed-DMC Item table;
* per-row routing and status;
* independent row saves;
* unsupported-row Advanced fallback;
* mixed Transportation, Activity, and Meal fixture;
* cross-adapter acceptance and accessibility proof.

**Exit:** One DMC Arrangement can contain heterogeneous Items without a DMC aggregate, mega-form, or Cruise-specific persistence.

This draft was never accepted on `main`. Slice 3R is the successor decision and is not yet accepted.

---

## 10. Proof contract

### 10.1 Service and command proof

* Every typed shape compiles to the expected generic M3/M4 graph.
* No service-family aggregate table is created.
* Create retries replay without duplicate records or audit success.
* A changed payload with the same idempotency key conflicts.
* Stale Arrangement or Service Offer locks leave all graphs unchanged.
* Cross-Agency, cross-Departure, cross-Arrangement, cross-version, and wrong-Item identifiers fail closed.
* Governing records remain immutable.
* Compatible successors receive edits without moving exact source pins silently.
* Unsupported graphs remain unchanged.
* One failed Item save leaves saved siblings unchanged.
* Supplier costs never create Client price components.
* Removing or discarding a draft connection follows shipped claim and binding lifecycle rules.
* Commands acquire locks in the repository’s accepted order.

### 10.2 Detector proof

For each family, prove:

* empty supported shape;
* populated supported shape;
* safe reopen without normalization drift;
* unsupported occurrence topology;
* unsupported capacity topology;
* unsupported cost topology;
* ambiguous deadline/deposit topology;
* incompatible connection;
* active read-only state;
* successor draft state;
* detector writes nothing.

### 10.3 Request proof

* Viewer receives not found for every route.
* Default page shows summaries with no open form fields.
* Explicit actions open one editor.
* Successful saves redirect `303` to summary.
* Invalid saves return `422` and preserve values.
* Submitted IDs are fully tenant- and graph-scoped.
* Read models and previews write nothing.
* Advanced links preserve a validated return target.

### 10.4 System and accessibility proof

1. Establish and connect the Hilton Hotel service.
2. Enter room inventory and applicable Hotel Supplier terms.
3. Enter the accepted Hotel deadlines and deposit without payment language.
4. Establish the three Smith transfer segments independently.
5. Confirm that editing one segment does not alter another.
6. Establish Island Sightseeing with per-person cost and minimum but no invented Pool.
7. Connect Hotel, Transportation, and Activity Services without automatic Client prices.
8. Reopen all supported shapes without identity loss.
9. Show one unsupported graph as Advanced and unchanged.
10. Edit a compatible successor while the governing version remains read-only.
11. Use a mixed-DMC table containing Transportation, Activity, and Meal Items.
12. Fail one DMC row without disturbing saved siblings.
13. Complete keyboard-only creation, invalid recovery, and connection.
14. Prove layouts at 375, 768, 1280, and 1400 pixels without page overflow.

### 10.5 Anti-hardcoding proof

* Hotel does not use Cruise cabin semantics.
* Transportation does not require Hotel stay or room-night semantics.
* Activity does not invent a seat or room Pool.
* Meal uses the Activity-family adapter without a Meal table.
* DMC remains an Arrangement with ordinary Items.
* No Cruise-specific table, evaluator, or persistence is required.
* No Supplier cost is treated as Client revenue.
* No illustrative Client price is stored without an explicit Client-pricing command.

---

## 11. Documentation and ship boundary

On Accept:

* create this document at `docs/planning/m4d1-slice3-hotel-transportation-activity-adapters.md`;
* update the M4D.1 parent Slice 3 section;
* update `AGENTS.md`, `docs/README.md`, `docs/planning/roadmap.md`, and `docs/terminology.md`;
* pin the implementation base;
* replace provisional command and route names with exact inspected names;
* record remaining deferred work explicitly.

During implementation:

* mark 3A–3D independently;
* do not mark the overall slice Shipped early;
* update `docs/ui/interface-contract.md` when each ordinary workspace ships;
* retain applicable generic screens as Advanced setup.

After all four deliveries merge green:

* pin the final merge commit;
* mark Slice 3 Shipped;
* identify Slice 4 Vineyard proof as the next unauthorized boundary until separately accepted.

---

## 12. Decisions required before Accept

1. **Slice boundary:** Confirm that Slice 3 ends at Supplier setup plus Service connection and does not add specialized Client-pricing matrices.
   **Recommendation:** Yes.

2. **Transportation granularity:** Are Smith transfer segments separate Client Services by default?
   **Recommendation:** Yes; permit an explicit combined service only when Staff choose it and the source graph is compatible.

3. **Hotel choices:** Are room categories Client choices only when Clients actually select them?
   **Recommendation:** Yes.

4. **Capacity:** May an adapter omit Resources or Pools when capacity is not applicable?
   **Recommendation:** Yes; never fabricate graph layers.

5. **Activity minimum:** Is the minimum a Supplier cost/commitment fact rather than capacity or enrollment?
   **Recommendation:** Yes.

6. **Optional Activity placement:** Does Slice 3 merely create/connect the optional Service, leaving Package placement to shipped generic Package controls or Slice 4?
   **Recommendation:** Yes.

7. **DMC meaning:** Is DMC only a heterogeneous Arrangement and Item workspace?
   **Recommendation:** Yes; no DMC model.

8. **Connection implementation:** Can the shipped Cruise claim/connection support be generalized safely, or should Slice 3 add a generic Item connection command and leave Cruise unchanged?
   **Must be resolved by code inspection before Accept.**

9. **Audit actions:** Does one generic Item-adapter save action suffice, or are family-specific actions required for operational clarity?
   **Recommendation:** One bounded generic Supplier Item setup action plus the existing Service connection action, unless shipped audit conventions require otherwise.

10. **Exact commands and routes:** Name them in a later accepted vertical plan after inspecting the shipped Slice 2D base. No “for example” names belong in that plan.

---

## 13. Exit criteria

Slice 3 is complete when ordinary Staff can:

* establish the accepted Hilton Hotel shape;
* establish the three Smith transfer segments;
* establish Island Sightseeing;
* manage a heterogeneous DMC Item list;
* connect each genuine Client service to exact Supplier support;
* understand what is saved, missing, connected, or Advanced;
* edit supported successor drafts safely;
* and do so without service-family persistence, duplicated calculation engines, automatic Client pricing, or knowledge of the generic M3/M4 graph.
