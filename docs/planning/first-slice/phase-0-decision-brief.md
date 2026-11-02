# Phase 0 decision brief: B10, B11, M1–M4

**Status:** Draft, 2026-11-01. Not implementation authority. This brief is input to decisions that are logged in the [Product Specification](../../spec/README.md). It decides nothing itself.

**Reads with:** [first-slice charter](first-slice-charter.md), [pending decision log entries](../../spec/pending-decision-log-entries.md), [ADR 0017](../../adr/0017-user-types-permissions-and-reseller-users.md).

Phase 0 closes only when these six data-model decisions are logged, along with a reviewed data model and screen inventory (D-66). For each decision, this brief gives what the proposed default commits the data model to, the main alternative, and a recommendation. The proposed wording lives in the pending entries file and is not repeated here.

## Summary

| Ref | Recommendation | Data-model consequence | Cases that depend on it |
| --- | --- | --- | --- |
| B10 | Accept, as worded in the pending entries | Reseller relationship (one channel each), offer publication, booking owner and seller of record | D4, D15 |
| B11 | Accept, as worded in the pending entries | Departure moves from one stored `status` to three statuses and a derived label; field errors gain an icon | D16, every screen |
| M1 | Accept, as worded in the pending entries | A per-group rule naming traveler types that use no capacity | D6 |
| M2 | Accept, as worded in the pending entries | Resource shells, each with a linked position pool and a cost per resource (INV-16) | D6, D7 |
| M3 | Accept, as worded in the pending entries | Supplier rate table with components; confirmation proposes cost lines and commission | D1, D2, D4, D10 |
| M4 | Accept, as worded in the pending entries | Template lines with a basis of per traveler, per unit, per booking or percentage | D9 |

The pending entries already incorporate this brief's earlier findings: the INV-16 wording for M2, the SUP-21 carve-out for M3, the four status tables and existing tokens for B11, and staff-chosen traveler type for M1.

## B10: Resellers in Slice 1

**The default commits the data model to:**
- **Reseller users:** `AgencyUser.user_type = reseller` plus a required reseller relationship, each with a check constraint and a same-agency foreign key (ADR 0017).
- **Publication:** exactly one channel per relationship, and publication rows from offer to channel (DEP-07, ACC-14). Since a channel is one-to-one with its relationship, the data model can treat the relationship as the channel; a shared channel is later scope.
- **Bookings:** a booking owner separate from the seller of record and the booking creator (ACC-18, FIN-05).

These all have to exist from step 2 (publishing) through step 9 (the reseller path). The reseller namespace and query scope are code-only.

**Alternative (defer resellers to Slice 2):** staff book BK-105, and step 9 and D15 drop out. Publishing would have no channel to target, so DEP-07 would need an interim meaning.
- *What it saves:* the reseller namespace, the scope, and the D15 tests.
- *What it costs:* the charter's exit walkthrough by a reseller user goes. The deny-by-default boundary (ADR 0017) then gets retrofitted later over more screens, which is the very risk ADR 0017 names. The booking owner and seller-of-record columns are needed anyway once commission exists.

**Recommendation:** accept the default. The path is thin (one relationship, one assigned booking), and building the boundary while the screens are few is cheaper.

## B11: Design tokens and status labels

**What the repo already has:**
- [application.css](../../../app/assets/tailwind/application.css) defines `--dd-*` custom properties on `:root` (brand, surfaces, text, structure, interaction) and `--color-dd-*` Tailwind theme colors. There is no dark theme.
- The form sample uses the same `--dd-*` tokens, so B11 keeps them. `.dd-field-error` has no icon, and the charter's UI acceptance requires one; B11 adds it.

**Status labels.** B11 takes labels from DEP-04, BKG-06, INV-18 and INV-34, the four tables the charter's UI acceptance cites. Shipped Departures store one `status` column (`draft`, `active`, `departed`). DEP-03 requires three independent statuses: sales status, operating decision and completion. DEP-04 requires the summary label to be derived and never stored. Slice 1 step 2 therefore replaces the stored column with three status columns and a computed label. Kept M2 lifecycle code and its tests change in that step.

**Alternative:** keep the shipped Departure status and map it to labels for display. This contradicts DEP-03 and DEP-04 and the technical baseline's "Derived status", so it is not recommended.

**Recommendation:** accept: existing tokens, light theme, the field-error icon, and labels from all four tables.

## M1: Children who take part without using a position

**The default commits the data model to:** a supplier rule on an inventory group listing the traveler types that participate but use no capacity. Allocation then counts positions and headcount separately. D6 depends on this: 9 participants, 7 positions, and Luca and Milo listed without positions.

**Alternative:** a per-traveler "uses no position" flag that staff set on each allocation.
- *What it saves:* no new rule.
- *What it costs:* the supplier's terms are no longer recorded where they apply, so every booking depends on staff remembering the age rule. This conflicts with keeping supplier terms on the arrangement.

**Recommendation:** accept. The rule keys off the traveler type staff choose on the booking (BKG-21). Choosing type from age stays deferred (BKG-27), so M1 needs no change if that is later adopted. Age is shown from date of birth (CLT-06, CLT-08) but does not drive the rule.

## M2: The excursion sold per resource

**The default commits the data model to:** activity groups made of resource shells. Each shell has a position count and a fixed cost per resource. A new resource is a dated capacity increase recorded only after the supplier confirms it (INV-26). D7 depends on this: capacity goes from 10 to 20, supplier cost to $2,000, and the excursion margin to −$350.

**Observation:** INV-16 already defines a vehicle shell with a linked seat pool, and a rule that capacity is never counted twice. A resource with positions has the same shape. Writing M2 as "INV-16 applies to activity resources" reuses one structure for transportation and activities. It also gives the Phase 1 spike a single pattern to test against the existing capacity pools.

**Alternative:** use INV-12's default activity representation, a capacity pool, plus a fixed cost line at pool scope (SMN-02). The second resource is a pool increase of 10 with a second cost line.
- *What it saves:* no new rule.
- *What it costs:* nothing in the structure ties the cost to the 10 positions it buys. D7's "blocked until a second resource is confirmed" becomes a convention rather than a constraint.

**Recommendation:** accept. Applying INV-16 also brings its whole-vehicle clause, so a private booking may take a whole resource. That fits a private excursion.

## M3: Supplier rates by occupancy position, with components

**The default commits the data model to:**
- a supplier rate table on the arrangement, keyed by inventory group and occupancy position, with base fare, non-commissionable fees, taxes, discount and commission;
- confirmation that proposes cost lines (SMN-02) and expected commission (SMN-32) from that table, which staff may override.

D1, D2, D4 and D10 need these amounts. B6 (an S01 discount that looks wrong, and $0 single-occupancy taxes) is a fixture value inside this table.

**SUP-21 carve-out:** SUP-21 lets staff record components but defers *automatically splitting* rates into commissionable, non-commissionable, tax and fee parts. M3 lifts that deferral only for deriving cost lines and commission from components staff enter. Splitting a single rate into components stays deferred. The pending entry states this, so the snapshot will not hold two contradicting rules.

**Alternative:** a single amount per group and position, with staff entering the commissionable amount and rate on each booking (SMN-32 as written).
- *What it saves:* the rate-table entity and the derivation.
- *What it costs:* commission entered by hand on every booking, and the four component columns in the Alpha schedule flattened away. Rework follows when Slice 2 needs them.

**Recommendation:** accept.

## M4: Client deposit per cabin

**The default commits the data model to:** a basis on each payment schedule template line: fixed per traveler, per unit, per booking, or percentage. CMN-09's examples list per traveler and percentage only. D9 depends on this: $500 each on BK-101 and BK-104, which have 3 and 4 travelers.

**Alternative:** keep CMN-09's bases and let staff adjust the proposed installments on each booking, which CMN-09 already allows.
- *What it saves:* one enum value.
- *What it costs:* a manual correction on every Alpha booking. The template would also be wrong for the fixture's main agreement.

**Recommendation:** accept. It is a small enum on a template line, and "per unit" also covers hotel rooms later.

## After the decisions

For each decision approved:
1. Log it in the Google Doc, which issues the next free `D-` number, and apply any rule change there.
2. Re-export [the snapshot](../../spec/product-specification.md).
3. Move the entry to "Already logged" in [pending decision log entries](../../spec/pending-decision-log-entries.md).

Then write the Slice 1 data model and screen inventory.
