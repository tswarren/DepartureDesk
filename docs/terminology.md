# DepartureDesk terminology standard

## 1\. Naming principles

DepartureDesk terminology should follow these rules:

1. **Use “departure” for the dated operational unit.**  
2. **Use “program” for a reusable or recurring travel concept.**  
3. **Use “client trip” for the agency’s commercial relationship with a client.**  
4. **Use “supplier arrangement” for what the agency contracts or books.**  
5. **Use “traveler assignment” for who receives a service.**  
6. **Use “responsibility allocation” for who owes the agency.**  
7. **Use “service component” for an individual travel service.**  
8. Avoid using **group**, **booking**, or **reservation** without a qualifier when the meaning could be ambiguous.

# 2\. Primary operating concepts

## Office

An **office** is an agency-owned operating location or business unit. It is a scope for access, defaults, attribution, and later operational ownership. It is not the tenant.

“Branch” may appear as an imported label. It must not produce a second model or a parallel authorization concept.

An office:

* belongs to exactly one agency;
* cannot contain another agency’s records;
* does not replace the current agency;
* may be assigned to staff explicitly;
* may supply a current operating context for a session.

People, clients, households, and suppliers remain agency-wide identities. Later departures and office-originated financial records may be owned by one office and must still carry a direct agency identifier.

### Usage

* “Assign Casey to the Harbor office.”
* “Create this departure in the MAIN office.”
* “Switch your current office.”

## Travel program

A **travel program** is a reusable concept, series, or umbrella under which one or more departures may be operated.

Examples:

* Smith Family Reunion  
* Annual Napa Wine Tour  
* St. Mark’s European Pilgrimage  
* Company President’s Club

A program may have one departure or recur over multiple dates and years.

A program may define reusable:

* Branding and description  
* Organizing parties  
* Package templates  
* Policies  
* Standard inclusions  
* Marketing information  
* Historical reporting

A program is optional. A one-time trip may begin directly as a departure.

### Usage

* “Create another departure for this program.”  
* “View previous Smith Family Reunion departures.”  
* “Copy package definitions from the 2027 program.”

## Departure

A **departure** is the primary operational record in DepartureDesk. It represents one dated occurrence of coordinated travel.

Examples:

* Smith Family Reunion Cruise — July 12, 2027  
* Napa Wine Country Tour — October 10, 2027  
* St. Mark’s Rome Pilgrimage — March 4–12, 2028

A departure contains or relates:

* Supplier arrangements  
* Packages  
* Client trips  
* Travelers  
* Inventory and capacity  
* Charges and payments  
* Supplier obligations  
* Operational deadlines  
* Documents and tasks  
* Projected and actual financial performance

### Usage

* “Open the departure.”  
* “This departure has 26 confirmed travelers.”  
* “The departure needs 16 travelers to break even.”  
* “Close and reconcile the departure.”

## Group

**Group** is an accepted travel-industry description, but it should not be the primary application object.

It may appear in client- or supplier-facing contexts such as:

* Group cruise agreement  
* Group hotel rate  
* Group leader  
* Group air contract  
* Group confirmation number

It should not be used ambiguously to mean:

* Departure  
* Traveling party  
* Client account  
* Supplier contract  
* All travelers  
* Package

When importing from another system, a legacy “group code” should map to a DepartureDesk departure or external reference.

# 3\. People and organizations

## Party

A **party** is a person, household, or organization that may participate in a business, financial, or operational relationship.

Party is the agency-owned identity root. User-facing screens should usually display the more specific role when that role exists:

* Client  
* Traveler  
* Supplier  
* Organizer  
* Group leader  
* Payer  
* Agency team member

Phase 2A ships party identity only. Client and supplier remain later profiles. Traveler remains a contextual role of a person.

Agency team members use person identities linked through agency membership. The team name in an agency is the linked person’s directory name; the user email remains the login identifier.

## Person

A **person** is an individual with a reusable identity record.

A person may participate in different departures as a:

* Traveler  
* Client  
* Payer  
* Group leader  
* Organizer  
* Emergency contact  
* Supplier contact

A person record is not automatically a traveler or client until assigned that role.

## Organization

An **organization** is a legal or informal entity that may act as a:

* Client  
* Sponsor  
* Organizer  
* Supplier  
* Employer  
* School, club, church, or association

## Client

A **client** is a person, household, or organization with a commercial relationship to the agency.

A client may:

* Purchase travel  
* Incur charges  
* Make payments  
* Sponsor travelers  
* Receive statements and communications  
* Be responsible for one or more client trips

A client is not necessarily a traveler.

## Traveler

A **traveler** is a person expected to receive or participate in one or more travel services.

A traveler may:

* Travel without being financially responsible  
* Receive services paid for by another client  
* Appear in multiple supplier reservations  
* Share accommodations with travelers from other client trips  
* Decline or purchase optional components

The application should use **traveler**, not passenger, as the general term.

## Passenger or guest

Use **passenger** only in supplier contexts where that is the normal term, such as:

* Airline passenger  
* Cruise passenger  
* Passenger-name submission

Use **guest** where the supplier or service convention requires it, such as:

* Hotel guest  
* Cruise guest

Both are contextual forms of traveler, not separate identity types.

## Household

A **household** is a servicing and communication collective stored as a party kind.

Household membership is an effective-dated person-to-household relationship. It is not created automatically, and sharing a cabin or room does not establish it.

Directory household is not:

* An insurance household  
* A traveling party  
* An occupancy group  
* A payer group

Insurance eligibility may later use a separate product-rule household. Do not reuse directory household as that concept without an explicit product decision.

## Contact information

**Contact information** belongs to a party. A person, household, or organization may each own emails, phones, and postal addresses. Shared mailing details belong on the household or organization; they are not copied onto members.

Directory email is not the login email on a user record. Suppression marks a current value “Do not use.” Deactivation means it is no longer this party’s contact. Primary destinations come from purpose assignments (`general`, `correspondence`, `billing`), not a boolean on the contact root.

## Party note

A **party note** is retained internal servicing context. Standard notes are visible to staff. Administrator-only notes are hidden from staff, including counts and empty states. Correction and removal keep the original body.

## Organizer

An **organizer** is the person or organization responsible for initiating or sponsoring a program or departure.

The organizer may or may not:

* Travel  
* Pay  
* Act as the main contact  
* Receive complimentary services  
* Assume contractual responsibility

## Group leader

A **group leader** is a departure-specific operational role for a person who coordinates participants or acts as a liaison with the agency.

A group leader is not automatically:

* The organizer  
* The responsible client  
* The payer  
* A traveler

## Payer

A **payer** is the party from whom a particular payment is received.

The payer may differ from:

* The traveler  
* The client responsible for the charge  
* The client-trip owner  
* The cardholder or bank-account owner

## Responsible client

A **responsible client** is a client assigned financial responsibility for some or all of a charge.

This is a charge-level role. It should not be inferred solely from who made a payment.

# 4\. Client-side travel records

## Client trip

A **client trip** is the agency’s operational and commercial record for serving one primary client within a departure.

It contains:

* A primary client  
* Travelers served  
* Package selections  
* Service components  
* Charges  
* Payment schedules  
* Payments and credits  
* Documents  
* Terms and acknowledgments  
* Client-specific communications

A client trip may include several suppliers and supplier reservations.

Separate client trips may share a cabin, hotel room, vehicle, or other supplier resource.

### Example

For a cabin shared by two households:

* Robert and Helen have one client trip.  
* David has another client trip.  
* Both client trips connect to the same cruise cabin reservation.

## Primary client

The **primary client** is the principal client under whom a client trip is organized.

The primary client determines the normal:

* Statement recipient  
* Communication recipient  
* Trip display name  
* Client-service context

The primary client is not necessarily responsible for every charge. Additional clients may receive responsibility allocations.

## Traveling party

A **traveling party** is an operational relationship among travelers or client trips that are coordinating or sharing services.

Examples include:

* Cabinmates  
* Roommates  
* Traveling companions  
* Family subgroups  
* Shared transfers  
* Dining groups

A traveling party does not merge:

* Client trips  
* Client balances  
* Households  
* Insurance eligibility  
* Documents or private communications

## Trip coordinator

A **trip coordinator** is the person designated to manage communication for a client trip or traveling party.

This is different from the departure-level group leader.

# 5\. Products and services

## Package

A **package** is a client-facing collection of services offered for sale by the agency.

Examples:

* Cruise-only package  
* Cruise plus pre-night hotel  
* Wine Country Tour  
* Land-and-air package  
* Base package with optional excursions

A package defines:

* Included services  
* Optional choices  
* Selling price  
* Eligibility  
* Capacity  
* Deposit schedule  
* Client terms

A package is what the agency sells; it is not the collection of supplier contracts used to fulfill it.

## Package option

A **package option** is a client-selectable variation or addition.

Examples:

* Balcony cabin upgrade  
* Single-room supplement  
* Additional hotel nights  
* Travel insurance  
* Optional vineyard tasting  
* Airport transfer

An option may be included, separately priced, or priced as a supplement.

## Package component

A **package component** defines a service included in or available through a package.

It is a template-level definition, such as:

* Motorcoach transportation  
* July 11 hotel night  
* Vineyard tasting  
* Seven-night cruise  
* Optional travel insurance

It does not represent a particular client’s confirmed service.

## Service component

A **service component** is a specific service purchased, assigned, or provided within a client trip.

Examples:

* Robert and Helen’s cruise passage  
* David’s share of Cabin 8142  
* Robert and Helen’s July 9–12 hotel stay  
* David’s insurance policy  
* Maria’s airline ticket  
* Robert’s participation in the vineyard tasting

A service component may originate from a package component or be added independently.

A service component connects:

* Client trip  
* Travelers  
* Client price  
* Responsible clients  
* Supplier fulfillment  
* Service dates  
* Status

## Included service

An **included service** is a package component covered by the package’s selling price.

It may still carry an internal supplier cost and traveler assignment.

## Optional service

An **optional service** is available through the departure but is not automatically included in the selected package.

## Agency service

An **agency service** is fulfilled directly by the agency rather than an external supplier.

Examples:

* Planning or management fee  
* Tour-hosting service  
* Agency-provided transfer  
* Documentation service

# 6\. Supplier-side records

## Supplier

A **supplier** is the legal or commercial entity from which the agency procures a travel service.

Examples:

* Cruise line  
* Hotel company  
* Vineyard  
* Motorcoach operator  
* Airline  
* Insurance company  
* Tour operator

## Service provider

A **service provider** is the operating entity, property, vessel, venue, or carrier delivering the service when it differs from the supplier.

Examples:

* Supplier: hotel wholesaler; service provider: named hotel  
* Supplier: cruise line; service provider: named ship  
* Supplier: tour operator; service provider: local excursion company

## Supplier arrangement

A **supplier arrangement** is the umbrella record for a contract, block, charter, reservation, policy, or other commitment between the agency and a supplier.

Examples:

* Cruise group agreement  
* Hotel room block  
* Motorcoach charter  
* Vineyard group booking  
* Group air contract  
* On-request hotel extension  
* Travel-insurance policy

It defines what the agency has requested, reserved, guaranteed, or purchased.

## Master arrangement

A **master arrangement** is a supplier arrangement under which more specific reservations or resources are created.

Examples:

* Cruise group agreement  
* Hotel block contract  
* Group air contract

“Master” should be used only in this qualified context, not as a general synonym for supplier arrangement.

## Supplier reservation

A **supplier reservation** is a specific confirmed or requested booking with a supplier.

Examples:

* Cruise Cabin 8142  
* Hotel room reservation  
* Passenger PNR  
* Vineyard reservation for 24 attendees  
* Household insurance policy

A supplier reservation may be a child of a broader supplier arrangement.

## Supplier resource

A **supplier resource** is a capacity-bearing or shareable unit supplied to the agency.

Examples:

* Cruise cabin  
* Hotel room  
* Motorcoach  
* Seat allocation  
* Tour slot

A supplier resource may serve travelers from multiple client trips.

## Confirmation

A **confirmation** is the supplier’s acknowledgment or identifier for an arrangement or reservation.

The UI should specify what it identifies:

* Group contract number  
* Cabin confirmation  
* Hotel confirmation  
* PNR  
* Policy number  
* Ticket number

Avoid a single unlabeled “confirmation number” when multiple supplier records exist.

# 7\. Inventory and capacity

## Capacity

**Capacity** is the maximum number of travelers or units a resource, arrangement, package, or departure can support.

Capacity does not imply that the agency has committed to or paid for the full amount.

## Block

A **block** is capacity a supplier is holding for the agency under defined release, guarantee, or payment terms.

Examples:

* 20 hotel rooms  
* 10 balcony cabins  
* 30 airline seats

## Allotment

An **allotment** is a quantity of supplier inventory made available to the agency.

Use block when the supplier agreement describes held capacity; use allotment when inventory is allocated but not necessarily contractually guaranteed. Where the supplier uses one term explicitly, retain its terminology.

## Commitment

A **commitment** is the agency’s contractual obligation under a supplier arrangement.

It may be:

* Fixed amount  
* Minimum quantity  
* Guaranteed count  
* Nonrefundable deposit  
* Cancellation or attrition exposure

Capacity and commitment must not be used interchangeably.

## Guarantee

A **guarantee** is a quantity or amount the agency agrees to pay regardless of final usage, subject to the contract’s terms.

## Allocation

An **inventory allocation** reserves some available capacity for a client trip, traveler, or service component.

Allocation does not necessarily mean supplier confirmation.

## Assignment

A **traveler assignment** associates a traveler with a service component or supplier resource.

Examples:

* Traveler assigned to Cabin 8142  
* Traveler assigned to Coach 1  
* Traveler assigned to the July 11 hotel room

## Utilization

**Utilization** compares allocated or used capacity with committed or available capacity.

The system should label the denominator when necessary:

* 24 of 30 seats sold  
* 12 of 20 rooms allocated  
* 12 of 15 guaranteed rooms sold

## Exposure

**Exposure** is a currently expected agency cost that is not covered by client sales or recoverable commitments.

Examples:

* Three guaranteed but unsold hotel rooms  
* Fixed motorcoach cost below break-even enrollment  
* Nonrefundable supplier deposit after cancellation

Exposure is a management estimate, not necessarily a posted accounting loss.

# 8\. Financial terminology

## Client price

The **client price** is the amount the agency charges for a package, component, fee, or adjustment.

## Supplier cost

The **supplier cost** is the amount the agency expects or is required to pay for supplier fulfillment.

Client price and supplier cost must never share one generic “amount” field.

## Charge

A **charge** is an amount owed to the agency by a client.

Charges may arise from:

* Package sales  
* Optional components  
* Supplements  
* Agency fees  
* Cancellation fees  
* Adjustments

## Responsibility allocation

A **responsibility allocation** assigns a charge, or part of a charge, to a responsible client.

Allocations may be expressed as:

* Fixed amount  
* Percentage  
* Quantity  
* Share

The sum of responsibility allocations must equal the charge amount before the charge is finalized.

## Payment schedule

A **payment schedule** defines expected client installments and due dates.

A scheduled installment is not a payment.

## Receipt

A **receipt** records money received by the agency.

Use receipt for the financial event and **receipt document** for the acknowledgment given to a client.

## Payment application

A **payment application** assigns some or all of a receipt, credit, or refund to a charge or scheduled installment.

## Unapplied funds

**Unapplied funds** are client funds received but not yet assigned to a particular charge.

## Refund

A **refund** is money returned or credited back to a client or received back from a supplier.

Always qualify it where the direction is unclear:

* Client refund  
* Supplier refund

## Supplier obligation

A **supplier obligation** is an amount the agency expects or is contractually required to pay to a supplier.

It may originate from:

* Fixed commitment  
* Deposit requirement  
* Guaranteed quantity  
* Confirmed reservation  
* Final supplier invoice  
* Cancellation penalty

## Supplier payment

A **supplier payment** records money the agency sends or transfers to a supplier.

## Supplier payment application

A **supplier payment application** assigns a supplier payment or credit to one or more supplier obligations.

## Margin

**Margin** is client revenue less attributable supplier costs and other included group expenses.

The application should distinguish:

* Projected margin  
* Confirmed margin  
* Actual margin  
* Recognized margin, if accounting recognition is implemented

## Cash position

**Cash position** is the net agency-controlled cash attributable to a departure:

## $$ \\text{Receipts}

## \\text{client refunds}

\\text{supplier payments} \+ \\text{supplier refunds} $$

Cash position is not profit.

## Break-even enrollment

**Break-even enrollment** is the minimum number of paying participants needed for projected revenue to cover applicable fixed and variable costs.

# 9\. Air terminology

## Air reservation

An **air reservation** represents the itinerary and booking context, commonly identified by a PNR or record locator.

## PNR

A **PNR** is an external air-reservation identifier. It is not the client trip or ticket.

## Ticket

A **ticket** is an issued passenger-level accountable document.

One air reservation may produce multiple tickets.

## Ticket value

**Ticket value** is the fare, taxes, and applicable carrier charges represented by the ticket.

## Settlement amount

The **settlement amount** is the net amount expected or reported as due through ARC/BSP or another settlement channel for a ticket.

The application should distinguish:

* Calculated settlement amount  
* Reported settlement amount  
* Settlement variance

## Supplier-collected payment

A **supplier-collected payment** is money paid directly by a client to a supplier. It contributes to the client’s trip cost but does not enter agency-controlled cash.

## Agency-collected payment

An **agency-collected payment** is money received and controlled by the agency, even if some or all will later be remitted through settlement.

# 10\. Status terminology

Statuses should describe one object only. Avoid a universal status list.

## Departure status

* Draft  
* Planning  
* Open for sale  
* Confirmed  
* Closed for sale  
* In operation  
* Completed  
* Reconciliation  
* Closed  
* Cancelled

## Client-trip status

* Inquiry  
* Quoted  
* Optioned  
* Confirmed  
* Partially cancelled  
* Cancelled  
* Traveled  
* Closed

## Service-component status

* Proposed  
* Requested  
* Pending confirmation  
* Confirmed  
* Waitlisted  
* Unable to confirm  
* Cancelled  
* Fulfilled

## Supplier-arrangement status

* Draft  
* Requested  
* Option held  
* Contracted  
* Active  
* Final count submitted  
* Completed  
* Reconciled  
* Cancelled

## Payment status

* Scheduled  
* Due  
* Partially paid  
* Paid  
* Overdue  
* Waived  
* Cancelled

These should be derived from financial facts where possible rather than manually selected.

# 11\. Terms to avoid or qualify

| Avoid | Preferred terminology |
| :---- | :---- |
| Group, when referring to the primary record | Departure |
| Reservation, without context | Client trip, supplier reservation, or air reservation |
| Booking, without context | Package selection, client trip, or supplier arrangement |
| Customer | Client or traveler, depending on meaning |
| Passenger as a universal term | Traveler |
| Vendor | Supplier |
| Group member | Traveler, client, organizer, or group leader |
| Owner | Primary client, responsible advisor, or responsible client |
| Balance | Client balance, supplier balance, or unapplied balance |
| Payment | Receipt, supplier payment, or supplier-collected payment |
| Cost per person for a fixed resource | Effective cost per sold traveler |
| Profit, before facts are final | Projected margin |
| Inventory for every service | Blocked capacity, on-request service, or supplier resource |

# 12\. Canonical relationship statement

The core DepartureDesk relationship should be documented this way:

> A departure offers packages and services to client trips. Client trips contain travelers and client-facing service components. Supplier arrangements provide the resources and services that fulfill those components. Traveler assignments identify who receives each service, while responsibility allocations identify which clients owe the agency. Client receipts and supplier payments are tracked independently so that cash position, exposure, and margin remain explainable.

And the shortest internal shorthand is:

> **Departure → client trips → service components → supplier fulfillment** **Travelers receive; clients owe; payers remit; suppliers fulfill.**

This vocabulary gives us a stable foundation for the data model, requirements, workflows, UI labels, and reports.  
