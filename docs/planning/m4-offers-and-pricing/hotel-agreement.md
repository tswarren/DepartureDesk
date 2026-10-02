# Hotel Agreement

**Status:** Shipped 2026-10-01  
**Location:** `docs/planning/m4-offers-and-pricing/hotel-agreement.md`  
**Parent:** [M4D.1 — Departure Composition Workspace](m4d1-departure-composition-workspace.md)  
**Authority:** [ADR 0015](../../adr/0015-supplier-agreement-operational-boundary.md) — Supplier agreement operational modeling boundary  
**Prerequisites:** Hotel Supplier Composition foundations, Hotel Supplier rates, Supplier complexity rebaseline, Approved Hilton Fort Lauderdale Marina fixture, Accepted Hotel Staff walkthrough  
**Implements:** Hotel Agreement only, through [workspace read mode](hotel-agreement-workspace-read-mode.md) then [term authoring](hotel-agreement-term-authoring.md)  
**Does not authorize:** Hotel Review and Activation, Hotel Lifecycle, document storage, generalized Supplier policy/calculation engines, Transportation, M4E

---

## 1. Purpose

Hotel Supplier Composition now has the operational and reference primitives needed to represent the Supplier agreement without introducing another Hotel-specific contract model.

Shipped authority includes:

- exact-version Supplier Arrangement and Item topology;
- Hotel Stay and schedule;
- nightly room inventory;
- Supplier rates and `commission_treatment`;
- fixed Supplier Deposit Requirements;
- Supplier Deadlines;
- Supplier confirmation infrastructure;
- version-owned `SupplierAgreementReference`;
- successor-copy behavior and exact-version immutability.

ADR 0015 and the Supplier complexity rebaseline establish the two relevant information layers:

### Operational definitions

Structured authority used by DepartureDesk now:

- Stay and schedule;
- nightly room inventory;
- Supplier rates;
- commission treatment;
- fixed Deposit Requirements;
- actionable Deadlines;
- Supplier confirmation.

### Agreement reference

Version-owned Supplier wording that Staff need to retrieve but DepartureDesk does not currently operate from.

Supported Hotel reference kinds are:

- `deposit_derivation`
- `attrition`
- `deposit_refund`
- `destination_fee`
- `additional_nights`
- `early_departure`
- `cancellation`

This plan creates the Staff-facing Hotel Agreement workspace over those existing records.

It does **not** create another Supplier agreement model.

---

## 2. Product outcome

For one Hotel `ArrangementItem`, Staff should be able to open one Hotel-native Agreement workspace and understand:

- what stay was contracted;
- what rooms were blocked for each night;
- what Supplier rates apply;
- what deposits are required;
- what operational deadlines exist;
- what additional contractual provisions were recorded;
- whether the exact Supplier Arrangement Version has been confirmed;
- whether Staff are looking at the governing agreement or a proposed successor.

The normal Hotel surface should use Hotel language rather than generic M3 implementation vocabulary.

The workspace is the primary typed Staff entry point for an existing Hotel Item.

It is not the place where the Hotel Item itself is created.

---

## 3. Core boundary

### 3.1 Unified working surface, not parallel domain

Hotel Agreement is a unified working surface over authoritative existing records.

It must not:

- copy authoritative values into a second Hotel Agreement table;
- create parallel Stay, inventory, rate, Deposit, Deadline, or confirmation records;
- derive executable policy from Supplier agreement wording;
- silently reinterpret generic M3 structures.

Specialized Hotel editors continue to mutate the existing authoritative records.

Hotel Agreement composes them into one coherent Staff workflow.

### 3.2 Available immediately

Hotel Agreement becomes available once a lodging `ArrangementItem` exists.

The Agreement may be incomplete.

An incomplete draft is normal planning state and must not be confused with failed activation readiness.

### 3.3 Item scope

One Hotel Agreement page represents exactly one lodging `ArrangementItem` on one exact Supplier Arrangement Version.

If an Arrangement contains two Hotel Items, each has its own Agreement workspace.

Version-wide records may appear on more than one Item page only when their existing coverage/scope makes them relevant.

They are not duplicated.

### 3.4 Exact-version rule

Hotel Agreement never merges records across versions.

The workspace always has:

- one Supplier Arrangement;
- one exact Supplier Arrangement Version;
- one lodging Arrangement Item.

If a successor draft exists, the default working view is the successor.

Otherwise the page defaults to the governing/current version.

Staff may explicitly switch between exact versions.

---

## 4. Navigation

From Composition → Suppliers, the primary action for an existing Hotel Item becomes:

> **Open Hotel Agreement**

The Hotel Agreement becomes the normal Staff mental model for working with the Supplier agreement.

Existing specialized editors remain available from inside Agreement.

Generic Supplier planning remains available as:

> **Advanced Supplier planning**

The older typed Hotel setup routes may remain because Agreement reuses them, but they are demoted from primary navigation.

---

## 5. Route and controller boundary

Use an Item-scoped typed route under Departure and Supplier Arrangement context.

Conceptually:

```text
/departures/:departure_id/
  supplier_arrangements/:supplier_arrangement_id/
  items/:arrangement_item_id/
  hotel_agreement
```

Exact-version selection is explicit route/query state.

Use a dedicated typed controller, such as:

```text
HotelAgreementsController
```

The controller primarily serves `show`.

It must not become a general-purpose Hotel mutation controller.

Existing Stay, inventory, rate, Deposit, and Deadline commands remain authoritative.

Hotel Agreement term authoring may use narrow Hotel-specific endpoints over `SupplierAgreementReference`.

---

## 6. Authorization

Reuse existing Departure permissions.

### Read

Users permitted to view the Departure/Supplier composition may view Hotel Agreement.

### Mutation

Only users with `manage_departures` may mutate editable draft records.

Do not add a Hotel-specific permission.

Agency, Departure, Arrangement, Item, and exact-Version ownership must be verified on every load and mutation.

A non-lodging Item fails closed rather than rendering a generic agreement page.

---

## 7. Read model

Introduce a write-free typed read model such as:

```text
HotelAgreementWorkspace
```

It returns Hotel-shaped read structures rather than exposing generic M3 records directly to the controller/view.

Suggested conceptual output:

```text
identity
version_state
stay
room_categories
nightly_blocks
rate_rows
deposit_rows
deadline_rows
term_rows
supplier_confirmation
source_default
section_states
advanced_findings
```

The read model does not persist state.

---

## 8. Page structure

Use this order:

1. Agreement overview
2. Stay
3. Room block
4. Supplier rates
5. Deposits
6. Deadlines
7. Agreement terms
8. Supplier confirmation

The order moves from service definition through economics and operational requirements into reference wording and confirmation state.

---

## 9. Agreement overview

The header shows:

- Hotel/Supplier name;
- Supplier Arrangement name;
- Hotel Item name;
- Departure;
- Stay dates when available;
- exact version number;
- version status;
- Supplier-confirmation status;
- derived agreement-source summary when available;
- Advanced Supplier planning link.

### Version labels

The header shows three facts together:

- Role: Draft, Proposed successor draft, Current governing agreement, or Superseded agreement.
- Confirmation: Not Supplier confirmed, or Supplier confirmed.
- Activation: Not yet activated, or Activated.

A proposed successor that is already Supplier-confirmed shows **Proposed successor draft** and **Supplier confirmed** together.

When a successor exists:

> **Proposed successor vN**  
> Based on current vN-1

Provide an explicit exact-version switcher.

Do not merge governing and successor information into one page.

---

## 10. Agreement progress

Hotel Agreement does not persist an Agreement-complete flag.

It also does not claim contractual completeness before Hotel Review & Activation defines reviewed/none semantics.

Do not show an overall `X of Y complete` score.

Instead show factual progress such as:

- Stay recorded
- Room block recorded
- Contracted rates recorded
- 3 deposits
- 1 deadline
- 5 agreement terms recorded

Derived section states may use:

- `Not started`
- `In progress`
- `Recorded`
- `Needs attention`

`Needs attention` means conflicting, ambiguous, or unsupported current data.

Missing data alone is not automatically an error.

---

## 11. Stay

### Display

Show:

- arrival date;
- departure date;
- check-in time;
- checkout time;
- time zone.

### Editing

Agreement shows the Stay summary and launches a focused existing Hotel Stay editor.

Do not build a second Stay mutation path.

### Derivation

The workspace identifies exactly one Hotel Stay occurrence for the Item/version.

The Stay is not one of the nightly capacity occurrences.

If no Stay exists:

> Not started

If more than one candidate exists:

> Needs attention

Do not guess.

### Hilton proof

The canonical fixture displays:

- arrival: November 4, 2027;
- departure: November 6, 2027;
- check-in: 3:00 p.m.;
- checkout: noon;
- time zone: America/New_York.

---

## 12. Room block

### Display

Use a Hotel-native nightly matrix.

Hilton:

| Night | Standard | Deluxe | Total |
| --- | ---: | ---: | ---: |
| Nov 4 | 5 | 2 | 7 |
| Nov 5 | 10 | 5 | 15 |

The Stay occurrence must not appear as capacity inventory.

### Editing

Agreement itself does not edit Pool quantities inline.

Actions launch the specialized Hotel inventory editor:

- Set up room block
- Edit room block
- Add room category
- Change nightly quantities

### Derivation

Room categories come from exact-version Supplier Resources for this Item.

Nightly cells come from exact-version capacity definitions for:

- the same Item;
- one inventory-night occurrence;
- one room-category Resource.

Never infer categories from labels or costs.

### Inventory modes

Numeric inventory renders the quantity.

Explicit nonnumeric supply renders its semantic state, for example:

> On request

or:

> Externally managed

Do not invent a number.

Multiple plausible Pool definitions for one cell cause `Needs attention`.

---

## 13. Supplier rates

### Display

Render Hotel-facing occupancy totals.

Hilton:

| Category | Single | Double | Triple | Quad |
| --- | ---: | ---: | ---: | ---: |
| Standard | $173 | $173 | $193 | $213 |
| Deluxe | $223 | $223 | $243 | $263 |

Also show commission treatment:

> Noncommissionable

### Cost authority

Use existing Supplier cost-authority selection:

1. ready contracted definition;
2. otherwise ready estimate;
3. otherwise incomplete.

Never present an estimate as contracted.

If an estimate is the best current authority, label:

> Estimated

and make Rates `In progress`.

### Night differences

Where the same category has identical rates across nights, Agreement may present one category matrix.

Where nights differ, clearly surface the exception rather than flattening it.

### Editing

Use the existing Hotel rate matrix.

Agreement provides:

- Set up rates
- Edit rates

No Agreement-specific rate mutation command.

---

## 14. Taxes and fees

Operational tax/cost components remain with the Supplier-rate/economics model where already structured.

Non-operational clauses remain agreement reference.

Do not create a generalized Hotel tax-policy model.

For example, the Hilton Destination Fee waiver is Agreement Terms wording rather than a negative Supplier cost or Client discount.

---

## 15. Deposits

### Display

Show relevant operational `SupplierDepositRequirementDefinition` records.

Hilton:

| Due | Amount |
| --- | ---: |
| Oct 1, 2026 | $415.60 |
| May 7, 2027 | $1,870.20 |
| Oct 4, 2027 | $1,870.20 |

The Agreement acceptance scenario records coverage that includes the Hilton Item on these three requirements before it asserts this schedule. That coverage is one link, `{ arrangement_item_id: <this item> }`, written through the existing deposit command.

The shipped persistence fixture leaves those requirements with empty coverage. That fixture stays the unassigned case: the amounts stay off the stay schedule and appear as unassigned, with a link to Advanced Supplier planning. Hotel Agreement does not backfill that fixture.

Fixed Deposit Requirements remain operational authority.

### Deposit derivation

Show the `deposit_derivation` reference contextually beneath the schedule:

> **How the Supplier derived these deposits**  
> Recorded — View/Edit

The reference explains the schedule but does not calculate or validate it.

It may also appear as a Recorded row in Agreement Terms, but full wording should have one canonical editor.

### Relevance

Show a Deposit Requirement when its existing coverage:

- explicitly includes this Hotel Item; or
- resolves entirely to Supplier cost authority belonging to this Item.

Do not infer ownership merely because the Arrangement contains only one Hotel Item.

Unassigned/ambiguous Deposit Requirements appear as Advanced/Needs attention rather than being silently assigned.

### Shared deposits

A Deposit Requirement covering multiple Items may appear on each affected Agreement page as:

> Shared across agreement

It remains one authoritative record.

### Editing

HA.1 ships a thin Hotel-native Deposit editor over the existing Deposit Requirement commands.

The editor exposes:

- amount;
- due date;
- scope.

Scope for this stay is one coverage link, `{ arrangement_item_id: <this item> }`.

Occurrence, resource, and pool coverage, percentage-of-cost deposits, contributor links, and other already-valid generic shapes stay read-only on the Agreement page, labeled Advanced configuration, and open Advanced Supplier planning.

The Agreement page and this editor use Hotel language. Advanced Supplier planning may use existing Supplier vocabulary.

---

## 16. Deadlines

### Display

Show relevant operational `SupplierDeadlineDefinition` rows in one consolidated Hotel Deadlines section.

Hilton:

> **Rooming list due** — October 3, 2027 at 5:00 p.m. ET

Only actual Deadline definitions belong here.

A date embedded inside agreement wording does not become a Deadline automatically.

Specifically, Hilton’s November 20, 2027 refund date remains outside the Deadline subsystem.

### Relevance

Use existing coverage semantics.

Do not show unrelated Arrangement deadlines.

Shared Deadlines may appear on each relevant Item page as:

> Shared across agreement

### Editing

HA.1 ships a thin Hotel-native Deadline editor over the existing Deadline commands.

The editor exposes:

- deadline label;
- due moment;
- scope for this stay, written as one coverage link `{ arrangement_item_id: <this item> }`.

Unsupported valid generic shapes remain visible as:

> Advanced configuration

with a link to Advanced Supplier planning.

---

## 17. Agreement Terms

Show a standard Hotel checklist for these closed kinds:

- Deposit derivation
- Attrition
- Deposit refund
- Destination Fee
- Additional nights
- Early departure
- Cancellation

### Status

Recorded rows show:

> Recorded

Missing rows show:

> Not recorded

`Not recorded` is neutral.

It does not mean the contract has no such term.

Hotel Agreement does not persist `reviewed — none`.

That semantic belongs to Hotel Review & Activation.

### Human presentation

Use Hotel-facing names and concise helper descriptions.

Examples:

**Attrition**  
Minimum room usage and Supplier consequences if contracted pickup is not achieved.

**Additional nights**  
Supplier availability or pricing provisions outside the contracted stay.

These descriptions are presentation guidance only.

They do not create domain semantics.

---

## 18. SupplierAgreementReference authoring boundary

Hotel Agreement uses the single shipped `SupplierAgreementReference` family.

Do not reintroduce specialized:

- attrition policy;
- Deposit Basis;
- refund policy;
- cancellation policy;
- amenity/concession policy models.

### Current Item-required kinds

These remain Item-scoped:

- `deposit_derivation`
- `attrition`
- `deposit_refund`

### Additional Hotel kinds

Hotel Agreement authorizes Staff authoring of:

- `destination_fee`
- `additional_nights`
- `early_departure`
- `cancellation`

Staff choose **This Hotel stay** or **Entire Supplier agreement**.

This Hotel stay persists `arrangement_item_id`. Entire Supplier agreement leaves `arrangement_item_id` null.

Wording does not choose the scope.

`deposit_derivation`, `attrition`, and `deposit_refund` stay Item-scoped. The command rejects a version-wide row for those three.

For each of the four optional kinds, a version has either one row for this Item or one row with no Item. Creating or updating into the other scope is rejected by `RecordSupplierAgreementReference` and by a database trigger. The checklist stays seven rows. If both rows are already present, that checklist row is Needs attention and links to both records.

A version-wide row appears on other Hotel Item pages as **Agreement-wide term** and edits the same record.

Do not silently duplicate version-wide terms onto each Item.

---

## 19. Agreement-reference editor

Use one mostly shared wording editor.

Common fields:

- governing wording;
- source description;
- Supplier reference;
- external reference;
- existing supported evidence/provenance metadata.

For `deposit_refund`, also show:

- original wording;
- governing wording.

Do not add specialized structured fields for percentages, dates, rates, minima, cancellation ladders, refund dates, or similar clause content.

Kind-specific helper copy may guide Staff without changing the persistence model.

No custom term kind is authorized in this plan.

---

## 20. Source default

Hotel Agreement may derive a source default for convenience.

If existing references share the same provenance, use that as the suggested source for a new term.

If existing references have mixed provenance, show no page-level default.

Saving a new term copies the chosen provenance into that reference.

There is:

- no shared source record;
- no live inheritance;
- no “Save Agreement source” command;
- no retroactive rewriting of existing references.

Each reference retains its own exact provenance.

---

## 21. Supplier confirmation

Hotel Agreement displays confirmation state but does not record Supplier confirmation.

Before confirmation:

> **Supplier confirmation**  
> Not confirmed

After exact-version confirmation:

> **Supplier confirmed**

Show available evidence metadata, including:

- evidence date;
- channel;
- Supplier identifier/reference where present;
- recorded metadata where useful.

Supplier confirmation and Arrangement activation must remain visibly distinct.

Confirmation freezes the exact-version agreement reference before activation.

Recording confirmation belongs to Hotel Review & Activation.

---

## 22. Immutability and successor behavior

### Unconfirmed draft

Editable through authorized typed workflows.

Agreement references may be added, edited, or deleted.

### Supplier-confirmed exact version

Read-only.

Do not allow insert, update, or delete of its agreement references.

### Activated governing version

Read-only.

Offer:

> Create successor draft

### Successor draft

Editable until its own Supplier confirmation.

Existing version-owned agreement references copy through the shipped successor mechanism.

Staff edit the successor copy.

The predecessor never changes.

Hotel Agreement must never silently create a successor when Staff click Edit.

### Deleting a copied reference

Readiness requires every predecessor `SupplierAgreementReference` to have a copy on the successor. Deleting that copy blocks activation of the successor until the copy exists again.

The delete confirmation for a row with `copied_from_id` says that before the delete proceeds. The delete still proceeds on an unconfirmed draft after that confirmation. A reference created on the successor, with no `copied_from_id`, does not get that warning.

Hotel Agreement does not weaken successor-copy readiness. If readiness fails later, the Agreement page names the missing copied term.

---

## 23. Version comparison

The first Hotel Agreement implementation includes:

- exact-version switcher;
- governing/successor labels;
- predecessor link.

It does **not** implement semantic section-level diff indicators yet.

Reliable cross-family semantic comparison is deferred.

A later plan may add:

> Changed from current agreement

only after comparison rules are explicitly accepted.

---

## 24. Needs-attention behavior

Reserve `Needs attention` for states such as:

- multiple candidate Stay records;
- ambiguous room-block authority;
- conflicting capacity Pools;
- unsupported rate authority;
- ambiguous Deposit ownership;
- ambiguous Deadline ownership;
- broken copied lineage;
- reference ownership mismatch.

A missing ordinary record is not automatically Needs attention.

One broken section does not prevent Staff from using the rest of the Agreement page.

If the typed Hotel surface cannot repair a valid generic configuration, link to Advanced Supplier planning.

Do not silently rewrite unsupported structures.

---

## 25. No new identity fields

This plan does not introduce new Hotel-specific structured fields for:

- Hotel group number;
- contract/signature date;
- agreement effective date.

Existing confirmation/evidence/reference facilities remain authoritative unless a later accepted workflow demonstrates a structured domain need under ADR 0015.

---

## 26. No Staff-note model

Do not introduce generic internal annotation persistence.

Agreement-reference provenance/evidence fields may be exposed only for their existing evidentiary purpose.

Supplier wording and Staff commentary must not be conflated.

---

## 27. First acceptance scenario

Use the Approved Hilton Fort Lauderdale Marina fixture.

The primary Staff journey must prove:

1. Open Composition → Suppliers.
2. Open the Hotel Agreement for the Hilton stay Item.
3. See exact Item/version identity.
4. Review Stay.
5. Review nightly room block.
6. Review Supplier-rate matrix.
7. Review deposits in both proofs: with Item coverage recorded, the schedule shows the three fixed amounts; with the persistence fixture’s empty coverage unchanged, those amounts are unassigned and off the schedule.
8. See Deposit derivation as reference, not calculation authority.
9. Review the actionable rooming-list Deadline.
10. Review the seven standard Agreement Terms rows.
11. See recorded versus not-recorded reference terms.
12. See Supplier confirmation status.
13. Launch one specialized editor and return to Agreement.
14. See no generic Supplier vocabulary on the Agreement page or the thin Deposit and Deadline editors.
15. Confirm that Hotel Agreement itself performs no Supplier confirmation or activation.
16. On an activated variant, create/open a successor draft and prove the workspace defaults to that successor.

A second Hotel Item is proved in focused tests rather than bloating the main Staff walkthrough.

Mixed provenance is likewise a focused test rather than a canonical Hilton fixture mutation.

---

## 28. Delivery sequence

Hotel Agreement is implemented in two reviewable slices.

### HA.1 — Agreement workspace and read model

Ships the typed workspace, exact-version read model, summaries, statuses, navigation, confirmation display, Advanced fallback, and the thin Hotel Deposit and Deadline editors.

It does not expand agreement-reference authoring beyond currently shipped behavior.

### HA.2 — Agreement-term authoring

Ships typed authoring of all seven accepted Hotel reference kinds, including provenance handling, version/item scope, draft deletion, and confirmation immutability.

**Combined delivery.** HA.1 and HA.2 were implemented together. The earlier rule that HA.2 starts only after HA.1 has landed and is green was not met as a separate review gate. This section amends that sequence. The combined implementation is the authority for both slices. It does not record a prior independent HA.1 landing.

---

## 29. Explicit non-goals

This plan does not authorize:

- Hotel Review & Activation;
- Hotel Lifecycle;
- recording Supplier confirmation from Agreement;
- Arrangement activation from Agreement;
- persisted reviewed/none state;
- an overall Hotel Agreement completeness flag;
- document upload or managed agreement files;
- printable agreement export;
- generalized Supplier contract-policy processing;
- attrition calculation;
- pickup calculation;
- refund calculation;
- Supplier refund receivable/settlement;
- conversion of November 20 to a Deadline;
- cancellation-charge calculation;
- automated deposit derivation;
- generalized tax policy;
- custom agreement-reference kinds;
- semantic governing-versus-successor diff;
- Transportation;
- M4E.

---

## 30. Accepted locks

Accepted 2026-10-01, this parent locks:

- one Item-scoped Hotel Agreement workspace;
- one exact-version view at a time;
- successor-first default when a successor exists;
- Hotel-shaped read model over existing M3 authority;
- Hotel Agreement as primary typed Staff entry point;
- existing Stay, room-block, and rate editors reused rather than duplicated;
- HA.1 thin Deposit and Deadline editors over existing commands;
- a deposit on the stay schedule only when coverage includes this Item or the requirement resolves entirely to this Item’s cost authority;
- Hilton schedule proof records that Item coverage; empty coverage remains the unassigned case;
- one scope per optional reference kind on a version;
- composed version role, confirmation, and activation labels;
- seven closed Hotel reference kinds;
- no reviewed-none semantics yet;
- no Supplier-confirmation mutation here;
- no new policy models;
- no new Hotel identity fields;
- HA.1 and HA.2 delivered together, as amended in §28.

---

## 31. Parent exit criteria

Hotel Agreement is complete when HA.1 and HA.2 ship and:

- one Hotel Item has one coherent typed Agreement workspace;
- Stay, room block, rates, Deposits, Deadlines, terms, and confirmation state are understandable on the Agreement page and the thin Deposit and Deadline editors without generic Supplier vocabulary;
- operational records retain existing authority;
- all seven Hotel reference kinds are readable;
- all seven are writable according to the accepted scope rules;
- Supplier-confirmed versions are immutable;
- successor drafts remain editable until their own confirmation;
- unsupported generic shapes remain intact and reachable through Advanced Supplier planning;
- no duplicate Hotel agreement domain exists;
- no executable policy was inferred from Supplier wording;
- [Hotel Review and Activation](hotel-review-and-activation.md) is Accepted separately.