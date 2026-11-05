# Slice 1 step 3: Arrangements, inventory, rate table, deadlines and tasks

**Status:** Accepted 2026-11-05; build not started. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) build step 3, [ADR 0018](../../adr/0018-arrangement-history-by-dated-adjustment.md) with its spike amendment (D-88), [ADR 0019](../../adr/0019-issued-document-storage.md) as this step amends it, and the decision log entries it cites.

Charter build step 3: arrangements, inventory groups, shells, pools and resources, the supplier rate table, and deadlines that create tasks. It closes **D1** (confirming the Alpha arrangement creates 32 cabin shells and no supplier cost) and **D12** (recorded deadlines create owned tasks that go overdue).

It covers charter workflow steps 3 to 5:
- **Suppliers and arrangements:** SUP-01, SUP-02, SUP-06, SUP-07, SUP-09, SUP-11, SUP-15 to SUP-18.
- **Deadlines and tasks:** SUP-22 to SUP-25, OPS-01 to OPS-05.
- **Inventory:** INV-01 to INV-05, INV-07, INV-09, INV-12, INV-16, INV-38, INV-39.
- **Rate table:** SUP-35, D-75.

Cost lines, schedule lines, amounts due and expected commission are build step 4 (D-85). Holds, allocations and bookings are build step 6. Agreement B's option cutoff is Slice 1b.

## Questions settled for this plan (2026-11-05)

Each was decided as shown in the Decision column. None needs a decision log entry. Question 3 amends ADR 0019, in PR 3a.

| # | Question | Decision |
| --- | --- | --- |
| 1 | **One PR or two.** This is the largest step so far. The charter allows one pull request per step or per demonstration case. | Two PRs. **3a** builds arrangements, inventory, the capacity ledger and the rate table, and closes D1. **3b** builds deadlines, tasks, My tasks and the Departure task panel, and closes D12. 3b depends on 3a's arrangements. |
| 2 | **How much of the capacity ledger.** ADR 0018 keeps the replay, projection, rebuild and reconciliation code and adds an allocations table. Step 3 has no holds or bookings. | Restore the replay and projection engine and recreate the pool, event and projection tables, with no version columns. Supply commands are opening (at confirmation), increase, supplier release and correction. **Defer the allocations table to build step 6**, where holds start, and **defer reconciliation** until a case needs it. Until then shell status is always Available or Returned to supplier. |
| 3 | **What "supplier confirmation recorded" means** (the guard on Confirm). SUP-05 keeps quotes and agreements as evidence, but ADR 0019 doesn't yet authorize supplier document uploads. | Confirmation records the supplier's group or confirmation reference (required), the date the supplier confirmed and an optional note. **Arrangement documents are built in 3a**, with ADR 0019 amended for them. They are in scope through SUP-06, which lists documents among what an arrangement records, and the screen inventory's S-12 row. SUP-05 itself is not cited by the charter and is not implemented as a rule. Attaching one is optional at Confirm. The rules are in "Arrangement documents" below. |
| 4 | **Who owns a deadline's task.** D12 needs owned tasks. Work groups (OPS-11) are out of Slice 1. | The Departure's default task owner (OPS-12), else the user who recorded the deadline. Staff may reassign (S-34). |
| 5 | **Arrangement currency.** FIN-22 gives a Departure one client currency, and FX is out of scope. | An arrangement's currency defaults to the Departure's and must equal it in Slice 1. Payee accounts carry their own currency (SUP-02), but an arrangement's payee account must match. Different currencies wait for the FX slice. |
| 6 | **Who sees and edits what** (ACC-30, ACC-31). | New catalog actions. Viewing arrangements, inventory, deadlines and tasks is baseline. Editing arrangements, inventory and deadlines needs **Supplier arrangements**. Viewing or editing the rate table (supplier cost and commission) needs **Departure management, Supplier arrangements or Financial records** to view, and **Supplier arrangements** to edit. Completing, waiving and starting tasks is baseline (ACC-30: "use tasks"). Reassigning a task needs Departure management. |
| 7 | **How the fixture hotel is shaped.** The charter lists Nov 5 as room shells, Nov 4 as "a limited group" and Nov 1–3 on request. | Each room type and night is its own inventory group (INV-01, INV-13). Nov 5 Garden Queen and Harbor Double are unit shells (4 and 4). Nov 4 Garden Queen and Harbor Double are firm capacity pools (2 and 1). Nov 1, 2 and 3 for each room type are On request pools with no numeric balance (6 groups). That's 10 hotel groups. |
| 8 | **The excursion.** INV-16 and D-71 sell it per resource. | One group, represented as unit shells, with one shell of 10 positions created at confirmation. A capacity rule marks Child 0–4 as taking part without using a position (INV-39). The second resource is a dated increase in Slice 1b (D7). |

## 3a. Arrangements, inventory, capacity ledger and rate table (D1)

### Payee accounts (SUP-02)

- New `payee_accounts`: supplier, name, currency, payment instructions as free text. A supplier has one or more. They're managed on the supplier page (S-11) by anyone who may manage the supplier directory.

### Arrangements (SUP-06, SUP-07, SUP-09 to SUP-11, SUP-16 to SUP-18)

- New `supplier_arrangements`: agency, Departure, supplier, payee account (optional until confirmation), status, currency, group or confirmation reference, reservation scope (`arrangement`, `per_unit`, `none`; SUP-10), obligation shape (`per_unit_used`, `committed_quantity`, `fixed_resource_charge`, `minimum_pickup`, `mixed`; SUP-16), default availability promise, covered services and dates as text, plain-language terms (SUP-18), confirmation date and note, and lock version.
- Status is `draft`, `confirmed`, `closed` or `cancelled` (SUP-11), checked in the database. Slice 1 builds create, edit while Draft, Confirm and Discard. Cancelling a confirmed arrangement and Closed (at reconciliation) come in later steps.
- **Draft** saves with required fields missing (D16 at step 6). Draft groups, terms and the rate table are edited in place with audit (ADR 0018).
- **Confirm** is one atomic command (ADR 0018):
  1. It needs a group or confirmation reference, a payee account, at least one inventory group, and service dates on every group.
  2. It records the confirmation date and note.
  3. It freezes the rate table rows.
  4. It creates unit shells and capacity pools, each with an opening inventory event.

  It records **no supplier cost** (D-75); build step 4 adds cost lines.
- **Discard** moves a Draft to Cancelled with no supplier or financial effect. In 3b it also waives open deadline tasks (SUP-23).
- An arrangement's Departure must not be Departed, and its currency equals the Departure's (question 5).

### Arrangement documents (SUP-06, S-12, ADR 0019 amendment)

- **What they are:** supplier quotes, agreements and confirmations kept with the arrangement as evidence. A document records its arrangement, a kind (quote, agreement, confirmation, other), an optional description, who uploaded it and when, and its SHA-256. The file lives in Active Storage, the same as the logo.
- **Accepted files:** PDF, PNG, JPEG, Word (.docx) and Excel (.xlsx), up to 20 MB. The type is checked against the file bytes, not only the name or the browser's label. Macro-enabled Office files (.docm, .xlsm) and legacy .doc and .xls are refused.
- **Who:**
  - Viewing and downloading needs Departure management, Supplier arrangements or Financial records, because agreements usually show supplier cost (ACC-31). Resellers never.
  - Uploading needs Supplier arrangements.
  - Any document can be uploaded before or after Confirm.
- **Removal:** staff with Supplier arrangements may remove a document at any time, Draft or Confirmed. Each removal is audited with the file's name, kind and SHA-256, and the file is purged. (This was chosen over keeping confirmed evidence permanently.)
- **Downloads:** they go through an authorized controller that loads the document through `Current.agency`, checks the permission and the stored SHA-256, and returns not found for other agencies (ADR 0019). Word and Excel files are always sent as downloads, never shown in the browser. PDFs and images display sandboxed.
- **ADR 0019 amendment:** it records these rules as the first authorized upload, alongside the logo. The rules are allowed types, size, access, removal, audit, the SHA-256 check and download handling. Active Storage's framework routes stay off.

### Inventory groups (INV-01 to INV-05, INV-07, INV-09, INV-12, INV-16, SUP-15)

- New `inventory_groups`: arrangement, label, service category (INV-12's list: hotel, all-inclusive resort, cruise, air, rail, transportation, activity, meal, insurance; not the supplier directory's categories), representation (`unit_shells`, `capacity_pool`, `none`), availability promise (`firm_block`, `releasable_block`, `courtesy_option`, `on_request`, `rate_only`), quantity at confirmation, maximum occupancy (positions per shell), service start and end as local date and time with an IANA zone (defaulting from the Departure), and position.
- The representation defaults from the service category (INV-12), and staff may change it while Draft. On request and Rate only groups store no quantity and show no balance (INV-04).
- New `capacity_rules`: group, traveler type, `uses_capacity` false. This is how Child 0–4 takes part in the excursion without a position (INV-39).
- Descriptive edits after confirmation are in place with audit. Structural edits after confirmation are refused in step 3; replacement inventory comes when a case needs it (INV-32).

### Shells and the capacity ledger (INV-05, INV-10, INV-26, INV-38, ADR 0018)

- New `unit_shells`: group, label (C01 to C08 and so on), positions, supplier unit assignment (blank until known; INV-06). Created only at confirmation (SUP-12).
- Recreated `capacity_pools`, `capacity_events` and `capacity_projections`, keyed to the inventory group, with no version columns. The append-only, non-numeric refusal, zone and owner triggers carry over (ADR 0018 spike amendment).
- Restored from tag `pre-m3-m4-deletion`: `CapacityTimelineReplay` and `CapacityProjectionRefresher` unchanged, and `RebuildCapacityProjection` and `RefreshDueCapacityProjection` without version lookups. `CapacityCommandSupport` is rewritten with the lock order agency, Departure, arrangement, then the pool row last.
- Supply commands are `IncreaseCapacity`, `RecordSupplierRelease` and `CorrectCapacity`. An agency-initiated reduction below active allocations is refused, though there are none until step 6. A future-dated adjustment applies at 11:59 p.m. agency time on its date, with the zone snapshotted (D-88).
- A shell group's opening event records how many shells were created. Returning a shell to the supplier is a shell-level event. Shell status is derived (INV-38): Available or Returned to supplier until step 6 adds allocations.

### Supplier rate table (SUP-35, D-75)

- New `supplier_rate_lines`: arrangement, inventory group, occupancy position (1st guest, 2nd, 3rd and so on, plus single), traveler type (optional), and amounts in minor units in the arrangement currency. The amounts are base fare, non-commissionable fees, taxes, discount, and a commission rate or amount as staff enter them.
- Rows freeze at confirmation and are never updated or deleted afterwards. A later change is a new row with an effective date that names the row it supersedes (ADR 0018). Step 3 builds the Draft editor and the freeze. Effective-dated replacement comes with the first case that changes a rate.
- Nothing is derived from the table in step 3. Build step 6 proposes cost and commission at booking confirmation (SMN-02, SMN-32).

### Screens

- **S-11 Supplier directory and detail:** the existing pages plus a payee accounts panel.
- **S-12 Arrangement detail:** status, reference, reservation scope, obligation shape, terms, inventory groups, documents (upload, download, remove), and Confirm or Discard. It hosts the rate table (S-14).
- **S-13 Arrangement form:** create and edit, saving as Draft with fields missing.
- **S-14 Supplier rate table:** a matrix of inventory group by occupancy position. It's visible only with the permissions in question 6.
- **S-17 Departure inventory:** the Departure's Inventory tab. Groups by category with their promise, shells as a grid with derived status, and pool quantity or "On request".
- **S-18 Inventory group detail:** shells or pool, capacity rules by traveler type, and the inventory event history.
- The Departure tab bar gains **Inventory** and **Suppliers** (the arrangements list).

### Alpha fixture

`AlphaFixture.load!` adds:
- **Alpha Cruises:** one payee account and one arrangement under Agreement A. It has four cabin groups (V01, O01, I01 with 3 positions, and S01 with 4), 8 cabins each, a rate table from the Alpha rate schedule (B6, read from the source document during the build), and confirmation, which creates 32 cabin shells.
- **Sablewater Harbor Hotel:** one arrangement with the 10 groups in question 7, confirmed.
- **Shore Excursions Group:** one arrangement with the excursion group, one 10-position resource shell and the Child 0–4 capacity rule, confirmed.

### D1

`test/system/demonstration/d1_test.rb` replaces its skip with these steps:
1. Load the fixture up to the Draft Alpha arrangement and check that no shells exist.
2. Confirm it through the screen.
3. Check that 32 shells now exist (8 per category, with 3, 3, 3 and 4 positions), that every shell is Available, and that no supplier cost record exists (D-75).

## 3b. Deadlines and tasks (D12)

### Supplier deadlines (SUP-22 to SUP-25, SET-10)

- New `supplier_deadlines`: arrangement, optional inventory group, type, actionable or informational, description, the supplier's local date with an optional time and its IANA zone, and the resolved instant stored when recorded. The types are SUP-22's: option or release, deposit or payment, names submission, rooming list, ticketing, final count or manifest, cancellation-tier cutoff, other.
- A date-only deadline resolves to 11:59 p.m. agency local time (SET-10, SUP-24). Recorded either way, the resolved instant is stored and not recalculated.
- Deadlines can be recorded on Draft or Confirmed arrangements (SUP-23). Changing a deadline updates its task's due date and keeps the history (OPS-04). Cancellation-tier cutoffs default to informational (SUP-22).

### Tasks (OPS-01 to OPS-05)

- New `tasks`:
  - **What it is:** agency, source (`supplier_deadline` or `manual` in step 3), action, due instant with its local date, time and zone.
  - **Who and state:** owner (an agency user), status (`open`, `in_progress`, `completed`, `waived`), and completion note or waiver reason.
  - **Links:** the Departure and the source record.
- **Overdue** is derived from the due instant and `Clock.current`, never stored.
- **Transitions** are the spec's task lifecycle for individual owners: start, complete with a note, waive with a reason, and reopen when the same requirement becomes actionable again. Group claim and hand-back wait for work groups. Each transition is audited.
- An actionable deadline creates its task in the same transaction. An informational one creates none.
- **Discarding a Draft arrangement** waives its open tasks with the reason "arrangement discarded" (SUP-23).
- Completing a task changes no other record (OPS-03). A deadline never releases inventory or pays anyone (SUP-25).

### Screens

- **S-15 Supplier deadlines:** a panel on the arrangement showing each deadline's type, actionable flag, local time and zone, resolved instant and linked task.
- **S-33 My tasks:** the signed-in user's open tasks by due instant, with Overdue shown as text and color. Start, complete or waive with a note.
- **S-34 Departure tasks:** the Departure's Tasks tab, with every task, its source, owner and status, and reassignment.
- Sign-in lands staff on My tasks (S-01) once it exists.

### Alpha fixture

The Agreement A deadlines:
- Alpha Cruises deposit: Nov 1, 2026.
- Alpha Cruises full deposit and names: Mar 1, 2027.
- Alpha Cruises final payment: Aug 1, 2027.
- Excursion final count: Oct 22, 2027 at 11:59 p.m. agency time (B9).
- Excursion payment: due the same day (B13).
- Hotel payment at checkout: Nov 6, 2027 (B14).

Each creates a task owned by the Departure's default task owner.

### D12

`test/system/demonstration/d12_test.rb` replaces its skip with these steps:
1. Load the fixture and check that every actionable deadline has an owned task, including the Oct 22, 2027 final count at 11:59 p.m. America/New_York.
2. Set the clock past Nov 1, 2026 and check that the deposit task shows Overdue while later ones don't.
3. Complete one task with a note and check that it leaves My tasks.

## Not in this step

- **Later in Slice 1:**
  - cost lines, schedule lines, amounts due and expected commission (build step 4);
  - holds, allocations and the allocations table (build step 6);
  - supplier reservations (step 7).
- **Slice 1b:** Agreement B and the option cutoff, and the dated resource increase (D7).
- **Later slices:**
  - supplier agreements copied into arrangements (SUP-04);
  - minimums and count warnings (SUP-26);
  - group benefits;
  - cancelling a confirmed arrangement;
  - work groups and reminders (OPS-09 to OPS-21);
  - reconciliation;
  - Needs attention.

## Tests

- **Model and database:**
  - status, representation, promise and deadline type checks;
  - same-agency keys throughout;
  - shells and pools refused before confirmation;
  - append-only capacity events and frozen rate rows;
  - On request pools refuse numeric events;
  - a stored resolved instant on deadlines.
- **Capacity engine:**
  - the restored replay and projection specs, adapted;
  - a future-dated release applying at 11:59 p.m. agency time;
  - the lock order.
- **Documents:**
  - each accepted type uploads;
  - a renamed executable, a macro-enabled Office file and a file over 20 MB are refused;
  - downloads check the permission and SHA-256;
  - Office files are sent as attachments;
  - removal is audited and purges the file;
  - other agencies get not found.
- **Commands:**
  - Confirm creates exactly the shells and pools, with opening events, and no cost, and is refused when the reference, payee or service dates are missing;
  - Discard waives tasks;
  - each command needs its permission and refuses other-agency records (not found);
  - the rate table is hidden and refused without the ACC-31 permissions.
- **Tasks:**
  - every transition and its guard;
  - overdue at fixed clock times;
  - a deadline change updates the due date and keeps the history;
  - an informational deadline makes no task.
- **System:**
  - D1 and D12;
  - S-12 to S-18, S-33 and S-34 at 1400px and 375px with no page overflow.

## Build order

**PR 3a** (D1), citing SUP-01, SUP-02, SUP-06, SUP-07, SUP-09 to SUP-12, SUP-15 to SUP-18, SUP-35, INV-01 to INV-05, INV-07, INV-09, INV-10, INV-12, INV-16, INV-26, INV-38, INV-39, D-75 and D-88:

1. Payee accounts and the S-11 panel.
2. Arrangements: Draft, edit, Discard, and the catalog actions (question 6).
3. Arrangement documents and the ADR 0019 amendment.
4. Inventory groups and capacity rules.
5. Capacity tables and the restored engine.
6. Confirm: shells, pools and opening events.
7. Rate table and its freeze.
8. Screens S-12 to S-14, S-17 and S-18, the Departure tabs, the Alpha fixture, D1 and docs.

**PR 3b** (D12), citing SUP-22 to SUP-25, OPS-01 to OPS-05, OPS-12 and SET-10:

1. Supplier deadlines and their resolved instants.
2. Tasks and transitions, including the Discard waiver.
3. Screens S-15, S-33 and S-34, sign-in landing, the Alpha fixture deadlines, D12 and docs.
