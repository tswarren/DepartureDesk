# DepartureDesk terminology

**Status:** Accepted product vocabulary

**Implementation note:** Agency, Agency User, Office, Session, permission, and Audit Event terminology is shipped. Client Person and person-backed Client terminology is shipped (M1A). Client Organization, organization-backed Client, organization-owned contact points, and organization-contact assignments are implemented on the M1B branch and shipped when that branch merges. Supplier and later commercial terms are not.

Use these terms consistently in requirements, code, migrations, UI labels, tests, and reports. A planned term does not authorize its implementation without an accepted slice plan.

## Agency identity

| Term | Meaning |
| --- | --- |
| Agency | The travel agency using DepartureDesk and owning tenant records. |
| Workspace code | Immutable, globally unique code used to locate an Agency before email lookup at sign-in and recovery. |
| Agency User | An account belonging to exactly one Agency. It is not a global person identity. |
| Access role | Administrator, staff, or viewer. Application permissions are checked through the named permission catalog. |
| Relationship | Descriptive workforce context on an Agency User. It grants no access. |
| Office | Agency-owned operating, attribution, defaulting, and reporting context. It is not a tenant or authorization boundary. |
| Session | Authentication record belonging to one Agency User and optionally storing a current Office preference. |
| Audit Event | Append-only evidence of a supported consequential action. It is not a general snapshot store. |

## Client identity

| Term | Meaning |
| --- | --- |
| Client Person | A consumer-side person known to an Agency. |
| Client Organization | A consumer-side organization known to an Agency. |
| Client | The stable consumer-side identity responsible for a commercial relationship or amount. A Client is based on either a Client Person or Client Organization; it is not necessarily a Traveler or the Payer of a Receipt. |
| Traveler | Contextual meaning for a Client Person referenced by a Traveler Assignment as receiving or expected to receive a travel service. MVP introduces no standalone Traveler identity record. |
| Responsible Client | The Client responsible for a particular Client Trip, Charge, or other explicitly named obligation. |
| Payer | The actual source of a Receipt. The Payer need not be the Responsible Client. |

## Supplier identity

| Term | Meaning |
| --- | --- |
| Supplier | The organization or person with whom the Agency contracts, books, or settles. |
| Service Provider | The organization or person actually delivering a service when different from the contracting Supplier. |
| Supplier Contact | A person used to communicate with a Supplier. It is not an Agency User or Client Person. |
| Supplier Location | A Supplier-owned operational place relevant to contracting or fulfillment. |

## Travel and commercial records

| Term | Meaning |
| --- | --- |
| Travel Program | Optional reusable or recurring concept from which Departures may be organized. It is not a live parent of accepted commercial records. |
| Departure | The dated operating root for one managed group-travel undertaking. |
| Supplier Arrangement | The Agency's agreement or planning relationship with a Supplier for a Departure. |
| Arrangement Item | A separately described service, resource, charge basis, or deliverable within a Supplier Arrangement. |
| Service Occurrence | A dated or otherwise bounded instance when a service is delivered. |
| Package | Optional offer container describing included, optional, or required-choice services and a Client price. |
| Client Trip | The Agency's commercial and operational relationship with one primary Client for a Departure. |
| Client Trip Service | One service selected, included, required, or added for a Client Trip. |
| Capacity Pool | The explicitly measured supply against which Holds and Allocations are made. |
| Hold | Expiring reservation of capacity for draft demand. It is not a Charge or Supplier confirmation. |
| Allocation | Confirmed consumption of declared capacity. |
| Assignment | Placement or responsibility detail that does not itself consume capacity unless its contract explicitly says so. |

## Financial records

| Term | Meaning |
| --- | --- |
| Charge | Posted Client receivable event. |
| Receipt | Agency-controlled money received from a Payer. |
| Application | Posted allocation of a Receipt, Credit, externally collected value, Supplier Payment, or Supplier Credit to a specific ledger item. |
| Supplier Obligation | Posted payable event representing an amount the Agency owes a Supplier. |
| Supplier Payment | Agency-controlled money paid to a Supplier. |
| Agency Cost | Internal or external Agency cost that must not be represented through a fabricated Supplier. |

## Terms requiring qualification

- Do not use **Party** as a model or universal identity root. Use Agency User, Client Person, Client Organization, Client, Traveler, Supplier, or Supplier Contact.
- Do not use **Group** as a record name when Departure, Client Trip, or Traveling Party is intended.
- Household, Family, and reusable consumer servicing group are deferred concepts, not current MVP records. Do not infer responsibility, travel, contact authority, occupancy, or insurance eligibility from informal relationships or shared contact values.
- Qualify **booking** as Client Trip, Supplier Reservation, air reservation, or another specific record.
- Qualify **reservation** by its owner and purpose.
- Qualify **payment** as Receipt, Supplier Payment, Supplier-collected payment, refund, or the applicable Application.
- Use **Advisor** only for an Agency Team responsibility introduced by a future accepted slice; it is not the general name for Agency Users.

The archived Party-era glossary is retained at [`archive/v0.02/terminology-party-model.md`](archive/v0.02/terminology-party-model.md) for history only.