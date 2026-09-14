# **DepartureDesk MVP Requirements**

## **Version 0.5 Organized Requirements Draft**

This document is the current working specification for the DepartureDesk MVP. It consolidates accepted requirements into the sections they govern, identifies the few remaining choices, and records exclusions in the deferred-scope section. Appendix B retains a compact index of earlier scoping decisions without functioning as a second requirements source.

Detailed accepted commercial and financial rules live in the companion [Commercial Domain Decision Register](commercial-domain-decision-register.md). They are linked rather than duplicated here.

DepartureDesk explains the departure. It calculates deterministic results from recorded terms, tracks decisions and evidence, and references specialized external systems without attempting to replace them.

## **Document status**

| Field | Current requirement |
| :---- | :---- |
| Document status | Working specification for acceptance, version 0.5 |
| Primary audience | Product, design, engineering, implementation planning, and acceptance-test authors |
| Supersedes within the compiled notes | The Legacy Infrastructure section and embedded Party-based terminology standard |
| Preserved authorities | Agency isolation, auditability, immutable posted money, explicit currency, historical snapshots, and command-level authorization unless amended here |
| Example Departures | Celebrity Beyond Eastern Caribbean Cruise and Vineyard Tour, used to test generality across Departure types rather than define a literal feature list |
| v0.5 organization | The v0.4 addendum is folded into governing sections; resolved and deferred items are removed from the open register; Appendix B becomes a non-governing decision index |

## **Document map**

* 1 Executive MVP definition

* 2 Governing domain and integrity principles

* 3 Agency, Office, Users, roles, and support access

* 4 Client and Supplier profiles

* 5 Departures, Packages, Client Trips, and services

* 6 Supplier Arrangements, inventory, capacity, and commitments

* 7 Client and Supplier financial contracts

* 8 Trip-specific services

* 9 Cancellations and change handling

* 10 System authority and external boundaries

* 11 Reporting, readiness, reconciliation, and closeout

* 12 Security, tenancy, audit, and historical integrity

* 13 MVP scope and deferred capabilities

* 14 Remaining decisions

* 15 Implementation sequence

* 16 Acceptance examples and test coverage

* Appendix A Source disposition and terminology alignment

* Appendix B Resolved decision index

## **Requirement labels**

| Label | Meaning |
| :---- | :---- |
| Locked for MVP | Treat as the current requirement unless deliberately amended. |
| Open decision | Resolve before the affected implementation slice; do not infer an answer from examples. |
| Deferred | Excluded from MVP, although the model should not prevent a reasonable later extension. |
| External authority | DepartureDesk records status, evidence, or summary; another system or Supplier makes the authoritative decision. |

# **1 Executive MVP definition**

DepartureDesk is an agency-scoped operational and commercial subledger for group travel. Its core job is to connect what the agency offers, what clients select, who travels, how suppliers fulfill the services, what each side owes, what has been paid, what remains at risk, and what must happen next.

## **Core questions the MVP must answer**

* Whose agency data is this and who may act?

* What departure is being operated and which office is responsible (for reporting and defaults only \- see Section 3)?

* What packages and services are offered?

* Which client trips and travelers participate, and who is the responsible payer for each?

* How is each service fulfilled and what inventory does it consume?

* What do clients owe and what funds have been received?

* What does the agency owe suppliers and what has been paid?

* Which commitments, deadlines, confirmations, and unresolved risks remain?

* What changed through cancellation, substitution, adjustment, or reconciliation?

## **Primary record flow**

| Layer | Primary records | Governing question |
| :---- | :---- | :---- |
| Tenant and access | Agency, Office, Agency User, Access Role, Support Access Grant | Who owns the data and who may act? |
| Directory | Client Person, Client, Client Organization, Household, Supplier, Supplier Contact | Who is involved and in what bounded business context? |
| Departure operations | Travel Program, Departure, Package, Client Trip, Client Trip Service | What is offered, selected, and coordinated? |
| Fulfillment | Supplier Arrangement, Supplier Reservation, Service Occurrence, Supplier Resource, assignments | How is each service provided and who receives it? |
| Financial | Charge, Receipt, Supplier Obligation, Supplier Payment, credits, refunds, commission | Who owes, who paid, and what remains? |
| Change and closeout | Cancellation Case, adjustments, reconciliation, closeout | How are later consequences preserved and resolved? |

**Locked for MVP.** Agency is the tenant; Departure is the dated operational unit; Client is the payer identity for a commercial relationship (its own record, distinct from Client Person and Client Organization); Client Trip is the client-facing commercial record; Client Trip Service is the common service envelope; posted financial history is corrected through explicit subsequent records.

# **2 Governing domain and integrity principles**

Agency is the sole tenant and business-data boundary. Office is an operating and reporting dimension, not a second tenant.

Client, supplier, and agency-user domains remain separate. No universal Party identity links them merely because they describe the same physical person or organization.

Traveler, responsible Client, payer, booking contact, household member, and resource occupant are distinct roles.

Client price and supplier cost are independent. Neither changes silently when the other changes.

Capacity and financial commitment are independent. Held or available inventory is not automatically payable.

A Charge is not a Receipt. A Supplier Obligation is not a Supplier Payment. Applications connect the applicable records.

Client and supplier ledgers remain independent. A refund, credit, cancellation, or payment on one side does not manufacture the corresponding event on the other.

Supplier-collected money can satisfy client value but never enters agency-controlled cash.

Draft facts may be edited. Posted or finalized financial facts are immutable and corrected through adjustments, credits, reversals, refunds, and superseding records.

Consequential records snapshot the names, terms, destinations, prices, and evidence needed to preserve historical meaning.

## **Naming rules**

| Use | For |
| :---- | :---- |
| Departure | One dated occurrence of coordinated travel |
| Travel Program | Reusable or recurring travel concept |
| Client Trip | Agency relationship with one primary Client on a Departure |
| Client Trip Service | One promised, purchased, assigned, or recorded service |
| Supplier Arrangement | Governing agreement with a Supplier |
| Supplier Reservation | Specific requested or confirmed Supplier booking |
| Traveler Assignment | Who receives a service |
| Resource Assignment | Placement into a cabin, room, seat, or vehicle |
| Responsible Client | Who owes the Agency for a Charge |

# **3 Agency office users roles and support access**

## **Agency**

An Agency is the travel business operating one logically isolated tenant. It owns agency users, directories, travel records, financial history, configuration, documents, communications, and audit history.

| Field | Current requirement |
| :---- | :---- |
| Required identity | UUID, display name, optional legal name, controlled workspace code or slug, country, default currency, IANA time zone, status, lock version, timestamps |
| Document-facing additions | Address, public email and phone, website, logo, sender and reply-to identities, footer, legal disclosures, and Seller-of-Travel registration/license number before client documents ship |
| Lifecycle | Active, suspended, or closed; lifecycle changes retain history and never cascade-delete |
| Defaults | Seed new records only; later default changes do not reinterpret existing money, dates, or documents |

***New this revision.** Seller-of-Travel registration/license number added to Agency identity \- several US states require it on client-facing documents and contracts.*

## **Office**

An Office is an agency-defined branch, division, location, or operating unit used for responsibility, defaults, workflow filtering, and reporting attribution. It is not a tenant, legal entity, permanent directory owner, or MVP security boundary.

Every active Departure has one current responsible Office.

Office reassignment is audited and preserves prior attribution.

Client and Supplier identities remain agency-wide.

Current Office supplies workflow context and defaults but never replaces Current Agency.

Inactive Offices cannot receive new assignments but remain visible historically.

Staff may collaborate across Offices in MVP. Restricted Office visibility is deferred.

**Locked for MVP.** Responsible Office is reporting and default-assignment metadata only. It does not restrict which Agency Users may view or act on a Departure in MVP; it carries no authorization behavior.

## **Agency User**

An Agency User is an independent login record belonging to exactly one Agency. The same normalized email may exist in different Agencies without disclosing or linking those relationships. Email is unique within an Agency.

| Field | Current requirement |
| :---- | :---- |
| Required data | Agency, name, normalized login email, optional title and phone, agency relationship, one access role, lifecycle status, Office affiliations, default Office, invitation and sign-in metadata, lock version, timestamps |
| Agency relationship examples | Employee, independent contractor, host-agency affiliate, outside accountant; descriptive only and does not grant access |
| Lifecycle | Invited, active, suspended, closed |
| Authentication context | Agency must be established before email and password lookup; sessions bind Agency User and Agency |

## **MVP roles and permissions**

| Role | MVP authority |
| :---- | :---- |
| Administrator | Ordinary work plus Agency profile, Offices, Users, role assignment, defaults, audited overrides, final closeout, and reopening; never platform-wide authority. |
| Staff | Ordinary directory, departure, sales, payment, supplier, and operational work; cannot manage access/settings, restricted overrides, or reopening. |
| Viewer | View authorized records and ordinary reports; no creation, updates, posting, cancellation, sending, upload, sensitive bulk export, or other side effects. |

* Use a centrally defined permission catalog.

* Assign exactly one system role per Agency User.

* Use hardcoded role-to-permission mappings for MVP.

* Application code checks named permissions rather than role names.

* Do not provide agency-configurable roles or direct per-user permission overrides in MVP.

* Prevent removal, suspension, or demotion of the last active Administrator.

* Each Client Trip carries one assigned Agency User as its primary point of contact, separate from responsible Office, used for routing and "my clients" views. No commission-split logic attaches to this in MVP.

## **Platform support access**

Platform Users authenticate separately and do not belong to Agencies. Platform status does not provide ambient tenant access. Entry requires a time-limited Support Access Grant for one Agency and creates an audited Support Session.

| Requirement | MVP rule |
| :---- | :---- |
| Default level | Read-only |
| Grant facts | Agency, Platform User, ticket or incident, reason, scope, requester, approver, timestamps, expiration, revocation, consent basis, emergency flag |
| Tenant interface | Persistent support banner with Agency, scope, reason, expiration, and exit |
| Attribution | Support acts as itself; never impersonates an Agency User in audit history |
| Sensitive data | Masked by default; credentials, password data, MFA secrets, and payment credentials are never viewable |
| Corrective access | Purpose-built audited repair commands; break-glass requires reauthentication, short duration, incident reference, notification, and review |

**Deferred.** Custom roles, per-user overrides, restricted Office visibility, external collaborators, cross-agency single sign-on, global user identity, host-agency sharing, and automated ticket-system support grants.

# **4 Client and supplier profiles**

## **Separate directory domains**

DepartureDesk maintains separate agency-owned client and supplier contexts. Similar names or contact details create duplicate warnings only within the relevant domain and never imply a cross-domain identity match.

| Record | Purpose | MVP distinction |
| :---- | :---- | :---- |
| Client Person | Individual in the consumer-side directory | May later act as Client, Traveler, payer, contact, organizer, or leader through explicit contextual roles. |
| Client Organization | Company, school, church, club, or association | May sponsor, organize, purchase, or pay for travel. Can be a Client. Can never be a Traveler. |
| Client | The payer identity for a commercial relationship | Its own record: references exactly one Client Person or Client Organization, plus commercial-only fields (billing terms, credit-hold status, statement preferences). Owns Charges, pays, sponsors Travelers, and owns Client Trips; not necessarily a Traveler. |
| Client Household | Agency-maintained servicing and communication grouping | Not a Client, account, payer group, trip, rooming group, or insurance household. |
| Supplier | Legal or commercial entity from which the Agency procures service | Separate from Client Organizations and Agency Users. |
| Supplier Location | Property, venue, terminal, or place associated with a Supplier | Not necessarily the legal contracting Supplier. |
| Supplier Contact | Person representing a Supplier in a work context | Not linked to a Client Person or Agency User merely because contact values match. |

**Locked for MVP.** A Client is its own record \- agency, a reference to exactly one Client Person or Client Organization, and commercial-only fields \- not a role flag added directly to Client Person or Client Organization. Every Charge and Client Trip references a Client. A Traveler Assignment always resolves to a Client Person; a Client Organization can never be a Traveler. Whether a Traveler is also the trip's responsible Client is incidental, not structural (see acceptance examples 3, 4, and 13 in Section 16).

## **Households**

A current Household has at least one current member and exactly one current primary contact.

Membership is effective-dated and historical changes are preserved.

A person may appear in more than one Household for a legitimate servicing reason.

Primary contact must be a current member.

Familial relationships are separate from Household membership.

Membership never implies travel, responsibility, payment, occupancy, communication authority, or insurance eligibility.

Client Trips and Charges identify an individual or organization Client explicitly.

Travelers on a Client Trip need not share any Household relationship with each other or with the responsible Client \- a Client Organization sponsoring unrelated employee Travelers is a normal case, not an exception.

## **Traveler identity data**

Traveler Assignment snapshots the trip-specific facts needed to fulfill and price the service: date of birth (or age at time of travel), and, where required for international travel, structured passport data \- number, issuing country, expiration date, name as it appears on the passport, and nationality.

**Locked for MVP.** Date of birth and passport fields are captured as structured data on the Traveler Assignment snapshot, consistent with the general snapshotting principle in Section 2 (these are point-in-time facts about the trip, not permanent facts about the Client Person). Age-based pricing exceptions (for example, a free lap infant or a free child up to an included-occupant count) are supported as flat, categorical rules keyed to a Traveler's rate category. Pricing that recalculates based on occupancy composition \- sliding scales, additional-occupant discount tiers that vary with who else is in the room \- remains deferred as "complex family/child occupancy pricing" (Section 13). Scanned passport images, if retained at all, are stored through the external secure-document-repository pattern in Section 10 (requirement, receipt, verification, expiration, reviewer, submission, external reference) rather than as a new sensitive-document vault inside DepartureDesk.

## **Contact points and communications**

Supported contact points are email, phone, and postal address.

A simple label, one preferred active destination per owner/channel, verification, consent, suppression, bounce, and disconnection may be recorded.

Contact purpose is contextual: booking contact, billing contact, on-trip contact, emergency contact, Supplier Arrangement contact, remittance contact, or group leader / trip coordinator.

A Household may use its primary contact or a genuinely shared destination; the interface identifies the source.

Every sent or attempted Communication snapshots recipient display name, contextual role, actual destination, related records, content/template version, actor, time, status, and external reference. The actor may be a human Agency User or the system/scheduled process for automated, transactional communications (see Section 11, Deadlines and reminders).

Directory email is not login identity merely because the literal value matches.

***New this revision.** Group leader / trip coordinator added as a contact purpose (not a distinct access role or portal login \- see Section 13). This gives staff a place to record and reach the group's coordinating contact without building portal-style external access.*

## **References search duplicates merge and lifecycle**

| Field | Current requirement |
| :---- | :---- |
| References | Immutable Agency-scoped human references; prefixes finalized through numbering policy; UUID remains relational identifier |
| Search | Agency-scoped and domain-aware; client search does not silently mix Supplier Contacts or Agency Users |
| Duplicate handling | Warn, allow eligible existing selection, and permit audited create-anyway; never auto-merge or disclose cross-agency data |
| Merge | Same Agency and compatible domain only; retain tombstone, aliases, and history; no cross-domain merge or automatic unmerge |
| Lifecycle | Active/inactive with dependency checks; historical records resolve after inactivation |
| Snapshots | Preserve supplier-facing names, statement addressee, responsible-client and payer names, contracting Supplier, confirmation issuer, communication destination, and document branding where consequential |

**Deferred.** Universal Party identity, cross-domain linking, automatic contact synchronization, Household financial accounts, generalized contact-purpose systems, client/supplier portals (including a Group Leader access role), automatic waitlisting, marketing automation, organization trees, shared global Supplier masters, and external identity enrichment.

# **5 Departures packages client trips and services**

## **Travel Program and Departure**

A Travel Program is an optional reusable concept or series. A Departure is one dated occurrence and the primary operational record. Industry uses of "group" remain qualified, such as group agreement, group leader, or supplier group number.

## **Lifecycle states**

| Record | MVP lifecycle | Boundary note |
| :---- | :---- | :---- |
| Departure | Draft, active, departed, closeout review, closed, reopened | Closing requires the accepted blocker/warning evaluation and creates an immutable versioned snapshot. Reopening requires an Administrator and preserves prior snapshots. |
| Client Trip | Draft, confirmed, traveled, cancelled or abandoned; cancellation in progress where consequential history exists | Confirmation atomically snapshots terms, confirms allocations, and posts only Charges currently due. Later change uses amendment, cancellation, or linked replacement rather than status rollback. |

## **Package**

A Package is a client-facing collection of services. Packages may define included services, choices, price, eligibility, sales capacity, payment schedule, and client terms. A Departure may also sell or record services without a Package.

**Locked for MVP.** Occupancy-based pricing (first/second/additional/single, double/single, and similar positions) is calculated at the resource or Client Trip Service level only. A Package-level occupancy selection (for example, the Vineyard Tour's double/single choice) is an input that seeds expected resource demand before actual assignments exist; it is not an independent second pricing mechanism. Actual room, cabin, or seat assignments remain their own records and may diverge from the package-level estimate. Occupancy-position pricing has no hardcoded ceiling; the cruise and hotel examples are illustrative rather than limiting.

## **Client Trip**

A Client Trip is the operational and commercial record for serving one primary Client within one Departure. It contains Travelers, selections, services, Charges, payment schedules, Receipts and credits, documents, acknowledgments, and communications. Separate Client Trips may share resources without merging balances or private context. Each Client Trip carries one assigned Agency User as its primary point of contact (see Section 3).

## **Client Trip Service**

| Field | Current requirement |
| :---- | :---- |
| Purpose | One service promised, sold, assigned, or recorded for a Client Trip |
| Common facts | Agency, Departure, Client Trip, category, description, requirement, source, dates, Travelers, price, currency, confirmation, fulfillment, provider, external reference, cancellation terms, notes |
| Selection treatment | Included, optional, required choice, or trip-specific |
| Fulfillment methods | Group allocation, individual Supplier booking, Agency fulfillment, externally managed, or not yet arranged |
| Inventory sources | Group block, individual Supplier inventory, on request, external, or none |

## **Assignments**

Traveler Assignment identifies who receives a Client Trip Service. It always resolves to a Client Person, never to a Client Organization.

Resource Assignment places a Traveler into a specific cabin, room, seat, vehicle, or other resource for applicable dates.

Traveling Party describes coordination or companionship only and does not create service, resource, Household, privacy, or financial facts.

Primary Client, responsible Client, payer, booking contact, and trip coordinator remain independent.

## **Required choice groups**

A choice group is a general mechanism attachable to any Client Trip Service, whether sourced from a Package or trip-specific. Each group defines a minimum and maximum number of selections and any number of options, each of which may be included at no additional charge or carry its own price. The Vineyard Tour dinner choice \- exactly one of two, one included and one surcharged \- is the acceptance example the mechanism must support, not the limit of what it supports.

**Locked for MVP.** Choice groups support arbitrary minimum/maximum selection counts and any number of options, and attach directly to a Client Trip Service rather than being gated by the presence of a Package. Only a selected alternative creates the applicable service assignment; a priced option also creates its Charge. Changing a selection releases and consumes the applicable capacity and posts an explicit financial adjustment when necessary.

## **Documents and waivers**

A Client Trip's documents include itineraries, invoices, confirmations, waivers, and rooming lists generated by DepartureDesk from its own recorded data, not only externally uploaded files. A rooming list is built from current Traveler and Resource Assignments rather than the Package's original occupancy estimate.

Generated documents and Communications use system-defined, versioned templates parameterized by the Agency branding fields in Section 3\. Agencies cannot edit template content in MVP.

**Locked for MVP.** Waiver execution for MVP is captured as either an uploaded signed or scanned copy, or a lightweight in-app acknowledgment (checkbox, actor, and timestamp, following the same snapshot pattern used for Communications). Native, legally certified e-signature capture (ESIGN/UETA-compliant, tamper-evident, audit-trailed) is deferred; if adopted later, it is integrated as a referenced external fact \- the same treatment as payment processing in Section 10 \- rather than built natively.

# **6 Supplier arrangements inventory capacity and commitments**

## **Supplier fulfillment records**

| Record | Meaning |
| :---- | :---- |
| Supplier Arrangement | Governing commercial agreement for a Departure or defined set of services. |
| Supplier Reservation | Specific requested, held, or confirmed Supplier booking; may stand alone or relate to an Arrangement. |
| Supplier Resource | Concrete capacity-bearing unit such as cabin, room, coach, or seat. |
| Service Occurrence | One dated and optionally timed performance, such as a particular transfer or excursion. |
| Confirmation | Qualified Supplier acknowledgment or identifier for a specific Arrangement or Reservation. |

## **Inventory and commitment distinctions**

| Concept | Meaning | Must not imply |
| :---- | :---- | :---- |
| Capacity | Maximum supported Travelers or units | That capacity is held, sold, guaranteed, or paid |
| Block | Capacity held under Supplier release or guarantee terms | That every blocked unit is guaranteed |
| Allotment | Inventory made available, not necessarily guaranteed | A payable commitment |
| On request | Availability requires Supplier confirmation | Current available inventory |
| Guarantee | Quantity or amount payable regardless of final use | That the units are sold or assigned |
| Inventory allocation | Some managed availability reserved internally | Supplier confirmation or resource placement |
| Utilization | Used or allocated quantity divided by a labeled capacity basis | One universal denominator |
| Exposure | Estimated risk from commitments or paid cash not expected to be recovered | A posted accounting loss |

**Locked for MVP.** Supplier Resource capacity is always scoped to a Service Occurrence with a date range. A resource with one fixed capacity for an entire engagement (a cruise cabin for the whole sailing) is modeled as a single occurrence spanning that full period; a resource with nightly variation (a hotel room block) is modeled as one occurrence per night. This is one mechanism, not two separate capacity models.

## **Supplier cost structure and quantity patterns**

Supplier Arrangement cost is modeled as a set of typed line-item components (for example: base, tax, fee, discount, commission), each with its own commissionable and taxable treatment, rather than one fixed formula per supplier type. The patterns below describe the component types and combination rules an Arrangement may use, not a menu of mutually exclusive formulas \- the cruise's five-component fare, the hotel's base-plus-tax-less-commission-plus-markup, the fixed coach cost, and the excursion's cost-plus-markup all compose from the same set of typed pieces.

* Fixed cost per Supplier arrangement or operated occurrence

* Per resource, such as cabin or room

* Per person or Traveler

* Per room-night

* Minimum billed quantity or guarantee

* Blocked versus guaranteed inventory

* Tier or occupancy position selected from a recorded price table

* Percentage deposit or commission applied to an explicit base

* Zero-cost or informational fulfillment when explicitly recorded

Occupancy-position price tables may contain as many positions as the Supplier terms require. No cruise, hotel, or other service-specific ceiling is hardcoded.

**Locked for MVP.** A mid-trip or later Supplier rate change is recorded through a Supplier Cost Adjustment event. Posted Supplier cost history is adjusted rather than edited, and the adjustment does not require a Cancellation Case unless the service is also being cancelled.

**Locked for MVP.** Threshold-triggered capacity (for example, one vehicle required per 15 seated Travelers) is a general pattern available to any Supplier Arrangement with per-unit capacity: DepartureDesk calculates the number of units required from confirmed counts and a configured threshold. Creating the additional Service Occurrence once a threshold is crossed remains a manual action by staff for any resource type, not an automatic system action.

**Locked for MVP.** Capacity changes do not silently create or release financial commitments. Contract terms create forecasts or commitments. A deterministic contractual milestone may post a Supplier Obligation only when amount, currency, due date, source lines, and triggering terms are complete; ambiguous or discretionary terms create a review item. Every Supplier Arrangement using a minimum-billed-quantity pattern carries an explicit cancelable\_below\_minimum flag recording whether the Agency may cancel without cost when the minimum is not reached, or must operate and pay the minimum regardless \- removing what was previously a case-by-case judgment call.

# **7 Client and supplier financial contracts**

## **Client ledger**

| Record | Contract |
| :---- | :---- |
| Charge | Posted amount owed to the Agency by one responsible Client in MVP. |
| Payment Schedule | Expected installments and due dates; not money received. |
| Receipt | Money received and controlled by the Agency. |
| Receipt Application | Applies Receipt or eligible Client credit to a Charge. |
| Unapplied Funds | Agency-controlled money not yet applied. |
| Client Credit | Noncash value reducing or available against an amount owed. |
| Client Refund | Agency-controlled cash returned to a Client or payer. |
| Supplier-collected Payment | Externally held Client payment that may satisfy value but does not enter Agency cash. |

## **Supplier ledger**

| Record | Contract |
| :---- | :---- |
| Supplier Cost | Expected or required cost of fulfillment; separate from Client price. |
| Commitment | Earlier contractual exposure that may not yet be a payable Obligation. |
| Supplier Obligation | Amount sufficiently definite that the Agency expects or is required to pay. |
| Supplier Payment | Agency-controlled money sent to a Supplier. |
| Supplier Payment Application | Applies a Supplier Payment or eligible Supplier credit to an Obligation. |
| Supplier Refund | Cash returned by a Supplier. |
| Supplier Credit | Noncash value reducing an obligation or available under Supplier restrictions. |
| Supplier-held Future Travel Credit | Externally held value with eligibility, expiration, transferability, and remaining balance. |

**Locked for MVP.** Each Payment Schedule installment, once confirmed by an authorized user, posts as its own Charge \- a booking may post a deposit Charge at booking time and a separate final-payment Charge later, rather than one lump Charge for the full sale. Deposit is not a separate record type; it is a category on a Payment Schedule installment / Charge (deposit, final payment, other). This lets a forfeited deposit be retained as itself under a cancellation disposition (Section 9\) without introducing a fourth ledger concept.

## **Financial invariants**

Each amount has explicit currency; currency mismatch raises rather than converting implicitly.

**Locked for MVP.** One operating currency per Departure. There is no multi-currency accounting, implicit conversion, or FX in MVP (see Section 13); this is a lock, not a soft recommendation.

**Locked for MVP.** Each Receipt is limited to one Departure. This is a hard MVP boundary. A Client paying across multiple Departures in one transaction is recorded as multiple Receipts, entered by staff as separate actions, optionally sharing an external payment reference for traceability. Within one Departure, a Receipt may apply to multiple Client Trips.

Each Charge has one responsible Client for MVP.

Posted Charges are adjusted, credited, reversed, or replaced rather than edited.

Payment processing remains external; safe processor references may be stored.

Estimated, quoted, contracted, committed, obligated, paid, credited, refunded, and final-billed stages must not be added together as separate costs.

Final billed cost is recorded during reconciliation without deleting earlier estimates or commitments.

## **Commission**

Commission requires separate calculation, earning, settlement, and cash states. Expected, earned, retained from net remittance, received from Supplier, and reversed are different facts. Supplier gross, net remittance, and later commission receipt must reflect what actually occurred rather than being inferred from a percentage.

Insurance commission uses this same Commission lifecycle and ledger treatment. It is not a separate revenue mechanism; it appears in Supplier balance and margin reporting like commission attributable to any other service.

## **Earned credit and loyalty programs**

**Locked for MVP.** Supplier earned-credit programs (for example, cruise Tour Conductor credit) are tracked as supplier-specific data for MVP \- the earning rule and outcome are recorded on the Arrangement, not modeled as a general, reusable loyalty-program construct. Generalize only if a second supplier requires the same shape (see Section 13).

## **Core calculated measures**

| Measure | Working definition |
| :---- | :---- |
| Client balance | Posted Charges less active Receipt, Client Credit, and Supplier-collected Payment Applications |
| Unapplied Receipt | Posted Receipt amount less active applications |
| Supplier balance | Posted Supplier Obligations less Supplier credits and Supplier Payment Applications |
| Operational cash position | Client Receipts plus Supplier Refunds and Commission Receipts, less Client Refunds, Supplier Payments, and paid Agency Costs |
| Projected margin | Projected Client revenue plus expected attributable commission, less one best expected-final-cost projection per Supplier source and planned Agency Costs |
| Actual operational margin | Final eligible Client revenue plus earned commission, less final reconciled Supplier costs and posted Agency Costs |
| Exposure | Always qualified: gross commitment, expected net, unsold guarantee, or Agency cash at risk |

For a bundled Package with a non-decomposable client price, margin remains at Package level. Per-service allocation of that price is deferred because DepartureDesk cannot calculate it deterministically from recorded terms.

The [commercial-domain decision register](commercial-domain-decision-register.md) governs posting, applications, corrections, refunds, responsibility transfer, commission, calculations, reporting, export, and closeout. Detailed slice plans must make those contracts executable without reopening them implicitly.

# **8 Trip specific services**

A Client Trip may contain required or optional services not drawn from a Departure Package or group inventory. These records use the same Client Trip Service envelope and participate in balances, Supplier cost, commission, operations, and profitability where applicable, but they do not alter group capacity unless explicitly linked.

| Service family | Source and fulfillment | MVP treatment |
| :---- | :---- | :---- |
| Transferred individual cruise booking | Transferred booking; individual Supplier reservation | Retain individual fare, terms, deposits, payments, cabin, and transfer confirmation; associate to group without consuming group block. Track group-benefit eligibility independently. |
| Travel insurance | Trip-specific Supplier booking; individual policy | Track plan, policyholder, covered Travelers, eligibility snapshot, insured cost, premium, collection, policy number, documents, acceptance or declination; no inventory. |
| Agency-issued air | Agency-issued; Air Reservation and passenger Tickets | Track PNR, segments, ticketing deadline, ticket documents, Client Charges, settlement obligation, fee, commission, and readiness; ticketing remains external. |
| Miscellaneous service | Supplier, Agency, or external fulfillment | Require meaningful category, description, dates, provider, scope/Travelers, price, cost or explicit unknown, confirmation, fulfillment status, and cancellation terms. |

**Locked for MVP.** A miscellaneous trip-specific service fulfilled by a third-party Supplier receives a minimal Supplier Arrangement or Supplier Reservation so its cost enters the standard Obligation and Payment ledger. It does not need capacity or a block. A service with no third-party Supplier uses Agency fulfillment and does not create a fabricated Supplier record.

* Source and fulfillment method are separate facts.

* A service may exist without a Package, group block, capacity pool, Departure-wide price, or Departure-wide Supplier Arrangement.

* Previously paid Supplier money is recorded as externally reported Supplier-collected value, not fabricated as a current Agency Receipt.

* Transferred bookings do not use group pricing or inventory merely because they carry the group number.

* Insurance household eligibility is snapshotted from the policy and never inferred from Client Household membership.

* One PNR may include several Travelers, but each issued Ticket belongs to one Traveler.

* The Agency is represented as Agency fulfillment, never as a fake Supplier.

* Repeated miscellaneous categories should graduate to a specialized extension.

**Locked for MVP.** Provide a generic Client Trip Service plus specialized detail records for transferred cruise booking, insurance policy, Air Reservation, and Ticket. Keep miscellaneous services lightweight but structured.

# **9 Cancellations and change handling**

Cancellation is a controlled operational and financial disposition. It identifies what will no longer be provided and records consequences without erasing the original sale, payment, Supplier commitment, or assignment.

## **Supported scope**

| Scope | Examples and implications |
| :---- | :---- |
| Entire Departure | Resolve every Client Trip, Charge, Arrangement, commitment, payment, commission, and optional service individually; never blind cascade. |
| Entire Client Trip | Cancel remaining services while preserving fulfilled services, nonrefundable value, fees, and history. |
| One Traveler | May change occupancy pricing, assignments, counts, insurance, credits, commission, and Supplier penalties. |
| One Client Trip Service | Cancel excursion while retaining cruise, hotel, and transfers. |
| One occurrence or assignment | Cancel a hotel night, one transfer, an excursion, or externally permitted air segment without inferring wider scope. |

## **Cancellation Case**

| Field | Current requirement |
| :---- | :---- |
| Core facts | Agency, Departure, Client Trip, exact scope, request and effective dates, requester, reason, actor, status, policy snapshots, evidence |
| Disposition families | Operational, Client financial, Supplier financial, commission, capacity |
| Lifecycle | Draft, awaiting Supplier response, quoted, approved, posted, withdrawn, superseded |
| Immutability | Draft can change; posted corrections use later adjustments |
| Preview | Show original Charge, Client credit, Supplier-cost recovery, Agency fee, payments, refund or credit, Supplier cost/credit/penalty/refund, commission, capacity, and unknowns |

## **Client side posting pattern**

* Preserve the original Charge.

* Credit the portion no longer owed.

* Post Supplier-cost recovery as a separate Charge chosen by the Agency; never assume it equals Supplier penalty.

* Post an Agency cancellation fee separately and retain waiver/override evidence.

* Reverse or reapply Receipt Applications as authorized.

* Record Client refund or same-Departure Client credit as its own disposition.

## **Supplier side posting pattern**

* Preserve original commitment, Obligation, deposit, and Payment.

* Record released cost through explicit Supplier credit or adjustment.

* Retain a forfeited deposit as the original deposit with a cancellation disposition, not a relabeled generic penalty.

* Record a new Supplier penalty Obligation separately when imposed.

* Distinguish Supplier cash refund, account credit, and Supplier-held future travel credit.

* Do not automatically pass a Supplier benefit to the Client.

## **Operational consequences**

* Capacity release is independent from financial release.

* Cancellation may reprice remaining Travelers; preserve old occupancy positions and post approved Charge adjustments.

* Use distinct actions for Cancel Traveler, Replace Traveler, Correct Legal Name, Move Traveler, and Cancel Booking.

* Commission may remain, reduce, reverse, be forfeited, or remain expected; record the actual consequence.

* Material unknowns cannot be silently treated as zero in the posting preview.

* Unresolved Cancellation Cases may block Departure closeout.

**Locked for MVP.** The calculate-versus-review boundary for cancellation is structural: a policy expressed fully as ordered date-or-threshold tiers with a fixed percentage or amount per tier (for example, the excursion's "before September 24, full refund; on or after, noncancellable") is calculated automatically. A policy that doesn't fit that shape \- discretionary per-guest exceptions, multi-factor fee schedules such as the cruise's name-change rules \- falls to the manual Cancellation Case review workflow. Store straightforward structured policies and calculate obvious consequences under this test; rely on the reviewed disposition workflow for everything else. Require explicit Supplier confirmation, Client recovery, Agency fee, credits/refunds, and audit of overrides and waivers. A universal penalty formula language remains deferred. See Section 6 for the related cancelable\_below\_minimum field.

# **10 System authority and external boundaries**

DepartureDesk should calculate a result when structured inputs and deterministic rules make the result reproducible. It should track a result when a Supplier or person must decide and evidence matters. It should reference a fact when a specialized external system owns the transaction, document, or real-time state.

| Treatment | DepartureDesk responsibility | Examples |
| :---- | :---- | :---- |
| Authoritative and calculated | Own inputs and calculate reproducible operational or financial result | Client and Supplier balances, remaining inventory, guarantee exposure, vehicles required, deposits, expected commission, projected margin |
| Authoritative but manually confirmed | Own status, history, evidence, and downstream workflow; person or Supplier decides | Name-change approval, accessible room, airport exception, final transfer time, cancellation disposition, Supplier credit |
| Referenced external fact | Store safe identifier, summary, status, snapshot, and reconciliation evidence | Card authorization, Supplier reservation, hotel PMS confirmation, insurance policy document, airline ticketing, accounting journal, scanned identity documents, e-signature execution |

## **Calculate in DepartureDesk**

* Cruise price components, occupancy-position selection, commission, Supplier gross and expected net

* Hotel base, tax, commission, markup, additional-adult charge, stay price, guarantee, and expected net cost

* Transfer vehicles required, remaining seats, fixed Supplier cost, Client revenue, and threshold effect

* Excursion paid count, minimum status, cost, revenue, and margin

* Deposit requirements and applications from explicit contract bases

* Capacity positions, assignments, utilization, and qualified exposure

* Client and Supplier balances, Agency cash position, Supplier-collected value, and projected/actual operational margin from posted facts

* Contractual deadlines and readiness warnings from structured rules

## **Track and confirm**

* Supplier confirmation and on-request availability

* Cruise name-change eligibility result, approval, fees, and restrictions

* Accessibility fulfillment and Advisor exceptions

* Final transfer schedules and Supplier acknowledgment

* Hotel room confirmation

* Commission confirmation and settlement

* Tour Conductor credit confirmation

* Cancellation consequences and evidence

* Manual contract interpretation with author, source, and effective date

## **Leave outside the MVP**

| External domain | DepartureDesk retains |
| :---- | :---- |
| Payment processor | Receipt/reference/application; no raw card data or native processing |
| Accounting system | Departure subledger and export status; no general ledger, bank reconciliation, payroll, statutory reporting, or formal statements |
| Supplier reservation platforms | Local request, confirmation evidence, snapshots, and reconciliation; no live inventory or reservation execution |
| GDS, carrier, ARC, or BSP | PNR, ticket, Client price, commission, and settlement summary; no issuance, exchanges, EMD, memo, or period-reconciliation engine |
| Insurance platform | Offer, selection, covered Travelers, insured cost, premium, policy number, status, and documents; no underwriting, claims, or servicing |
| Secure document repository | Requirement, receipt, verification, expiration, reviewer, submission, and external reference \- including passport scans and executed e-signature certificates if adopted; full sensitive-document storage requires separate approval |
| Transportation operations | Contracted vehicle, assignments, schedule, pickup, and contact; no GPS, routing, telematics, driver hours, or dispatch |
| Incident and claims systems | Operational note and external case reference; no legal, medical, security, or detailed accident case management |

# **11 Reporting readiness reconciliation and closeout**

## **Required operational reporting**

* Departure enrollment and Traveler counts

* Package and Client Trip Service selection

* Group-block, transferred, on-request, and trip-specific fulfillment shown separately

* Capacity by category, night, occurrence, and resource

* Confirmed, assigned, released, guaranteed, and unused quantities

* Deadline and readiness status with evidence

* Client Charges, Receipts, unapplied funds, balances, and past-due installments

* Supplier commitments, Obligations, Payments, credits, balances, and expected refunds

* Commission expected, earned, retained, received, reversed, and unresolved

* Qualified exposure and projected versus actual operational margin

## **Deadlines and reminders**

DepartureDesk generalizes deadlines (deposit due, option date, rooming list due, final payment, ticketing deadline, and others) into one Deadline concept any record can register against: a due date, the related record, and a reminder lead time. A background process checks upcoming deadlines and issues reminders.

**Locked for MVP.** Internal staff reminders are in-app/dashboard alerts only; no email in MVP. Client-facing reminders are limited to payment-related deadlines (deposit, final payment), sent by email only, using a fixed built-in set of triggers \- not agency-configurable in MVP. Client-facing deadline reminders are transactional communications, routed through the existing Communication record (Section 4\) with the sending actor recorded as the system/scheduled process rather than an Agency User. They are distinct from, and not covered by, the marketing automation explicitly deferred in Section 13\.

## **Needs attention queue**

The MVP provides a general staff needs-attention queue in addition to calendar deadlines. It includes at least stale Cancellation Cases, bounced Communications, and capacity approaching a configured threshold. Alerts identify the triggering record and condition and do not replace the underlying workflow or authoritative status.

## **Cross Departure Client history**

A Client profile includes a minimal list of that Client's Client Trips across Departures. Lifetime-value calculations and behavioral segmentation remain deferred.

## **Closeout principle**

A Departure cannot close with unresolved Client receivables, Supplier balances, refunds, unapplied value, commission, or unreconciled financial events unless they are explicitly resolved through an accepted disposition. Hard financial-integrity blockers cannot be waived. Qualified operational warnings require an Administrator waiver with a recorded reason, and small balances require an Administrator-authorized write-off rather than silent zeroing.

Closing creates an immutable, versioned closeout snapshot and rejects new financial postings. Post-close correction requires Administrator reopening with actor, reason, timestamp, and prior-snapshot reference. A later close creates a new snapshot without rewriting earlier reports.

# **12 Security tenancy audit and historical integrity**

* Agency context comes only from authenticated Agency User or active Support Session.

* Request parameters, headers, and unsigned cookies cannot establish Agency context.

* Load ordinary records through Current Agency; agency\_id is not accepted from ordinary form input.

* Cross-agency identifiers return not found without revealing existence.

* Scope search, autocomplete, counts, reports, exports, jobs, broadcasts, and communications by Agency.

* Permission enforcement occurs in queries, endpoints, commands, background jobs, exports, delivery, APIs, and UI; hidden buttons are not authorization.

* Jobs carry an Agency-owned identifier or Agency ID, reload Agency, revalidate lifecycle, and scope all work.

* Every consequential action records the true actor, Agency, subject, time, reason, and before/after or event payload as applicable.

* No ordinary hard deletion of records with operational, financial, communication, document, merge, or audit history.

* Privacy deletion or redaction follows a separate policy-aware process that respects legal and audit retention.

* Command locking and idempotency are required for posting, reversal, transfer, refund, capacity override, closeout, and support repair workflows.

# **13 MVP scope and deferred capabilities**

## **Implement for MVP**

| Workstream | Included scope |
| :---- | :---- |
| Foundation rework | Agency-scoped login identity, Office as reporting/default context only, roles/permissions, Platform Users, Support Access Grants, tenant and audit hardening |
| Directories | Separate Client Person, Client Organization, and Client (payer identity) records, Households, contact points (including group leader as a contact purpose), search, duplicate warnings, lifecycle, snapshots, and domain-safe merge where required before production |
| Departure operations | Travel Programs, Departures, Packages, Client Trips (with assigned Agency User), Client Trip Services, general-purpose choice groups, assignments, service occurrences, confirmations, deadlines, and readiness |
| Supplier planning | Arrangements with composable typed cost components, Reservations, Resources with date-scoped capacity, fixed/per-unit/per-night/minimum cost patterns, general threshold-triggered capacity calculation, block/guarantee/allocation, commitment and exposure, cancelable\_below\_minimum flag |
| Client financials | One responsible Client per Charge, per-installment Payment Schedule/Charge posting with Deposit as a Charge category, immutable posted Charges, Receipts (hard one-per-Departure boundary), applications, same-Departure credits/refunds, balances |
| Supplier financials | Obligations, Payments, applications, credits/refunds, deposits, final cost, commission states, supplier-specific earned-credit tracking, balances |
| Trip-specific services | Generic service path plus transferred cruise, insurance, Air Reservation/Ticket, structured miscellaneous support, and traveler date-of-birth/passport data |
| Documents and reminders | Generated itineraries, invoices, confirmations, and waivers; upload or in-app-checkbox waiver execution; internal in-app deadline alerts; client email reminders for payment deadlines; Agency Seller-of-Travel registration field |
| Cancellation | Case, preview, manually confirmed dispositions, tiered date/percentage automatic calculation with manual-review fallback, explicit credits/fees/penalties/refunds/application changes, capacity and commission consequences |
| Reporting and closeout | Operational and financial summaries, qualified exposure, margin, readiness, reconciliation, and controlled closeout |

## **Explicitly deferred**

* Custom and per-user roles; restricted Office visibility; external collaborators; global identity and cross-agency sharing

* Household financial accounts, universal Party identity, cross-domain merge, automatic contact synchronization, client/supplier portals, and marketing automation

* Group Leader / trip coordinator as a distinct access role or portal login (captured only as a contact purpose for MVP)

* Waitlisting when a capacity category is sold out (the Client Trip Service selection-treatment field can accept a waitlisted value later without a schema change)

* Native e-signature capture (ESIGN/UETA-compliant, tamper-evident, audit-trailed); waivers use upload or in-app acknowledgment instead

* Agency-configurable deadline reminder rules and channels; MVP ships a fixed built-in set

* General earned-credit/loyalty program model (Tour Conductor-style credit is tracked as supplier-specific data only)

* General formula builder for arbitrary pricing or cancellation rules

* Complex family/child occupancy pricing that recalculates based on occupancy composition (flat categorical age-based rules are in scope; see Section 4\)

* Legacy data migration from the prior system, which is a separate initiative

* Agency-defined group-organizer incentive programs, such as one complimentary place per eight paid Travelers

* Per-service margin allocation within a bundled Package

* Full Stored Value and cross-Departure credits

* Multi-currency accounting, implicit conversion, and realized/unrealized FX

* Full general ledger, bank reconciliation, automated revenue recognition, tax filing, and statutory reporting

* Native card processing, disputes, and chargebacks

* Advisor or contractor commission splits

* Automated ARC/BSP reconciliation, air exchanges, residual EMDs, and debit/credit memos

* Live Supplier inventory and booking execution

* Insurance underwriting and claims

* Transportation dispatch and telematics

* Full sensitive identity-document repository (structured passport fields are in scope; scanned images route to the external secure-document pattern)

* Portfolio financial consolidation and cross-client or cross-agency netting

# **14 Remaining decisions**

The [commercial-domain decision register](commercial-domain-decision-register.md) records the accepted financial, cancellation, reporting, closeout, export, and reference-number decisions. Do not reopen those decisions here. Resolve the remaining questions in the first implementation milestone that depends on them.

## **Product-wide question**

| Priority | Decision | Current direction |
| :---- | :---- | :---- |
| P1 | Language and localization | Decide before document generation whether MVP output is English-only or requires locale-aware templates and formatting. |

## **Acceptance-fixture facts**

These questions complete the two reference scenarios and their Supplier terms. They do not establish general architecture by themselves.

* Cruise Hard Stop Date, sailing time, name-change fee schedule, code RED communication, and precise Tour Conductor earning and averaging rules
* Transfer route-specific airport timing standard
* Excursion result below the minimum and detailed inclusions
* Vineyard hotel contract-year conflicts, deposit and option-payment bases, dinner deposit year, lunch dates, coach guaranteed and blocked meanings, and numeric base Package price
* Cancellation, child, lap-infant, accessibility, and substitution terms for Vineyard Suppliers

# **15 Implementation sequence**

The maintained implementation sequence is the [product roadmap](roadmap.md). In summary:

1. Harden and maintain the agency-identity baseline.
2. Build separate Client and Supplier directories.
3. Establish the Departure core.
4. Build Supplier planning, capacity, commitments, and exposure.
5. Add offers and pricing, followed by Client Trips and fulfillment.
6. Add the Client and Supplier subledgers.
7. Add changes, cancellations, documents, deadlines, and operational readiness.
8. Complete reconciliation, closeout, support access, and pilot-readiness work.

Supplier planning precedes packages and client offers so availability, contractual terms, and expected cost exist before the system describes what the Agency can sell. Each milestone must retain the financial and cancellation boundaries accepted in the commercial-domain decision register.

# **16 Acceptance examples and test coverage**

## **Representative acceptance examples**

* The same normalized email signs into separate Agency A and Agency B user records without revealing the other relationship.

* An inactive Office remains on history but cannot receive a new responsible-Office assignment, and its historical presence carries no access implication.

* Martha Smith is a Client Person and, via her own Client record, an individual Client; her Household includes Daniel and Emily, while only selected people become Travelers.

* Olivia Brown's Client record is the responsible Client for Noah Brown's Traveler Assignment without Olivia herself traveling.

* A Client Person and Supplier Contact use the same email without linkage or synchronization.

* Celebrity Cruises is a Supplier with contacts, a group Arrangement, cabin-category block, specific cabin Reservations, and Traveler/Resource Assignments.

* A transferred individual cruise booking associates to the Departure without reducing group-block inventory or adopting group pricing.

* A hotel room can return to internal availability after cancellation while its guaranteed Supplier cost remains.

* A transfer adds a second operated vehicle when seated Travelers exceed 15; lap infants consume neither seat nor price under that service rule.

* The Vineyard package requires exactly one dinner choice and charges only the Deluxe surcharge, using the general choice-group mechanism rather than a bespoke dinner-only implementation.

* A cancellation preserves original Charge and Receipt, posts separate Client credit, Supplier-cost recovery, Agency fee, Supplier consequence, refund/credit, and application changes.

* A Platform User cannot enter a tenant without a valid grant; read-only support cannot mutate; all support activity is attributed correctly.

* A Client Organization sponsors and pays for five employee Travelers who share no Household relationship with each other or with the organization's contact; the Client Organization itself is never a Traveler.

* An excursion configured with cancelable\_below\_minimum \= false requires the Agency to pay the minimum guarantee even though only three of five required paid Travelers confirmed.

* A Departure cannot close while a same-Departure Client Credit remains unapplied; staff must apply, refund, or otherwise resolve it.

* A generated rooming list reflects current Resource Assignments and changes when a Traveler moves between cabins or rooms.

* A staff member can open a Client profile and see that Client's Client Trips across Departures without searching each Departure separately.

## **Required test families**

| Family | Minimum proof |
| :---- | :---- |
| Tenancy and authentication | Agency-scoped lookup, cross-agency non-disclosure, invitations/resets/session binding, jobs and broadcasts |
| Authorization | Permission checks at query, endpoint, command, job, export, and delivery layers; Viewer causes no side effects; last Administrator protected |
| Support access | Grant scope, expiry, revocation, read-only enforcement, sensitive masking, banner, platform and tenant audit |
| Directory | Domain separation, Client/Client Person/Client Organization distinction, Household invariants, contact ownership, contextual routing, snapshots, duplicate safety, merge/tombstones, lifecycle dependencies |
| Departure and service | Package and trip-specific sources, fulfillment methods, Traveler and Resource Assignments, general choice groups (arbitrary min/max), confirmation dimensions |
| Capacity and commitment | Date-scoped occurrences, blocked/guaranteed/on-request distinctions, threshold-triggered unit calculation, allocations, utilization, release without silent financial mutation, cancelable\_below\_minimum |
| Client ledger | Immutable posting, per-installment Charge/Deposit posting, applications, unapplied funds, reversals, refunds/credits, payer/responsibility independence, one-Receipt-per-Departure, currency |
| Supplier ledger | Cost-stage non-duplication, Obligations, Payments/applications, deposits, credits/refunds, commission settlement, supplier-specific earned credit |
| Cancellation | Scope, preview, tiered calculate-vs-review boundary, unknown handling, independent client/supplier/capacity/commission outcomes, repricing, posting correction |
| Documents and reminders | Generated itinerary/invoice/confirmation/waiver, waiver upload/acknowledgment capture, internal in-app alerts, client payment-deadline emails via Communication |
| Closeout | Blockers, waivers, reconciliation, reopening, retained history and report consistency |

# **Appendix A Source disposition and terminology alignment**

| Compiled-notes section | Disposition in this document |
| :---- | :---- |
| Agencies, Offices, Users, and Access | Current; consolidated into Sections 3, 12, 13, and 16\. |
| Infrastructure marked Legacy | Superseded; still-valid tenancy, defaults, lifecycle, and numbering ideas folded into current sections. |
| Client and Supplier Profiles | Current draft; consolidated into Sections 4, 12, 13, and 16\. |
| Embedded terminology standard | Superseded because it retains Party, owning-Office authority, purpose assignments, Service Component, and mixed status concepts. |
| Financial Contracts | Foundational decisions consolidated into Section 7; unresolved items moved to Section 14\. |
| Authority | Consolidated into Section 10 and used to define the MVP boundary. |
| Trip-specific services | Consolidated into Section 8 and Client Trip Service requirements. |
| Cancellations | Consolidated into Section 9; exact lifecycle dependencies remain in Section 14\. |
| Sample departure documents | Serve as acceptance data and a generality stress test for Cruise, Hotel, Transfers, Excursion, and Vineyard package behaviors rather than as separate architecture. |
| MVP scoping reviews through v0.4 | Governing requirements are consolidated into Sections 3-13; resolved decisions are indexed in Appendix B; only unresolved items remain in Section 14\. |

## **Canonical governing statement**

An Agency operates Departures through responsible Offices. A Departure offers Packages and services to Client Trips. Client Trips contain Travelers and Client Trip Services. Services may be fulfilled from group Arrangements, individual Supplier Reservations, directly by the Agency, or as external information. Traveler Assignments identify who receives each service, Resource Assignments identify placement, and responsible Clients identify who owes each Charge. Client and Supplier financial events remain independent, posted history is immutable, and cancellations create explicit operational and financial consequences.

In shorthand: Travelers receive; responsible Clients owe; payers remit; Suppliers or the Agency fulfill.

# **Appendix B Resolved decision index**

This index preserves the provenance of settled scoping decisions without duplicating their governing language. The requirements in Sections 3 through 13 control if an index summary is incomplete.

## **Decisions incorporated before v0.4**

| Topic | Resolution |
| :---- | :---- |
| Client identity model | Client is its own record referencing exactly one Client Person or Client Organization; not a role flag (Section 4). |
| Office enforcement | Reporting and default-assignment metadata only; no access restriction in MVP (Section 3). |
| Occupancy pricing level | Resource/service level only; Package-level occupancy seeds expected demand (Section 5). |
| Supplier cost structure | Composable typed line-item components rather than a fixed formula per supplier type (Section 6). |
| Age-based pricing scope | Flat categorical rules in scope; occupancy-composition-based pricing deferred (Section 4, 13). |
| Capacity date-scoping | Always scoped to a Service Occurrence with a date range; static capacity is a single spanning occurrence (Section 6). |
| Threshold-triggered capacity | General calculation pattern for any Arrangement; occurrence creation stays a manual action (Section 6). |
| Choice group generality | Arbitrary min/max and option counts; attaches to any Client Trip Service, not only Packages (Section 5). |
| Payment Schedule / Charge / Deposit shape | Each installment posts as its own Charge; Deposit is a Charge category, not a separate table (Section 7). |
| Currency | Locked: one operating currency per Departure, no FX in MVP (Section 7). |
| Cross-departure receipts | Hard one-Receipt-per-Departure boundary; staff splits manually (Section 7). |
| Cancellation minimum-billing | Explicit cancelable\_below\_minimum flag on Supplier Arrangement (Section 6). |
| Cancellation calculate-vs-review boundary | Tiered date/percentage shape calculates automatically; everything else requires manual review (Section 9). |
| Earned-credit / loyalty scope | Supplier-specific tracked data for MVP; generalize only if a second supplier needs it (Section 7). |
| Traveler identity data | Date of birth and structured passport fields captured on Traveler Assignment; scans go through the external document pattern (Section 4). |
| Documents | Generated by DepartureDesk (itinerary, invoice, confirmation, waiver), not upload-only (Section 5). |
| Waiver execution | Upload or in-app checkbox for MVP; native e-signature deferred (Section 5). |
| Deadline reminders | Internal: in-app only. Client-facing: email only, payment deadlines only, fixed set (Section 11). |
| Group Leader | Deferred as an access role; captured as a contact purpose (Section 4, 13). |
| Waitlisting | Deferred; extensible later via the existing selection-treatment field (Section 13). |
| Assigned agent per Client Trip | Added: one Agency User per Client Trip as primary contact, no commission-split logic (Section 3, 5). |
| Seller-of-Travel field | Added to Agency identity (Section 3). |

## **Decisions incorporated in v0.4**

| Topic | Resolution | Amends |
| :---- | :---- | :---- |
| Client Trip lifecycle | Draft to confirmed to traveled, with explicit abandoned, cancellation, amendment, and replacement paths. Confirmation atomically posts only currently due Charges. | Section 5 and commercial register |
| Departure lifecycle | Draft to active to departed to closeout review to closed, with Administrator reopening that preserves prior snapshots. | Section 5 and commercial register |
| Legacy data migration | Treated as a separate initiative from the existing legacy system; out of scope for this document. | Section 13 |
| Insurance commission | Integrated into the standard Commission ledger rather than a separate mechanism, so insurance revenue appears in supplier balance and margin reporting like any other supplier. | Sections 7, 8 |
| Communication/document templates | System-defined and versioned, parameterized by existing Agency branding fields (logo, sender/reply-to identity, footer, legal disclosures). Not agency-editable content in MVP. | Sections 4, 5 |
| Mid-trip supplier rate changes | General Supplier Cost Adjustment event \- same immutable-ledger pattern as Charges (adjust, never edit) \- independent of Cancellation Case. | Sections 6, 7 |
| Staff alerting beyond deadlines | General needs-attention queue covering stale Cancellation Cases, bounced Communications, and near-threshold capacity, not only calendar deadlines. | Section 11 |
| Miscellaneous trip-specific services with a real Supplier | Always receive a minimal Supplier Arrangement/Reservation (no capacity or block required) so cost enters the standard Obligation/Payment ledger. No third-party Supplier means no Arrangement, per the existing Agency-fulfillment rule. | Section 8 |
| Rooming list | Generated document built from Traveler and Resource Assignment data for Supplier delivery, not only a tracked deadline. | Sections 5, 11 |
| Occupancy-position pricing | No hardcoded ceiling on the number of positions. The cruise and hotel examples are illustrative, not limiting. | Sections 5, 6 |
| Client Credit vs. Departure closeout | An unapplied same-Departure Client Credit blocks closeout the same way an unresolved refund does. | Sections 7, 11 |
| Cross-Departure Client history | A minimal view \- list of a Client's Client Trips across Departures \- is in scope for MVP. Lifetime-value calculation and behavioral segmentation remain deferred. | Section 11 |
| Bundled package margin allocation | Margin reporting stays at the package level. Allocating a non-decomposable package price across component services is deferred, consistent with the "calculate only when deterministic" principle in Section 10\. | Section 7 |
| Agency-defined group-organizer incentive programs | Deferred for MVP. Distinct from Tour Conductor-style Supplier programs, which are already tracked as supplier-specific data. | Section 13 |

The language and localization question remains unresolved and therefore appears only in Section 14\. Legacy migration, agency-defined organizer incentives, and per-service bundled Package margin allocation are deferred in Section 13 rather than treated as open MVP decisions.

---
