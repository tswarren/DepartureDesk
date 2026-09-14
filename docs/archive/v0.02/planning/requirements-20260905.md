# DepartureDesk — Requirements Draft

## 1\. Product purpose

The application will help travel agencies plan, sell, operate, account for, and close group travel programs involving:

* Multiple travelers  
* One or more responsible clients or paying organizations  
* One or more suppliers  
* Shared or individually booked travel services  
* Blocked or on-request inventory  
* Fixed, variable, and guaranteed supplier costs  
* Client deposits and installment payments  
* Supplier deposits and payment deadlines  
* Package pricing and profitability  
* Traveler documentation and operational requirements

The application must preserve the distinctions among:

1. What the agency arranged with suppliers  
2. What the agency sold or promised to clients  
3. Which travelers receive each service  
4. Which clients are financially responsible  
5. How client services are fulfilled by supplier bookings

## 2\. Core definition

A **group** is a managed travel program associated with a departure, event, or shared itinerary.

The group provides a common operating context for:

* Supplier contracts and reservations  
* Package definitions  
* Client trips  
* Travelers  
* Inventory and capacity  
* Customer charges and payments  
* Supplier obligations and payments  
* Deadlines, documents, and tasks  
* Projected and actual financial performance

A group is not itself:

* A client  
* A household  
* A supplier reservation  
* A client reservation  
* A package  
* A payment account

Instead, it relates those records to one another.

## 3\. Supported group structures

The application must support groups where:

* The agency reserves a block with a single supplier.  
* The agency coordinates services from multiple suppliers.  
* The agency packages multiple supplier services into one client-facing product.  
* Each traveler pays separately.  
* One client or organization pays for multiple travelers.  
* Multiple clients share responsibility for one supplier reservation.  
* One client trip includes services from multiple suppliers.  
* The agency guarantees or prepays inventory before it is sold.  
* Services are booked on demand rather than from inventory.  
* Some products are included in the package while others are optional add-ons.

These structures must be combinable within the same group.

## 4\. Core domain model

### 4.1 Group

The system shall maintain a group record containing:

* Unique group identifier  
* Human-readable name  
* Short group code  
* Description  
* Group type  
* Owning agency office or branch  
* Responsible advisor or group manager  
* Organizer or group leader  
* Primary destination  
* Start and end dates  
* Sales-open and sales-close dates  
* Group status  
* Default currency  
* Default terms and policies  
* Internal notes  
* Client-facing description

Suggested lifecycle:

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

Status changes should not replace the more specific statuses of supplier arrangements, reservations, payments, or travelers.

### 4.2 Person and organization

The system shall maintain reusable records for:

* Individual people  
* Households  
* Organizations  
* Suppliers  
* Agency personnel

A person may be related to several households or organizations, but the system must identify the relevant relationship for a particular trip.

### 4.3 Group party roles

A person or organization may participate in a group as:

* Organizer  
* Group leader  
* Sponsor  
* Booking contact  
* Responsible client  
* Payer  
* Traveler  
* Emergency contact  
* Travel advisor  
* Supplier contact

A party may have more than one role.

## 5\. Client trips

A **client trip** represents the agency’s service and commercial relationship with a client or household for a particular group.

The system shall allow a client trip to contain:

* One or more travelers  
* One or more responsible clients  
* One or more package selections  
* One or more reservation components  
* Optional services and add-ons  
* Client charges  
* Payment schedules  
* Receipts, refunds, and credits  
* Terms and acknowledgments  
* Documents and communications  
* Client-trip status

The client trip must not be required to correspond one-to-one with a supplier reservation.

### 5.1 Client-trip relationships

The system shall support:

* One client trip covering several travelers  
* One traveler appearing on a client trip without being the payer  
* Multiple responsible clients on one client trip  
* Separate client trips linked as traveling companions  
* Separate client trips sharing a cabin, room, vehicle, or other supplier resource  
* Transfers of financial responsibility without changing traveler assignments  
* Separate financial statements for clients sharing a supplier resource

## 6\. Travelers and households

A **traveler** is a person who receives one or more travel services.

The system shall distinguish traveler identity from:

* Client identity  
* Payer identity  
* Reservation contact  
* Group leader  
* Household membership

### 6.1 Household relationships

The system shall support household membership for requirements such as:

* Insurance eligibility  
* Shared statements  
* Shared contact information  
* Guardian relationships  
* Joint financial responsibility

Household membership should be effective-dated or captured as a snapshot where supplier rules depend on it.

Changing a person’s general profile later must not silently alter the eligibility basis of an existing insurance policy or other confirmed booking.

## 7\. Traveling parties and shared resources

A **traveling party** links travelers or client trips that coordinate or share services without merging their financial accounts.

The system shall support traveling parties for:

* Shared cruise cabins  
* Shared hotel rooms  
* Shared rental vehicles  
* Seating requests  
* Dining arrangements  
* Traveling companions  
* Family or affinity subgroups

A traveling party shall not, by itself, determine:

* Household membership  
* Client ownership  
* Payment responsibility  
* Insurance eligibility

## 8\. Packages

A **package** represents a client-facing collection of travel services sold by the agency.

The system shall support:

* Packages created specifically for one group  
* Multiple packages within a group  
* Package versions or pricing tiers  
* Per-person, per-room, per-household, and flat pricing  
* Adult, child, occupancy, or category pricing  
* Included components  
* Optional components  
* Required component choices  
* Package capacity  
* Sales dates  
* Deposit and final-payment schedules  
* Client-facing inclusions and exclusions

A package may be sold as:

* One bundled price  
* An itemized total  
* A base package with optional add-ons

The client-facing price must remain distinct from underlying supplier costs.

## 9\. Reservation components

A **reservation component** represents a specific service sold or assigned to a client trip.

Examples include:

* Cruise passage  
* Hotel stay  
* Motorcoach transportation  
* Air ticket  
* Vineyard tasting  
* Travel insurance  
* Transfer  
* Meal  
* Excursion  
* Tour guide  
* Agency service

Each component shall identify:

* The group and client trip  
* The product or package inclusion  
* Travelers receiving the service  
* Responsible clients  
* Supplier arrangement or reservation fulfilling it  
* Service dates  
* Quantity and unit basis  
* Selling price  
* Status  
* Cancellation terms  
* Confirmation status

A component may be fulfilled by:

* One supplier reservation  
* Multiple supplier reservations  
* Agency-provided service  
* An arrangement not yet confirmed

## 10\. Supplier arrangements

A **supplier arrangement** represents a contract, block, reservation, policy, or commitment between the agency and a supplier.

The system shall support:

* Group contracts  
* Allotments and blocks  
* Individual bookings  
* On-request services  
* Charters  
* Insurance policies  
* Supplier guarantees  
* Agency-provided services

Each supplier arrangement shall contain:

* Supplier  
* Service provider, where different  
* Supplier confirmation or contract number  
* Parent arrangement  
* Service type  
* Service dates  
* Booking and confirmation status  
* Capacity  
* Cost terms  
* Commission terms  
* Deposit and final-payment deadlines  
* Cancellation, release, and attrition terms  
* Supplier contacts and documents  
* Amounts billed, paid, refunded, and outstanding

### 10.1 Arrangement hierarchy

The system shall support parent and child arrangements.

Examples:

* Cruise group agreement → individual cabin reservations  
* Hotel block → individual room reservations  
* Motorcoach contract → individual coach resources  
* Air group contract → passenger tickets  
* Insurance provider relationship → individual household policies

## 11\. Supplier resources and traveler assignments

A **supplier resource** represents a capacity-bearing or shareable item, such as:

* Cruise cabin  
* Hotel room  
* Motorcoach  
* Airline seat allocation  
* Tour departure  
* Dining table

The system shall permit:

* Multiple travelers on one resource  
* Travelers from different households on one resource  
* Travelers from different client trips on one resource  
* Changes in occupants without changing financial responsibility automatically  
* Different occupancy by date or service segment  
* Waitlisted or requested assignments

Traveler assignment and client responsibility must remain separate.

## 12\. Financial responsibility

The application shall record explicit responsibility allocations for client-facing charges.

A responsibility allocation shall identify:

* Client  
* Charge or reservation component  
* Amount, percentage, or quantity  
* Effective date  
* Reason or allocation method  
* Allocation status

The application shall support:

* One client paying the entire charge  
* Equal or unequal splits  
* Household-level responsibility  
* Sponsor contributions  
* Employer or organization subsidies  
* Responsibility transfers  
* Separate payment schedules for clients sharing one service

For any charge:

# $$ \\sum \\text{responsibility allocations}

\\text{charge amount} $$

A traveler must not automatically become financially responsible merely because they receive a service.

## 13\. Supplier costs

Supplier costs shall remain separate from client prices.

The system shall support the following cost behaviors:

| Cost behavior | Example |
| :---- | :---- |
| Fixed per departure | One tour escort |
| Fixed per resource | $3,000 per motorcoach |
| Variable per traveler | $60 vineyard tasting |
| Per room per night | Hotel accommodation |
| Per cabin | Cruise cabin |
| Minimum guarantee | At least 15 hotel rooms |
| Tiered | Different rates by attendance band |
| Stepped capacity | Second coach required after 30 travelers |
| Percentage | Commission or processing fee |
| Complimentary ratio | One free traveler per 20 paid |
| Manually estimated | Preliminary cost before contract |
| Pass-through | Client pays the supplier-defined amount |

The system shall preserve:

* Estimated cost  
* Contracted cost  
* Final billed cost  
* Adjustments  
* Supplier refunds  
* Cost recognition date

## 14\. Inventory, capacity, and commitments

The system shall distinguish:

* Available supplier capacity  
* Capacity blocked by the agency  
* Capacity guaranteed by the agency  
* Capacity allocated to reservations  
* Capacity confirmed by the supplier  
* Capacity waitlisted  
* Capacity released  
* Actual usage

### 14.1 Fixed resources

For resources such as motorcoaches, the system shall:

* Track capacity per resource  
* Track fixed cost per activated resource  
* Warn before a sale requires another resource  
* Support proposed resources not yet committed  
* Recalculate expected utilization and effective unit cost  
* Preserve the supplier’s fixed-cost structure

### 14.2 Nightly hotel inventory

Hotel inventory shall be tracked by:

* Property  
* Room type  
* Service date or night  
* Blocked rooms  
* Guaranteed rooms  
* Sold rooms  
* Released rooms  
* Remaining rooms  
* Room rate  
* Guarantee exposure

A multi-night stay may draw different nights from different arrangements or pricing terms.

### 14.3 On-request services

Services such as travel insurance or hotel extensions may be sold without reserved inventory.

The system shall track:

* Requested  
* Quoted  
* Awaiting client approval  
* Submitted to supplier  
* Confirmed  
* Declined  
* Unable to confirm  
* Cancelled

## 15\. Travel insurance

The system shall treat travel insurance as an optional, separately booked reservation component unless included by the agency’s package terms.

An insurance policy may cover one or more travelers subject to supplier eligibility rules.

The system shall support:

* Household-based policy eligibility  
* Multiple covered travelers  
* Insured trip cost by traveler  
* Quote date and expiration  
* Time-sensitive purchase deadline  
* Policy number  
* Premium  
* Coverage plan  
* Effective date  
* Supplier confirmation  
* Offer and disclosure records  
* Acceptance or declination  
* Policy documents

The system shall prevent travelers from different insurance households from being placed on one policy when the selected product prohibits it.

Sharing a cabin or room must not establish insurance-household eligibility.

## 16\. Hotel extensions

The system shall allow a client to extend a stay before or after the group’s core hotel dates.

A single client-facing hotel stay may include:

* Nights allocated from the group block  
* Nights booked on request  
* Nights at a different rate  
* Nights under a different supplier confirmation  
* Nights with different cancellation terms

The system shall preserve fulfillment, pricing, cost, and status at the nightly level when those facts differ.

## 17\. Client charges and schedules

The system shall support client charges for:

* Package purchases  
* Optional components  
* Supplements  
* Upgrades  
* Single-occupancy charges  
* Cancellation fees  
* Change fees  
* Agency service fees  
* Insurance premiums  
* Adjustments

Charges may be scheduled through:

* Initial deposit  
* Interim installments  
* Final payment  
* Ad hoc due dates

Client due dates must remain distinct from supplier payment deadlines.

## 18\. Receipts, refunds, and applications

The system shall record money received independently from the charges to which it is applied.

Each receipt shall identify:

* Paying client  
* Group  
* Client trip  
* Date  
* Amount and currency  
* Payment method  
* External transaction reference  
* Status  
* Applications to charges or installments  
* Unapplied amount

The system shall support:

* Partial payments  
* One payment covering multiple travelers or charges  
* One payment covering multiple client trips  
* Unapplied funds  
* Refunds  
* Chargebacks  
* Reversals  
* Transfers between eligible charges

Every movement of money must remain auditable.

## 19\. Supplier obligations and payments

The system shall record supplier obligations separately from client receipts.

It shall support:

* Supplier deposits  
* Scheduled installments  
* Final balances  
* Variable-count estimates  
* Guaranteed minimums  
* Final invoices  
* Supplier refunds  
* Credits  
* Adjustments  
* Payment applications

A client cancellation must not automatically eliminate a supplier obligation. Supplier cost consequences shall be determined by the applicable supplier arrangement and its current commitment state.

## 20\. Budgeting and profitability

The system shall calculate group financial performance using both projected and actual information.

Required measures include:

* Projected client revenue  
* Confirmed client revenue  
* Cash received  
* Fixed supplier cost  
* Variable supplier cost  
* Guaranteed but unsold exposure  
* Estimated total cost  
* Contracted total cost  
* Actual billed cost  
* Supplier payments  
* Projected margin  
* Actual margin  
* Cash position  
* Break-even enrollment  
* Remaining capacity  
* Effective cost per sold traveler

For a packaged departure:

# $$ \\text{Projected margin}

## \\text{Projected revenue}

## \\text{Fixed costs}

## \\text{Variable costs}

\\text{Known group expenses} $$

The system shall not treat projected margin as earned accounting income.

## 21\. Operational deadlines

The system shall track deadlines associated with:

* Client deposits  
* Client final payments  
* Supplier deposits  
* Supplier final payments  
* Inventory release dates  
* Attrition dates  
* Preliminary counts  
* Final guaranteed counts  
* Passenger-name submissions  
* Rooming lists  
* Insurance purchase windows  
* Document collection  
* Cancellation thresholds

A deadline may apply to:

* The group  
* A supplier arrangement  
* A client trip  
* A traveler  
* A reservation component

## 22\. Audit and historical integrity

The application shall preserve an auditable history of:

* Booking changes  
* Traveler assignments  
* Responsibility reallocations  
* Prices and costs  
* Supplier commitments  
* Count submissions  
* Payment applications  
* Refunds and reversals  
* Deadline changes  
* Status changes  
* User actions

Confirmed supplier facts must not be silently rewritten when client-side arrangements change.

# Proposed application areas

This domain likely divides into six main workspaces:

1. **Groups** — program overview, lifecycle, team, dates, and status  
2. **Sales and clients** — inquiries, client trips, travelers, packages, and balances  
3. **Suppliers** — contracts, bookings, blocks, costs, deadlines, and payments  
4. **Operations** — manifests, rooming, assignments, documents, tasks, and counts  
5. **Inventory** — capacity, allocations, availability, guarantees, and releases  
6. **Financials** — charges, receipts, supplier obligations, cash position, and profitability

# Decisions to address next

Before moving into screens or detailed workflows, I think we should settle these questions:

1. **Primary client container:** Should a client trip normally belong to one client/household, with other payers added through responsibility allocations, or should it be jointly owned by several clients?  
     
2. **Package scope:** Is every client purchase represented as a package, including simple cruise-only groups, or can client trips contain standalone components without a package?  
     
3. **Accounting boundary:** Will the application maintain operational group accounting only, or serve as an accounting subledger with export to systems such as QuickBooks?  
     
4. **Money custody:** Will agencies receive most client funds directly, or must the system equally support supplier-collected credit-card payments?  
     
5. **Air travel:** Should ticketing and ARC/BSP reconciliation be part of the initial product, integrated later, or treated as externally managed reservations?  
     
6. **Group variants:** Should one group contain multiple departures, or should every departure be its own group beneath a reusable program?

My preliminary recommendations are:

* One client trip should have a primary client, with additional responsibility allocations allowed.  
* Standalone components should be allowed; packages should not be mandatory.  
* Each actual departure should be its own operational group.  
* The financial model should be designed as a subledger even if the first release exports summarized entries.  
* Agency-collected and supplier-collected payments must both be supported because they produce materially different cash and reconciliation behavior.

---

That creates a sensible boundary: the application is not an ARC/BSP reconciliation system, but air tickets must participate correctly in group costing, client accounting, and profitability.

I would lock the decision this way:

> The application will track air reservations and ticket-level financial details, including the expected or reported ARC/BSP settlement amount for each ticket. It will not reconcile agency-wide ARC/BSP settlement drafts, reports, or bank withdrawals.

## Revised air-travel requirement

### 1\. Air reservations and tickets are separate records

An **air reservation** represents the itinerary and booking context:

* Supplier or validating carrier  
* GDS or booking source  
* PNR or record locator  
* Passengers  
* Flight segments  
* Group air contract, if applicable  
* Fare quote  
* Ticketing deadline  
* Reservation status

A **ticket** represents an issued accountable document:

* Ticket number  
* Passenger  
* Issuing or validating carrier  
* Issue date  
* Currency  
* Fare and tax amounts  
* Commission  
* Fees  
* Settlement amount  
* Document status  
* Original, exchange, or refund relationships

One PNR may contain multiple travelers and multiple tickets. Each ticket should remain attributable to one traveler.

## 2\. Ticket-level financial fields

The application should support these amounts separately:

| Amount | Meaning |
| :---- | :---- |
| Base fare | Fare before taxes and carrier-imposed charges |
| Taxes and fees | Government, airport, and carrier amounts |
| Total ticket amount | Total value of the issued ticket |
| Client selling price | Amount charged to the responsible client |
| Agency service fee | Separately retained agency fee |
| Standard commission | Commission deducted or earned on the ticket |
| Override/incentive | Additional expected revenue, if attributable |
| Supplier-collected amount | Amount charged directly by the carrier or supplier |
| Agency-collected amount | Amount received directly by the agency |
| ARC/BSP settlement amount | Net amount expected or reported through settlement |
| Refund amount | Value returned on a refunded document |
| Penalty | Cancellation or change penalty |
| Residual value | Unused amount retained for future application |
| Final agency revenue | Commission, fees, overrides, or markup attributable to the ticket |

Not every source will provide every field. The application should distinguish unavailable data from a genuine zero.

## 3\. Settlement amount must be stored explicitly

The application should not rely solely on a locally calculated ARC/BSP settlement amount.

Settlement can be affected by:

* Commission  
* Tax treatment  
* Carrier fees  
* Exchanges  
* Refunds  
* Penalties  
* Debit or credit memos  
* GDS or reporting differences  
* Settlement-period adjustments

The record should therefore support:

* **Calculated settlement amount**  
* **Reported settlement amount**  
* **Settlement amount source**  
* **Settlement reporting date**  
* **Settlement period or reference**  
* **Variance between calculated and reported amounts**

When a reported value exists, it becomes the authoritative ticket cost for group financial reporting, subject to later correction.

## 4\. Calculation support

For a straightforward agency-issued ticket, the preliminary calculation might be:

# $$ \\text{Expected settlement}

## \\text{ticket total}

## \\text{deductible commission}

\\text{other permitted deductions} $$

For example:

| Item | Amount |
| :---- | ----: |
| Base fare | $500 |
| Taxes and carrier fees | $100 |
| Ticket total | $600 |
| Deductible commission | ($25) |
| Expected ARC settlement | $575 |
| Agency service fee charged separately | $40 |

The client-facing and agency financial results are then:

* Client ticket charge: $600, unless supplier-collected  
* Agency service fee: $40  
* ARC settlement obligation: $575  
* Ticket commission: $25  
* Service-fee revenue: $40  
* Total expected agency revenue: $65

The application should not mistakenly treat the full $600 ticket value as agency revenue.

## 5\. Settlement status

Each ticket should carry a lightweight settlement status:

* Not applicable  
* Estimated  
* Awaiting settlement data  
* Reported  
* Corrected  
* Disputed  
* Reversed

This is ticket-level tracking, not settlement-batch reconciliation.

The application may optionally retain a settlement-period identifier so tickets can be filtered or imported together, but it need not:

* Recreate the entire ARC/BSP sales report  
* Reconcile the settlement draft to a bank account  
* Balance all tickets in an ARC/BSP reporting period  
* Manage agency-wide debit and credit memos  
* Submit data to ARC or BSP

## 6\. Air fulfillment within a group

Air should follow the same general component model as other services:

```
flowchart TD
    CT["Client trip"]
    AC["Air component"]
    PNR["Air reservation / PNR"]
    TK["Passenger ticket"]
    SF["Settlement financials"]

    CT --> AC
    AC --> PNR
    PNR --> TK
    TK --> SF
```

A client trip may contain:

* No air  
* Air for only some travelers  
* Multiple PNRs  
* Multiple carriers  
* Different outbound and return arrangements  
* Group air and independently booked air  
* Tickets issued at different times  
* Supplier-collected and agency-settled tickets

## 7\. Responsibility and traveler assignment

The passenger named on the ticket is not necessarily the responsible client.

For example:

| Ticket passenger | Responsible client | Ticket charge | Service fee |
| :---- | :---- | ----: | ----: |
| Minor traveler | Parent | $600 | $40 |
| Employee | Employer | $800 | $50 |
| Group participant | Sponsoring organization | $450 | $0 |

The air component should identify:

* Traveler receiving the flight  
* Client responsible for the ticket price  
* Client responsible for agency fees  
* Party that actually paid  
* Supplier or settlement channel receiving the ticket funds

These may be different parties.

## 8\. Supplier-collected versus agency-settled air

The application must support both patterns.

### Agency-settled ticket

* Agency collects money from the client.  
* Agency owes the reported ARC/BSP settlement amount.  
* Commission and service fees contribute to agency revenue.  
* Settlement amount appears as an agency obligation.

### Supplier-collected ticket

* Airline or supplier charges the client directly.  
* The application records the client’s total trip cost.  
* The amount is not recorded as agency-held cash.  
* The agency may still earn commission or charge a separate service fee.  
* No agency settlement obligation is created unless reported otherwise.

This distinction is essential to prevent group cash-position reports from counting funds the agency never controlled.

## 9\. Ticket lifecycle

Even without full ARC/BSP reconciliation, the application should support:

* Reserved but not ticketed  
* Ticketed  
* Voided  
* Exchanged  
* Partially exchanged  
* Refunded  
* Partially refunded  
* Used or traveled  
* No-show  
* Residual credit remaining

Financial corrections should be recorded through linked documents or adjustments rather than overwriting the original ticket.

An exchange should preserve:

* Original ticket  
* New ticket  
* Additional collection  
* Refund or residual value  
* Change penalty  
* New settlement amount  
* Effect on client balance  
* Effect on group cost and revenue

## 10\. Effect on group financials

Group reporting should separate:

* Air sold to clients  
* Air paid directly to suppliers  
* Air collected by the agency  
* Expected ARC/BSP settlement  
* Reported ARC/BSP settlement  
* Air commission  
* Agency air-service fees  
* Refunds and penalties  
* Unsettled or missing ticket data

A useful group air summary would be:

| Measure | Amount |
| :---- | ----: |
| Client air value | $18,000 |
| Supplier-collected directly | $3,000 |
| Agency-collected air value | $15,000 |
| Reported ARC/BSP settlement | $14,250 |
| Ticket commission | $750 |
| Agency service fees | $900 |
| Expected air revenue | $1,650 |

This preserves the difference between sales volume, cash custody, supplier liability, and agency revenue.

## Locked scope statement

I would add this to the requirements:

> **Air settlement scope:** The application shall maintain passenger-level air reservations and ticket records with sufficient financial detail to include air accurately in client balances, supplier obligations, cash-position reporting, and group profitability. For agency-issued tickets, it shall store the expected and reported ARC/BSP settlement amount for each accountable document. Full ARC/BSP settlement-period reconciliation, reporting submission, draft reconciliation, and bank reconciliation are outside the initial product scope.

The remaining implementation decision is how ticket and settlement details enter the application. The domain should support manual entry from the beginning and leave room for GDS, mid-office, or ARC/BSP report imports without making an integration necessary for the first release.  
