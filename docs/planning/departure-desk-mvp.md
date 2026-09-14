# **DepartureDesk MVP Requirements and Decision Register**

## **Version 0.5 Organized Requirements Draft**

This document is the current working specification for the DepartureDesk MVP. It consolidates accepted requirements into the sections they govern, keeps unresolved choices in one open decision register, and records exclusions in the deferred-scope section. Appendix B retains a compact index of earlier scoping decisions without functioning as a second requirements source.

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

* 14 Open decision register

* 15 Recommended implementation sequence

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
| Departure | Planning, on sale, departed, closed, cancelled | Closeout blockers, waivers, reopening, and the closeout snapshot remain open in Section 14\. |
| Client Trip | Draft, confirmed, traveled, cancelled | The exact relationship between confirmation and Charge posting remains open in Section 14; confirmation must not silently post money until that boundary is accepted. |

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

**Locked for MVP.** Capacity changes do not silently create or release financial commitments. Contract terms create forecasts or commitments; sufficiently definite payable amounts create Supplier Obligations under a lifecycle decision still to be finalized (Section 14). Every Supplier Arrangement using a minimum-billed-quantity pattern carries an explicit cancelable\_below\_minimum flag recording whether the Agency may cancel without cost when the minimum is not reached, or must operate and pay the minimum regardless \- removing what was previously a case-by-case judgment call.

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
| Client balance | Posted Charges less Client credits and active Receipt Applications |
| Unapplied Receipt | Posted Receipt amount less active applications |
| Supplier balance | Posted Supplier Obligations less Supplier credits and Supplier Payment Applications |
| Agency-controlled cash position | Agency cash received less Client cash refunds and Supplier payments plus Supplier cash refunds |
| Projected margin | Projected Client revenue plus expected attributable commission less projected Supplier and known Agency-provided costs |
| Actual operational margin | Final net Client Charges plus recognized attributable commission less final Supplier and attributable Agency costs; formal treatment remains open |
| Exposure | Always qualified: gross commitment, expected net, unsold guarantee, or Agency cash at risk |

For a bundled Package with a non-decomposable client price, margin remains at Package level. Per-service allocation of that price is deferred because DepartureDesk cannot calculate it deterministically from recorded terms.

**Open decision.** Formal lifecycle matrices, Charge posting trigger, responsibility transfer, overpayments, refund authority, Supplier Obligation trigger, commission lifecycle, gross-versus-net settlement, taxes and rounding, accounting export, and closeout blockers remain unresolved (see Section 14).

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

A Departure should not close while material operational or financial issues remain. The exact blocker matrix is an open decision, but candidate blockers include draft transactions, unapplied Receipts, unresolved refunds, Client receivables, missing Supplier invoices, unpaid Obligations, unallocated Supplier credits, unresolved commission, unexplained estimate-to-actual variance, unresolved Cancellation Cases, and unapplied same-Departure Client Credits. A Client Credit blocks closeout until it is applied, refunded, or otherwise resolved.

**Open decision.** Define hard blockers, waivable warnings, waiver authority, small-balance treatment, reopening, late adjustments, and whether closeout creates a frozen snapshot.

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

# **14 Open decision register**

Resolve each question in the first implementation slice that depends on it. Priority indicates architectural sequencing, not business importance. The recommended direction is guidance for the decision discussion, not an accepted requirement.

## **Client financial lifecycle**

| Priority | Decision | Recommended current direction |
| :---- | :---- | :---- |
| P0 | Charge posting boundary | An authorized user explicitly confirms the sale and posts the Charge. Selection, Receipt, and Supplier confirmation are neither sufficient nor required by themselves. |
| P0 | Receipt, application, reversal, and refund lifecycle | Define the immutable posted boundary, explicit application reversal and reapplication, and refund authority before client-money implementation. |
| P0 | Posted responsibility transfer | Use an explicit transfer or credit-and-recharge pattern. Never update responsible Client in place on a posted Charge. |
| P1 | Overpayments and negative balances | Decide whether they are allowed, how later installments use them, transfer limits, refund timing, and abandoned-balance treatment. |
| P1 | Tax, fee, discount, and rounding rules | Define calculation bases, inclusive or exclusive treatment, noncommissionable elements, precision, and presentation. |

## **Supplier financial lifecycle**

| Priority | Decision | Recommended current direction |
| :---- | :---- | :---- |
| P0 | Supplier cost stages and Obligation trigger | Commitment preserves earlier exposure. An Obligation begins when the amount is sufficiently definite to be payable or scheduled. |
| P0 | Supplier Payment and application lifecycle | Use the same ledger separation and immutable posting principles as Receipts without assuming identical business states. |
| P1 | Commission lifecycle and settlement | Lock expected, earned, retained, received, and reversed triggers, including gross-versus-net behavior. |

## **Cancellation reporting and closeout**

| Priority | Decision | Recommended current direction |
| :---- | :---- | :---- |
| P0 | Cancellation lifecycle and posting authority | Retain the reviewed Cancellation Case and explicit posted consequences from Section 9; define approval, withdrawal, supersession, and correction authority. |
| P1 | Formal reporting definitions | Lock sales volume, Agency revenue, actual operational margin, final cost, cash position, exposure, receivable, and payable. |
| P1 | Closeout and reopening | Define hard blockers, waivable warnings, waiver authority, small-balance treatment, write-offs, late postings, reopening, and whether closeout creates a frozen snapshot. |

## **Exports documents and identifiers**

| Priority | Decision | Recommended current direction |
| :---- | :---- | :---- |
| P1 | Language and localization | Decide whether generated documents and Communications are English-only for MVP or require locale-aware templates and formatting. |
| P2 | Accounting export | Start with a manually initiated summarized export after ledger events and report definitions are stable. |
| P2 | Numbering prefixes | Lock reference prefixes in the numbering ADR before exposing durable human references. |

## **Example data questions**

These questions complete acceptance fixtures and Supplier terms. They do not establish general architecture by themselves.

* Cruise Hard Stop Date, sailing time, name-change fee schedule, code RED communication, and precise Tour Conductor earning and averaging rules

* Transfer route-specific airport timing standard

* Excursion result below the minimum and detailed inclusions

* Vineyard return date, hotel contract-year conflicts, deposit and option-payment bases, dinner deposit year, lunch dates, coach guaranteed and blocked meanings, and numeric base Package price

* Cancellation, child, lap-infant, accessibility, and substitution terms for Vineyard Suppliers

# **15 Recommended implementation sequence**

* Accept the consolidated terminology, supersession list, and this revision's resolved decisions.

* Rework Agency User authentication, Office semantics (metadata only), permissions, Platform Users, and support access.

* Replace the shared Party directory with bounded Client Person, Client Organization, and Client (payer identity) records, and migrate preserved directory behavior.

* Establish Departure, Package, Client Trip, Client Trip Service, assignment, and fulfillment contracts, including general-purpose choice groups and traveler identity snapshots (date of birth, passport).

* Implement Supplier Arrangements with composable cost components, Reservations, date-scoped Resources, service occurrences, capacity, commitment, deadline, and exposure foundations, including the cancelable\_below\_minimum flag and general threshold-triggered capacity calculation.

* Lock and implement Charge and Receipt lifecycles (per-installment posting, Deposit as a category, one-Receipt-per-Departure), applications, responsibility, refunds, and same-Departure credits.

* Lock and implement Supplier Obligation, Payment, application, deposit, final-cost, and commission lifecycles.

* Add trip-specific service extensions, document generation (itineraries, invoices, confirmations, waivers), and waiver execution (upload / in-app acknowledgment).

* Implement Cancellation Case preview, the tiered-date-percentage calculate/review boundary, reviewed dispositions, and immutable posting.

* Implement the Deadline concept, the general needs-attention queue, internal in-app alerts, and client payment-deadline email reminders.

* Define reporting measures, reconciliation, closeout blockers, waivers, reopening, and final acceptance examples.

This sequence keeps financial and cancellation behavior dependent on accepted ledger contracts rather than allowing dashboard formulas or UI status lists to define persistence indirectly.

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
| Client Trip lifecycle | draft to confirmed to traveled to cancelled. "Confirmed" aligns with the Charge posting boundary already in the Section 14 register. | Section 5 |
| Departure lifecycle | planning to on sale to departed to closed to cancelled. "Closed" aligns with the existing closeout event in Section 11\. | Section 5 |
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

# **DepartureDesk Commercial Domain Decision Register**

**Status:** Accepted planning contract  
**Scope:** Departure, Client Trip, Supplier planning, capacity, commercial terms, financial ledgers, amendments, documents, reporting, and closeout  
**Purpose:** Consolidate the product decisions required before detailed implementation planning. This document is normative where it uses **must**, **must not**, **may**, or **requires**.

## **1\. Governing principles**

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

## **2\. Terminology used in this register**

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

## **3\. Client sales, Charges, and payment schedules**

### **3.1 Charge granularity and provenance**

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

### **3.2 Client Trip confirmation**

Confirming a Client Trip is one atomic command. It must:

1. Revalidate current Package and selected-service terms.  
2. Require acknowledgment of detected term changes.  
3. Snapshot prices, inclusions, selections, cancellation terms, relevant names, and Supplier-term provenance.  
4. Convert valid holds into confirmed allocations.  
5. Post only Charges currently due.  
6. Record a durable Client Trip reference.  
7. Commit all effects together or none of them.

Confirmation must fail without partial side effects when a required hold has expired, capacity is no longer available, a material change lacks valid Client acknowledgment, pricing changes have not been acknowledged, required Supplier confirmation is missing, or Charge posting fails.

### **3.3 Draft pricing and acknowledgment**

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

### **3.4 Calculations and rounding**

1. Every percentage-based tax, fee, discount, deposit, or commission component must explicitly identify its base source lines.  
2. The component must state whether it is included in or added to the quoted amount.  
3. Calculation order comes from the applicable recorded pricing terms, not an arbitrary Agency-wide formula.  
4. A posted component snapshots its base, rate, calculation order, rounding method, and minor-unit result.  
5. Calculations may retain additional internal precision, but each posted source line is rounded to the transaction currency's minor unit.  
6. A contract-total difference caused by line rounding is represented as a visible rounding-adjustment line.

## **4\. Client Receipts, credits, and externally collected value**

### **4.1 Separate value types**

DepartureDesk must keep these concepts distinct:

- Receipt Application: Agency cash applied to a Charge.  
- Client Credit Application: noncash Client Credit applied to a Charge.  
- Supplier-collected Payment Application: value collected by a Supplier and applied to a Charge without entering Agency cash.

An issued Client Credit remains available value until applied. Credit issuance alone does not reduce a Charge.

### **4.2 Receipt boundary and payer identity**

1. A Receipt represents one Agency-controlled cash event and preserves the actual payer, who need not be the responsible Client for any Charge.  
2. MVP requires one Departure and one currency per Receipt.  
3. Receipt Applications may span Charges and Client Trips within that Departure.  
4. A Receipt records payment method, effective date, posting timestamp, external processor/bank reference when applicable, recorder, and evidence or note required by Agency policy.  
5. Effective date describes when the payment economically occurred; posting timestamp controls as-of inclusion.  
6. The system may propose applications in due-date and stable-reference order, but posting must preserve the exact approved applications. No hidden allocation order may change Client balances.

### **4.3 Charge balance**

For a posted Charge:

> **Outstanding Charge balance \= Charge total − active Receipt Applications − active Client Credit Applications − active Supplier-collected Payment Applications**

Applications are immutable after posting. Corrections require reversal and, when appropriate, a new application.

### **4.4 Unapplied funds and overpayments**

1. A Receipt may remain partly or wholly unapplied.  
2. If a Receipt exceeds currently posted Charges for its Departure, the excess remains Unapplied Funds for later same-Departure use or refund.  
3. A Charge must not become negative because of an overpayment.  
4. DepartureDesk must not automatically convert excess cash into a noncash Client Credit.  
5. Unapplied Receipts, Credits, and Supplier-collected value remain separately visible and may block closeout.

### **4.5 Refunds, returns, and reversals**

1. A returned, rejected, or externally reversed payment creates a compensating return event; the original Receipt remains intact.  
2. The return command atomically reverses all active applications affected by the returned amount and restores the applicable Charge balances.  
3. An authorized returned-payment fee is a separate Charge source line, not an edit to the Receipt.  
4. The same preservation and compensating-event rule applies to returned Supplier Payments.  
5. A partial or full Client Refund is a first-class Agency cash event linked to the Receipt, unapplied funds, Credit, Charge/Application disposition, responsible Client, approval, and reason as applicable.  
6. A refund does not edit or delete the original Receipt or its historical Applications. The refund command posts the required reversals or credit dispositions atomically.  
7. A mistaken internal posting is corrected by reversal and replacement. An external return records the externally caused failure. A Client Refund records an authorized outbound payment. These event types must not be conflated.

### **4.6 Supplier-collected payments**

1. Supplier-collected value must be recorded with Supplier evidence, payer, amount, currency, external reference, effective date, and affected Client Trip or service context.  
2. It reduces Client balances only through explicit Supplier-collected Payment Applications.  
3. It never increases Agency cash.  
4. A Supplier refund or reversal creates a linked compensating event that reverses the applicable external-payment applications.

## **5\. Supplier costs, Obligations, invoices, and Payments**

### **5.1 Supplier Obligation granularity**

1. One Supplier Obligation represents one payable event or due date.  
2. It may contain multiple source lines spanning cost components, Reservations, or Service Occurrences when they share that payable event.  
3. Each source line must preserve links to the originating Supplier Arrangement, Reservation, Service Occurrence, cost component, commitment, and governing terms where applicable.  
4. A continuing Arrangement-level running balance is not a substitute for event-based Obligations.

### **5.2 Posting Obligations**

1. A deterministic contractual milestone may post an Obligation automatically when amount, currency, due date, source lines, and triggering terms are complete.  
2. Ambiguous, missing, or discretionary terms create a review item. The system must not guess or post a zero-value Obligation.  
3. Automatic posting must be idempotent and retain the triggering term/version and event.

### **5.3 Supplier invoices and reconciliation**

1. Supplier Invoice is a first-class reconciliation record.  
2. It stores Supplier reference, invoice and received dates, totals, currency, document evidence, and invoice lines.  
3. An Invoice does not replace, silently edit, or become the Supplier Obligation ledger.  
4. Reconciliation matches Invoice lines to Obligation lines.  
5. Differences require reviewed, explicit Supplier cost or Obligation adjustment records.  
6. Final reconciled Supplier cost must remain traceable to both the original commercial source and Supplier evidence.

### **5.4 Supplier credits**

An issued Supplier Credit is available value but reduces an Obligation only through a Supplier Credit Application. Supplier Credit Applications are reversed, not edited.

### **5.5 Supplier Payments**

1. One Supplier Payment may cover Obligations from multiple Departures when Agency, Supplier, and currency match.  
2. Supplier Payment Applications attribute payment portions to particular Obligations and therefore to Departures.  
3. Any unapplied remainder stays at the Agency-Supplier level until applied, refunded, or otherwise resolved.  
4. A Supplier Refund is a first-class Agency cash event linked to the Supplier, original Supplier Payment or Supplier Credit context, affected Applications/Obligations, reason, effective date, and posting timestamp.  
5. Supplier Refund corrections preserve the original cash event and use linked compensating records.

## **6\. Commission**

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

## **7\. Agency-provided and miscellaneous costs**

1. Agency Cost is a first-class record.  
2. It may be linked to a Departure, Client Trip Service, or Service Occurrence.  
3. Planned Agency Costs affect projected margin.  
4. Posted Agency Costs affect actual operational margin.  
5. An Agency Cost affects operational cash position only when marked paid with an external payment reference.  
6. Agency Costs must not create fake Suppliers, Supplier Obligations, or Supplier Payments.

## **8\. Capacity, holds, and allocations**

### **8.1 Capacity basis**

1. Each capacity bucket declares its explicit basis, such as resource units, Traveler positions, or another named quantity.  
2. Holds and allocations consume that declared quantity.  
3. Traveler Assignments and Resource Assignments provide placement or occupancy detail without double-counting capacity.

### **8.2 Holds**

1. A draft Client Trip may create an explicit expiring hold.  
2. A hold reduces internal availability but creates no Charge, Supplier Obligation, or Supplier confirmation.  
3. At expiry, the hold releases automatically and retains immutable expiry history.  
4. Automated expiry uses a system actor and idempotent release event.  
5. A live hold may be extended by Staff within configured duration/count limits and never beyond a contractual Supplier cutoff.  
6. An Administrator may override configured extension limits with a reason when capacity and Supplier terms still permit the extension.  
7. Extension is an auditable event, not a silent edit to the original expiry.  
8. Every extension atomically rechecks availability and conflicting allocations.  
9. An expired or released hold cannot be extended; a new hold must reacquire capacity.

### **8.3 Confirmed allocations and concurrency**

1. Confirming or changing an allocation locks the relevant Service Occurrence and capacity bucket, rechecks availability, and succeeds completely or reports a conflict.  
2. Confirmed demand may exceed managed capacity only through an Administrator override.  
3. An over-capacity override records quantity, reason, actor, time, and affected occurrence.  
4. The exception remains in a needs-attention queue until resolved or acknowledged.  
5. An operationally authorized cancellation releases capacity even if Client or Supplier financial consequences remain unresolved.  
6. Hold and allocation records are retained after release, expiry, substitution, or cancellation.

### **8.4 Pending Supplier fulfillment**

1. A Client Trip may be confirmed while a required service remains on request with its Supplier.  
2. The pending service must create a visible readiness warning.  
3. A service or its terms may explicitly require Supplier confirmation before Client Trip confirmation; that stricter rule must then block confirmation.  
4. Client Trip confirmation must never fabricate Supplier confirmation.

## **9\. Amendments, substitutions, movement, and cancellation**

### **9.1 Governing amendment rule**

1. Confirmed commercial terms and posted money do not change through ordinary edits.  
2. Upgrade, downgrade, promotion, surcharge, goodwill, cancellation repricing, and reinstatement use an explicit Client Trip Amendment identity.  
3. An amendment posts only approved differences through new Charges, Credits, cost adjustments, or other compensating records.  
4. Supplier cost changes remain separate from Client price changes.

### **9.2 Responsibility changes**

When responsibility for a partially paid Charge changes:

1. Paid history and its original responsible Client remain preserved.  
2. Only the outstanding balance transfers through linked adjustment/transfer records.  
3. Receipt and application history must not be rewritten as if the new Client made the earlier payment.

### **9.3 Traveler substitution**

1. Replacing a Traveler on a confirmed Client Trip uses an explicit substitution amendment.  
2. Old and new assignments remain linked and historically visible.  
3. The command reevaluates eligibility, identity requirements, Supplier rules, pricing consequences, documents, and capacity placement.  
4. A legal-name correction for the same person is not a substitution, but must retain change history and determine whether issued documents require supersession.

### **9.4 Moving between Departures**

1. A genuinely clean draft may move to another Departure in place.  
2. A linked replacement Client Trip is required after posted money, consequential issued documents, or confirmed/expired/released capacity history exists.  
3. The original and replacement remain cross-referenced.  
4. A move must not rewrite the original Departure's historical sales, capacity, or financial reporting.

### **9.5 Cancellation**

1. Client and Supplier consequences resolve independently and may post at different times.  
2. A structured cancellation policy may calculate deterministic proposed credits or fees automatically.  
3. Calculated consequences affect the ledger only after authorized posting.  
4. An approved Client refund may proceed before Supplier reimbursement arrives.  
5. Operational cancellation releases capacity after Agency authorization rather than waiting for financial disposition.  
6. A Cancellation Case stays open until every required operational, Client, Supplier, commission, capacity, and payment disposition is resolved or explicitly marked inapplicable.  
7. Reinstatement uses an amendment and reacquires current terms and capacity; cancelled assignments are not merely reactivated.  
8. Occupancy changes preserve prior pricing positions and present proposed Charge or Credit adjustments for approval.

## **10\. Documents and Communications**

1. Draft documents may be regenerated.  
2. An issued document version is immutable.  
3. It must preserve the rendered artifact, template/version, input snapshot, branding, addressee, responsible Client, related records, actor, and issuance time.  
4. A correction creates a new issued version explicitly superseding the prior version.  
5. Superseded versions remain historically available subject to retention policy.  
6. Creating or superseding a document does not send it.  
7. Sending creates a Communication linked to the exact issued version and its recipients.  
8. Sensitive-data authorization for screen display does not imply permission to export or include the data in a document.

## **11\. Dates, time zones, and deadlines**

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

## **12\. Sensitive Traveler data and retention**

1. Sensitive fields are masked in ordinary views.  
2. Administrators and Staff may reveal designated fields only through a named permission; Viewers may never reveal them.  
3. Reveal is an explicit, audited action recording actor, Traveler, fields, time, purpose/reason, and related Client Trip.  
4. Exports and generated documents require separate permission checks.  
5. Passport scans and full sensitive identity documents remain in an approved external secure repository; DepartureDesk stores structured fields and safe external references only.  
6. When the operational and legally required retention period expires, sensitive structured values are automatically redacted under Agency policy.  
7. Traveler Assignment, document reference, fulfillment history, and audit evidence remain after redaction.  
8. An active legal or operational hold pauses redaction.

## **13\. Configuration ownership and effective dating**

1. Settings may be overridden only at declared scopes.  
2. The effective value follows system default, then Agency, then the most-specific allowed Departure, Package, Supplier Arrangement, or Service Occurrence override.  
3. Each setting definition must declare its permitted owner scopes.  
4. Consequential commands snapshot both the resolved value and its source.  
5. Later configuration changes affect future resolutions and do not reinterpret historical consequences.  
6. Hold-extension limits, deadline rules, reminder lead times, tolerances, and similar settings must identify their owner and effective-date behavior explicitly.

## **14\. Authorization and command authority**

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

## **15\. Reporting definitions**

### **15.1 As-of basis**

1. Posting timestamp determines whether a financial event is included in an as-of report.  
2. Effective date is reported separately and may support operational analysis, but does not rewrite the historical posting cutoff.  
3. Reversals appear according to their own posting timestamps while preserving links to the reversed events.  
4. Consequential records snapshot their Office attribution at posting or confirmation. Later Office reassignment does not rewrite historical reporting; reports may present current Office separately when useful.

### **15.2 Projected revenue and cost**

- **Projected Client revenue:** Confirmed Client Trip prices, including posted Charges and confirmed future installments. Draft pipeline is reported separately.  
- **Projected Supplier cost:** One current expected-final-cost projection per source, selected from the best available evidence. Estimates, commitments, Obligations, and invoices are never added together as separate costs for the same source.  
- Planned Agency Costs are included in projected margin.

### **15.3 Actual operational margin**

> **Actual operational margin \= final eligible Client revenue \+ earned commission − final reconciled Supplier costs − posted Agency Costs**

Pass-through components are excluded from Client revenue when their source-line classification says they are not Agency revenue.

### **15.4 Operational cash position**

> **Operational cash position \= Client Receipts \+ Supplier Refunds \+ Commission Receipts − Client Refunds − Supplier Payments − paid Agency Costs**

Supplier-collected payments and noncash credits are excluded. Posting an Agency Cost affects margin; it affects cash only when marked paid with an external payment reference.

### **15.5 Accounting export**

MVP accounting export produces paired summary and event-detail files with stable source IDs. It must preserve linkage among source records, posted events, reversals, applications, Departure, Office attribution, counterparty, posting timestamp, effective date, and currency.

## **16\. Closeout and reopening**

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

## **17\. Human-readable references**

1. Reference formats are system-defined by record type.  
2. Each Agency owns a separate, non-resetting sequence for each applicable record type.  
3. Office codes do not appear in references.  
4. A record receives its durable reference at its first consequential transition, not merely because a draft exists.  
5. References are permanent, never reused, and remain searchable after cancellation, reversal, or absorption.  
6. Existing Departure format `D-000001` remains the pattern baseline.  
7. The detailed implementation plan must publish a record-type mapping. Recommended issuance points are:

| Record | Consequential transition |
| :---- | :---- |
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

## **18\. Lifecycle transition contracts**

### **18.1 Departure**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| Draft → Active | Required identity, dates, Office, manager, currency, and operational configuration complete | Staff with permission or Administrator | Issues reference if absent; permits planning and sales | Return to draft only before consequential downstream history |
| Active → Departed | Applicable date reached | System date transition or authorized Staff | Status/audit only | Correct erroneous date/status through authorized correction; no financial side effects |
| Departed → Closeout review | Travel/service period complete | Staff with permission | Runs blocker and warning evaluation | May return to departed while unresolved |
| Closeout review → Closed | No hard blockers; warnings resolved or validly waived | Administrator | Creates immutable closeout snapshot; blocks new postings | Reopen command only |
| Closed → Reopened | Reason supplied | Administrator | Preserves prior snapshot; allows corrective activity | Later close creates a new snapshot version |

### **18.2 Client Trip**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| Draft → Confirmed | Valid terms, acknowledgments, required holds/capacity, required Supplier confirmations, due-charge data | Staff with permission or Administrator | Atomic commercial snapshot, allocations, currently due Charges, reference | Cancellation or amendment; not status rollback |
| Confirmed → Traveled | Applicable date reached and not cancelled | System date transition | Status/audit only | Authorized correction if date/status erroneous |
| Draft → Cancelled/abandoned | No consequential history requiring a case | Staff with permission | Releases live holds; preserves record | New draft or linked replacement |
| Confirmed/Traveled → Cancellation in progress | Cancellation request accepted for handling | Staff with permission | Opens Cancellation Case; does not itself decide every consequence | Complete or reject case with history |
| Eligible clean draft → Moved | No posted money, consequential issued documents, or capacity history | Staff with permission | Changes Departure and revalidates terms | Audit correction |
| Consequential trip → Replacement | Target Departure and replacement terms valid | Staff with permission | Creates linked replacement; original remains | Cancel replacement or create another amendment |

### **18.3 Client Trip Service**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| Draft selection → Held | Applicable capacity available | Staff with permission | Creates expiring hold | Release/expiry event |
| Draft selection → On request | Supplier request required | Staff with permission | Creates Supplier-facing request state and readiness warning | Withdraw request with history |
| Held/selected → Confirmed | Client Trip confirmation or approved amendment succeeds | Staff with permission or Administrator override | Snapshots terms; confirms allocation; may post Charge source | Amendment/cancellation |
| Confirmed → Cancelled | Operational cancellation authorized | Staff with permission | Releases capacity; opens/updates financial dispositions | Reinstatement amendment |
| Cancelled → Reinstated replacement | Current terms/capacity available | Staff with permission | New linked assignment/service state | Further amendment |

### **18.4 Supplier Arrangement**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| Draft → Active | Supplier, terms, dates, currency, capacity/cost definitions complete | Staff with permission | Terms become available to planning and sales | Amend/version; do not rewrite snapshotted sales |
| Active → Amended version | Revised terms approved | Staff with permission | New version affects future resolutions; existing snapshots preserved | New corrective version |
| Active → Ended/inactive | No prohibited active dependency or override path satisfied | Staff with permission | Prevents new use; retains history | Reactivate only when contractually valid |

### **18.5 Supplier Reservation and confirmation**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| Planned → Requested | Request data complete | Staff with permission | Records request and Supplier communication context | Withdraw with history |
| Requested → Confirmed | Supplier evidence received | Staff with permission | Records Supplier confirmation provenance; may trigger deterministic commitments/Obligations | Supplier amendment/cancellation event |
| Requested → Declined | Supplier response received | Staff with permission | Records reason; raises readiness/capacity issue | New request or alternate Supplier path |
| Confirmed → Changed/cancelled | Supplier evidence and reason recorded | Staff with permission | Recalculates planning exposure; proposes but does not silently post Client consequences | New confirmation/amendment |

### **18.6 Capacity hold and allocation**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| None → Live hold | Availability after atomic recheck | Staff with permission | Consumes held quantity until expiry | Release or expiry |
| Live hold → Extended | Still live; within cutoff; availability revalidated | Staff within limits; Administrator override beyond limits | Adds extension event and new expiry | New extension or release; never edit history |
| Live hold → Expired | Expiry reached | System | Releases quantity; retains history | New hold only |
| Live hold → Confirmed allocation | Confirmation command succeeds | Staff with permission or Administrator over-capacity authority | Converts held quantity without double consumption | Release, cancellation, or substitution event |
| Confirmed allocation → Released | Authorized operational change/cancellation | Staff with permission | Restores availability; preserves allocation history | New hold/allocation required |

### **18.7 Cancellation Case**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| None → Open | Cancellation accepted for handling | Staff with permission | Captures scope, request, policy version, and unresolved disposition checklist | Reject/withdraw with reason when no cancellation was executed |
| Open → Operationally cancelled | Required operational approvals complete | Staff with permission | Cancels affected service/trip and releases capacity | Reinstatement amendment |
| Open → Financial dispositions pending | Calculations available | Staff with permission | Presents proposed Client/Supplier/commission consequences | Recalculate before posting if inputs change |
| Pending → Consequences posted | Authorized approvals complete | Staff with posting permission | Posts explicit Charges, Credits, Obligations, adjustments, or refunds | Compensating records only |
| Open → Resolved | Every required disposition resolved or inapplicable | Staff with permission | Closes case with full evidence | Reopen case with reason; posted records remain immutable |

### **18.8 Posted financial records**

Posted Charge, Receipt, Application, Credit, Supplier Obligation, Supplier Payment, Commission event, Agency Cost, refund, write-off, return, and adjustment records do not transition back to editable draft states. Their lifecycle is:

| Transition | Rule |
| :---- | :---- |
| Draft/prepared → Posted | Validate authority, source, currency, dates, amounts, idempotency, and open-period/Departure status in one transaction |
| Posted → Partly/fully applied | Create immutable Applications; do not edit the posted principal |
| Posted → Reversed/returned/adjusted | Create linked compensating event and atomically update derived balances |
| Included in closeout | Preserve event and posting cutoff in immutable snapshot |

### **18.9 Supplier Invoice**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| Received/draft → Recorded | Supplier identity, reference, dates, currency, totals, evidence | Staff with permission | Issues reference; available for reconciliation | Void/supersede with reason; retain original |
| Recorded → Partly/fully reconciled | Line matches and variances reviewed | Staff with permission | Links lines to Obligations; prepares adjustments | Reverse links/adjustments through explicit correction |
| Reconciled → Superseded | Corrected Supplier invoice received | Staff with permission | New version/reference relationship | Reconcile superseding version; retain both |

### **18.10 Issued document and Communication**

| Transition | Preconditions | Required authority | Principal effects | Reversal/correction |
| :---- | :---- | :---- | :---- | :---- |
| Draft → Issued | Required data and permissions complete | Staff with document permission | Freezes rendered artifact and input snapshot | Superseding issued version only |
| Issued → Sent | Explicit recipients and channel selected | Staff with communication permission | Creates Communication linked to exact version | Follow-up/correction Communication; sent history remains |
| Issued → Superseded | Corrected version issued | Staff with document permission | Links old and new versions | Another superseding version |

## **19\. Required command contract template**

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

## **20\. Specification amendment checklist**

### **20.1 Add or formalize records**

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

### **20.2 Replace ambiguous formulas**

- [ ] Replace any balance formula that subtracts issued Credits directly with application-controlled balance effects.  
- [ ] Include Supplier-collected Payment Applications in Charge balance without including them in Agency cash.  
- [ ] Define Supplier Obligation balance through Payments, Supplier Credits, commission settlement, and reversals.  
- [ ] Define projected Supplier cost as one selected expected-final value per source.  
- [ ] Add the accepted actual operational margin formula.  
- [ ] Add the accepted operational cash-position formula.  
- [ ] Classify pass-through lines explicitly.

### **20.3 Add normative boundaries**

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

### **20.4 Publish matrices and catalogs**

- [ ] Lifecycle matrix for every stateful record, using Section 18 as the baseline.  
- [ ] Named-permission/command authority matrix.  
- [ ] Configuration key catalog with allowed owner scopes and effective dating.  
- [ ] Capacity-basis catalog with measurement and assignment semantics.  
- [ ] Charge, Obligation, adjustment, and application reason catalogs.  
- [ ] Closeout blocker/warning catalog.  
- [ ] Record-type reference code and issuance-point catalog.  
- [ ] Accounting export field and stable-ID contract.

### **20.5 Verification requirements**

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

## **21\. Planning disposition**

The decisions in this register are sufficiently complete to proceed to record-level domain design and phased implementation planning. The remaining work consists of naming, schemas, command decomposition, migration sequencing, UI workflow design, and test implementation. Those activities must make these contracts more specific without silently reopening them.
