# Current application architecture

**Status:** Implemented baseline, as of Slice 1 step 9a

**Scope:** Current application; later commercial domains are excluded

DepartureDesk ships agency identity and administration (ADRs 0005, 0016 and 0017), the M1 client and supplier directories, Departures as reshaped by Slice 1 step 2, and the Slice 1 step 3 supplier layer: payee accounts, supplier arrangements with documents, inventory groups, the capacity ledger, the supplier rate table (ADR 0018), supplier deadlines with the tasks they create, step 4's supplier money: cost lines, schedule lines, trigger events and amounts due; step 5's package offerings with client prices, and client terms; step 6a's travelers, their links to clients, and Client Trips; step 6b's draft bookings with their travelers, choices, price lines and held space; step 6c's acceptances and confirmation, with the client charge, booking supplier cost and expected commission; step 7's supplier reservations; step 8a's installments, client payments, credit, reversals and receipts; step 8b's supplier payments, the balance basis and commission confirmation; and step 9a's reseller relationships, publishing to their channels, and a booking's owner and seller of record. The M3 and M4 layers were deleted in charter Phase 1 (D-66); tag `pre-m3-m4-deletion` holds them, and only the capacity replay and projection code was restored from it. Scope and standing are in the [first-slice charter](../planning/first-slice/first-slice-charter.md) and the [planning index](../planning/README.md).

## Shipped records and authorization catalog

| Record | Current responsibility |
| --- | --- |
| `Agency` | Tenant, workspace-code identity, lifecycle, the one agency time zone, locale defaults, the client-facing profile, footers, hold duration, installment buffer, optional logo (Active Storage, served by `AgencyLogosController`), and ownership root. |
| `Office` | Optional agency-owned assignment and reporting context with no time zone (ADR 0016). It grants no permission. |
| `AgencyUser` | One agency-scoped login account with independent credentials, lifecycle, and user type (`agency_admin`, `staff`, `reseller`). |
| `UserPermission` | A staff user's grant from the five-permission catalog; the database refuses it for any other user type (ADR 0017). |
| `Reseller` | A reseller relationship and its one channel (D-68); `reseller` users belong to one. Staff with Reseller relationships authorize one and set its direct-contact setting (ACC-13, DOC-08). Pause, suspension and ending are not built. |
| `OfferingPublication` | An offering published to one reseller's channel (DEP-07), open until staff withdraw it (DEP-09) or the Departure returns to Draft (DEP-08). Only the withdrawal is written after creation, once; publishing again makes a new row. |
| `AgencyDocumentInclusion` | Per agency and document family, which profile fields and footer a document shows (SET-06, SET-07). |
| `TravelerType` | The agency's ordered traveler types, seeded Adult, Child and Child 0–4 (BKG-21). |
| `Session` | Authentication root and optional current-Office preference. It derives Agency through AgencyUser. |
| `AuditEvent` | Append-only evidence for commands on Agency, AgencyUser, Office, ClientPerson, Client, ClientOrganization, Supplier, SupplierLocation, SupplierContact, Departure, TravelerType, SupplierArrangement, Traveler, ClientTrip, ClientBooking, SupplierReservation, ClientPayment, SupplierPayment and Reseller subjects. Actions and subject types are closed catalogs. |
| `ClientPerson` | Agency-scoped person known to the directory. Not a Client, AgencyUser, or Traveler. |
| `ClientOrganization` | Agency-scoped organization known to the directory. Not a Supplier. |
| `Client` | Explicit commercial identity for exactly one Client Person or Client Organization, with an immutable `CL-` reference. |
| `ClientPersonEmailAddress`, `ClientPersonPhoneNumber`, `ClientPersonPostalAddress` | Person-owned contact points. They are not Agency User credentials. |
| `ClientOrganizationEmailAddress`, `ClientOrganizationPhoneNumber`, `ClientOrganizationPostalAddress`, `ClientOrganizationWebsite` | Organization-owned contact points. |
| `ClientOrganizationContact` | Effective-dated assignment of a Client Person to a Client Organization. Current means `ends_on IS NULL`. |
| `Supplier` | Agency-scoped organization or individual contracting identity, with an immutable `SUP-` reference and fixed category assignments. |
| `SupplierCategoryAssignment` | Required category membership for a Supplier. At least one category; `other_label` only for `other`. |
| `SupplierEmailAddress`, `SupplierPhoneNumber`, `SupplierPostalAddress`, `SupplierWebsite` | Supplier-owned contact points. |
| `SupplierLocation` | Supplier-owned operational place with optional structured address, timezone, and one location-level phone. |
| `SupplierContact` | Named person in one Supplier work context. Not a Client Person or AgencyUser. |
| `SupplierContactEmailAddress`, `SupplierContactPhoneNumber` | Contact-owned destinations. |
| `PayeeAccount` | A supplier's account for payments: name, currency and free-text payment instructions (SUP-02). Managed on the supplier page. |
| `Departure` | Agency-owned dated operational root. Three statuses (`sales_status`, `operating_decision`, `completion_status`) with a derived summary label and `on_sale?` (DEP-03 to DEP-05); a `DEP-` reference issued at creation (D-91); Ready to sell and Return to Draft; Mark Departed and the scheduled departed sweep (until step 11, D-83); optional hold-duration and installment-buffer overrides. Travel Program is not implemented. |
| `DepartureTeamMember` | A staff user on a Departure's team, optionally its default task owner (ACC-09, OPS-12). Grants nothing. |
| `DepartureDecision` | Append-only operating decision history: value, who, when, note (DEP-19). |
| `SupplierArrangement` | One supplier's arrangement for one Departure, with an `ARR-` reference and no versions (ADR 0018). Status `draft`, `confirmed`, `closed` or `cancelled` (SUP-11); one live arrangement per supplier per Departure. Its currency equals the Departure's. Draft is edited in place; Confirm and Discard are commands. Slice 1 builds create, edit, Confirm and Discard. |
| `ArrangementDocument` | A supplier quote, agreement, confirmation or other document kept with an arrangement, with its SHA-256 and the file in Active Storage (ADR 0019 as amended). Downloads go through `ArrangementDocumentsController`. |
| `InventoryGroup` | The smallest part of an arrangement with its own availability (INV-01): service category, representation (`unit_shells`, `capacity_pool`, `none`), availability promise, quantity, positions per unit, and local service dates with an IANA zone. Structural fields freeze at confirmation. |
| `CapacityRule` | A traveler type that takes part in a group without using a position (INV-39). |
| `UnitShell` | One cabin, room or resource, created only at confirmation (SUP-12, INV-05). Its status is derived from its capacity events (INV-38): Available or Returned to supplier until build step 6 adds allocations. |
| `CapacityPool` | One per pool group, created at confirmation and carrying the group's availability promise. |
| `CapacityEvent` | Append-only supply ledger for a group: opening at confirmation, increase, supplier release and correction, each with an idempotency key. A future-dated change applies at 11:59 p.m. agency time on its date, with the zone snapshotted (D-88). |
| `CapacityProjection` | Rebuildable current supplier capacity for numeric groups, refreshed by `CapacityProjectionRefresher` from `CapacityTimelineReplay`. On request, Rate only and no-shared-inventory groups have none (INV-04). |
| `SupplierRateLine` | One row of an arrangement's supplier rate table (SUP-35): group, occupancy position (single, or 1st to 9th guest), optional traveler type, and base fare, non-commissionable fees, taxes, discount and a commission rate or amount, in minor units of the arrangement currency. Frozen once the arrangement leaves Draft. Nothing is derived from it yet (D-75). |
| `SupplierRateBand` | A column of the rate grid (S-14): a label, a set of occupancy positions, and optionally one traveler type, as the exception to an untyped band covering the same positions; same-type bands never overlap. The arrangement holds its pricing pattern (cruise bands, one per guest, per room, custom) and the values every fare shares (non-commissionable fare, taxes and fees, commission as a percentage with its basis or a dollar amount). Saving the grid writes one rate line per position, recording which shared values a fare overrides; rates can be copied from another arrangement of the same supplier and currency. Frozen with the rate table at confirmation. |
| `SupplierDeadline` | A supplier deadline on an arrangement (SUP-22 to SUP-25): type, actionable or informational, description, optional group, the supplier's local date with an optional time and zone, and the resolved instant, stored when recorded or changed and never recalculated. A date-only deadline resolves to 11:59 p.m. agency time (SET-10). It prompts staff only. |
| `Task` | One work item a person must act on (OPS-01, OPS-02): source (`supplier_deadline` or `manual`), action, due instant with its local date, time and zone, an individual owner, status `open`, `in_progress`, `completed` or `waived` with the completion note or waiver reason the database requires, and its Departure. An actionable deadline has exactly one. Overdue is derived from `Clock.current`. Its history is in the Departure's audit trail. |
| `CostLine`, `CostLineShell` | What a supplier commitment costs in total (SMN-02): scope (arrangement, an inventory group, or named shells), basis (fixed; per unit, person or night; or a percentage of another line), amount and stage. Committed lines are committed cost exposure (SUP-13); a commitment for unsold space names its shells (D-75). Fixed once an amount posts against it. |
| `ScheduleLine` | When a portion falls due (SMN-04): a fixed amount, a percentage of its cost line, an amount per unit times a count, or one amount per shell; on a fixed date, an event, days after an event, or the earlier of an event and a date. It may name the supplier deadline it pays, whose task it uses. Never adds to cost (SMN-03). |
| `TriggerEvent` | An SMN-11 event dated when it happened, with an optional count and reference. Append-only. Confirm records Arrangement confirmed and the sweep records Service date. |
| `AmountDue` | The only supplier payable (SMN-05): posted from a schedule line, at most one per shell per line (SMN-10, D-81), or recorded directly. The amount and the facts used are snapshotted (SMN-06). Append-only; paid status arrives with payments. |
| `Offering`, `OfferingChoice`, `OfferingOption` | A Departure's package (BKG-13) in its operating currency. Its contents are choices, each `included` or `add_on`, made per traveler, unit or trip, with a required single, optional single or optional multiple pattern (optional multiple only for add-ons, BKG-14). Each option draws on one inventory group of the same Departure, which a trigger enforces. `Offering#booking_blockers` lists what step 6 needs before booking. |
| `OfferingPrice` | A client price on an option for an occupancy position (single, a guest number, or any) and optional traveler type (BKG-21). `OfferingPriceLookup` tries the traveler's position, then the 1st-guest price for a lone guest, then any position, each with a type row before the any-type row. Changing a price never changes a booking (BKG-23). |
| `AgencyCancellationTier`, `ClientCancellationTier` | Client cancellation tiers (BKG-31): from a number of days before departure, a percentage of the affected service's accepted charge or a fixed amount per traveler or per unit of a service category. The agency's are the defaults; a Departure's terms may override them whole. The agency also keeps reusable terms wording. |
| `ClientTermsVersion`, `ClientPaymentScheduleLine` | A Departure's numbered client terms (BKG-28, D-76): the agency wording as copied, the Departure's own wording, the tier override, and the payment schedule template (CMN-09, D-77), with one balance line and at most one payment that counts as acceptance (BKG-41). Staff may start by copying another Departure's terms. A locked version and its rows are refused by a trigger; step 6 locks on acceptance. |
| `Traveler`, `TravelerLink` | A traveler profile, always one person (CLT-05): legal name as given names, middle name, surname and suffix, a preferred name never sent to suppliers (CLT-28), date of birth, supplier-required gender or sex, email and phone. No passport fields. It saves with details missing but needs a name. A link to a client has a relationship (Self, Family member, Employee or member, Other) and grants nothing (CLT-09, CLT-10); Self only for a person client, at most one per client. Creating a person client may add its Self traveler (CLT-11). |
| `ClientTrip` | One responsible client (CLT-02), at most one Departure (OVR-02), and a `T-` reference issued at creation (REF-04, D-94) that never changes. Status is derived (BKG-03); with no bookings yet it is Not booked. |
| `ClientBooking`, `BookingTraveler` | A purchase of the trip's Departure's package (BKG-05) with a reference from its trip (REF-04), status Draft, Confirmed, Discarded or Cancelled (BKG-06), an owner and a seller of record that are each the agency or a reseller, separate from its creator (ACC-18, FIN-05), created only while the Departure is On sale (DEP-05). Travelers are profiles or placeholders, each with a traveler type (CLT-13, CLT-15). Confirmation is refused in 6b with the list of what is missing (BKG-45, D16). |
| `ChoiceSelection`, `SelectionOccupant` | A chosen option (BKG-14). A per-unit selection is one numbered unit whose occupants have positions in it; occupants whose type uses no capacity have none (INV-39). A per-traveler selection lists participants. A removed selection with allocation history is kept as removed. |
| `BookingPriceLine` | A traveler's proposed price on a selection, from `OfferingPriceLookup`, re-proposed only when the booking's contents change; an offering price change touches none (BKG-23). |
| `InventoryAllocation` | A hold or reservation of a whole shell, positions in a shell, or pool places (INV-17). Held, Reserved or Released, forward only and never deleted (INV-18, D-88). A hold expires at 11:59 p.m. agency time on the last day of the hold duration and stops consuming at read time; it extends once, and a replacement after an edit keeps its expiry and extension. `GroupCapacity` derives what is left, refuses agency reductions below consuming allocations (INV-26) and flags a capacity conflict after a supplier release. |
| `BookingAcceptance` | The client's acceptance (BKG-41): who, method, date, terms version, accepted total and a fingerprint of the price lines; stale once either changes (BKG-39). Email or signed keeps an evidence file (ADR 0019 amendment) or where it is kept; phone or in person a note; a designated payment only when the terms name one, noted until build step 8 (D-94). Append-only. The first acceptance locks the terms version, copying the agency tiers it followed. |
| `ClientCharge`, `ChargeLine` | Made at confirmation from the price lines with the accepted terms (BKG-25, CMN-01 to CMN-03, D-94): one charge per booking, lines by traveler, type, position and option, agency creditor and route. Append-only. |
| `ExpectedCommission` | Proposed per booking service from the rate table at confirmation (SMN-32, D-92), with the proposal kept; overridable while Expected by Supplier arrangements or Financial records. Booking-scoped committed cost lines are proposed beside it, except for shells already committed as unsold space (D-75). |
| `SupplierReservation`, `SupplierReservationUnit`, `SupplierReservationEvent` | A request to the supplier for a booking's units from one arrangement (INV-33), at its scope (SUP-10): several units under arrangement scope, one under per unit, none under none. Requested, then Confirmed with the supplier's reference and the date it answered (INV-34, INV-35, REF-09); decline and cancel are Slice 1b. A unit has one open request (a partial unique index). Events are append-only (INV-26). Accepting changes no price, charge or allocation. `ChoiceSelection#needs_supplier_request?`: on-request, rate-only and directly booked units, or any under per unit. |
| `InstallmentProposal`, `Installment` | A draft booking's proposed installments from its terms' payment schedule (CMN-09), re-proposed only when the price, units or terms change, adjustable before acceptance, and covered by the acceptance's fingerprint; at confirmation, the charge's installments, any due by then combined into one due that day (CMN-08, CMN-12). Installments are append-only. `bin/rails bookings:create_missing_installments` backfills bookings confirmed before step 8 (D-94). |
| `ClientPayment`, `ClientPaymentApplication`, `ClientPaymentReversal`, `Receipt` | A payment on a Client Trip with a `PAY-` reference, by route: the agency, or a supplier on the Departure (CMN-18, CMN-29). Applications put it toward installments, oldest first by default (CMN-21); the rest is the trip's credit (CMN-23, CMN-24). A reversal adds negative applications and keeps both records (CMN-27, D-96). An agency payment issues a gap-free `RCP-` receipt, snapshotted at issue (CMN-55); a supplier payment gets none and, on an agency-owed line, shows as supplier-held funds (SMN-27). All append-only. `TripMoney` reads a trip's balances. |
| `SupplierPayment`, `SupplierPaymentApplication`, `SupplierPaymentReversal` | A payment the agency made to a supplier, with an `SPY-` reference, optional payee account and references (SMN-18), applied to that supplier's amounts due on the Departure, the rest unapplied until applied (SMN-19, SMN-22). A reversal adds negative applications (SMN-23). All append-only; a payment changes no cost or capacity. `AmountDue#paid_status` is Unpaid, Part paid or Paid. A schedule line's payment task, or a direct amount's, completes as `supplier_money.settle` once everything it posted is settled and it can post no more (SMN-17). |
| `TriggerEventShell` | The shells a Client booking confirmed event names; a per-shell schedule line posts only for shells its events name (D-81). |
| `ReferenceSequence` | Agency-scoped reference counters. Issued today: `CL-` clients, `SUP-` suppliers, `DEP-` departures, `ARR-` arrangements and `T-` trips. Formats for later namespaces are defined but not issued. Issuance does not create a missing row. |
| `AccessPermission` module | Closed action catalog: each action requires baseline, admin-only, a permission, any of several permissions, or reseller, checked against the user type and `UserPermission` grants (ADR 0017). It is application code, not a persisted record. |

Invitation and password-reset token facts are stored on `AgencyUser`; they are not separate identity records.

## Tenancy and authentication

- `Agency` is the sole tenant boundary.
- Sign-in resolves normalized workspace code before the agency-scoped normalized email.
- The same email in two agencies represents two independent AgencyUsers with separate passwords and sessions.
- `Current.session` is the authentication root; `Current.agency` comes only from its AgencyUser.
- Request parameters never establish Agency tenancy.
- A foreign-Agency identifier returns not found through an Agency-scoped lookup.
- Every authenticated request rechecks that both Agency and AgencyUser are active.

## Office context

Office is operational context, not authorization. `Current.office` resolves from an active same-Agency Office stored on the Session, then the AgencyUser's active default Office, then `nil`. Changing Office changes no permission. An Agency may have no Offices.

## Current permissions

An Agency Admin satisfies every requirement except `reseller`. Staff hold the baseline plus their granted permissions. A `reseller` user satisfies no staff requirement; reseller actions arrive in Slice 1 step 9b.

| Action | Requirement |
| --- | --- |
| View workspace, select current Office | Baseline |
| Manage Agency profile, Offices, AgencyUsers and user permissions | Agency Admin only |
| View and manage the Client directory, including contact details, travelers and their links | Baseline |
| View and manage Client Trips and bookings, holds included (`view_bookings`, `manage_bookings`) | Baseline |
| View and manage the Supplier directory, including contact details and payee accounts | Baseline |
| View Departures | Baseline |
| Manage Departures | Departure management |
| View supplier arrangements and inventory | Baseline |
| Manage supplier arrangements, inventory, capacity and the rate table | Supplier arrangements |
| View supplier costs: the rate table and supplier documents (ACC-31) | Departure management, Supplier arrangements or Financial records |
| Use tasks: view, start, complete, waive and reopen (ACC-30) | Baseline |
| Reassign a task | Departure management |
| Record cost lines, schedule lines and trigger events | Supplier arrangements |
| Record a direct amount due (SMN-05) | Supplier arrangements or Financial records |
| View each service's supplier status and an arrangement's supplier reservations (`view_supplier_reservations`) | Baseline |
| Start a supplier request and record the supplier's answer (`manage_supplier_reservations`) | Supplier arrangements |
| View client money: installments, payments, credit and receipts (`view_client_money`) | Baseline |
| Record, apply and reverse client payments (`manage_client_money`, CMN-19) | Financial records |
| Record, apply and reverse supplier payments (`manage_supplier_payments`, SMN-18) | Financial records |
| Confirm an expected commission with the supplier's amount (`confirm_commission`, SMN-33) | Supplier arrangements or Financial records |
| View the package, client prices and client terms | Baseline |
| Edit the package, prices and a Departure's client terms | Departure management |
| Edit the agency's client terms wording and default cancellation tiers | Agency Admin only |
| Authorize a reseller relationship and set its direct-contact setting (`manage_reseller_relationships`, ACC-13) | Reseller relationships |
| Publish a package to a reseller's channel and withdraw it (`publish_offerings`, DEP-07) | Departure management |
| Assign a booking's owner and set a draft's seller of record (`assign_bookings`, ACC-18, FIN-05) | Departure management |

Application code checks catalog actions, not user types or grant names. After sign-in, staff land on My tasks unless a protected page sent them to sign in (S-01).

## Persistence and command boundaries

- Application records use PostgreSQL 18 UUIDv7 identifiers and `timestamptz` timestamps.
- The primary database and Solid Queue database are separate. The departed sweep (`MarkEligibleDeparturesDepartedJob`, hourly) reads the primary database and enqueues `MarkDepartureDepartedJob` children into the queue database with no spanning transaction. Delivery is at least once. Queue name: `departures`.
- Database constraints and triggers protect normalized identity values, same-Agency references, append-only audits, decision history and capacity events, and immutable tenant identifiers.
- Supplier-layer records carry `agency_id` with composite foreign keys to their parents, so a shell, event, rule or rate line cannot point at another agency's or another arrangement's group. Triggers refuse numeric capacity records on non-numeric groups, ownership changes on capacity records, and any change to rate lines once their arrangement leaves Draft.
- Money is stored as `bigint` minor units with an explicit currency (ADR 0001). Staff-typed amounts are parsed by `MoneyInput`, which refuses more decimal places than the currency has rather than rounding.
- New domain code reads the time from `Clock.current`; tests fix it with `set_clock`.
- `btree_gist` is enabled on the primary database only for `client_org_contacts_no_overlapping_history`.
- Consequential multi-record changes use explicit commands, transactions, lock ordering, and same-transaction audit events. Arrangement commands lock agency, Departure, arrangement, then inventory groups and pools last. Mutable aggregates use optimistic `lock_version` checks.
- Capacity events carry an idempotency key, so a resubmitted supply form records once.
- Multi-branch CHECK constraints on nullable columns are wrapped in `COALESCE(..., false)`, because PostgreSQL passes a CHECK whose expression is NULL.
- Recording or changing a deadline keeps its task in step in the same transaction: an actionable deadline creates a task for the Departure's default task owner, else the recorder; a change moves the task's due date; marking it informational waives the task, and actionable again reopens it (OPS-04). Discarding a Draft arrangement waives its open tasks. Task commands lock agency, Departure, then the task.
- `SupplierAmountPosting` posts amounts due when a schedule line's date arrives or its event is recorded, only on a confirmed arrangement, rounding percentages half up once per amount (ADR 0001). The hourly `PostDueSupplierAmountsJob` (queue `supplier_money`) enqueues `PostArrangementAmountsDueJob` per confirmed arrangement with schedule lines, which posts as the system. Completing a final count, rooming list or ticketing task records that event (SMN-12) and needs Supplier arrangements.
- `ProposeBookingSupplierCost` proposes a unit's supplier cost and commission from the rate table at the actual occupancy; build step 6 calls it at booking confirmation.
- Last-active-administrator protection locks Agency, then AgencyUser, then rechecks current state.

## Not shipped

The application has no Household, Travel Program, booking amendment or cancellation, client installment, supplier reservation decline or cancellation, commission receipts or offsets, issued document, platform-support, or MFA records. Reseller users have schema only. Capacity reconciliation, cancelling a confirmed arrangement, effective-dated rate replacement, work groups, reminders, task creation by hand, supplier amendments and adjustments with a reason, and supplier invoice references are deferred. Directory tables do not store `office_id`. No universal `Party`, global `User`, `AgencyMembership`, or Office-based authorization layer may be restored. FX is not supported; an arrangement's currency equals its Departure's.

See [ADR 0005](../adr/0005-agency-identity.md) as amended by ADRs 0016 and 0017 for the identity contract, [ADR 0018](../adr/0018-arrangement-history-by-dated-adjustment.md) for the supplier layer, and the [planning index](../planning/README.md) for standing.
