# Hotel Review and Activation

**Status:** Accepted 2026-10-01  
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

A `SupplierConfirmation` for the version already freezes that version’s agreement references. This plan keeps that rule. After confirmation, Staff cannot insert, update, or delete agreement references or the absence facts in §6. Operational stay, inventory, rate, deposit, and Deadline edits remain governed by their existing draft rules. This plan does not add a new freeze to those operational records beyond what activation already imposes.

Activation of a Hotel version passes `existing_confirmation_id` and does not collect a second evidence form. The generic activation command still creates evidence when no confirmation exists, except for the lodging check in §8.

Hilton proof: the group or confirmation number may be blank. Staff record the evidence date and the reason the identifier is absent. That evidence date remains distinct from the unspecified original contract date.

### Activation

The Hotel post calls `ActivateSupplierArrangementVersion` for the exact draft. It does not add a Hotel activation command.

Activation still does not post a Supplier payment, a guest folio, an attrition charge, a refund, or a Client Trip. It does not create a Service Offer or connect a Client Service.

---

## 6. Reviewed — none

Optional agreement-reference kinds may be either recorded wording or an explicit statement that Staff reviewed that scope and no clause of that kind exists.

Those kinds are:

- `destination_fee`
- `additional_nights`
- `early_departure`
- `cancellation`

Item kinds stay wording:

- `deposit_derivation`
- `attrition`
- `deposit_refund`

This plan does not add a reviewed-none fact for an Item kind, a deposit, or a Deadline.

### Scope

An absence uses the same scope as the optional reference it replaces.

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
- `kind` is one of the four optional kinds;
- it has no wording;
- Item scope names the Arrangement Item; agreement-wide scope leaves that Item null;
- one Item-scoped absence per version, Item, and kind;
- one agreement-wide absence per version and kind.

Record and remove the absence only on the unconfirmed editable draft, through an explicit command. Confirmation makes the absence immutable, same as agreement-reference wording.

A successor copies each absence and keeps lineage and scope. Deleting a copied absence on the successor blocks that successor’s activation until the copy exists again, matching the copied-reference rule.

### Display for this Item

Resolve each optional kind in this order:

1. Agreement-wide wording for that kind.
2. Agreement-wide Reviewed — none for that kind.
3. Wording recorded on this Item.
4. Reviewed — none recorded on this Item.
5. Not recorded.

| Resolved fact | Label |
| --- | --- |
| Wording at the winning scope | The recorded governing wording |
| An absence at the winning scope | Reviewed — none |
| Neither | Not recorded |

Not recorded and Reviewed — none stay distinct. Reviewed — none is not a warning. Not recorded on this Item blocks the Hotel post for that optional kind. Another Item’s wording or absence does not satisfy this Item.

Hilton proof: no separate cancellation schedule is an Item-scoped **Reviewed — none** for `cancellation` on the Hilton stay. Destination fee, additional nights, and early departure are recorded wording on that stay. The three Item kinds are recorded wording. None of those rows is an empty reference.

---

## 7. Required versus optional

### Required before the Hotel post

- The stay shape is supported.
- The nightly inventory shape is supported.
- Each inventory night has one ready contracted Supplier-cost definition. A working definition does not qualify. A ready estimate does not qualify.
- The deposits on this Item’s schedule are supported thin deposits. The Hilton proof is the three fixed amounts $415.60, $1,870.20, and $1,870.20.
- The three Item reference kinds have governing wording on this Item.
- For this Item, each optional kind resolves to governing wording or Reviewed — none.
- A `SupplierConfirmation` already exists for this exact version.
- Generic `SupplierArrangementActivationReadiness` is ready, including a copied absence or copied reference where the predecessor had one.

An unassigned deposit stays off the schedule. It still blocks the Hotel post until Staff assign it or the generic editor holds it as an Advanced shape. Advanced blocks the post either way. The review does not backfill coverage.

This plan does not require a particular deposit count for every lodging Item. The Hilton proof requires those three amounts. Another lodging Item posts when every deposit on its schedule is a supported thin deposit.

### Deadlines

A rooming-list Deadline is not required for every lodging Item. The Hilton proof records one supported thin `rooming_list_due` Deadline on October 3, 2027, at 5:00 p.m. America/New_York.

When this Item has a rooming-list Deadline, that Deadline must be a supported thin shape. An unsupported Deadline is Advanced and blocks the Hotel post.

When this Item has no rooming-list Deadline, the review says that none is recorded. That display is not **Reviewed — none**, and it is not a blocker. Silence does not mean Staff reviewed the agreement and found no cutoff. This plan does not add an absence fact for a Deadline.

### Optional

Destination fee, additional nights, early departure, and cancellation are optional in the sense that wording is not required when Reviewed — none is recorded for this Item. They are not optional to leave as Not recorded.

A recorded optional term and Reviewed — none are both sufficient. Neither is a warning.

### Forecast readiness

Ready means the existing `forecast_ready` cost-definition status. This plan does not mark a definition ready, does not add usage assumptions, and does not change the Hotel rate editor. Until each inventory night has one ready contracted definition, the Hotel post stays blocked and the rate section stays short of **Recorded** / **Contracted**.

---

## 8. Post gate and generic readiness

`SupplierArrangementActivationReadiness` remains the activation authority. The Hotel post gate is not a second readiness predicate. It says only whether this review can post the existing activation command. The Cruise review uses the same split: `cruise_post_allowed?` does not replace generic readiness.

### Lodging confirmation check

Confirmation before activation is the same kind of fact Cruise already enforces for a Cruise Item. A lodging Item adds one check to `SupplierArrangementActivationReadiness`: the exact version has a `SupplierConfirmation` before it can be ready. The blocker is lodging-scoped. A Cruise Item keeps `cruise_agreement_unconfirmed`. An Arrangement with neither a lodging Item nor a Cruise Item is unchanged.

The Hotel post still passes the existing confirmation into activation. The generic activation screen does not ask for new Hotel evidence when that confirmation already exists.

### Hotel post gate

The Hotel post is allowed only when all of the following are true:

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
- a missing scheduled deposit or an unassigned deposit;
- a missing Item-kind reference;
- an optional kind that is Not recorded for this Item;
- Supplier confirmation not yet recorded;
- a generic readiness blocker, including a missing successor copy of a reference or an absence.

Not blockers and not warnings:

- recorded optional wording;
- Reviewed — none for this Item;
- no rooming-list Deadline;
- a supported thin rooming-list Deadline when the agreement has one;
- blank Supplier group or confirmation number when the confirmation states why;
- blank original contract date;
- quoted tax, attrition exposure, or a refund amount that this product does not calculate.

The review does not add an acknowledgement that turns a blocker into a warning. Existing generic activation acknowledgements stay on the generic command and are not redesigned here.

---

## 10. Access

A Viewer with `view_departures` can open the review and read every section, including wording and confirmation evidence.

Confirmation and activation require `manage_departures`. Denial matches the other Composition management routes: an authenticated Viewer is redirected. The review does not reveal a second permission model.

Another agency’s departure, arrangement, version, or item identifier returns not found.

The review shows one version. An explicit `version_id` must belong to the Arrangement. Otherwise the page uses the editable draft when one exists, then the governing version.

---

## 11. After activation

The governing activated version is read-only on the Agreement page. Confirmation reads **Supplier confirmed**. Activation reads **Activated**. Those labels stay separate.

The Hotel review no longer offers confirmation or activation for that version.

Creating a successor stays the existing explicit successor action. This review does not create one. A proposed successor is Hotel Lifecycle.

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

Only then does Staff activate. The governing Agreement page is read-only. No payment, folio, attrition charge, refund, or Client Trip exists because of that activation.

A second Hotel Item on the same version does not change the Hilton Item’s room nights, deposits, rates, or agreement wording. That second Item may record a different Item-scoped outcome for an optional kind, including Reviewed — none where the Hilton stay has wording.

A lodging Item with no rooming-list Deadline still passes this review when the other required facts are present.

---

## 14. Exit

This plan is accepted. Implementation is complete when:

- the review is write-free and uses the Agreement workspace;
- Staff can record `SupplierConfirmation` on the unconfirmed draft without activating;
- that confirmation freezes agreement references and absences;
- an optional-kind absence is Item-scoped or agreement-wide under the same scope invariant as optional references;
- optional kinds can be wording or Reviewed — none for this Item, and Not recorded remains distinct;
- a missing rooming-list Deadline is not a blocker and is not labeled Reviewed — none;
- the Hotel post calls the existing activation command only when §8 allows it;
- a lodging version without confirmation is not generically ready;
- Cruise and non-Hotel activation behavior is unchanged;
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
- reviewed-none for deposits, Deadlines, or Item kinds
- a Hotel command that marks a cost definition forecast-ready
- a change to generic activation meaning for Cruise or for an Arrangement that is not lodging
