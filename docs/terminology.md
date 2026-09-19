# DepartureDesk terminology

**Status:** Accepted product vocabulary

**Implementation note:** Agency, Agency User, Office, Session, permission, and Audit Event terminology is shipped. Client Person and person-backed Client terminology is shipped (M1A). Client Organization, organization-backed Client, organization-owned contact points, and organization-contact assignments are shipped (M1B). Supplier, Supplier categories, and Supplier-owned contact points are shipped (M1C). Supplier Location, Supplier Contact, and Supplier Contact-owned destinations are shipped (M1D). M1E shipped directory proof and hardening without new vocabulary. Departure draft, activation, reference issuance, return to draft, departed, scheduled departed jobs, and schedule/currency/lifecycle correction are shipped (M2A and M2B). Travel Program is a deferred, not-yet-defined concept. M2C proof is shipped and M2 is complete. The [M3 parent](planning/m3-supplier-planning.md) is accepted (amended through M3E). [M3A](planning/m3a-draft-arrangement-structure.md), [M3B](planning/m3b-supplier-capacity.md), [M3C](planning/m3c-cost-terms-and-forecasts.md), [M3D.0](planning/m3d0-planning-workspace-compression.md), and [M3D](planning/m3d-activation-reservations-confirmations.md) are shipped. Supplier Arrangement, Arrangement version, Arrangement Item, Service Occurrence, Supplier Resource, capacity, draft cost-term, guided planning-workflow, activation, Reservation, confirmation, and confirmation-triggered commitment vocabulary is shipped. [M3E](planning/m3e-supplier-operational-control.md) and [ADR 0013](adr/0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) are Accepted; M3E.1 commitment disposition, shared evidence coverage, and open-state inactivation vocabulary is shipped; M3E.2 Deadline definition, occurrence, projection, and `deadline_requirement` vocabulary is shipped. Later M3E deposit, planning-milestone, exposure, Needs attention, and Arrangement-ending vocabulary remains unimplemented. M3F remains planned vocabulary only.

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
| Travel Program | Deferred, not-yet-defined reusable or recurring concept. It is not an M2 record and is not a live parent of accepted commercial records. |
| Departure | The dated operating root for one managed group-travel undertaking. |
| Supplier Arrangement | Shipped M3A draft vocabulary. The Agency's agreement or planning relationship with one contracting Supplier for one Departure. Lifecycle is `draft`, `active`, `ended`, or `abandoned`. M3A creates only `draft` and `abandoned` arrangements. There is no Arrangement `cancelled` status. |
| Arrangement version | Shipped M3A draft vocabulary. Exact commercial definition of a Supplier Arrangement. Activated versions are immutable; successor versions govern future resolution without rewriting prior use. Lifecycle is `draft`, `activated`, `superseded`, or `abandoned`. M3A creates only the initial `draft` version and may abandon it. |
| Arrangement Item | Shipped M3A draft vocabulary. A separately described Supplier-side service, deliverable, or commercial line within a Supplier Arrangement. |
| Service Occurrence | Shipped M3A draft vocabulary. A dated or otherwise bounded performance of an Arrangement Item. Dates may fall outside the Departure operating window. Lifecycle belongs to the stable Occurrence identity for planning and inactivation as `planned` or `cancelled`. There is no Occurrence `completed` status. |
| Supplier Resource | Shipped M3A draft vocabulary. The supplied unit or category relevant to capacity or later placement, such as a cabin category, room type, or coach. |
| Supplier Reservation | Shipped M3D vocabulary. Stable Supplier-facing booking identity under an M3 Arrangement, with exact-version revisions and precise scope rows. |
| Arrangement contact | Shipped M3A vocabulary. Optional Supplier Contact used as a communication pointer for an Arrangement. It grants no authority. |
| Capacity Pool | Shipped M3B vocabulary. Explicitly measured Supplier-side supply for one Service Occurrence and Supplier Resource, with a declared inventory mode and whole-number measurement basis (`resource_units` or `traveler_positions`). `unmanaged` is Item capacity applicability, not a Pool mode. Draft configuration, the capacity engine, and M3D Staff event UI are shipped. Holds and Allocations consume capacity from M5; they are not M3 records. |
| Capacity pair classification | Shipped M3B draft vocabulary. Exact-version Occurrence–Resource decision of `pooled` or `not_applicable` for a managed Item. |
| Capacity event | Shipped M3B/M3D vocabulary. Append-only Supplier-side capacity fact (`established`, `increased`, `released`, `reinstated`, `withdrawn`, `corrected_up`, `corrected_down`). Staff surfaces ship with M3D. |
| Current Supplier capacity | Shipped M3B engine vocabulary. Rebuildable projection of applied capacity events for a numeric Pool. |
| Capacity reconciliation | Shipped M3B/M3D vocabulary. Observed Supplier quantity compared to the ledger at a point in time, with append-only resolution. Staff surfaces ship with M3D. |
| Supplier cost source | Shipped M3C draft vocabulary. Exact-version economic identity for one Supplier cost, Arrangement-wide or Item-scoped, with an explicit charging Supplier. |
| Supplier cost definition | Shipped M3C draft vocabulary. Editable estimate or contracted term definition (`working` / `forecast_ready`) for one source. Currency equals Departure `operating_currency`. |
| Cost component | Shipped M3C draft vocabulary. Typed component with economic role separate from calculation kind; explicit quantity and percentage-base semantics. |
| Charging Supplier | Shipped M3C draft vocabulary. Explicit Supplier expected to charge the Agency for a cost source; independent from Service Provider. |
| Cost usage assumption | Shipped M3C draft vocabulary. Lightweight exact Item-context planning quantities and optional anonymous occupancy profiles. Not Client demand. |
| Forecast readiness | Shipped M3C draft vocabulary. Explicit `forecast_ready` state on a cost definition after validation (and Staff attestation for contracted). Planning claim only; effective contracted terms begin at Arrangement activation under shipped M3D. |
| Supplier confirmation | Shipped M3D vocabulary. Immutable Supplier acknowledgment evidence for an Arrangement or Reservation; may include an external identifier or confirmed-without-identifier path. |
| Committed Supplier | Shipped M3D vocabulary. Explicit `committed_supplier_id` on a commitment trigger and opening snapshot; eligibility is contractor, applicable effective Provider, or charging Supplier of contracted monetary authority. |
| Commitment | Shipped M3D opening vocabulary for confirmation-triggered openings. M3E.1 ships source-shaped `confirmation_trigger` openings with append-only dispositions including `released`. M3E.2 ships `deadline_requirement` openings from Deadline occurrence plus commitment-definition line. Accepted M3E still includes `deposit_requirement` tranche openings (not yet implemented). There is no unrestricted manual opening. Explicit contractual exposure that may precede a Supplier Obligation. It is not an Obligation, invoice, or Payment. |
| Counterproposal | Shipped M3D vocabulary. Reservation scope outcome that records a Supplier counteroffer without confirming the scope, changing capacity, or opening a commitment. |
| Deposit requirement | Accepted M3E vocabulary (not yet implemented). Supplier requirement stating amount or calculation rule, due rule, and refundability; materializes as immutable tranches. It is not a Payment. |
| Deadline | Shipped M3E.2 vocabulary. Exact-version Deadline Definition with closed type/kind/rule/precision/zone/cardinality; immutable Deadline Occurrence; derived due/overdue/warning projection. Actionable or informational. Time alone does not open commitments. |
| Exposure | Accepted M3E vocabulary (not yet implemented). Qualified planning risk derived from recorded terms and commitments. It is not a posted accounting loss. |
| Package | Optional offer container describing included, optional, or required-choice services and a Client price. |
| Client Trip | The Agency's commercial and operational relationship with one primary Client for a Departure. |
| Client Trip Service | One service selected, included, required, or added for a Client Trip. |
| Hold | Expiring reservation of capacity for draft demand. It is not a Charge or Supplier confirmation. |
| Allocation | Confirmed consumption of declared capacity. |
| Assignment | Placement or responsibility detail that does not itself consume capacity unless its contract explicitly says so. |

## Supplier-planning workflow language

| Term | Meaning |
| --- | --- |
| Guided Item setup | Shipped M3D.0 workflow that creates an Item and optional first Occurrence and Resource atomically while preserving their separate M3A records. |
| Bulk capacity decision | Shipped M3D.0 workflow for reviewing and classifying multiple eligible Occurrence–Resource pairs within the existing hierarchy. It is not a capacity matrix. |
| Guided initial cost | Shipped M3D.0 workflow that creates a cost source, one definition stage, and an initial component or explicit zero-cost declaration atomically. |
| Contextual planning quantity | Explicit Staff-entered assumption or occupancy input requested where a cost calculation needs it. It is not inferred demand. |
| Readiness review | Dedicated review of a cost definition, its formulas, inputs, result or blockers, and provenance before Staff explicitly marks it forecast-ready. |
| Reorder mode | Focused keyboard-operable mode for changing Item or Resource order; routine movement controls remain outside the default reading state. |

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