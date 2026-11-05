# Slice 1 step 2: Departure statuses and Ready to sell

**Status:** Accepted 2026-11-05; build not started. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) step 2, D-90 and D-91.

Charter build step 2: Departure statuses, Ready to sell, publishing to a reseller channel. Workflow step 2 cites DEP-01, DEP-03 to DEP-07 and FIN-22. The charter's scope table limits Slice 1 to Draft, Ready to sell, publishing to one channel, and the operating decision Proceed. No D-case closes in this step. S-08 is the Departure part of D16, which closes in step 6.

## Questions settled for this plan (2026-11-05)

Each recommendation below was accepted. Question 1 is logged as D-90, which amends the charter's build table, and question 2 as D-91, which step 2 records in ADR 0004.

| # | Question | Decision |
| --- | --- | --- |
| 1 | **Publishing.** S-10 publishes an *offering* to a *reseller channel* (DEP-07, D-68). Offerings arrive in build step 5 and reseller relationships can't be created until step 9, so step 2 has nothing to publish. | Move publishing (S-10, offering publication, DEP-07 to DEP-09) to build step 9, the reseller path. Step 2 builds Ready to sell and Return to Draft. Step 9 adds publish and unpublish, plus the DEP-08 withdrawal on return to Draft. Logged as **D-90**. |
| 2 | **When a Departure gets its reference.** The shipped code issues `DEP-` at first activation, so drafts have none (ADR 0004). REF-01 says the records in the references table have a reference, with no draft exception. REF-03 accepts that discarded records keep theirs. | Issue the reference when the Departure is created, and backfill existing drafts in the migration. A Departure always shows its reference, gaps from abandoned drafts are accepted (REF-05), and Ready to sell isn't tied to numbering. Logged as **D-91**; step 2 amends ADR 0004. |
| 3 | **Departure team versus responsible office and user.** S-09 adds the team (ACC-09) and a default task owner (OPS-12). ADR 0016 says the team replaces the responsible office as the routing fact. | Replace both. Drop `responsible_office_id` and `responsible_agency_user_id`; the migration moves each responsible user into the team as its default task owner. The Departure list filters by team member instead. A team is optional for Ready to sell. Team membership grants nothing (ACC-09). |
| 4 | **The shipped M2 lifecycle screens.** Activation, return to draft, mark departed, and the schedule, currency and lifecycle corrections exist because an active Departure restricted edits. The spec has no activation; edits after Ready to sell create review items (DEP-12), which are later scope; and the completion table has no Departed → Active step. | Replace activation with **Mark Ready to sell**, and keep **Return to Draft** with an optional note (the spec's guard is the permission only). Keep **Mark Departed** and the departed sweep until step 11 (D-83). Retire the schedule, currency and lifecycle corrections: the Departure form edits dates, currency and time zone in any non-Departed state, and each save is audited. Once Departed, the Departure is read-only (DEP-43). |
| 5 | **What Ready to sell requires.** DEP-06 says the MVP calculates no viability and blocks nothing automatically. S-10 says it is "refused with reasons if not ready". | Require the fields a sale depends on: name, start and end dates, currency (FIN-22) and time zone, as the shipped activation does today. The refusal lists each missing field with a link to it (UI acceptance). Nothing about capacity, cost or price is checked. |
| 6 | **Itinerary.** DEP-01 lists name, description *and itinerary*. | No itinerary field in step 2. The Alpha fixture's description covers it, and the itinerary is built from services in later steps. Revisit if the documents in step 10 need free text. |

## 1. Three statuses (DEP-03, DEP-04, D-79, D-86)

Replace `departures.status` with three columns, each checked in the database:

| Column | Values | Created as | Slice 1 transitions |
| --- | --- | --- | --- |
| `sales_status` | `draft`, `ready_to_sell` | `draft` | Mark Ready to sell; Return to Draft (DEP-06) |
| `operating_decision` | `undecided`, `proceed`, `postpone`, `cancel` | `undecided` | Record Proceed (charter scope) |
| `completion_status` | `active`, `departed`, `cancelled`, `superseded` | `active` | Mark Departed (staff, and the sweep until step 11) |

- All four decision values and all four completion values are allowed by the database, but Slice 1 offers no way to reach Postpone, Cancel, Cancelled or Superseded. Their summary labels are still derived, so later steps add only the transitions.
- **Summary label** (DEP-04): a method, never stored, applying the spec's table in order. Completion labels come first, then Cancelling and Postponed, then Not on sale and On sale. Reconciled is added in step 11 with the reconciliation record. Sales paused is not built in Slice 1 (D-79), so it is not part of the derivation yet.
- **On sale** (DEP-05): `Departure#on_sale?` is Ready to sell, decision Undecided or Proceed, and completion Active. Steps 6 and 10 call it before any hold or booking. It is a model method with a matching scope, not a column.
- **Ready to sell completeness**: the shipped `departures_activation_completeness` check moves from `status <> 'draft'` to `sales_status = 'ready_to_sell'`, and no longer requires a responsible user (question 3).
- **Departed**: `departed_at` pairs with `completion_status = 'departed'`, as it does with `status` today. A Departed Departure refuses edits, Ready to sell changes and decisions (DEP-43).
- **Migration**: `draft` becomes Draft, Undecided, Active. `active` becomes Ready to sell, Undecided, Active. `departed` becomes Ready to sell, Undecided, Departed. `first_activated_at` is dropped; the audit history keeps when each status changed.

## 2. Operating decision history (DEP-16, DEP-19, DEP-20)

- New `departure_decisions`: `agency_id`, `departure_id` (same-agency composite foreign key), `decision`, `note`, `decided_by_id`, `decided_at`. Append-only: rows reject update and delete in the model and in PostgreSQL, like audit events.
- `RecordDepartureDecision` accepts Proceed only in Slice 1, with an optional note. It needs Departure management, writes the history row, updates `operating_decision` and audits, all in one transaction.
- The overview shows the current decision with who and when, and the history beneath.

## 3. Departure team (ACC-09, OPS-12)

- New `departure_team_members`: `agency_id`, `departure_id`, `agency_user_id`, `default_task_owner` (boolean), timestamps. Unique on Departure and user; a partial unique index allows at most one default task owner per Departure. Same-agency composite foreign keys to both.
- Members are Agency Admins or staff (`AgencyUser.agency_staff`), never reseller users.
- Commands: `AddDepartureTeamMember`, `RemoveDepartureTeamMember`, `SetDepartureDefaultTaskOwner`. Each needs Departure management and is audited against the Departure. Removing the default task owner clears it.
- `CreateDeparture` adds the creating user to the team as the default task owner, the way it sets the responsible user today.
- Team membership never appears in an authorization check (ACC-09).

## 4. Departure form and overrides (DEP-01, S-08)

- Adds two optional overrides: `hold_duration_days` (at least 1) and `installment_buffer_days` (at least 0). Blank means the agency default applies, and the form shows the agency value as the hint. A Departure records an override only when staff enter one; it never copies the agency value (SET-14).
- `Departure#effective_hold_duration_days` and `#effective_installment_buffer_days` return the override or the agency default. Steps 6 and 10 use them.
- The form saves as Draft with dates, currency or time zone missing, as the shipped form already does. A name stays required to save, so every Departure can be found and listed. The form already has the error summary; it gains the unsaved-changes guard from step 1.

## 5. Screens

| Screen | Step 2 content | Left for later steps |
| --- | --- | --- |
| S-06 Departures | Reference, name, dates, summary label (text and color), team default owner; search by reference or name; filter by label and team member | Cabins sold of 32 (step 5), open client balance (step 8) |
| S-07 Departure overview | Header with reference, name, dates and label; the three statuses; identity facts; team panel (S-09); decision with history; Mark Ready to sell or Return to Draft; Record Proceed; Mark Departed when eligible | The four summary panels (steps 5 to 8), the tab bar's other tabs (each added by its step), and the Mark Departed condition (step 11, D-83) |
| S-08 Departure form | Identity, dates, currency, time zone, hold duration and installment buffer overrides | |
| S-09 Departure team | Members, default task owner, add, remove, set owner | |
| S-10 Publish to reseller | Not built (question 1) | Step 9 |

The Departure header and tab bar follow the screen inventory's settled layout: tabs are pages, and at 375px the tab bar scrolls in its own strip. In step 2 the bar has one tab, Overview.

## 6. Code removed or replaced

- Commands: `ActivateDeparture` becomes `MarkDepartureReadyToSell`. `ReturnDepartureToDraft` remains, with its note optional. `UpdateDepartureResponsibility` is replaced by the team commands. `CorrectDepartureSchedule`, `CorrectDepartureCurrency` and `CorrectDepartureLifecycle` are removed (question 4), with their controllers, views, routes and tests.
- `DepartureReferenceIssuance` moves from activation to creation (question 2).
- `SearchDepartures` filters by summary label, using a SQL expression that matches `Departure#summary_label`, and by team member instead of responsible office and user. The `*_query_count_test.rb` and EXPLAIN tests are updated for the new indexes.
- Audit catalog: `departure.activated` becomes `departure.ready_to_sell`. Adds `departure.decision_recorded`, `departure.team_member_added`, `departure.team_member_removed` and `departure.default_task_owner_changed`. Removes `departure.responsibility_changed` and the three `*_corrected` actions.
- `MarkDepartureDeparted` and the departed jobs read and write `completion_status`. Their behavior is unchanged until step 11 (D-83).

## 7. Alpha fixture

`AlphaFixture.load!` keeps Alpha Omega as a draft, adds the creating admin to its team as the default task owner, records Proceed, and marks it Ready to sell, which the fixture's later steps assume. Its reference becomes `DEP-0001` on creation (question 2).

## Not in this step

Publishing and channels (step 9, question 1). Postpone and Cancel decisions, review dates (DEP-17), review items (DEP-12 to DEP-15), the cancellation and postponement workflows, Sales paused (D-79) and reconciliation (step 11). Removal of the departed sweep (step 11, D-83). Work groups (OPS-11).

## Tests

- **Model:** the summary label for every row of the spec's table, including combinations Slice 1 can't reach yet. `on_sale?` for each status combination. The effective override values.
- **Database:** status value checks, Ready to sell completeness, the `departed_at` pairing, same-agency keys and the single default owner for the team, and append-only decisions.
- **Commands:**
  - Ready to sell needs Departure management and lists missing fields. Return to Draft keeps the reference. Proceed is recorded with history.
  - Departed refuses edits and status changes.
  - Team commands refuse reseller users, and refuse users and Departures from another agency (not found).
  - Each successful command writes one audit event.
- **Requests:** staff without Departure management can view but get no mutation controls and are refused server-side. Other-agency Departures return not found.
- **System:** create a Draft with fields missing, complete it, mark Ready to sell, record Proceed, add a team member and set the default owner, return to Draft. S-06 to S-09 at 1400px and 375px with no page overflow.
- **Existing tests:** M2 tests (`m2a_*`, `m2b_*`, `m2_departure_*`) are updated for the three statuses, not deleted. Tests of the retired correction commands are removed with them. The pending D-case tests are unchanged.

## Build order

One pull request, citing DEP-01, DEP-03 to DEP-06, DEP-16, DEP-19, DEP-20, DEP-43, ACC-09, OPS-12, FIN-22, D-79, D-83, D-86, D-90 and D-91:

1. Three status columns, the label and `on_sale?`, with the data migration.
2. Reference issued at creation (D-91), with the ADR 0004 amendment.
3. Departure team, replacing the responsible office and user.
4. Operating decision history and Proceed.
5. Ready to sell and Return to Draft, replacing activation. Remove the corrections.
6. Overrides on the form.
7. Search, list and overview screens (S-06 to S-09), the Alpha fixture, the interface contract and AGENTS.md (invariant 10's Departure wording and the shipped Departure vocabulary), and the planning index.
