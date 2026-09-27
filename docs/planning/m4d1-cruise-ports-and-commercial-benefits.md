# Cruise rework — sailing ports and commercial benefits

**Status:** Accepted 2026-09-26. Implementation authority for optional departure and return ports, itinerary notes, and versioned tour-conductor and GAP terms only. Not shipped.

**Parent context:** [Cruise rework decision and delivery plan](drafts/DepartureDesk-cruise-rework-plan-draft.md) and [Cruise staff journey](drafts/DepartureDesk-cruise-rework-staff-journey.md). Neither is accepted. Accepting this slice does not accept the rest of the rework, and it does not authorize Hotel or any other non-Cruise adapter.

**Scenario:** [Celebrity Beyond 2027 — Canonical Cruise Scenario](fixtures/celebrity-beyond-2027-canonical-scenario-draft.md), still Draft. Its tour-conductor and GAP sections record agreement wording and use **Terms recorded; entitlement not calculated.** They do not require entitlement statuses or an allocation flag. Amounts display the Departure operating currency.

## 1. Outcome

Staff can record sailing facts and two agreement terms without building a port engine, an itinerary engine, or a benefits calculator.

1. Optional departure port, return port, and itinerary notes on the sailing. Blank values do not block a draft.
2. The existing typed 15% commission rule, left in Supplier rate economics. It has no second source of truth in Commercial benefits.
3. A Commercial benefits section with versioned wording for tour-conductor credit and the Group Amenity Program.

The Cruise review shows a port name when it is present. It shows each saved benefit with the label **Terms recorded; entitlement not calculated.** The section also shows which agreement revision that wording represents.

## 2. Decisions this slice locks

| Topic | Contract |
| --- | --- |
| Endpoint ports | Optional names of the departure port and the return port. They are sailing facts for review and for later Client-facing wording. They are not a place catalog, a geographic code, or a required draft field. The Smith scenario leaves both blank. |
| Itinerary notes | Optional prose on the sailing form, stored in the existing Occurrence `description`. A structured port-by-port schedule stays deferred. |
| Ports of call | No structured schedule. |
| Sailing times and zones | No change. The sailing keeps one authoritative time zone. Local start and end times stay paired: both blank, or both set. Separate port zones and one-sided times stay deferred until a deadline or a Client promise needs them. |
| Normal commission | Remains the typed rate-schedule rule on commissionable fare. NCCF and taxes stay outside that basis. This slice does not add a commission field. |
| Tour-conductor credit | An agreement term. The Smith wording records the 1-per-16 qualification rule, who counts, how a Single counts, and how a credit would be valued. The slice does not apply a credit or store `projected`, `earned`, `applied`, or `forfeited`. |
| GAP points | A group-level agreement term. The Smith wording records four points expected, the forty-day expectation, the eight-stateroom condition, and the selection and forfeiture rules. The slice does not store a point count, an allocated flag, amenity selection, point purchases, or fulfillment. |
| Benefit shape | At most one term of each type on an Arrangement version. Each term has a type, a Staff summary of at most 4,000 characters, an optional short source citation, and the Arrangement version it belongs to. A successor copies it for review. An activated version freezes it. There is no numeric ratio column, point column, or entitlement-status column. |
| Activation | An empty Commercial benefits section does not block activation. Record a term when the agreement has one. Do not invent an entitlement to satisfy a gate. |
| Edits after confirmation | Staff may finish transcribing terms already agreed for the current revision. A change to wording or citation already recorded for a Supplier-confirmed revision is an amendment and needs confirmation of that amendment. The screen shows which revision the wording represents. |
| Supporting file | No file link in this slice. The optional citation keeps the brochure date identifiable. The brochure file waits for an accepted agreement-document design. |
| Marketing support | Informational only. Not a term type in this slice. |
| Client offers | Benefit wording stays on the Cruise workspace. This slice does not show it in Offer Design. Port names are not copied into published wording. A later slice may show port names as read-only Supplier context. |

Commercial benefits are Supplier agreement terms. They are not Slice 2D Client terms, and they are not the booking-dependent `$500` deposit policy.

## 3. Staff workflow

### 3.1 Sailing

On **Set up a Cruise** and **Edit sailing**, the sailing group gains:

- Departure port, optional
- Return port, optional
- Itinerary notes, optional

Saving a sailing with any of these blank remains valid. Clearing a value removes it from the draft. Saving them does not rename the Arrangement, recompute the proposed name, or change the time zone.

The Cruise workspace summary shows a port when it is present. An absent port is omitted. The summary does not say the port is unknown in a way that looks like a stored fact. Itinerary notes appear with the sailing when present.

The Smith proof saves both ports blank. A separate test saves named ports. Those names are not canonical scenario facts.

### 3.2 Commercial benefits

The Cruise workspace gains a **Commercial benefits** section, separate from Supplier rates and from deposits and deadlines.

The section states that normal commission remains in Supplier rates. It then lists saved terms. Each term shows its type, optional citation, and wording, with the status line **Terms recorded; entitlement not calculated.**

Term types are exactly:

- Tour-conductor credit
- Group Amenity Program

A version holds at most one of each. Wording is required when a term is saved. The citation is optional. An empty section is a valid draft and a valid activation. An invalid save of one term leaves the other term and the sailing facts unchanged.

A Viewer may read the section. Staff with `manage_departures` may change it only as §3.3 allows.

### 3.3 Transcription and amendment

Confirmation attests to the agreement as a whole at that revision. Benefit editing follows that boundary.

| Case | What Staff may do | What the section shows |
| --- | --- | --- |
| Draft revision, not Supplier-confirmed | Add either term, or edit its wording and citation. This is transcription of a draft. | Draft wording for this version. The group agreement is not Supplier-confirmed. |
| Supplier-confirmed revision, term not yet saved | Add the missing term. This finishes transcription of terms already agreed. It does not create a new agreement revision. | Agreed terms not yet transcribed, on the Supplier-confirmed revision. |
| Supplier-confirmed revision, term already saved | Do not edit that wording or citation in place. Create a successor and change the copy. The governing confirmation stays in force until the amendment is confirmed. | Governing version: recorded wording for that confirmed revision. Successor: proposed amendment awaiting confirmation. |
| Activated version | No in-place add or edit. Further transcription or change is a successor. | Frozen wording for that governing version. |

This slice does not add the group-confirmation command. It may transcribe terms that were already agreed. Editing draft wording must not silently change an agreement the Supplier has already confirmed. The later group-confirmation work must distinguish that transcription from an amendment to agreed terms.

Saved wording is a recorded term. The screen labels it **Terms recorded; entitlement not calculated.** It must not present that wording as a calculated entitlement or as the Supplier confirmation itself.

Until the confirmation command exists, confirmation still occurs through the shipped activation path, and an activated version is frozen. The edit command must already refuse an in-place change to wording saved on a Supplier-confirmed revision, so the later confirmation work does not reopen benefit editing.

A successor copies each saved term. Abandoning the successor leaves the governing wording in force. Activating a successor freezes the successor’s copy and does not rewrite the predecessor. Amended wording governs only after that successor is confirmed and activated. This slice does not treat an unconfirmed successor as the governing agreement.

### 3.4 Smith proof text

The tour-conductor wording used in proof must be able to state:

- one cruise-only credit per sixteen qualifying full-tariff guests, based on double occupancy;
- first- and second-position guests count;
- third and fourth passengers do not count;
- a Single paying 200% of full fare counts as two guests;
- the credit uses the average cruise fare of the categories booked, excludes NCCF, government fees, and taxes, and is net of commission;
- the 1-per-16 ratio may improve to 1 per 14 with four GAP points or 1 per 12 with six GAP points.

The GAP wording used in proof must be able to state:

- four group points, not five points per traveler;
- points are expected forty days after group creation if the group was deposited by day thirty;
- the group must retain at least eight staterooms;
- selections are due before final payment;
- unallocated points are forfeited at final payment if the group falls below eight staterooms;
- standard amenities are for full-paying guests and exclude third and fourth passengers unless the amenity says otherwise;
- additional points may be purchased at $12.50 per point per stateroom.

The citation used with either term may be `July 2025 Celebrity Groups brochure`. Those sentences are the Staff-authored record. The application does not parse them into rules.

## 4. Persistence

### 4.1 Ports and itinerary notes

Add two optional sailing fields on `service_occurrence_definitions`:

| Field | Contract |
| --- | --- |
| `departure_port_name` | Optional, blank-to-null, trimmed, maximum 160 characters |
| `return_port_name` | Optional, blank-to-null, trimmed, maximum 160 characters |

Itinerary notes use the existing `description` column and its existing 2,000-character limit. The typed sailing form labels that field **Itinerary notes**. No new description column is added.

Port names participate in the existing draft-definition freeze and in successor copy. They are not columns on the stable `ServiceOccurrence` identity. Non-Cruise forms do not show them and do not require them. Null means the other verticals are unchanged.

`departure_port_name` and `return_port_name` are the narrow authorized exception to the ADR 0008 statement that an Occurrence definition holds only name, description, schedule, zone, and provider override. That exception stands until the implementation of this slice amends ADR 0008. This acceptance does not edit the ADR. Itinerary notes reuse `description` and are not part of the exception. The exception does not add a return time zone or independent endpoint times.

Do not store port names in the Arrangement name, the sailing name, or the itinerary notes.

### 4.2 Benefit terms

Add a stable benefit identity owned by the Arrangement, and a version-owned definition, following ADR 0008.

The identity holds ownership only: agency, Departure, Arrangement, and stable id.

The definition holds:

| Field | Contract |
| --- | --- |
| `term_type` | `tour_conductor_credit` or `group_amenity_program` |
| `body` | Required trimmed text, maximum 4,000 characters |
| `source_citation` | Optional, blank-to-null, trimmed, maximum 160 characters |
| version, lineage, and lock | Same version ownership, `copied_from`, and optimistic lock as other exact-version definitions |

Rules:

- A definition belongs to one Arrangement version.
- At most one definition of each `term_type` on a version.
- `CreateSupplierArrangementSuccessor` copies each definition onto the successor. There is no live inheritance.
- An activated version’s definition is immutable in Rails and PostgreSQL, consistent with M3D.7.
- A Supplier-confirmed revision rejects an in-place change to an existing body or citation. Adding a missing type on a confirmed, not-yet-activated revision is allowed.
- The type catalog is closed. Marketing support is not a type.
- No money column, ratio, point count, status, file id, or Service Offer foreign key.
- No new `AuditEvent` action. The wording is the versioned record. Audit details are not a copy of it.

## 5. Explicitly out of this slice

- The group-confirmation command, provisional reference, and contract date. The edit boundary in §3.3 is in scope; the confirmation action is not.
- Estimate-to-contracted rate copy.
- Deposit, Hard Stop, final-payment, and `$500` policy changes.
- Same-terms capacity increases and supplemental cabin blocks.
- Agreement file upload, and any link from a benefit term to a file.
- A port catalog, geocoding, ports of call, or a day-by-day itinerary.
- A second sailing time zone, or a local time at only one end of the sailing.
- Earned tour-conductor credits, allocated GAP points, amenity selection, point purchases, fulfillment, and Marketing Fund concessions.
- Showing benefit wording in Offer Design, or copying ports or benefit wording into Client prices or published offers.
- Hotel and later non-Cruise adapters.

## 6. Proof

1. Save a Smith sailing with both ports blank and itinerary notes blank. The draft remains valid, and the summary omits the ports.
2. In a separate test, save a departure port, a return port, and itinerary notes. The summary shows the ports and notes. Renaming the ship or the itinerary name does not clear them. Those port names are not canonical fixture facts.
3. Clear one port on the draft. The other port and the itinerary notes remain.
4. Save a tour-conductor term and a GAP term with the Smith facts in §3.4 and the July 2025 citation. The section shows **Terms recorded; entitlement not calculated.** It does not show a dollar credit, a point balance, or an allocated state. It names the draft version the wording belongs to.
5. A second term of the same type on that version is rejected. A body longer than 4,000 characters is rejected. A citation longer than 160 characters is rejected.
6. Leave commission on the rate schedule. The benefits section does not become the commission editor.
7. A failed save of one term leaves the other term and the sailing facts unchanged.
8. Activate with Commercial benefits empty. Activation succeeds, and no entitlement is created.
9. Activate with both terms present. The port names and term wording are read-only. The section identifies them as the governing version.
10. Create a successor and change copied wording. The governing version’s wording is unchanged. The successor is labeled as a proposed amendment and is not the governing agreement. Abandoning the successor leaves the governing wording in force.
11. A Viewer can read the section and cannot edit it. Another agency’s identifiers return not found.
12. A non-Cruise Occurrence still saves without port names.

The later confirmation slice must prove the remaining boundary: on a Supplier-confirmed, not-yet-activated revision, adding a missing term is allowed, and changing a term already saved on that revision is rejected in place.
