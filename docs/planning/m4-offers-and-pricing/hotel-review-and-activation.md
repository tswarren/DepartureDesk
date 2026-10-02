# Hotel Review and Activation

**Status:** Accepted 2026-10-01 · implementation amendment in progress 2026-10-02  
**Location:** `docs/planning/m4-offers-and-pricing/hotel-review-and-activation.md`  
**Parent:** [Hotel Agreement](hotel-agreement.md)  
**Authority:** [ADR 0015](../../adr/0015-supplier-agreement-operational-boundary.md) — Supplier agreement operational modeling boundary  
**Prerequisites:** Hotel Agreement shipped  
**Does not authorize:** Hotel Lifecycle, Transportation, M4E, a Client Service connection, document storage, an attrition calculator, or a change to generic activation meaning for Cruise or non-Hotel Arrangements

---

## 1. Purpose

Hotel Agreement lets Staff read one lodging Item and record agreement wording on the editable draft. It displays Supplier confirmation and does not record it. It does not activate the Arrangement.

This plan defines the next Hotel boundary: a write-free review of that exact version, an explicit Supplier confirmation on the unconfirmed draft, and activation through the existing Supplier activation command. After activation, the governing version stays read-only on the Agreement page.

The review answers ADR 0015’s activation questions in Hotel language. It does not attest that every provision of the Hotel contract has been modeled, and it does not calculate attrition, a refund, or a folio.

---

## 2. Product outcome

For one Hotel `ArrangementItem` and one exact Supplier Arrangement Version, Staff can:

- review the stay, nightly room block, Supplier rates, deposits, Deadlines recorded for this Item, agreement wording, and confirmation state without the review itself writing those records;
- record Supplier confirmation on the unconfirmed draft, with evidence date, channel, and a Supplier identifier or an explicit reason that none was supplied;
- activate that exact version only when the Hotel post gate and generic activation readiness both allow it;
- return to the Agreement page and see the governing version read-only, with confirmation and activation labeled separately.

A Viewer can read the review. A Viewer cannot confirm or activate.

---

## 3. Scope

This plan covers the Accepted Hotel Staff walkthrough steps that review the exact version, activate it, and show the governing version read-only.

Successor proposed presentation, the complete Hilton browser journey, and the documentation updates that follow activation belong to Hotel Lifecycle.

---

## 4. Review surface

The review is one exact lodging Item and one exact version. It is assembled from the shipped Hotel Agreement workspace. It does not create a second stay, inventory, rate, deposit, deadline, term, or confirmation model.

The compilation is write-free. Opening it, refreshing it, and reading it persist nothing.

The page shows the Agreement sections in Agreement order:

1. Stay
2. Nightly room block
3. Supplier rates, including `Contracted` or `Estimated` when the Agreement reader has a usable authority
4. Deposits on this Item’s schedule
5. Deadlines on this Item’s schedule
6. The seven agreement-reference kinds, resolved for this Item
7. Supplier confirmation
8. Activation

An unsupported valid generic shape stays intact. The review labels it Advanced and links to generic Supplier planning. Advanced blocks the Hotel post. The review does not rewrite the shape.

The normal Hotel labels stay the Agreement labels. Generic Supplier vocabulary stays off this page.

---

## 5. Confirmation versus activation

Supplier confirmation and Arrangement activation stay visibly distinct.

### Confirmation

Staff record confirmation on the unconfirmed draft, before activation. The command creates the existing `SupplierConfirmation` for that exact version and the contracting Supplier. It uses the existing booking evidence: evidence kind, evidence date, channel, reference note, and either a Supplier identifier or `confirmed_without_identifier_reason`.

The evidence date is the date of the confirmation evidence. It does not fill the blank original contract date. The Hotel page does not upload a document.

Recording confirmation does not activate the Arrangement, open capacity, materialize deposits, or post a payment.

### When confirmation may be recorded

Supplier confirmation freezes a reviewed Hotel agreement. It is **not** generic activation readiness minus the missing confirmation.

Staff may record confirmation when the typed Hotel agreement review is complete:

- the Stay shape is supported;
- the nightly room-block shape is supported;
- every inventory night has a complete supported contracted Hotel rate shape;
- every Deposit relevant to this Hotel, when any exists, is assigned and uses the supported thin Hotel shape;
- every Deadline relevant to this Hotel, when any exists, uses the supported Hotel shape;
- each of the seven Hotel agreement-reference kinds is explicitly reviewed as recorded wording or **Reviewed — none** at its permitted scope;
- no Hotel section is Advanced.

Because `SupplierConfirmation` belongs to the exact Supplier Arrangement Version and the confirmation freeze covers lodging definitions on that version, every lodging Item on the exact version must satisfy this same typed Hotel confirmation review before the confirmation is recorded. One completed Hotel stay may not freeze another unfinished Hotel stay.

Generic `SupplierArrangementActivationReadiness` blockers do **not** block Supplier confirmation merely because they are activation blockers. Capacity openings, materialized Deposit tranches, posted commitments, generic cost-source coverage, commitment-trigger coverage, and activation acknowledgements belong to activation.

Recording confirmation still does not activate the Arrangement, open capacity, materialize deposits, or post a payment.

### What confirmation freezes

Supplier confirmation is the last mutation of the Hotel agreement on that exact version. It is evidence for the definitions present at that moment. This plan does not keep the confirmation and allow those definitions to change underneath it, and it does not add a fingerprint or an invalidation command.

After a `SupplierConfirmation` exists for a version that includes a lodging Item, Staff cannot insert, update, or delete these records on that version:

- the stay and its schedule;
- room Resources and nightly inventory;
- Supplier rate definitions and their components for that lodging Item;
- Deposit Requirements for that lodging Item;
- Deadline definitions for that lodging Item, including a rooming-list Deadline when one is recorded;
- agreement references;
- Reviewed — none absences.

The existing draft commands enforce that freeze. A Hotel editor and the generic Supplier editor both reject the mutation. `ActivateSupplierArrangementVersion` may still materialize openings, tranches, and commitments from the frozen definitions. This freeze does not change a version that has no lodging Item.

A frozen confirmed version is never edited in place. Before first activation, Staff explicitly revise the confirmed agreement into a new draft version; after activation, changes use the normal successor path. Each revised or successor version requires its own Supplier confirmation. This plan does not add a command that removes `SupplierConfirmation` and resumes editing.

### Revise a confirmed agreement before first activation

`CreateSupplierArrangementSuccessor` cannot correct a Supplier-confirmed initial draft. It requires an active Arrangement, an activated governing predecessor, and no existing draft. A never-activated version also cannot become `superseded`: that status is only for a version that has been activated.

This plan adds one explicit revision command. It is part of this plan, not Hotel Lifecycle. Without it, a transcription mistake after confirmation has no ordinary correction. Abandoning the Arrangement and rebuilding it is not that correction.

The command is atomic. It runs only when all of the following are true:

- the Departure is active;
- the Arrangement is still `draft` and has no governing version;
- the exact version is the sole draft, includes a lodging Item, and already has a `SupplierConfirmation`;
- the actor has `manage_departures`.

In one transaction it:

1. Copies that version’s definition graph into a new draft version, using the same copy lineage as a successor. The copy includes stay, inventory, rates, deposits, Deadlines, agreement references, and Reviewed — none absences.
2. Does not copy `SupplierConfirmation`. The new draft is not confirmed.
3. Marks the confirmed version `abandoned`, with a required reason and `abandoned_at`. It does not mark the Arrangement abandoned. `AbandonSupplierArrangement` remains the command that discards a never-activated Arrangement.
4. Records an audit event for the revision. The abandoned version and its confirmation stay readable historical evidence.

After the command, only the new draft can be edited. The abandoned version cannot be activated. The new draft cannot be activated until Staff record a new `SupplierConfirmation` for it. A second revision repeats the same command against that later confirmed draft.

First activation of the revised draft stays the first activation of the Arrangement, not a successor activation. `ActivateSupplierArrangementVersion` accepts that sole draft when its `copied_from` version is an abandoned, never-activated, Supplier-confirmed version of the same still-draft Arrangement. An ordinary first draft, with no `copied_from`, is unchanged. A draft copied from an activated governing version remains the existing successor path. Cruise and non-lodging Arrangements are unchanged.

The Hotel review offers this revision only for a Supplier-confirmed lodging draft that has not been activated. It does not create a post-activation successor.

Activation of a Hotel version passes `existing_confirmation_id` and does not collect a second evidence form. The generic activation command still creates evidence when no confirmation exists, except for the lodging check in §8.

Hilton proof: the group or confirmation number may be blank. Staff record the evidence date and the reason the identifier is absent. That evidence date remains distinct from the unspecified original contract date.

### Activation

The Hotel post calls `ActivateSupplierArrangementVersion` for the exact draft. It does not add a Hotel activation command.

Activation still does not post a Supplier payment, a guest folio, an attrition charge, a refund, or a Client Trip. It does not create a Service Offer or connect a Client Service.

---

## 6. Reviewed — none

Every Hotel agreement-reference kind may be either recorded wording or an explicit statement that Staff reviewed the permitted scope and no clause of that kind exists.

The seven kinds are:

- `deposit_derivation`
- `attrition`
- `deposit_refund`
- `destination_fee`
- `additional_nights`
- `early_departure`
- `cancellation`

The three Item kinds — `deposit_derivation`, `attrition`, and `deposit_refund` — remain **this Hotel stay** only. They do not gain agreement-wide scope. The other four kinds may use the existing Item or agreement-wide scope.

No absence is inferred from silence. Missing wording with no absence remains **Not reviewed** and blocks Supplier confirmation. This plan still does not add a reviewed-none fact for a Deposit or a Deadline.

### Scope

An absence uses the same scope allowed for the reference it replaces. The three Item kinds are Item-scoped only; the four other kinds may be Item-scoped or agreement-wide.

**This Hotel stay**

```text
version + arrangement_item + kind
```

**Entire Supplier agreement**

```text
version + kind
arrangement_item = nil
```

The scope invariant applies to references and absences together:

- a kind uses either agreement-wide scope or Item scope on one version, never both;
- at one Item and kind, either wording or Reviewed — none, never both;
- different Hotel Items may have different Item-scoped outcomes;
- an agreement-wide reference or absence applies to every Item on the version;
- a successor copy preserves that scope and lineage.

Hotel Item A can have destination-fee wording while Hotel Item B on the same version has Reviewed — none for destination fee. An agreement-wide destination-fee reference or absence covers both Items, and neither Item then records a separate outcome for that kind.

### Persistence

Do not store an empty `SupplierAgreementReference`. Do not add a `none` kind to that catalog.

The smallest record is one absence:

- it belongs to the Agency, the Departure, the Arrangement, and the exact version;
- `kind` is one of the seven Hotel agreement-reference kinds;
- it has no wording;
- Item scope names the Arrangement Item; agreement-wide scope leaves that Item null;
- one Item-scoped absence per version, Item, and kind;
- one agreement-wide absence per version and kind.

Record and remove the absence only on the unconfirmed editable draft, through an explicit command. Confirmation makes the absence immutable, same as agreement-reference wording.

A successor copies each absence and keeps lineage and scope. Deleting a copied absence on the successor blocks that successor’s activation until the copy exists again, matching the copied-reference rule.

### Display for this Item

Resolve each agreement-wide-capable kind in this order:

1. Agreement-wide wording for that kind.
2. Agreement-wide Reviewed — none for that kind.
3. Wording recorded on this Item.
4. Reviewed — none recorded on this Item.
5. Not reviewed.

| Resolved fact | Label |
| --- | --- |
| Wording at the winning scope | The recorded governing wording |
| An absence at the winning scope | Reviewed — none |
| Neither | Not reviewed |

Not reviewed and Reviewed — none stay distinct. Reviewed — none is not a warning. Not reviewed blocks Supplier confirmation. Another Item’s wording or absence does not satisfy this Item. For the three Item-only kinds, resolve only this Item's wording, this Item's Reviewed — none, then Not reviewed.

Hilton proof: no separate cancellation schedule is an Item-scoped **Reviewed — none** for `cancellation` on the Hilton stay. Destination fee, additional nights, and early departure are recorded wording on that stay. The three Item kinds are recorded wording. None of those rows is an empty reference.

---

## 7. Required versus optional

### Required before Supplier confirmation

- The Stay shape is supported.
- The nightly inventory shape is supported.
- Each inventory night has one complete supported contracted Hotel rate shape. A ready estimate does not qualify.
- Every Deposit relevant to this Item, when any exists, is a supported thin Deposit. Zero Supplier deposits is valid and is displayed as **No Supplier deposits recorded**.
- Every recorded Hotel Deadline, when any exists, is assigned to a Hotel scope and uses the supported shape. An unassigned generic Deadline is Advanced for the typed Hotel path.
- All seven Hotel agreement-reference kinds are explicitly reviewed as wording or **Reviewed — none** at their permitted scope.
- No Hotel section is Advanced.

An unassigned Deposit stays off the schedule and blocks the typed Hotel confirmation path until Staff assign it or resolve it in Advanced Supplier planning. The review does not backfill coverage.

The Hilton proof requires its three fixed amounts $415.60, $1,870.20, and $1,870.20. That is fixture proof, not a universal Hotel Deposit requirement.

### Additional requirements before activation

- A `SupplierConfirmation` exists for this exact version.
- Generic `SupplierArrangementActivationReadiness` is ready, including copied references/absences and operational requirements.
- Each inventory night selects a ready contracted Supplier-cost definition. A provisional estimate never clears the typed Hotel activation gate.
- The typed Hotel review has proved the constrained Hotel shape before it supplies the existing generic cost-source and commitment-trigger coverage acknowledgements to `ActivateSupplierArrangementVersion`.

### Deadlines

A rooming-list Deadline is not required for every lodging Item. The Hilton proof records one supported thin `rooming_list_due` Deadline on October 3, 2027, at 5:00 p.m. America/New_York.

When this Item has a rooming-list Deadline, that Deadline must be a supported thin shape. An unsupported Deadline is Advanced and blocks the Hotel post.

When this Item has no rooming-list Deadline, the review says that none is recorded. That display is not **Reviewed — none**, and it is not a blocker. Silence does not mean Staff reviewed the agreement and found no cutoff. This plan does not add an absence fact for a Deadline.

### Optional

All seven Hotel agreement-reference kinds require an explicit review outcome before Supplier confirmation. Recorded wording and **Reviewed — none** are both sufficient at the kind's permitted scope. **Not reviewed** is incomplete. The three Item-only kinds remain this-stay-only; the other four retain Item or agreement-wide scope.

### Forecast readiness

Ready means the existing `forecast_ready` cost-definition status and `MarkCostDefinitionForecastReady` remains the only transition to it.

The typed Hotel rate save supplies the generic forecast inputs needed by the supported Hotel shape instead of asking Staff to operate generic cost planning. For each supported contracted room-night definition it creates or reuses the Item/Occurrence/Resource usage assumption, records `expected_billable_nights = 1`, and owns exactly one anonymous profile labeled `Contracted rooms`. That profile repeats one anonymous `Hotel guest` participant category across occupancy positions `1..maximum_occupancy` for that room category, with `resource_unit_count` equal to the current blocked-room quantity. The save then calls `MarkCostDefinitionForecastReady` with provenance `Hotel contracted rate workspace`.

Do not weaken `validate_ready!`. A later consequential rate edit returns the definition to working through the existing cost command behavior; after the Hotel save restores a complete supported shape, the Hotel path recreates/reuses the required usage inputs and marks it ready again. The typed room-inventory editor keeps both the Hotel-owned profile's blocked-room quantity and its anonymous position list synchronized when room quantity or maximum occupancy changes. A second profile, a renamed `Contracted rooms` profile, or another occupancy shape is Advanced Supplier planning and is not silently overwritten.

A ready estimate may be displayed, but it never clears the typed Hotel activation gate and the Hotel path never auto-acknowledges provisional costs.

---

## 8. Post gate and generic readiness

`SupplierArrangementActivationReadiness` remains the activation authority. The Hotel post gate is not a second readiness predicate. It says only whether this review can post the existing activation command. The Cruise review uses the same split: `cruise_post_allowed?` does not replace generic readiness.

### Lodging confirmation check

Confirmation before activation is the same kind of fact Cruise already enforces for a Cruise Item. A lodging Item adds one check to `SupplierArrangementActivationReadiness`: the exact version has a `SupplierConfirmation` before it can be ready. The blocker is lodging-scoped. A Cruise Item keeps `cruise_agreement_unconfirmed`. An Arrangement with neither a lodging Item nor a Cruise Item is unchanged.

The Hotel post still passes the existing confirmation into activation. The generic activation screen does not ask for new Hotel evidence when that confirmation already exists.

### Hotel activation gate

The Hotel activation post is allowed only when all of the following are true:

- the version is the editable draft;
- the review’s Item is lodging and the shapes in §7 are supported;
- no section on the review is Advanced;
- the required facts in §7 are present;
- for this Item, every optional kind resolves to wording or Reviewed — none;
- generic readiness has no blockers;
- the selected cost authority for each inventory night is a ready contracted definition.

These Hotel gaps block the Hotel button. They are not added to `SupplierArrangementActivationReadiness`, except the lodging confirmation check above. This plan does not change readiness for a Cruise Arrangement or for an Arrangement that is not lodging.

The generic activation route remains the Advanced path. It can still activate a lodging version that fails a Hotel-only gate when generic readiness is otherwise ready and the lodging confirmation exists. The Hotel review does not post in that case, and it names the Hotel blocker.

---

## 9. Blockers versus warnings

The review lists blockers in Hotel language and links each one to the Agreement editor or the generic screen that can address it.

Blockers:

- unsupported stay, inventory, deposit, Deadline, or rate shape;
- a missing stay or nightly inventory;
- a working contracted rate, or a ready estimate used as the only authority;
- an unassigned, incomplete, or unsupported relevant Deposit; zero relevant Deposits is valid;
- any Hotel agreement-reference kind that remains Not reviewed;
- Supplier confirmation not yet recorded when evaluating activation;
- after confirmation, a generic activation-readiness blocker, including a missing successor copy of a reference or an absence.

Not blockers and not warnings:

- recorded optional wording;
- Reviewed — none for this Item;
- no rooming-list Deadline;
- a supported thin rooming-list Deadline when the agreement has one;
- blank Supplier group or confirmation number when the confirmation states why;
- blank original contract date;
- quoted tax, attrition exposure, or a refund amount that this product does not calculate.

The normal Hotel UI does not expose generic **cost-source coverage** or **commitment-trigger coverage** acknowledgement language. The typed Hotel activation post supplies those two existing generic acknowledgement values internally only when the exact version is entirely within the constrained Hotel shape: every retained Item is lodging, every lodging Item passes the typed Hotel review, every inventory night has one supported contracted source, there is no arrangement-wide Supplier cost source outside those Hotel matrices, relevant Deposits and Deadlines are scoped and supported, no Hotel section is Advanced, and no generic Supplier commitment-trigger definitions exist. A mixed Hotel/non-Hotel Arrangement or a version with generic commitment triggers uses **Advanced Supplier planning** for activation instead of silently auto-attesting to facts the Hotel workflow did not review.

It does **not** auto-acknowledge provisional estimates. `provisional_costs_acknowledged` stays false; an estimate keeps typed Hotel activation blocked.

The elapsed-date acknowledgement is shown only when activation preview finds an already-elapsed Hotel Deposit or Deadline occurrence, and the UI names the affected Hotel date instead of displaying an unconditional generic checkbox.

---

## 10. Access

A Viewer with `view_departures` can open the review and read every section, including wording and confirmation evidence.

Confirmation and activation require `manage_departures`. Denial matches the other Composition management routes: an authenticated Viewer is redirected. The review does not reveal a second permission model.

Another agency’s departure, arrangement, version, or item identifier returns not found.

The review shows one version. An explicit `version_id` must belong to the Arrangement. Otherwise the page uses the editable draft when one exists, then the governing version.

---

## 11. After activation

The governing activated version is read-only on the Agreement page. The Hotel agreement-defining records in §5 are already frozen when Supplier confirmation is recorded, before this activation step. Confirmation reads **Supplier confirmed**. Activation reads **Activated**. Those labels stay separate.

The Hotel review no longer offers confirmation or activation for that version.

Creating a successor after activation stays the existing explicit successor action. This review does not create that successor. A proposed successor is Hotel Lifecycle. Before first activation, the revision command in §5 is how Staff correct a Supplier-confirmed draft.

---

## 12. Interface

The review uses the existing administration page, panel, button, and field anatomy in the [interface contract](../../ui/interface-contract.md). It introduces no new color, type, or status system.

Status is text plus the existing state treatment. Color is not the only signal. The page keeps a skip link, visible focus, and keyboard access to the confirmation action, the activate action, and every blocker link. The post actions are real buttons, disabled in text when the gate is closed, not by color alone.

---

## 13. Hilton proof

On the Hilton Fort Lauderdale Marina stay, a passing review shows, without writing operational records:

- November 4–6 stay;
- November 4 inventory 5 Standard / 2 Deluxe and November 5 inventory 10 Standard / 5 Deluxe;
- ready contracted Single/Double/Triple/Quad rates and **Contracted** on the rate section;
- deposits $415.60, $1,870.20, and $1,870.20 on the stay schedule;
- one rooming-list Deadline on October 3, 2027, at 5:00 p.m. Eastern, because this scenario has one;
- governing refund wording, with the original nonrefundable sentence still visible;
- Item-scoped **Reviewed — none** for cancellation on this stay;
- Supplier confirmation recorded, evidence date distinct from the blank original contract date, identifier absent with a reason.

Only then does Staff record confirmation. After that confirmation, a change to the stay, a room quantity, a rate, a deposit, the rooming-list Deadline, agreement wording, or Reviewed — none is rejected, and the same confirmation remains. Revising that confirmed draft keeps the confirmation on an abandoned version and opens a new unconfirmed draft copied from it. The abandoned version cannot activate. The new draft activates only after its own Supplier confirmation. Staff then activate. The governing Agreement page is read-only. No payment, folio, attrition charge, refund, or Client Trip exists because of that activation.

A second Hotel Item on the same version does not change the Hilton Item’s room nights, deposits, rates, or agreement wording. That second Item may record a different Item-scoped outcome for an optional kind, including Reviewed — none where the Hilton stay has wording.

A lodging Item with no rooming-list Deadline still passes this review when the other required facts are present.

---

## 14. Exit

This plan is accepted. Implementation is complete when:

- the review is write-free and uses the Agreement workspace;
- Staff can record `SupplierConfirmation` on the unconfirmed draft without activating, and only when §5’s confirmation gate passes;
- that confirmation freezes the Hotel agreement-defining records in §5, including stay, inventory, rates, deposits, Deadlines, agreement references, and absences;
- a later edit of a frozen fact is rejected on that version and is not repaired by replacing or fingerprinting the confirmation;
- before first activation, revising a Supplier-confirmed lodging draft abandons that version, retains its confirmation, and creates one editable unconfirmed copy;
- the abandoned confirmed version cannot activate, and the revised draft activates only as the Arrangement’s first activation after its own confirmation;
- an optional-kind absence is Item-scoped or agreement-wide under the same scope invariant as optional references;
- all seven Hotel agreement-reference kinds can be wording or Reviewed — none at their permitted scope, and Not reviewed remains distinct;
- a missing rooming-list Deadline is not a blocker and is not labeled Reviewed — none;
- the Hotel post calls the existing activation command only when §8 allows it;
- a lodging version without confirmation is not generically ready;
- Cruise and non-lodging activation behavior is unchanged, except that a revised lodging draft may be the Arrangement’s first activation when it was copied from an abandoned confirmed draft;
- a Viewer can read and cannot confirm or activate;
- another agency’s identifiers return not found;
- the Hilton proof in §13 passes;
- the governing version is read-only after activation;
- no successor is created by the review.

---

## 15. Explicitly out

- Hotel Lifecycle, including successor proposed presentation
- Transportation
- M4E
- a Client Service connection or Service Offer
- document storage
- an attrition, refund, or folio calculator
- empty `SupplierAgreementReference` rows
- reviewed-none for deposits or Deadlines
- a confirmation fingerprint, in-place invalidation, or a command that removes `SupplierConfirmation` to resume editing
- a change to generic activation meaning for Cruise or for an Arrangement that is not lodging, beyond the first-activation case in §5 for a revised lodging draft


---

## Amendment — 2026-10-02 Hotel workflow simplification

Implementation of the first accepted Review and Activation contract exposed that treating confirmation as “generic activation readiness except confirmation” reintroduced generic M3 workflow into the normal Hotel path. This amendment is authoritative over conflicting earlier wording in this document.

The remediation is not complete, and this capability must not be marked Shipped, until both of these end-to-end proofs pass without opening generic Supplier planning:

1. the Hilton fixture, including its three Deposits, October 3 rooming-list Deadline, explicit agreement review, Supplier confirmation, and activation; and
2. a simpler Hotel with no Supplier deposits, no rooming-list Deadline, and explicit **Reviewed — none** outcomes where clauses do not exist.

Additional implementation invariants:

- schema changes that amend already-created Hotel Review tables/functions ship in a new forward migration; previously applied migration versions are not relied on to rerun;
- command lock order remains Agency → Departure → Arrangement → Version;
- the PostgreSQL lodging freeze must recognize Item-, Occurrence-, Resource-, and Pool-scoped Deposit/Deadline coverage on both coverage links and their parent definitions;
- wording-versus-absence and Item-versus-agreement-wide exclusivity remain serialized at the exact version;
- the shared version graph copier, confirmation freeze, and pre-activation revision remain in force;
- Hotel Lifecycle remains Not authorized.
