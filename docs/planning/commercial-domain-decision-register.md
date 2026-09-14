# DepartureDesk Commercial Domain Decision Register

**Status:** Accepted planning contract

**Scope:** Departure, Client Trip, Supplier planning, capacity, commercial terms, financial ledgers, amendments, documents, reporting, and closeout

**Purpose:** Consolidate the product decisions required before detailed implementation planning. This document is normative where it uses **must**, **must not**, **may**, or **requires**.

## 1. Governing principles

1. Posted financial events are immutable. Corrections use linked reversal, adjustment, refund, return, write-off, or reapplication records.
2. Operational truth, commercial truth, Supplier truth, and cash movement remain distinct. One event must not imply another unless an accepted command contract explicitly couples them.
3. A Departure uses one transaction currency. Cross-currency accounting and exchange-rate realization are outside the initial implementation unless separately approved.
4. Estimates, commitments, Obligations, invoices, Payments, and final reconciled costs are distinct stages. Reports select the best applicable stage; they never add stages together.
5. Supplier-collected money may satisfy Client Charges but is not Agency cash.
6. Commercial terms are snapshotted when a Client Trip is confirmed. Later changes use amendments and affect future sales by default.
7. Capacity changes occur through atomic commands that lock and recheck the applicable capacity bucket.
8. Consequential actions require explicit command authority, audit evidence, and idempotency. Ordinary CRUD status updates are not an acceptable lifecycle mechanism.
9. Historical snapshots, posted money, issued documents, and released or expired capacity history are not rewritten to make the current state appear simpler.
10. Financial reports are reproducible from posting timestamps and immutable closeout snapshots.

## 2. Terminology used in this register

- **Charge:** A posted Client receivable event for one due installment or other immediately due amount.
- **Charge source line:** A traceable reason and amount within a Charge, such as a Package, optional Client Trip Service, fee, amendment, or rounding adjustment.
- **Receipt:** Agency-controlled money received from a payer.
- **Application:** A posted allocation of value from a Receipt, Credit, Supplier-collected payment, Supplier Payment, Supplier Credit, or commission settlement to a specific ledger item.
- **Supplier Obligation:** A posted amount the Agency owes a Supplier for one payable event or due date.
- **Supplier Invoice:** Supplier-provided billing evidence reconciled against Obligations; it is not itself the payable ledger.
- **Agency Cost:** A first-class internal or externally incurred Agency cost that must not be represented through a fabricated Supplier.
- **Capacity bucket:** The occurrence- or category-specific unit against which holds and confirmed allocations are measured.
- **Commercial snapshot:** The immutable terms, selections, prices, policy provenance, and relevant names captured when a Client Trip is confirmed.
- **Material change:** A draft change affecting price, payment schedule, cancellation terms, required inclusions, optional services selected, capacity/resource category, or what the Client receives or owes.

## 3. Client sales, Charges, and payment schedules

### 3.1 Charge granularity and provenance

1. One Payment Schedule installment posts as one Charge.
2. A Charge contains one or more immutable source lines identifying the commercial source and reason.
3. Supported source reasons must include at least:
   - Package price;
   - optional Client Trip Service;
   - fee or surcharge;
   - amendment difference;
   - cancellation fee or credit consequence;
   - write-off or other authorized adjustment; and
   - explicit rounding adjustment.
4. A bundled Package remains one Package-priced source line. DepartureDesk must not invent allocations among included services solely for reporting.
5. Source lines must retain stable links or snapshots identifying the originating Package, Client Trip Service, Amendment, policy calculation, or other source.
6. Future installments remain scheduled rather than posted until their due/posting milestone occurs.
7. A deterministic due milestone may post a scheduled Charge automatically when its responsible Client, amount, currency, due date, source lines, and governing snapshot are complete. An incomplete or exceptional installment creates a review item rather than a guessed Charge.

### 3.2 Client Trip confirmation

Confirming a Client Trip is one atomic command. It must:

1. Revalidate current Package and selected-service terms.
2. Require acknowledgment of detected term changes.
3. Snapshot prices, inclusions, selections, cancellation terms, relevant names, and Supplier-term provenance.
4. Convert valid holds into confirmed allocations.
5. Post only Charges currently due.
6. Record a durable Client Trip reference.
7. Commit all effects together or none of them.

Confirmation must fail without partial side effects when a required hold has expired, capacity is no longer available, a material change lacks valid Client acknowledgment, pricing changes have not been acknowledged, required Supplier confirmation is missing, or Charge posting fails.

### 3.3 Draft pricing and acknowledgment

1. A draft Client Trip uses current Package and service terms until confirmation.
2. DepartureDesk must visibly identify changes since the draft was last reviewed.
3. Material changes require recorded Client acknowledgment before confirmation.
4. Nonmaterial changes require authorized staff acknowledgment.
5. Client acknowledgment must record:
   - responsible Client;
   - acknowledged terms version or fingerprint;
   - method and supporting evidence/reference;
   - staff member recording it; and
   - timestamp.
6. A later material change invalidates the prior acknowledgment for the affected terms.

### 3.4 Calculations and rounding

1. Every percentage-based tax, fee, discount, deposit, or commission component must explicitly identify its base source lines.
2. The component must state whether it is included in or added to the quoted amount.
3. Calculation order comes from the applicable recorded pricing terms, not an arbitrary Agency-wide formula.
4. A posted component snapshots its base, rate, calculation order, rounding method, and minor-unit result.
5. Calculations may retain additional internal precision, but each posted source line is rounded to the transaction currency's minor unit.
6. A contract-total difference caused by line rounding is represented as a visible rounding-adjustment line.

## 4. Client Receipts, credits, and externally collected value

### 4.1 Separate value types

DepartureDesk must keep these concepts distinct:

- Receipt Application: Agency cash applied to a Charge.
- Client Credit Application: noncash Client Credit applied to a Charge.
- Supplier-collected Payment Application: value collected by a Supplier and applied to a Charge without entering Agency cash.

An issued Client Credit remains available value until applied. Credit issuance alone does not reduce a Charge.

### 4.2 Receipt boundary and payer identity

1. A Receipt represents one Agency-controlled cash event and preserves the actual payer, who need not be the responsible Client for any Charge.
2. MVP requires one Departure and one currency per Receipt.
3. Receipt Applications may span Charges and Client Trips within that Departure.
4. A Receipt records payment method, effective date, posting timestamp, external processor/bank reference when applicable, recorder, and evidence or note required by Agency policy.
5. Effective date describes when the payment economically occurred; posting timestamp controls as-of inclusion.
6. The system may propose applications in due-date and stable-reference order, but posting must preserve the exact approved applications. No hidden allocation order may change Client balances.

### 4.3 Charge balance

For a posted Charge:

> **Outstanding Charge balance = Charge total − active Receipt Applications − active Client Credit Applications − active Supplier-collected Payment Applications**

Applications are immutable after posting. Corrections require reversal and, when appropriate, a new application.

### 4.4 Unapplied funds and overpayments

1. A Receipt may remain partly or wholly unapplied.
2. If a Receipt exceeds currently posted Charges for its Departure, the excess remains Unapplied Funds for later same-Departure use or refund.
3. A Charge must not become negative because of an overpayment.
4. DepartureDesk must not automatically convert excess cash into a noncash Client Credit.
5. Unapplied Receipts, Credits, and Supplier-collected value remain separately visible and may block closeout.

### 4.5 Refunds, returns, and reversals

1. A returned, rejected, or externally reversed payment creates a compensating return event; the original Receipt remains intact.
2. The return command atomically reverses all active applications affected by the returned amount and restores the applicable Charge balances.
3. An authorized returned-payment fee is a separate Charge source line, not an edit to the Receipt.
4. The same preservation and compensating-event rule applies to returned Supplier Payments.
5. A partial or full Client Refund is a first-class Agency cash event linked to the Receipt, unapplied funds, Credit, Charge/Application disposition, responsible Client, approval, and reason as applicable.
6. A refund does not edit or delete the original Receipt or its historical Applications. The refund command posts the required reversals or credit dispositions atomically.
7. A mistaken internal posting is corrected by reversal and replacement. An external return records the externally caused failure. A Client Refund records an authorized outbound payment. These event types must not be conflated.

### 4.6 Supplier-collected payments

1. Supplier-collected value must be recorded with Supplier evidence, payer, amount, currency, external reference, effective date, and affected Client Trip or service context.
2. It reduces Client balances only through explicit Supplier-collected Payment Applications.
3. It never increases Agency cash.
4. A Supplier refund or reversal creates a linked compensating event that reverses the applicable external-payment applications.

## 5. Supplier costs, Obligations, invoices, and Payments

### 5.1 Supplier Obligation granularity

1. One Supplier Obligation represents one payable event or due date.
2. It may contain multiple source lines spanning cost components, Reservations, or Service Occurrences when they share that payable event.
3. Each source line must preserve links to the originating Supplier Arrangement, Reservation, Service Occurrence, cost component, commitment, and governing terms where applicable.
4. A continuing Arrangement-level running balance is not a substitute for event-based Obligations.

### 5.2 Posting Obligations

1. A deterministic contractual milestone may post an Obligation automatically when amount, currency, due date, source lines, and triggering terms are complete.
2. Ambiguous, missing, or discretionary terms create a review item. The system must not guess or post a zero-value Obligation.
3. Automatic posting must be idempotent and retain the triggering term/version and event.

### 5.3 Supplier invoices and reconciliation

1. Supplier Invoice is a first-class reconciliation record.
2. It stores Supplier reference, invoice and received dates, totals, currency, document evidence, and invoice lines.
3. An Invoice does not replace, silently edit, or become the Supplier Obligation ledger.
4. Reconciliation matches Invoice lines to Obligation lines.
5. Differences require reviewed, explicit Supplier cost or Obligation adjustment records.
6. Final reconciled Supplier cost must remain traceable to both the original commercial source and Supplier evidence.

### 5.4 Supplier credits

An issued Supplier Credit is available value but reduces an Obligation only through a Supplier Credit Application. Supplier Credit Applications are reversed, not edited.

### 5.5 Supplier Payments

1. One Supplier Payment may cover Obligations from multiple Departures when Agency, Supplier, and currency match.
2. Supplier Payment Applications attribute payment portions to particular Obligations and therefore to Departures.
3. Any unapplied remainder stays at the Agency-Supplier level until applied, refunded, or otherwise resolved.
4. A Supplier Refund is a first-class Agency cash event linked to the Supplier, original Supplier Payment or Supplier Credit context, affected Applications/Obligations, reason, effective date, and posting timestamp.
5. Supplier Refund corrections preserve the original cash event and use linked compensating records.

## 6. Commission

1. Commission must distinguish expected, earned, settled, received, and reversed states.
2. The earning milestone is defined by the Supplier Arrangement; no universal milestone is imposed.
3. If the Agency owes a Supplier $1,000 gross and remits $900 after retaining $100 commission, DepartureDesk records:
   - a $1,000 Supplier Obligation;
   - a $900 Supplier Payment; and
   - a $100 Commission Settlement Application clearing the remainder.
4. Retained commission is not Supplier Credit and does not reduce gross Supplier cost.
5. Commission paid later by a Supplier creates a Commission Receipt applied to earned commission.
6. A Commission Receipt is neither a Client Receipt nor a Supplier Refund.
7. Commission reversal must preserve the original earning and settlement/receipt history through compensating records.

## 7. Agency-provided and miscellaneous costs

1. Agency Cost is a first-class record.
2. It may be linked to a Departure, Client Trip Service, or Service Occurrence.
3. Planned Agency Costs affect projected margin.
4. Posted Agency Costs affect actual operational margin.
5. An Agency Cost affects operational cash position only when marked paid with an external payment reference.
6. Agency Costs must not create fake Suppliers, Supplier Obligations, or Supplier Payments.

## 8. Capacity, holds, and allocations

### 8.1 Capacity basis

1. Each capacity bucket declares its explicit basis, such as resource units, Traveler positions, or another named quantity.
2. Holds and allocations consume that declared quantity.
3. Traveler Assignments and Resource Assignments provide placement or occupancy detail without double-counting capacity.

### 8.2 Holds

1. A draft Client Trip may create an explicit expiring hold.
2. A hold reduces internal availability but creates no Charge, Supplier Obligation, or Supplier confirmation.
3. At expiry, the hold releases automatically and retains immutable expiry history.
4. Automated expiry uses a system actor and idempotent release event.
5. A live hold may be extended by Staff within configured duration/count limits and never beyond a contractual Supplier cutoff.
6. An Administrator may override configured extension limits with a reason when capacity and Supplier terms still permit the extension.
7. Extension is an auditable event, not a silent edit to the original expiry.
8. Every extension atomically rechecks availability and conflicting allocations.
9. An expired or released hold cannot be extended; a new hold must reacquire capacity.

### 8.3 Confirmed allocations and concurrency

1. Confirming or changing an allocation locks the relevant Service Occurrence and capacity bucket, rechecks availability, and succeeds completely or reports a conflict.
2. Confirmed demand may exceed managed capacity only through an Administrator override.
3. An over-capacity override records quantity, reason, actor, time, and affected occurrence.
4. The exception remains in a needs-attention queue until resolved or acknowledged.
5. An operationally authorized cancellation releases capacity even if Client or Supplier financial consequences remain unresolved.
6. Hold and allocation records are retained after release, expiry, substitution, or cancellation.

### 8.4 Pending Supplier fulfillment

1. A Client Trip may be confirmed while a required service remains on request with its Supplier.
2. The pending service must create a visible readiness warning.
3. A service or its terms may explicitly require Supplier confirmation before Client Trip confirmation; that stricter rule must then block confirmation.
4. Client Trip confirmation must never fabricate Supplier confirmation.

## 9. Amendments, substitutions, movement, and cancellation

### 9.1 Governing amendment rule

1. Confirmed commercial terms and posted money do not change through ordinary edits.
2. Upgrade, downgrade, promotion, surcharge, goodwill, cancellation repricing, and reinstatement use an explicit Client Trip Amendment identity.
3. An amendment posts only approved differences through new Charges, Credits, cost adjustments, or other compensating records.
4. Supplier cost changes remain separate from Client price changes.

### 9.2 Responsibility changes

When responsibility for a partially paid Charge changes:

1. Paid history and its original responsible Client remain preserved.
2. Only the outstanding balance transfers through linked adjustment/transfer records.
3. Receipt and application history must not be rewritten as if the new Client made the earlier payment.

### 9.3 Traveler substitution

1. Replacing a Traveler on a confirmed Client Trip uses an explicit substitution amendment.
2. Old and new assignments remain linked and historically visible.
3. The command reevaluates eligibility, identity requirements, Supplier rules, pricing consequences, documents, and capacity placement.
4. A legal-name correction for the same person is not a substitution, but must retain change history and determine whether issued documents require supersession.

### 9.4 Moving between Departures

1. A genuinely clean draft may move to another Departure in place.
2. A linked replacement Client Trip is required after posted money, consequential issued documents, or confirmed/expired/released capacity history exists.
3. The original and replacement remain cross-referenced.
4. A move must not rewrite the original Departure's historical sales, capacity, or financial reporting.

### 9.5 Cancellation

1. Client and Supplier consequences resolve independently and may post at different times.
2. A structured cancellation policy may calculate deterministic proposed credits or fees automatically.
3. Calculated consequences affect the ledger only after authorized posting.
4. An approved Client refund may proceed before Supplier reimbursement arrives.
5. Operational cancellation releases capacity after Agency authorization rather than waiting for financial disposition.
6. A Cancellation Case stays open until every required operational, Client, Supplier, commission, capacity, and payment disposition is resolved or explicitly marked inapplicable.
7. Reinstatement uses an amendment and reacquires current terms and capacity; cancelled assignments are not merely reactivated.
8. Occupancy changes preserve prior pricing positions and present proposed Charge or Credit adjustments for approval.

## 10. Documents and Communications

1. Draft documents may be regenerated.
2. An issued document version is immutable.
3. It must preserve the rendered artifact, template/version, input snapshot, branding, addressee, responsible Client, related records, actor, and issuance time.
4. A correction creates a new issued version explicitly superseding the prior version.
5. Superseded versions remain historically available subject to retention policy.
6. Creating or superseding a document does not send it.
7. Sending creates a Communication linked to the exact issued version and its recipients.
8. Sensitive-data authorization for screen display does not imply permission to export or include the data in a document.

## 11. Dates, time zones, and deadlines

1. A Departure has a default IANA time zone.
2. A timed Service Occurrence stores its local date/time and explicit IANA zone and may override the Departure default.
3. All-day travel dates remain date values rather than artificial midnight timestamps.
4. A Deadline preserves its relative rule and the resolved due date/time/zone used operationally.
5. Changing a default time zone or deadline configuration does not reinterpret confirmed records, issued documents, or resolved deadlines.
6. Date-only lifecycle transitions may run automatically and must be audited.
7. Date automation must not post money, cancel services, release capacity except through an explicit expiry rule, close a Departure, or fabricate fulfillment.
8. MVP documents use English-authored templates with locale-ready formatting for numbers, currency, dates, addresses, and time zones.
9. A timestamp deadline is due at its stored local time and zone and becomes overdue immediately after that instant.
10. When a contractual rule supplies only a cutoff date, the resolved deadline is the end of that local calendar day in the governing zone unless the Supplier terms explicitly define another cutoff.
11. Deadline comparison must use the resolved instant while displaying the governing local date, time, and zone.

## 12. Sensitive Traveler data and retention

1. Sensitive fields are masked in ordinary views.
2. Administrators and Staff may reveal designated fields only through a named permission; Viewers may never reveal them.
3. Reveal is an explicit, audited action recording actor, Traveler, fields, time, purpose/reason, and related Client Trip.
4. Exports and generated documents require separate permission checks.
5. Passport scans and full sensitive identity documents remain in an approved external secure repository; DepartureDesk stores structured fields and safe external references only.
6. When the operational and legally required retention period expires, sensitive structured values are automatically redacted under Agency policy.
7. Traveler Assignment, document reference, fulfillment history, and audit evidence remain after redaction.
8. An active legal or operational hold pauses redaction.

## 13. Configuration ownership and effective dating

1. Settings may be overridden only at declared scopes.
2. The effective value follows system default, then Agency, then the most-specific allowed Departure, Package, Supplier Arrangement, or Service Occurrence override.
3. Each setting definition must declare its permitted owner scopes.
4. Consequential commands snapshot both the resolved value and its source.
5. Later configuration changes affect future resolutions and do not reinterpret historical consequences.
6. Hold-extension limits, deadline rules, reminder lead times, tolerances, and similar settings must identify their owner and effective-date behavior explicitly.

## 14. Authorization and command authority

1. MVP retains the fixed Administrator, Staff, and Viewer roles, implemented through named permissions.
2. Staff and Administrators may perform ordinary sales, payment, Supplier, cancellation-disposition, and document actions when their named permission permits.
3. Administrator-only actions include:
   - restricted policy or capacity overrides;
   - write-offs;
   - qualified-warning waivers;
   - over-capacity confirmation;
   - final closeout;
   - reopening; and
   - hold extensions outside configured Staff limits.
4. Viewers cause no posting or other side effects.
5. Assignment as advisor, manager, or responsible staff member does not itself grant authority.
6. Every consequential command must define required permission, validation, transaction boundary, lock order, idempotency key/behavior, audit event, and compensating path.

## 15. Reporting definitions

### 15.1 As-of basis

1. Posting timestamp determines whether a financial event is included in an as-of report.
2. Effective date is reported separately and may support operational analysis, but does not rewrite the historical posting cutoff.
3. Reversals appear according to their own posting timestamps while preserving links to the reversed events.
4. Consequential records snapshot their Office attribution at posting or confirmation. Later Office reassignment does not rewrite historical reporting; reports may present current Office separately when useful.

### 15.2 Projected revenue and cost

- **Projected Client revenue:** Confirmed Client Trip prices, including posted Charges and confirmed future installments. Draft pipeline is reported separately.
- **Projected Supplier cost:** One current expected-final-cost projection per source, selected from the best available evidence. Estimates, commitments, Obligations, and invoices are never added together as separate costs for the same source.
- Planned Agency Costs are included in projected margin.

### 15.3 Actual operational margin

> **Actual operational margin = final eligible Client revenue + earned commission − final reconciled Supplier costs − posted Agency Costs**

Pass-through components are excluded from Client revenue when their source-line classification says they are not Agency revenue.

### 15.4 Operational cash position

> **Operational cash position = Client Receipts + Supplier Refunds + Commission Receipts − Client Refunds − Supplier Payments − paid Agency Costs**

Supplier-collected payments and noncash credits are excluded. Posting an Agency Cost affects margin; it affects cash only when marked paid with an external payment reference.

### 15.5 Accounting export

MVP accounting export produces paired summary and event-detail files with stable source IDs. It must preserve linkage among source records, posted events, reversals, applications, Departure, Office attribution, counterparty, posting timestamp, effective date, and currency.

## 16. Closeout and reopening

1. Closing a Departure requires reconciliation checks and creates an immutable, versioned closeout snapshot.
2. Hard financial-integrity blockers cannot be waived.
3. Qualified operational warnings may be waived only by an Administrator with a recorded reason.
4. Hard blockers include unresolved Client receivables, Supplier balances, refunds, unapplied value, commission, or unreconciled financial events unless explicitly resolved through payment, application, reversal, refund, write-off, or another approved disposition.
5. Small balances require an Administrator-authorized write-off adjustment; they are not silently treated as zero.
6. A closed Departure rejects new financial postings.
7. Post-close correction requires Administrator reopening.
8. Reopening records actor, reason, timestamp, and prior snapshot reference.
9. The previous snapshot remains immutable; a later close creates the next snapshot version.
10. Reports issued from an earlier snapshot remain reproducible after reopening.

## 17. Human-readable references

1. Reference formats are system-defined by record type.
2. Each Agency owns a separate, non-resetting sequence for each applicable record type.
3. Office codes do not appear in references.
4. A record receives its durable reference at its first consequential transition, not merely because a draft exists.
5. References are permanent, never reused, and remain searchable after cancellation, reversal, or absorption.
6. Existing Departure format `D-000001` remains the pattern baseline.
7. The detailed implementation plan must publish a record-type mapping. Recommended issuance points are:

| Record | Consequential transition |
| --- | --- |
| Departure | First activation/publication or other transition making it operationally usable |
| Client Trip | Confirmation |
| Charge | Posting |
| Receipt | Posting/recording receipt of funds |
| Supplier Obligation | Posting |
| Supplier Payment | Posting/recording disbursement |
| Supplier Invoice | Formal recording for reconciliation |
| Cancellation Case | Opening the case |
| Issued Document | Issuance |

The exact record catalog and type codes remain an implementation-document task, not an open product-policy question.

## 18. Lifecycle transition contracts

### 18.1 Departure

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| Draft → Active | Required identity, dates, Office, manager, currency, and operational configuration complete | Staff with permission or Administrator | Issues reference if absent; permits planning and sales | Return to draft only before consequential downstream history |
| Active → Departed | Applicable date reached | System date transition or authorized Staff | Status/audit only | Correct erroneous date/status through authorized correction; no financial side effects |
| Departed → Closeout review | Travel/service period complete | Staff with permission | Runs blocker and warning evaluation | May return to departed while unresolved |
| Closeout review → Closed | No hard blockers; warnings resolved or validly waived | Administrator | Creates immutable closeout snapshot; blocks new postings | Reopen command only |
| Closed → Reopened | Reason supplied | Administrator | Preserves prior snapshot; allows corrective activity | Later close creates a new snapshot version |

### 18.2 Client Trip

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| Draft → Confirmed | Valid terms, acknowledgments, required holds/capacity, required Supplier confirmations, due-charge data | Staff with permission or Administrator | Atomic commercial snapshot, allocations, currently due Charges, reference | Cancellation or amendment; not status rollback |
| Confirmed → Traveled | Applicable date reached and not cancelled | System date transition | Status/audit only | Authorized correction if date/status erroneous |
| Draft → Cancelled/abandoned | No consequential history requiring a case | Staff with permission | Releases live holds; preserves record | New draft or linked replacement |
| Confirmed/Traveled → Cancellation in progress | Cancellation request accepted for handling | Staff with permission | Opens Cancellation Case; does not itself decide every consequence | Complete or reject case with history |
| Eligible clean draft → Moved | No posted money, consequential issued documents, or capacity history | Staff with permission | Changes Departure and revalidates terms | Audit correction |
| Consequential trip → Replacement | Target Departure and replacement terms valid | Staff with permission | Creates linked replacement; original remains | Cancel replacement or create another amendment |

### 18.3 Client Trip Service

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| Draft selection → Held | Applicable capacity available | Staff with permission | Creates expiring hold | Release/expiry event |
| Draft selection → On request | Supplier request required | Staff with permission | Creates Supplier-facing request state and readiness warning | Withdraw request with history |
| Held/selected → Confirmed | Client Trip confirmation or approved amendment succeeds | Staff with permission or Administrator override | Snapshots terms; confirms allocation; may post Charge source | Amendment/cancellation |
| Confirmed → Cancelled | Operational cancellation authorized | Staff with permission | Releases capacity; opens/updates financial dispositions | Reinstatement amendment |
| Cancelled → Reinstated replacement | Current terms/capacity available | Staff with permission | New linked assignment/service state | Further amendment |

### 18.4 Supplier Arrangement

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| Draft → Active | Supplier, terms, dates, currency, capacity/cost definitions complete | Staff with permission | Terms become available to planning and sales | Amend/version; do not rewrite snapshotted sales |
| Active → Amended version | Revised terms approved | Staff with permission | New version affects future resolutions; existing snapshots preserved | New corrective version |
| Active → Ended/inactive | No prohibited active dependency or override path satisfied | Staff with permission | Prevents new use; retains history | Reactivate only when contractually valid |

### 18.5 Supplier Reservation and confirmation

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| Planned → Requested | Request data complete | Staff with permission | Records request and Supplier communication context | Withdraw with history |
| Requested → Confirmed | Supplier evidence received | Staff with permission | Records Supplier confirmation provenance; may trigger deterministic commitments/Obligations | Supplier amendment/cancellation event |
| Requested → Declined | Supplier response received | Staff with permission | Records reason; raises readiness/capacity issue | New request or alternate Supplier path |
| Confirmed → Changed/cancelled | Supplier evidence and reason recorded | Staff with permission | Recalculates planning exposure; proposes but does not silently post Client consequences | New confirmation/amendment |

### 18.6 Capacity hold and allocation

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| None → Live hold | Availability after atomic recheck | Staff with permission | Consumes held quantity until expiry | Release or expiry |
| Live hold → Extended | Still live; within cutoff; availability revalidated | Staff within limits; Administrator override beyond limits | Adds extension event and new expiry | New extension or release; never edit history |
| Live hold → Expired | Expiry reached | System | Releases quantity; retains history | New hold only |
| Live hold → Confirmed allocation | Confirmation command succeeds | Staff with permission or Administrator over-capacity authority | Converts held quantity without double consumption | Release, cancellation, or substitution event |
| Confirmed allocation → Released | Authorized operational change/cancellation | Staff with permission | Restores availability; preserves allocation history | New hold/allocation required |

### 18.7 Cancellation Case

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| None → Open | Cancellation accepted for handling | Staff with permission | Captures scope, request, policy version, and unresolved disposition checklist | Reject/withdraw with reason when no cancellation was executed |
| Open → Operationally cancelled | Required operational approvals complete | Staff with permission | Cancels affected service/trip and releases capacity | Reinstatement amendment |
| Open → Financial dispositions pending | Calculations available | Staff with permission | Presents proposed Client/Supplier/commission consequences | Recalculate before posting if inputs change |
| Pending → Consequences posted | Authorized approvals complete | Staff with posting permission | Posts explicit Charges, Credits, Obligations, adjustments, or refunds | Compensating records only |
| Open → Resolved | Every required disposition resolved or inapplicable | Staff with permission | Closes case with full evidence | Reopen case with reason; posted records remain immutable |

### 18.8 Posted financial records

Posted Charge, Receipt, Application, Credit, Supplier Obligation, Supplier Payment, Commission event, Agency Cost, refund, write-off, return, and adjustment records do not transition back to editable draft states. Their lifecycle is:

| Transition | Rule |
| --- | --- |
| Draft/prepared → Posted | Validate authority, source, currency, dates, amounts, idempotency, and open-period/Departure status in one transaction |
| Posted → Partly/fully applied | Create immutable Applications; do not edit the posted principal |
| Posted → Reversed/returned/adjusted | Create linked compensating event and atomically update derived balances |
| Included in closeout | Preserve event and posting cutoff in immutable snapshot |

### 18.9 Supplier Invoice

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| Received/draft → Recorded | Supplier identity, reference, dates, currency, totals, evidence | Staff with permission | Issues reference; available for reconciliation | Void/supersede with reason; retain original |
| Recorded → Partly/fully reconciled | Line matches and variances reviewed | Staff with permission | Links lines to Obligations; prepares adjustments | Reverse links/adjustments through explicit correction |
| Reconciled → Superseded | Corrected Supplier invoice received | Staff with permission | New version/reference relationship | Reconcile superseding version; retain both |

### 18.10 Issued document and Communication

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| --- | --- | --- | --- | --- |
| Draft → Issued | Required data and permissions complete | Staff with document permission | Freezes rendered artifact and input snapshot | Superseding issued version only |
| Issued → Sent | Explicit recipients and channel selected | Staff with communication permission | Creates Communication linked to exact version | Follow-up/correction Communication; sent history remains |
| Issued → Superseded | Corrected version issued | Staff with document permission | Links old and new versions | Another superseding version |

## 19. Required command contract template

Every lifecycle or posting command specification must state:

1. Command name and business intent.
2. Actor and named permission.
3. Agency/tenant and Office access checks.
4. Inputs and source record versions.
5. Preconditions and validation errors.
6. Lock targets and canonical lock order.
7. Idempotency key and replay result.
8. Records created, snapshotted, applied, released, or superseded.
9. Financial, capacity, document, communication, and reporting side effects.
10. Audit event payload, including before/after or explicit event facts.
11. Notification or needs-attention behavior.
12. Compensating command; ordinary destructive undo is prohibited.

## 20. Specification amendment checklist

### 20.1 Add or formalize records

- [ ] Charge source line and provenance fields.
- [ ] Client Credit Application.
- [ ] Supplier-collected Payment and Application, including reversal.
- [ ] Supplier Obligation source line.
- [ ] Supplier Invoice, Invoice Line, reconciliation match, and adjustment linkage.
- [ ] Supplier Credit Application.
- [ ] Commission earning, settlement application, Receipt, application, and reversal records.
- [ ] Agency Cost and paid status/evidence.
- [ ] Capacity basis, bucket, hold, extension, allocation, release, expiry, and override records/events.
- [ ] Client Trip commercial snapshot and acknowledgment evidence.
- [ ] Client Trip Amendment, substitution, responsibility transfer, and linked replacement relationships.
- [ ] Cancellation Case disposition checklist.
- [ ] Issued Document Version, supersession, and Communication linkage.
- [ ] Sensitive-data reveal audit and legal/operational hold.
- [ ] Closeout Snapshot and reopening linkage.

### 20.2 Replace ambiguous formulas

- [ ] Replace any balance formula that subtracts issued Credits directly with application-controlled balance effects.
- [ ] Include Supplier-collected Payment Applications in Charge balance without including them in Agency cash.
- [ ] Define Supplier Obligation balance through Payments, Supplier Credits, commission settlement, and reversals.
- [ ] Define projected Supplier cost as one selected expected-final value per source.
- [ ] Add the accepted actual operational margin formula.
- [ ] Add the accepted operational cash-position formula.
- [ ] Classify pass-through lines explicitly.

### 20.3 Add normative boundaries

- [ ] Confirmation transaction boundary and failure atomicity.
- [ ] Commercial snapshot timing and version provenance.
- [ ] Material-change classification and acknowledgment invalidation.
- [ ] Capacity consumption, expiry, extension, concurrency, release, and over-capacity rules.
- [ ] Pending Supplier service behavior and per-service confirmation requirement.
- [ ] Amendment versus edit rules.
- [ ] Responsibility transfer and Traveler substitution rules.
- [ ] Inter-Departure move/replacement boundary.
- [ ] Client/Supplier cancellation independence and reinstatement.
- [ ] Document issuance, supersession, and separate send action.
- [ ] Time-zone, all-day date, resolved-deadline, and default-change rules.
- [ ] Sensitive-data permission, redaction, and hold rules.
- [ ] Configuration scope precedence and consequential snapshotting.
- [ ] Posting-timestamp reporting basis.
- [ ] Closeout blockers, warnings, write-offs, snapshots, and reopening.
- [ ] Human-reference format, sequence scope, issuance point, and permanence.

### 20.4 Publish matrices and catalogs

- [ ] Lifecycle matrix for every stateful record, using Section 18 as the baseline.
- [ ] Named-permission/command authority matrix.
- [ ] Configuration key catalog with allowed owner scopes and effective dating.
- [ ] Capacity-basis catalog with measurement and assignment semantics.
- [ ] Charge, Obligation, adjustment, and application reason catalogs.
- [ ] Closeout blocker/warning catalog.
- [ ] Record-type reference code and issuance-point catalog.
- [ ] Accounting export field and stable-ID contract.

### 20.5 Verification requirements

- [ ] Concurrent last-unit allocation: exactly one succeeds without an authorized override.
- [ ] Expiry versus confirmation race: one atomic outcome, no double release or allocation.
- [ ] Idempotent confirmation: retry creates no duplicate snapshot, allocation, Charge, or reference.
- [ ] Credit issuance does not change a Charge until application.
- [ ] Supplier-collected application reduces Client balance but not Agency cash.
- [ ] Returned payment restores balances and preserves original Receipt/application history.
- [ ] Invoice reconciliation posts explicit differences without editing Obligations.
- [ ] Projected cost never double-counts stages.
- [ ] Responsibility transfer preserves paid history and moves only outstanding value.
- [ ] Cancellation releases capacity before financial resolution when operationally authorized.
- [ ] Client refund can post before Supplier reimbursement.
- [ ] Reinstatement reacquires current terms and capacity.
- [ ] Material draft change invalidates stale Client acknowledgment.
- [ ] Issued document correction supersedes rather than replaces the prior artifact.
- [ ] Sensitive reveal and export enforce separate permissions and audit trails.
- [ ] As-of report excludes events posted after the cutoff even when their effective date is earlier.
- [ ] Closed Departure rejects posting; reopening preserves the earlier snapshot.
- [ ] Reference sequences are Agency-scoped, non-resetting, unique, and never reused.

## 21. Planning disposition

The decisions in this register are sufficiently complete to proceed to record-level domain design and phased implementation planning. The remaining work consists of naming, schemas, command decomposition, migration sequencing, UI workflow design, and test implementation. Those activities must make these contracts more specific without silently reopening them.
